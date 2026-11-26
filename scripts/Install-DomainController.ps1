<#
.SYNOPSIS
    Richtet den Domain Controller des Exchange-Labs ein.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) auf der DC-VM.

    Phase 'Install' (Standard):
      - Datendisk F: (NTFS) fuer NTDS und SYSVOL (Host-Cache None, siehe Bicep)
      - deutsche Regionaleinstellungen
      - AD DS + DNS
      - Modus 'Forest': neuer Forest mit Functional Level 2016 (WinThreshold),
        weil Exchange Server SE nur FFL 2012 R2/2016 unterstuetzt
      - Modus 'Replica': weiterer DC in der bestehenden Domain (Domain-Admin im UPN-Format)
      - registriert einen einmaligen Startup-Task fuer Phase 'PostReboot'
      - verzoegerter Neustart (120 s), damit der Run Command seinen Status melden kann
      - hat die Windows-Wartung bereits einen Neustart vorgemerkt, verweigert dcpromo die Heraufstufung:
        dann Kennwoerter DPAPI-geschuetzt ablegen, Startup-Task fuer Phase 'Promote' registrieren, neu starten

    Phase 'Promote' (einmaliger Startup-Task, SYSTEM, nur nach vorgemerktem Neustart):
      - liest und loescht die Kennwoerter, stuft herauf wie oben, danach weiter mit 'PostReboot'

    Phase 'PostReboot' (einmaliger Startup-Task, SYSTEM, keine Secrets):
      - DNS-Forwarder 168.63.129.16, DNS-Registrierung des DC
      - nur Modus 'Forest': Reverse-Zone des Subnets und Split DNS (interne Zone <PublicDomainName>
        mit mail/autodiscover/MX auf die interne Exchange-IP); weitere DCs erhalten beides per Replikation
      - schreibt Marker und entfernt den Task

    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'SafeModePasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'AdminPasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Passwoerter kommen als protectedParameters und werden nur fuer die Heraufstufung benoetigt.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Run Command kann keine PSCredential uebergeben.')]
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $DomainName,

    [Parameter(Mandatory)]
    [string] $NetbiosName,

    [Parameter(Mandatory)]
    [string] $PublicDomainName,

    [Parameter(Mandatory)]
    [string] $ExchangeIp,

    [string] $SafeModePasswordB64,

    # Forest = erster DC (legt den Forest an), Replica = weiterer DC in der bestehenden Domain.
    [ValidateSet('Forest', 'Replica')]
    [string] $Mode = 'Forest',

    # Nur Modus Replica:
    [string] $AdminUser,
    [string] $AdminPasswordB64,
    [string] $FirstDcIp,

    # Sprache der Lab-Daten: Gebietsschema der VM (de = de-DE, en = en-GB mit deutscher Tastatur) und AD-Standorte.
    [ValidateSet('de', 'en')]
    [string] $LabLanguage = 'de',

    [ValidateSet('Install', 'Promote', 'PostReboot')]
    [string] $Phase = 'Install'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$ScriptDir = Join-Path $LabRoot 'Scripts'
$TaskName = 'ExchangeLab-CompleteDomainController'
$PromoteTaskName = 'ExchangeLab-PromoteDomainController'
$SecretDir = Join-Path $LabRoot 'Secrets'
$SecretFile = Join-Path $SecretDir 'promote.dat'
$PromoteAttemptFile = Join-Path $LabRoot 'promote-attempts.txt'
$MarkerFile = Join-Path $LabRoot 'dc-ready.txt'
$SelfText = $MyInvocation.MyCommand.ScriptBlock.ToString()

