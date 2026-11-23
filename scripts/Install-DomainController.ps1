<#
.SYNOPSIS
    Richtet den Domain Controller des Exchange-Labs ein.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) auf der DC-VM.

    Phase 'Install' (Standard):
      - Datendisk F: (NTFS) fuer NTDS und SYSVOL (Host-Cache None, siehe Bicep)
      - deutsche Regionaleinstellungen
      - AD DS + DNS, neuer Forest mit Functional Level 2016 (WinThreshold),
        weil Exchange Server SE nur FFL 2012 R2/2016 unterstuetzt
      - registriert einen einmaligen Startup-Task fuer Phase 'PostReboot'
      - verzoegerter Neustart (120 s), damit der Run Command seinen Status melden kann

    Phase 'PostReboot' (einmaliger Startup-Task, SYSTEM, keine Secrets):
      - DNS-Forwarder 168.63.129.16, Reverse-Zone des Subnets, DNS-Registrierung des DC
      - Split DNS: interne Zone <PublicDomainName> mit mail/autodiscover/MX auf die interne Exchange-IP
      - schreibt Marker und entfernt den Task

    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'SafeModePasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Passwort kommt als protectedParameter und wird nur fuer Install-ADDSForest benoetigt.')]
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

    [ValidateSet('Install', 'PostReboot')]
    [string] $Phase = 'Install'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$ScriptDir = Join-Path $LabRoot 'Scripts'
$TaskName = 'ExchangeLab-CompleteDomainController'
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

function Initialize-RegionalSetting {
    Write-LabLog 'Setze deutsche Regionaleinstellungen (Zeitzone, Gebietsschema, Tastatur).'
    Set-TimeZone -Id 'W. Europe Standard Time'
    Set-WinSystemLocale -SystemLocale de-DE
    Set-WinHomeLocation -GeoId 94
    Set-Culture -CultureInfo de-DE
    Set-WinUserLanguageList -LanguageList de-DE -Force
    if (Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        # Uebernimmt die Einstellungen fuer Anmeldebildschirm und neue Benutzerprofile.
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    }
}

function Save-OwnScript {
    param([Parameter(Mandatory)][string] $Destination)
    if ($PSCommandPath -and (Test-Path -Path $PSCommandPath)) {
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

function Invoke-InstallPhase {
    if ((Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole -ge 4) {
        Write-LabLog 'Server ist bereits Domain Controller, nichts zu tun.'
        return
    }

    if (-not $SafeModePasswordB64) {
        throw 'SafeModePasswordB64 fehlt.'
    }

    Initialize-DataDisk -DriveLetter 'F' -FileSystem NTFS -Label 'ADDS'
    Initialize-RegionalSetting

    Write-LabLog 'Installiere AD DS und DNS.'
    $feature = Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
    if (-not $feature.Success) {
        throw 'Installation von AD-Domain-Services/DNS fehlgeschlagen.'
    }

    # Erst Registrierung des Startup-Tasks, dann Heraufstufung: so laeuft PostReboot garantiert nach dem Neustart.
    $scriptCopy = Join-Path $ScriptDir 'Install-DomainController.ps1'
    Save-OwnScript -Destination $scriptCopy
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Phase PostReboot -DomainName {1} -NetbiosName {2} -PublicDomainName {3} -ExchangeIp {4}' -f $scriptCopy, $DomainName, $NetbiosName, $PublicDomainName, $ExchangeIp
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-LabLog "Startup-Task $TaskName registriert."

    $safeModePassword = ConvertTo-SecureString -String (ConvertFrom-Base64String $SafeModePasswordB64) -AsPlainText -Force
    Import-Module ADDSDeployment

    Write-LabLog "Lege Forest $DomainName (NetBIOS $NetbiosName, Functional Level 2016) an."
    $forestParams = @{
        DomainName                    = $DomainName
        DomainNetbiosName             = $NetbiosName
        ForestMode                    = 'WinThreshold'
        DomainMode                    = 'WinThreshold'
        InstallDns                    = $true
        DatabasePath                  = 'F:\NTDS'
        LogPath                       = 'F:\NTDS'
        SysvolPath                    = 'F:\SYSVOL'
        SafeModeAdministratorPassword = $safeModePassword
        NoRebootOnCompletion          = $true
        Force                         = $true
        WarningAction                 = 'SilentlyContinue'
    }
    $result = Install-ADDSForest @forestParams
    if ($result.Status -ne 'Success') {
        throw "Install-ADDSForest meldet Status '$($result.Status)': $($result.Message)"
    }

    # Der erste DC nutzt sich selbst als DNS-Server.
    $adapter = Get-NetAdapter | Where-Object Status -EQ 'Up' | Select-Object -First 1
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '127.0.0.1'
    Write-LabLog "DNS-Client von Adapter $($adapter.Name) zeigt auf 127.0.0.1."

    Write-LabLog 'Forest angelegt. Neustart in 120 Sekunden.'
    & shutdown.exe /r /t 120 /c 'ExchangeLab: Neustart nach DC-Heraufstufung' /d p:4:2 | Out-Null
}

function Invoke-PostRebootPhase {
    $deadline = (Get-Date).AddMinutes(30)
    while ($true) {
        try {
            if ((Get-Service -Name NTDS).Status -eq 'Running' -and (Get-Service -Name DNS).Status -eq 'Running') {
                Import-Module ActiveDirectory
                Get-ADDomain -Identity $DomainName | Out-Null
                break
            }
        }
        catch {
            Write-LabLog "AD noch nicht bereit: $($_.Exception.Message)"
        }
        if ((Get-Date) -gt $deadline) {
            throw 'AD DS/DNS nach 30 Minuten nicht bereit.'
        }
        Start-Sleep -Seconds 20
    }
    Write-LabLog 'AD DS und DNS laufen.'

    Set-DnsServerForwarder -IPAddress '168.63.129.16'
    Write-LabLog 'DNS-Forwarder 168.63.129.16 (Azure DNS) gesetzt.'

    # Vor der DNS-Registrierung und vor dem Domaenenbeitritt der Exchange-VM, damit PTR-Records dynamisch entstehen.
    Add-ReverseLookupZone -IpAddress $ExchangeIp

    & ipconfig.exe /registerdns | Out-Null
    & nltest.exe /dsregdns | Out-Null
    Write-LabLog 'DNS-Registrierung des DC angestossen.'

    if (-not (Get-DnsServerZone -Name $PublicDomainName -ErrorAction SilentlyContinue)) {
        Add-DnsServerPrimaryZone -Name $PublicDomainName -ReplicationScope Domain
        Write-LabLog "Split-DNS-Zone $PublicDomainName angelegt."
    }
    Add-SplitDnsRecord -Zone $PublicDomainName -Name 'mail' -Type A -Value $ExchangeIp
    Add-SplitDnsRecord -Zone $PublicDomainName -Name 'autodiscover' -Type CNAME -Value "mail.$PublicDomainName."
    Add-SplitDnsRecord -Zone $PublicDomainName -Name '.' -Type MX -Value "mail.$PublicDomainName."

    Set-Content -Path $MarkerFile -Value (Get-Date -Format o) -Encoding ASCII
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-LabLog 'Domain Controller fertig eingerichtet, Startup-Task entfernt.'
}

try {
    Write-LabLog "Start (Domain $DomainName)."
    switch ($Phase) {
        'Install' { Invoke-InstallPhase }
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