New-Item -Path $LogDir, $ScriptDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir "Install-DomainController-$Phase.log"

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Phase, $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function ConvertFrom-Base64String {
    param([Parameter(Mandatory)][string] $Value)
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function Initialize-DataDisk {
    param(
        [Parameter(Mandatory)][string] $DriveLetter,
        [Parameter(Mandatory)][ValidateSet('NTFS', 'ReFS')][string] $FileSystem,
        [Parameter(Mandatory)][string] $Label
    )

    if (Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue) {
        Write-LabLog "Laufwerk ${DriveLetter}: existiert bereits, Datendisk wird nicht neu formatiert."
        return
    }

    # Ein evtl. vorhandenes DVD-Laufwerk darf den Buchstaben nicht blockieren.
    $cdrom = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 5 AND DriveLetter = '${DriveLetter}:'"
    if ($cdrom) {
        Write-LabLog "DVD-Laufwerk belegt ${DriveLetter}: und wird nach Z: verschoben."
        Set-CimInstance -InputObject $cdrom -Property @{ DriveLetter = 'Z:' }
    }

    $disk = Get-Disk | Where-Object PartitionStyle -EQ 'RAW' | Sort-Object Number | Select-Object -First 1
    if (-not $disk) {
        throw 'Keine uninitialisierte Datendisk gefunden.'
    }

    Write-LabLog "Initialisiere Disk $($disk.Number) als ${DriveLetter}: ($FileSystem, Label $Label)."
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $DriveLetter | Out-Null
    Format-Volume -DriveLetter $DriveLetter -FileSystem $FileSystem -NewFileSystemLabel $Label -Confirm:$false | Out-Null
}

function Invoke-NativeCommand {
    # Externes Programm mit Ausgabe und Exit-Code. Windows PowerShell 5.1 wirft bei "2>&1" unter ErrorActionPreference
    # Stop schon die erste stderr-Zeile als Fehler, bevor der Exit-Code pruefbar ist (Testdeployment 2026-11-26).
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [string[]] $ArgumentList = @(),
        [int[]] $SuccessExitCodes = @(0),
        [switch] $NoThrow
    )
    $null = Get-Command -Name $FilePath -CommandType Application -ErrorAction Stop  # sonst bliebe ein alter Exit-Code stehen
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { "$_" }) }
    finally { $ErrorActionPreference = $previousPreference }
    $exitCode = $LASTEXITCODE
    if ($SuccessExitCodes -notcontains $exitCode -and -not $NoThrow) {
        throw ('{0} endete mit Exit-Code {1}: {2}' -f (Split-Path -Path $FilePath -Leaf), $exitCode, (($output | Select-Object -Last 5) -join ' '))
    }
    [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Test-CbsRebootPending {
    Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
}

function Initialize-RegionalSetting {
    # Gebietsschema der Lab-Sprache. Zeitzone immer W. Europe (Auto-Shutdown, Wartung). Englisch mit deutschem
    # Tastaturlayout, weil die Azubis an deutschen Tastaturen sitzen.
    $setting = @{
        de = @{ Culture = 'de-DE'; GeoId = 94; InputMethod = '0407:00000407' }
        en = @{ Culture = 'en-GB'; GeoId = 242; InputMethod = '0809:00000407' }
    }[$LabLanguage]
    Write-LabLog "Setze Regionaleinstellungen $($setting.Culture) (Zeitzone, Gebietsschema, Tastatur)."
    Set-TimeZone -Id 'W. Europe Standard Time'
    Set-WinSystemLocale -SystemLocale $setting.Culture
    Set-WinHomeLocation -GeoId $setting.GeoId
    Set-Culture -CultureInfo $setting.Culture
    $languageList = New-WinUserLanguageList -Language $setting.Culture
    $languageList[0].InputMethodTips.Clear()
    $languageList[0].InputMethodTips.Add($setting.InputMethod)
    Set-WinUserLanguageList -LanguageList $languageList -Force
    if (Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        # Uebernimmt die Einstellungen fuer Anmeldebildschirm und neue Benutzerprofile.
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    }
}

function Save-OwnScript {
    param([Parameter(Mandatory)][string] $Destination)
    if ($PSCommandPath -and (Test-Path -Path $PSCommandPath)) {
        # Startup-Tasks laufen bereits aus der Kopie (Phase Promote): nicht auf sich selbst kopieren.
        if ([IO.Path]::GetFullPath($PSCommandPath) -ieq [IO.Path]::GetFullPath($Destination)) {
            return
        }
        Copy-Item -Path $PSCommandPath -Destination $Destination -Force
    }
    else {
        Set-Content -Path $Destination -Value $SelfText -Encoding ASCII
    }
}

function Add-SplitDnsRecord {
    param(
        [Parameter(Mandatory)][string] $Zone,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][ValidateSet('A', 'CNAME', 'MX')][string] $Type,
        [Parameter(Mandatory)][string] $Value
    )

    $existing = Get-DnsServerResourceRecord -ZoneName $Zone -Name $Name -RRType $Type -ErrorAction SilentlyContinue
    if ($existing) {
        Write-LabLog "DNS-Record $Type $Name.$Zone existiert bereits."
        return
    }

    switch ($Type) {
        'A' { Add-DnsServerResourceRecordA -ZoneName $Zone -Name $Name -IPv4Address $Value }
        'CNAME' { Add-DnsServerResourceRecordCName -ZoneName $Zone -Name $Name -HostNameAlias $Value }
        'MX' { Add-DnsServerResourceRecordMX -ZoneName $Zone -Name $Name -MailExchange $Value -Preference 10 }
    }
    Write-LabLog "DNS-Record $Type $Name.$Zone -> $Value angelegt."
}

function Add-ReverseLookupZone {
    # /24-Reverse-Zone des Lab-Subnets. Ohne sie meldet nslookup "UnKnown" und laeuft in Timeouts.
    param([Parameter(Mandatory)][string] $IpAddress)

    $octets = $IpAddress.Split('.')
    $zoneName = '{0}.{1}.{2}.in-addr.arpa' -f $octets[2], $octets[1], $octets[0]
    if (Get-DnsServerZone -Name $zoneName -ErrorAction SilentlyContinue) {
        Write-LabLog "Reverse-Zone $zoneName existiert bereits."
        return
    }
    $networkId = '{0}.{1}.{2}.0/24' -f $octets[0], $octets[1], $octets[2]
    Add-DnsServerPrimaryZone -NetworkId $networkId -ReplicationScope Domain -DynamicUpdate Secure
    Write-LabLog "Reverse-Zone $zoneName ($networkId) angelegt."
}

# AD-Standorte je Sprache: Zentrale (alle Lab-Server) und Niederlassung (ohne DC). Gleiche Namen wie die
# Standort-OUs in scripts/data/<Sprache>/LabUsers.psd1 (ein Test prueft das).
$LabSites = @{
    de = @{ Headquarters = 'Berlin'; Branch = 'Hamburg'; HeadquartersDescription = 'Zentrale'; BranchDescription = 'Niederlassung (ohne DC)' }
    en = @{ Headquarters = 'London'; Branch = 'Manchester'; HeadquartersDescription = 'Head office'; BranchDescription = 'Branch office (no DC)' }
}

function Initialize-LabSite {
    # Default-First-Site-Name wird zur Zentrale mit dem /24 der Lab-Server. Die Niederlassung bekommt das
    # folgende /24 als nominelles Subnetz (kein Azure-Subnetz) und haengt an derselben Standortverknuepfung.
    # Idempotent und nicht fatal: Standorte sind Uebungsmaterial, die Domain funktioniert auch ohne.
    param([Parameter(Mandatory)][string] $IpAddress)

    $site = $LabSites[$LabLanguage]
    $octets = $IpAddress.Split('.')
    $subnets = @(
        @{ Name = '{0}.{1}.{2}.0/24' -f $octets[0], $octets[1], $octets[2]; Site = $site.Headquarters }
        @{ Name = '{0}.{1}.{2}.0/24' -f $octets[0], $octets[1], ([int]$octets[2] + 1); Site = $site.Branch }
    )
    try {
        $default = Get-ADReplicationSite -Filter "Name -eq 'Default-First-Site-Name'"
        if ($default) {
            Rename-ADObject -Identity $default.DistinguishedName -NewName $site.Headquarters
            Write-LabLog "AD-Standort Default-First-Site-Name in $($site.Headquarters) umbenannt."
        }
        Set-ADReplicationSite -Identity $site.Headquarters -Description $site.HeadquartersDescription
        if (-not (Get-ADReplicationSite -Filter "Name -eq '$($site.Branch)'")) {
            New-ADReplicationSite -Name $site.Branch -Description $site.BranchDescription
            Write-LabLog "AD-Standort $($site.Branch) angelegt."
        }
        foreach ($subnet in $subnets) {
            if (-not (Get-ADReplicationSubnet -Filter "Name -eq '$($subnet.Name)'")) {
                New-ADReplicationSubnet -Name $subnet.Name -Site $subnet.Site -Location $subnet.Site
                Write-LabLog "Subnetz $($subnet.Name) dem Standort $($subnet.Site) zugeordnet."
            }
        }
        $linkName = '{0}-{1}' -f $site.Headquarters, $site.Branch
        $link = Get-ADReplicationSiteLink -Filter "Name -eq 'DEFAULTIPSITELINK'"
        if ($link) {
            Rename-ADObject -Identity $link.DistinguishedName -NewName $linkName
            Write-LabLog "Standortverknuepfung DEFAULTIPSITELINK in $linkName umbenannt."
        }
        if (-not ((Get-ADReplicationSiteLink -Identity $linkName).SitesIncluded | Where-Object { $_ -like "CN=$($site.Branch),*" })) {
            Set-ADReplicationSiteLink -Identity $linkName -SitesIncluded @{ Add = $site.Branch }
            Write-LabLog "Standort $($site.Branch) in die Standortverknuepfung $linkName aufgenommen."
        }
    }
    catch {
        Write-LabLog "WARNUNG: AD-Standorte nicht vollstaendig eingerichtet: $($_.Exception.Message)"
    }
}

function Register-PhaseTask {
    # Startup-Task fuer eine spaetere Phase. Keine Secrets in den Argumenten.
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][ValidateSet('Promote', 'PostReboot')][string] $TargetPhase
    )
    $scriptCopy = Join-Path $ScriptDir 'Install-DomainController.ps1'
    Save-OwnScript -Destination $scriptCopy
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Phase {1} -DomainName {2} -NetbiosName {3} -PublicDomainName {4} -ExchangeIp {5} -Mode {6} -LabLanguage {7}' -f $scriptCopy, $TargetPhase, $DomainName, $NetbiosName, $PublicDomainName, $ExchangeIp, $Mode, $LabLanguage
    if ($Mode -eq 'Replica') {
        $arguments += " -AdminUser $AdminUser -FirstDcIp $FirstDcIp"
    }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable
    Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-LabLog "Startup-Task $Name (Phase $TargetPhase) registriert."
}

function Save-PromotionSecret {
    # DPAPI (LocalMachine), Ordner nur fuer Administratoren und SYSTEM; wird nach der Heraufstufung geloescht.
    Add-Type -AssemblyName System.Security
    New-Item -Path $SecretDir -ItemType Directory -Force | Out-Null
    Invoke-NativeCommand -FilePath 'icacls.exe' -ArgumentList @($SecretDir, '/inheritance:r', '/grant:r', '*S-1-5-32-544:(OI)(CI)F', '*S-1-5-18:(OI)(CI)F') | Out-Null
    $payload = @{ SafeModePasswordB64 = $SafeModePasswordB64; AdminPasswordB64 = $AdminPasswordB64 } | ConvertTo-Json -Compress
    $protected = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($payload), $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
    [IO.File]::WriteAllBytes($SecretFile, $protected)
}

function Get-PromotionSecret {
    Add-Type -AssemblyName System.Security
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($SecretFile), $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
    [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
}

function Invoke-InstallPhase {
    if ((Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole -ge 4) {
        Write-LabLog 'Server ist bereits Domain Controller, nichts zu tun.'
        return
    }
    if (Get-ScheduledTask -TaskName $PromoteTaskName -ErrorAction SilentlyContinue) {
        Write-LabLog 'Heraufstufung nach Neustart ist bereits geplant, nichts zu tun.'
        return
    }

    if (-not $SafeModePasswordB64) {
        throw 'SafeModePasswordB64 fehlt.'
    }
    if ($Mode -eq 'Replica') {
        foreach ($name in 'AdminUser', 'AdminPasswordB64', 'FirstDcIp') {
            if (-not (Get-Variable -Name $name -ValueOnly)) {
                throw "Parameter $name fehlt (Modus Replica)."
            }
        }
    }

    Initialize-DataDisk -DriveLetter 'F' -FileSystem NTFS -Label 'ADDS'
    Initialize-RegionalSetting

    Write-LabLog 'Installiere AD DS und DNS.'
    $feature = Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
    if (-not $feature.Success) {
        throw 'Installation von AD-Domain-Services/DNS fehlgeschlagen.'
    }

    # Windows-Wartung nach dem ersten Start (CbsTask, LanguageFeaturesOnDemand) merkt nach etwa
    # 12-16 Minuten einen Neustart vor. Danach verweigert dcpromo die Heraufstufung ("Role change is in
    # progress or this computer needs to be restarted"), auch mit -SkipPreChecks. Je nach Zeitpunkt trifft
    # das den ersten oder den weiteren DC (im Testdeployment nachgewiesen). In diesem Fall erst neu starten
    # und per Startup-Task heraufstufen. Der Run Command meldet trotzdem Erfolg: Alle nachfolgenden Schritte
    # warten ohnehin per Wait-DomainController, bis der erste DC wirklich bereit ist.
    if (Test-CbsRebootPending) {
        Save-PromotionSecret
        Register-PhaseTask -Name $PromoteTaskName -TargetPhase Promote
        Write-LabLog 'Windows-Wartung hat einen Neustart vorgemerkt (CBS RebootPending). Heraufstufung nach dem Neustart, Neustart in 60 Sekunden.'
        & shutdown.exe /r /t 60 /c 'ExchangeLab: Neustart vor der DC-Heraufstufung (Windows-Wartung)' /d p:4:2 | Out-Null
        return
    }

    Invoke-Promotion
}

function Invoke-PromotePhase {
    try {
        if ((Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole -ge 4) {
            Write-LabLog 'Server ist bereits Domain Controller, nichts zu tun.'
            return
        }
        if (Test-CbsRebootPending) {
            # Wartung noch nicht abgeschlossen: hoechstens zwei weitere Neustarts, danach abbrechen.
            $attempt = 1
            if (Test-Path -Path $PromoteAttemptFile) {
                $attempt = [int](Get-Content -Path $PromoteAttemptFile -Raw) + 1
            }
            Set-Content -Path $PromoteAttemptFile -Value $attempt -Encoding ASCII
            if ($attempt -gt 2) {
                throw 'Nach zwei weiteren Neustarts ist immer noch ein Neustart vorgemerkt, Heraufstufung abgebrochen.'
            }
            Write-LabLog "Immer noch Neustart vorgemerkt, weiterer Neustart (Versuch $attempt von 2)."
            & shutdown.exe /r /t 30 /c 'ExchangeLab: weiterer Neustart vor der DC-Heraufstufung' /d p:4:2 | Out-Null
            return
        }

        # Startup-Tasks laufen frueh im Boot: erst warten, bis das Netz bzw. der erste DC erreichbar ist.
        if ($Mode -eq 'Replica') {
            $deadline = (Get-Date).AddMinutes(10)
            while (-not (Test-NetConnection -ComputerName $FirstDcIp -Port 389 -InformationLevel Quiet -WarningAction SilentlyContinue)) {
                if ((Get-Date) -gt $deadline) {
                    throw "Erster DC $FirstDcIp nach 10 Minuten nicht per LDAP erreichbar."
                }
                Start-Sleep -Seconds 15
            }
        }
        else {
            Start-Sleep -Seconds 30
        }

        $secret = Get-PromotionSecret
        $script:SafeModePasswordB64 = $secret.SafeModePasswordB64
        $script:AdminPasswordB64 = $secret.AdminPasswordB64
        Remove-Item -Path $SecretFile -Force
        Unregister-ScheduledTask -TaskName $PromoteTaskName -Confirm:$false -ErrorAction SilentlyContinue
        Invoke-Promotion
    }
    catch {
        # Ohne Secret und Task kein endloser Kreislauf; der Fehler steht im Log.
        Remove-Item -Path $SecretFile -Force -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $PromoteTaskName -Confirm:$false -ErrorAction SilentlyContinue
        throw
    }
}

function Invoke-Promotion {
    # Erst Registrierung des Startup-Tasks, dann Heraufstufung: so laeuft PostReboot garantiert nach dem Neustart.
    Register-PhaseTask -Name $TaskName -TargetPhase PostReboot

    $safeModePassword = ConvertTo-SecureString -String (ConvertFrom-Base64String $SafeModePasswordB64) -AsPlainText -Force
    Import-Module ADDSDeployment

    $commonParams = @{
        InstallDns                    = $true
        DatabasePath                  = 'F:\NTDS'
        LogPath                       = 'F:\NTDS'
        SysvolPath                    = 'F:\SYSVOL'
        SafeModeAdministratorPassword = $safeModePassword
        NoRebootOnCompletion          = $true
        Force                         = $true
        WarningAction                 = 'SilentlyContinue'
    }

    if ($Mode -eq 'Forest') {
        Write-LabLog "Lege Forest $DomainName (NetBIOS $NetbiosName, Functional Level 2016) an."
        $result = Install-ADDSForest @commonParams -DomainName $DomainName -DomainNetbiosName $NetbiosName -ForestMode 'WinThreshold' -DomainMode 'WinThreshold'
        # Der erste DC nutzt sich selbst als DNS-Server.
        $dnsServers = @('127.0.0.1')
    }
    else {
        # UPN-Format: von einem Rechner ausserhalb der Domain scheitert NETBIOS\Benutzer.
        $adminPassword = ConvertTo-SecureString -String (ConvertFrom-Base64String $AdminPasswordB64) -AsPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$AdminUser@$DomainName", $adminPassword
        Write-LabLog "Stufe weiteren DC fuer $DomainName herauf (Quelle der Erstreplikation: $FirstDcIp)."
        $result = Install-ADDSDomainController @commonParams -DomainName $DomainName -Credential $credential
        # Erster DC zuerst, eigene Adresse nur als zweiter Eintrag (Microsoft-Empfehlung, sonst Startverzoegerung).
        $dnsServers = @($FirstDcIp, '127.0.0.1')
    }
    if ($result.Status -ne 'Success') {
        throw "Heraufstufung ($Mode) meldet Status '$($result.Status)': $($result.Message)"
    }

    $adapter = Get-NetAdapter | Where-Object Status -EQ 'Up' | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $dnsServers
    Write-LabLog "DNS-Client von Adapter $($adapter.Name) zeigt auf $($dnsServers -join ', ')."

    Write-LabLog "Heraufstufung ($Mode) abgeschlossen. Neustart in 120 Sekunden."
    & shutdown.exe /r /t 120 /c 'ExchangeLab: Neustart nach DC-Heraufstufung' /d p:4:2 | Out-Null
}

function Invoke-PostRebootPhase {
    $deadline = (Get-Date).AddMinutes(30)
    while ($true) {
        try {
            if ((Get-Service -Name NTDS).Status -eq 'Running' -and (Get-Service -Name DNS).Status -eq 'Running') {
                Import-Module ActiveDirectory
                Get-ADDomain -Identity $DomainName | Out-Null
                # Ein neuer Replikat-DC wartet nach dem ersten Start auf die AD-Erstsynchronisation.
                # Bis dahin laeuft der Dienst, die DNS-Cmdlets melden aber "Failed to get information for server".
                Get-DnsServerForwarder -ErrorAction Stop | Out-Null
                break
            }
        }
        catch {
            Write-LabLog "AD/DNS noch nicht bereit: $($_.Exception.Message)"
        }
        if ((Get-Date) -gt $deadline) {
            throw 'AD DS/DNS nach 30 Minuten nicht bereit.'
        }
        Start-Sleep -Seconds 20
    }
    Write-LabLog 'AD DS und DNS laufen.'

    # Forwarder sind pro DNS-Server gespeichert und werden nicht repliziert, also auf jedem DC setzen.
    Set-DnsServerForwarder -IPAddress '168.63.129.16'
    Write-LabLog 'DNS-Forwarder 168.63.129.16 (Azure DNS) gesetzt.'

    # Die AD-integrierten Zonen legt nur der erste DC an, weitere DCs bekommen sie per Replikation.
    if ($Mode -eq 'Forest') {
        # Vor der DNS-Registrierung und vor dem Domaenenbeitritt der Exchange-VM, damit PTR-Records dynamisch entstehen.
        Add-ReverseLookupZone -IpAddress $ExchangeIp
        # Vor der DNS-Registrierung, damit die standortbezogenen SRV-Records gleich unter dem neuen Namen entstehen.
        Initialize-LabSite -IpAddress $ExchangeIp
    }

    & ipconfig.exe /registerdns | Out-Null
    & nltest.exe /dsregdns | Out-Null
    Write-LabLog 'DNS-Registrierung des DC angestossen.'

    if ($Mode -eq 'Forest') {
        if (-not (Get-DnsServerZone -Name $PublicDomainName -ErrorAction SilentlyContinue)) {
            Add-DnsServerPrimaryZone -Name $PublicDomainName -ReplicationScope Domain
            Write-LabLog "Split-DNS-Zone $PublicDomainName angelegt."
        }
        Add-SplitDnsRecord -Zone $PublicDomainName -Name 'mail' -Type A -Value $ExchangeIp
        Add-SplitDnsRecord -Zone $PublicDomainName -Name 'autodiscover' -Type CNAME -Value "mail.$PublicDomainName."
        Add-SplitDnsRecord -Zone $PublicDomainName -Name '.' -Type MX -Value "mail.$PublicDomainName."
    }

    Set-Content -Path $MarkerFile -Value (Get-Date -Format o) -Encoding ASCII
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-LabLog 'Domain Controller fertig eingerichtet, Startup-Task entfernt.'
}

try {
    Write-LabLog "Start (Domain $DomainName)."
    switch ($Phase) {
        'Install' { Invoke-InstallPhase }
        'Promote' { Invoke-PromotePhase }
        'PostReboot' { Invoke-PostRebootPhase }
    }
    Write-LabLog 'Ende ohne Fehler.'
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    Write-LabLog $_.ScriptStackTrace
    exit 1
}
