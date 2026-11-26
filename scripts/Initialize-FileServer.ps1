<#
.SYNOPSIS
    Richtet den Fileserver des Labs ein (Freigaben, AGDLP-Berechtigungen, Basisordner, Altlasten).

.DESCRIPTION
    Phase 'Prepare' (Azure Managed Run Command als LocalSystem, vor dem Domaenenbeitritt, parallel zum DC-Aufbau):
      - legt FileServer.psd1 und LabUsers.psd1 unter C:\ExchangeLab\Scripts ab (auch fuer den Generator)
      - Datendisk F: (NTFS, Label Daten)
      - deutsche Regionaleinstellungen
      - Ordnergeruest unter F:\Shares, zunaechst nur fuer Administratoren und SYSTEM
      Keine Rolleninstallation: Die Windows-Wartung nach dem ersten Start merkt nach 12-16 Minuten einen
      Neustart vor (im Testdeployment nachgewiesen), das passiert erst nach dem Neustart des Beitritts.

    Phase 'Complete' (Run Command nach dem Domaenenbeitritt):
      - wartet auf Domaenenbeitritt
      - Rollen Dateiserver und Ressourcen-Manager fuer Dateiserver (FSRM), RSAT fuer AD, DNS und FSRM
      - Firewall-Gruppe Datei- und Druckerfreigabe (per Resource-ID, unabhaengig von der Sprache)
      - wartet auf die Lab-Benutzer (legt die Exchange-Installation an)
      - eigener PTR-Record, falls die Exchange-Installation vor dem Beitritt fertig war
      - globale Gruppen GG-* mit Mitgliedern und domaenenlokale Gruppen DL-FS-<Bereich>-M/-R (AGDLP)
      - NTFS-Berechtigungen per SID, SMB-Freigaben mit zugriffsbasierter Aufzaehlung (ABE)
      - Basisordner Home\<Benutzer> mit Besitzer und AD-Attributen HomeDrive/HomeDirectory
      - absichtliche Altlasten aus FileServer.psd1 (Kapitel 8 der Uebungen)
      - einmaliger Update-Task (Update-LabServer.ps1) und Lab-Info.txt auf dem oeffentlichen Desktop
      - optional Task TraineeLab-FileServerResize: verkleinert die VM nach Beispieldokumenten und Updates
        auf FinalVmSize (Resize-FileServer.ps1, verwaltete Identitaet der VM)

    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'AdminPasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Passwort kommt als protectedParameter und wird nur lokal fuer AD-Aufrufe verwendet.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Run Command kann keine PSCredential uebergeben.')]
[CmdletBinding()]
param(
    [ValidateSet('Prepare', 'Complete')]
    [string] $Phase = 'Prepare',

    # Sprache der Lab-Daten: Gebietsschema der VM (de = de-DE, en = en-GB mit deutscher Tastatur) und Lab-Info.
    [ValidateSet('de', 'en')]
    [string] $LabLanguage = 'de',

    # Nur Phase 'Prepare':
    [string] $LabUsersB64,
    [string] $FileServerB64,

    # Nur Phase 'Complete':
    [string] $DomainName,
    [string] $NetbiosName,
    [string] $AdminUser,
    [string] $AdminPasswordB64,
    [string] $DcComputerName,
    [string] $CompanyOu,
    [string] $UpdateScriptB64,

    # Optional: Dauergroesse der VM nach den Beispieldokumenten (leer = Groesse bleibt).
    [string] $FinalVmSize = '',
    [string] $ResizeScriptB64 = '',
    [string] $WaitForSampleDocuments = 'true',

    [int] $UserWaitMinutes = 90
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$ScriptDir = Join-Path $LabRoot 'Scripts'
$LabUsersFile = Join-Path $ScriptDir 'LabUsers.psd1'
$FileServerFile = Join-Path $ScriptDir 'FileServer.psd1'
$SampleStatusFile = Join-Path $LabRoot 'sample-documents.json'
$HomeOwnerMarker = Join-Path $LabRoot 'fs-home-owner.done'
$CompleteMarker = Join-Path $LabRoot 'fs-complete.done'
$UpdateTaskName = 'ExchangeLab-InitialUpdates'
$ResizeTaskName = 'TraineeLab-FileServerResize'

# Well-known SIDs (sprachunabhaengig).
$SidAdministrators = 'S-1-5-32-544'
$SidSystem = 'S-1-5-18'
$SidEveryone = 'S-1-1-0'
$SidAuthenticatedUsers = 'S-1-5-11'

New-Item -Path $LogDir, $ScriptDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir "Initialize-FileServer-$Phase.log"

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Phase, $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function ConvertFrom-Base64String {
    param([Parameter(Mandatory)][string] $Value)
    # loadFileAsBase64 liefert die Datei samt BOM, das Zeichen U+FEFF darf nicht im Inhalt landen.
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value)).TrimStart([char]0xFEFF)
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

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)][scriptblock] $ScriptBlock,
        [Parameter(Mandatory)][string] $Activity,
        [int] $Attempts = 3,
        [int] $DelaySeconds = 30
    )
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            return & $ScriptBlock
        }
        catch {
            Write-LabLog "$Activity - Versuch $i/$Attempts fehlgeschlagen: $($_.Exception.Message)"
            if ($i -eq $Attempts) { throw }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Content)
    # Mit BOM, damit Windows PowerShell 5.1 Umlaute korrekt liest.
    [IO.File]::WriteAllText($Path, $Content, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true))
}

function Invoke-IcaclsCommand {
    # Exit 1332 (ERROR_NONE_MAPPED): Die SID einer eben auf DC01 angelegten Gruppe ist auf dem DC, den der
    # Fileserver fragt (z. B. DC02), noch nicht repliziert. Dann warten und wiederholen (Testdeployment 2026-11-26).
    # AllowFileErrors: Bei /T /C (Besitz rekursiv) sind Fehler einzelner Dateien hinnehmbar, z. B. weil der Generator
    # parallel Dateien umbenennt; sie werden protokolliert. Erkannt wird das sprachneutral am Exit-Code
    # (2/3 Datei/Pfad fehlt, 5 Zugriff verweigert, 32 Datei in Verwendung).
    param([Parameter(Mandatory)][string[]] $Arguments, [switch] $AllowFileErrors)
    for ($attempt = 1; ; $attempt++) {
        $result = Invoke-NativeCommand -FilePath 'icacls.exe' -ArgumentList $Arguments -NoThrow
        if ($result.ExitCode -eq 0) { return }
        $text = $result.Output -join ' '
        $unmapped = $result.ExitCode -eq 1332 -or $text -match 'No mapping between account names'
        $fileErrors = @(2, 3, 5, 32) -contains $result.ExitCode -or $text -match 'Failed processing [1-9]'
        if (-not $unmapped -and $AllowFileErrors -and $fileErrors) {
            Write-LabLog "icacls $($Arguments[0]): einzelne Dateien nicht bearbeitet ($(($result.Output | Select-Object -Last 1)))."
            return
        }
        if (-not $unmapped -or $attempt -ge 20) {
            throw "icacls $($Arguments -join ' ') endete mit $($result.ExitCode): $text"
        }
        Write-LabLog "SID noch nicht aufloesbar (Replikation), neuer Versuch in 15 Sekunden ($attempt/20)."
        Start-Sleep -Seconds 15
    }
}

function Get-LocalizedAccountName {
    param([Parameter(Mandatory)][string] $Sid)
    (New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $Sid).Translate([System.Security.Principal.NTAccount]).Value
}

function Get-SharePath {
    param([Parameter(Mandatory)][hashtable] $Config, [Parameter(Mandatory)][string] $RelativePath)
    Join-Path $Config.Root $RelativePath
}

#region Phase Prepare

function Initialize-DataDisk {
    param(
        [Parameter(Mandatory)][string] $DriveLetter,
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

    Write-LabLog "Initialisiere Disk $($disk.Number) als ${DriveLetter}: (NTFS, Label $Label)."
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $DriveLetter | Out-Null
    Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel $Label -Confirm:$false | Out-Null
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

function Initialize-ShareFolder {
    param([Parameter(Mandatory)][hashtable] $Config)

    New-Item -Path $Config.Root -ItemType Directory -Force | Out-Null
    # Bis zur Phase Complete nur Administratoren und SYSTEM, die Rechte der Abteilungen kommen nach dem Beitritt.
    Invoke-IcaclsCommand -Arguments @($Config.Root, '/inheritance:r', '/grant:r', "*${SidAdministrators}:(OI)(CI)F", "*${SidSystem}:(OI)(CI)F")
    foreach ($folder in $Config.Folders) {
        New-Item -Path (Get-SharePath -Config $Config -RelativePath $folder.Path) -ItemType Directory -Force | Out-Null
    }
    Write-LabLog "Ordnergeruest unter $($Config.Root) angelegt ($($Config.Folders.Count) Ordner)."
}

function Invoke-PreparePhase {
    foreach ($name in 'LabUsersB64', 'FileServerB64') {
        if (-not (Get-Variable -Name $name -ValueOnly)) {
            throw "Parameter $name fehlt (Phase Prepare)."
        }
    }
    Write-Utf8File -Path $LabUsersFile -Content (ConvertFrom-Base64String $LabUsersB64)
    Write-Utf8File -Path $FileServerFile -Content (ConvertFrom-Base64String $FileServerB64)
    $config = Import-PowerShellDataFile -Path $FileServerFile

    Initialize-DataDisk -DriveLetter $config.DriveLetter -Label $config.VolumeLabel
    Initialize-RegionalSetting
    Initialize-ShareFolder -Config $config
}

#endregion

#region Phase Complete

function Install-FileServerRole {
    $features = 'FS-FileServer', 'FS-Resource-Manager', 'RSAT-FSRM-Mgmt', 'RSAT-AD-PowerShell', 'RSAT-DNS-Server'
    $missing = @(Get-WindowsFeature -Name $features | Where-Object { -not $_.Installed } | ForEach-Object Name)
    if ($missing) {
        $result = Invoke-WithRetry -Activity 'Install-WindowsFeature' -ScriptBlock {
            Install-WindowsFeature -Name $missing
        }
        Write-LabLog "Installiert: $($missing -join ', ') (Neustart noetig: $($result.RestartNeeded))."
    }
    else {
        Write-LabLog 'Rollen Dateiserver, FSRM und RSAT sind bereits installiert.'
    }

    # Gruppe "Datei- und Druckerfreigabe" (FirewallAPI.dll,-28502), damit SMB im VNet erreichbar ist.
    Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28502'
    Write-LabLog 'Firewall-Regeln Datei- und Druckerfreigabe aktiviert.'
}

function Register-FileServerPtrRecord {
    # Die Exchange-Installation legt PTR-Records am Ende aus den A-Records an. Tritt der Fileserver wegen der
    # Beispieldaten erst danach bei, fehlt sein Eintrag in der Reverse-Zone. Nicht fatal.
    $session = $null
    try {
        Import-Module -Name DnsServer
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1).IPAddress
        $octets = $ip.Split('.')
        $zone = '{0}.{1}.{2}.in-addr.arpa' -f $octets[2], $octets[1], $octets[0]
        $session = New-CimSession -ComputerName $AdParams.Server -Credential $AdParams.Credential
        if (Get-DnsServerResourceRecord -CimSession $session -ZoneName $zone -Name $octets[3] -RRType Ptr -ErrorAction SilentlyContinue) {
            Write-LabLog "PTR-Record fuer $ip existiert bereits."
            return
        }
        $fqdn = ('{0}.{1}.' -f $env:COMPUTERNAME, $DomainName).ToLowerInvariant()
        Add-DnsServerResourceRecordPtr -CimSession $session -ZoneName $zone -Name $octets[3] -PtrDomainName $fqdn
        Write-LabLog "PTR-Record $ip -> $fqdn angelegt."
    }
    catch {
        Write-LabLog "WARNUNG: PTR-Record nicht angelegt: $($_.Exception.Message)"
    }
    finally {
        if ($session) { Remove-CimSession -CimSession $session }
    }
}

function Wait-DomainJoinComplete {
    $deadline = (Get-Date).AddMinutes(30)
    while ($true) {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $joinPending = Test-Path -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain'
        $secureChannel = $false
        if ($computerSystem.PartOfDomain -and -not $joinPending) {
            try { $secureChannel = Test-ComputerSecureChannel } catch { $secureChannel = $false }
        }
        if ($secureChannel) {
            Write-LabLog "Domaenenbeitritt zu $($computerSystem.Domain) abgeschlossen, Secure Channel ok."
            return
        }
        if ((Get-Date) -gt $deadline) {
            throw 'Domaenenbeitritt nach 30 Minuten nicht abgeschlossen.'
        }
        Write-LabLog "Warte auf Domaenenbeitritt (Teil der Domain: $($computerSystem.PartOfDomain), Neustart ausstehend: $joinPending)."
        Start-Sleep -Seconds 20
    }
}

function Wait-LabUser {
    # Die Lab-Benutzer legt die Exchange-Installation zu Beginn ihrer Installationsphase an.
    param([Parameter(Mandatory)][string[]] $SamAccountName)

    $deadline = (Get-Date).AddMinutes($UserWaitMinutes)
    while ($true) {
        $missing = @($SamAccountName | Where-Object { -not (Get-ADUser -Filter "SamAccountName -eq '$_'" @AdParams) })
        if (-not $missing) {
            Write-LabLog "Alle $($SamAccountName.Count) Lab-Benutzer sind im AD vorhanden."
            return
        }
        if ((Get-Date) -gt $deadline) {
            throw "Lab-Benutzer nach $UserWaitMinutes Minuten nicht vorhanden: $($missing -join ', ')"
        }
        Write-LabLog "Warte auf Lab-Benutzer ($($missing.Count) fehlen, z. B. $($missing[0]))."
        Start-Sleep -Seconds 60
    }
}

function Add-LabGroup {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][ValidateSet('Global', 'DomainLocal')][string] $Scope,
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Description
    )
    $group = Get-ADGroup -Filter "Name -eq '$Name'" @AdParams
    if (-not $group) {
        New-ADGroup -Name $Name -SamAccountName $Name -GroupScope $Scope -GroupCategory Security -Path $Path -Description $Description @AdParams
        $group = Get-ADGroup -Identity $Name @AdParams
        Write-LabLog "Gruppe $Name ($Scope) angelegt."
    }
    return $group
}

function Add-LabGroupMember {
    param(
        [Parameter(Mandatory)] $Group,
        [object[]] $Member = @()
    )
    if (-not $Member) { return }
    $existing = @(Get-ADGroupMember -Identity $Group @AdParams | ForEach-Object { $_.SID.Value })
    $toAdd = @($Member | Where-Object { $existing -notcontains $_.SID.Value })
    if ($toAdd) {
        Add-ADGroupMember -Identity $Group -Members $toAdd @AdParams
        Write-LabLog "Gruppe $($Group.Name): $($toAdd.Count) Mitglied(er) hinzugefuegt."
    }
}

function Resolve-LabPrincipal {
    # Liefert das AD-Objekt eines Sonderprinzipals (@DomainUsers), einer Lab-Gruppe oder eines Benutzers.
    param([Parameter(Mandatory)][string] $Name)
    if ($Name -eq '@DomainUsers') {
        return Get-ADGroup -Identity "$($script:DomainSid)-513" @AdParams
    }
    if ($script:Groups.ContainsKey($Name)) {
        return $script:Groups[$Name]
    }
    return Get-ADUser -Identity $Name @AdParams
}

function Resolve-LabPrincipalSid {
    param([Parameter(Mandatory)][string] $Name)
    switch ($Name) {
        '@Everyone' { return $SidEveryone }
        '@AuthenticatedUsers' { return $SidAuthenticatedUsers }
        '@DomainUsers' { return "$($script:DomainSid)-513" }
    }
    return (Resolve-LabPrincipal -Name $Name).SID.Value
}

function Initialize-LabGroup {
    param([Parameter(Mandatory)][hashtable] $Config)

    $script:Groups = @{}
    foreach ($definition in $Config.GlobalGroups) {
        $group = Add-LabGroup -Name $definition.Name -Scope Global -Path "$($definition.OrganizationalUnit),$script:CompanyDn" -Description $definition.Description
        $script:Groups[$definition.Name] = $group
        Add-LabGroupMember -Group $group -Member @($definition.Members | Where-Object { $_ } | ForEach-Object { Get-ADUser -Identity $_ @AdParams })
    }

    $dlPath = "$($Config.DomainLocalGroupOrganizationalUnit),$script:CompanyDn"
    foreach ($folder in @($Config.Folders | Where-Object { $_.Stem })) {
        foreach ($variant in @(@{ Suffix = 'M'; Members = $folder.Modify }, @{ Suffix = 'R'; Members = $folder.Read })) {
            $name = 'DL-FS-{0}-{1}' -f $folder.Stem, $variant.Suffix
            $group = Add-LabGroup -Name $name -Scope DomainLocal -Path $dlPath -Description ($Config.DomainLocalGroupDescription[$variant.Suffix] -f $env:COMPUTERNAME, $folder.Path)
            $script:Groups[$name] = $group
            Add-LabGroupMember -Group $group -Member @($variant.Members | Where-Object { $_ } | ForEach-Object { Resolve-LabPrincipal -Name $_ })
        }
    }
}

function Initialize-FolderAcl {
    # Reihenfolge aus FileServer.psd1: uebergeordnete Ordner zuerst, damit die Vererbung stimmt.
    param([Parameter(Mandatory)][hashtable] $Config)

    foreach ($folder in $Config.Folders) {
        $path = Get-SharePath -Config $Config -RelativePath $folder.Path
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        $grants = @()
        if ($folder.Protected) {
            Invoke-IcaclsCommand -Arguments @($path, '/inheritance:r', '/grant:r', "*${SidAdministrators}:(OI)(CI)F", "*${SidSystem}:(OI)(CI)F")
        }
        foreach ($principal in @($folder.List | Where-Object { $_ })) {
            # Nur dieser Ordner: Inhalt sehen, ohne Vererbung in die Unterordner.
            $grants += '*{0}:(RX)' -f (Resolve-LabPrincipalSid -Name $principal)
        }
        if ($folder.Stem) {
            $grants += '*{0}:(OI)(CI)M' -f $script:Groups["DL-FS-$($folder.Stem)-M"].SID.Value
            $grants += '*{0}:(OI)(CI)RX' -f $script:Groups["DL-FS-$($folder.Stem)-R"].SID.Value
        }
        if ($grants) {
            Invoke-IcaclsCommand -Arguments (@($path, '/grant:r') + $grants)
        }
        Write-LabLog "NTFS-Rechte fuer $($folder.Path) gesetzt."
    }
}

function Initialize-LabShare {
    param([Parameter(Mandatory)][hashtable] $Config)

    $administrators = Get-LocalizedAccountName -Sid $SidAdministrators
    $authenticatedUsers = Get-LocalizedAccountName -Sid $SidAuthenticatedUsers
    foreach ($share in $Config.Shares) {
        $path = Get-SharePath -Config $Config -RelativePath $share.Path
        if (-not (Get-SmbShare -Name $share.Name -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name $share.Name -Path $path -Description $share.Description -FullAccess $administrators -ChangeAccess $authenticatedUsers -FolderEnumerationMode AccessBased | Out-Null
            Write-LabLog "Freigabe \\$env:COMPUTERNAME\$($share.Name) -> $path angelegt (ABE)."
        }
        else {
            Set-SmbShare -Name $share.Name -FolderEnumerationMode AccessBased -Description $share.Description -Force
            Grant-SmbShareAccess -Name $share.Name -AccountName $administrators -AccessRight Full -Force | Out-Null
            Grant-SmbShareAccess -Name $share.Name -AccountName $authenticatedUsers -AccessRight Change -Force | Out-Null
        }
    }
}

function Initialize-HomeFolder {
    param([Parameter(Mandatory)][hashtable] $Config, [Parameter(Mandatory)][hashtable] $LabData)

    $homeRoot = Get-SharePath -Config $Config -RelativePath $Config.HomeFolders.Path
    foreach ($user in $LabData.Users) {
        $sam = $user.SamAccountName
        $path = Join-Path $homeRoot $sam
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        $sid = (Get-ADUser -Identity $sam @AdParams).SID.Value
        Invoke-IcaclsCommand -Arguments @($path, '/grant:r', "*${sid}:(OI)(CI)M")
        if (-not (Test-Path -Path $HomeOwnerMarker)) {
            # Besitzer = Benutzer, damit Kontingente und Berichte nach Besitzer stimmen. /C: weiter bei Einzelfehlern.
            Invoke-IcaclsCommand -Arguments @($path, '/setowner', "*$sid", '/T', '/C', '/Q') -AllowFileErrors
        }
        $unc = '\\{0}\{1}\{2}' -f $env:COMPUTERNAME, $Config.HomeFolders.Share, $sam
        Set-ADUser -Identity $sam -HomeDrive $Config.HomeFolders.DriveLetter -HomeDirectory $unc @AdParams
    }
    Set-Content -Path $HomeOwnerMarker -Value (Get-Date -Format o) -Encoding ASCII
    Write-LabLog "Basisordner fuer $($LabData.Users.Count) Benutzer eingerichtet ($($Config.HomeFolders.DriveLetter) = \\$env:COMPUTERNAME\$($Config.HomeFolders.Share)\<Benutzer>)."
}

function Enable-LabRecycleBin {
    # Der geloeschte Praktikant soll aus dem AD-Papierkorb wiederherstellbar sein. Die Exchange-Installation
    # aktiviert den Papierkorb ebenfalls, wer zuerst kommt, gewinnt.
    try {
        $feature = Get-ADOptionalFeature -Identity 'Recycle Bin Feature' @AdParams
        if ($feature.EnabledScopes.Count -gt 0) { return }
        $forest = Get-ADForest @AdParams
        Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target $forest.Name -Confirm:$false @AdParams
        Write-LabLog 'AD-Papierkorb aktiviert.'
    }
    catch {
        Write-LabLog "WARNUNG: AD-Papierkorb nicht aktiviert: $($_.Exception.Message)"
    }
}

function Copy-SampleFile {
    # Kopiert einige vorhandene Dokumente samt Zeitstempeln, z. B. in den Basisordner des Praktikanten.
    param([Parameter(Mandatory)][string] $Source, [Parameter(Mandatory)][string] $Destination, [int] $Count = 12)
    New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    $files = @(Get-ChildItem -Path $Source -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -First $Count)
    foreach ($file in $files) {
        $target = Join-Path $Destination $file.Name
        if (Test-Path -LiteralPath $target) { continue }
        Copy-Item -LiteralPath $file.FullName -Destination $target
        $copy = Get-Item -LiteralPath $target
        $copy.CreationTime = $file.CreationTime
        $copy.LastWriteTime = $file.LastWriteTime
        $copy.LastAccessTime = $file.LastAccessTime
    }
}

function Add-OrphanedSid {
    param([Parameter(Mandatory)][hashtable] $Config, [Parameter(Mandatory)][hashtable] $Item)

    $marker = Join-Path $LabRoot ('fs-orphan-{0}.done' -f $Item.SamAccountName)
    if (Test-Path -Path $marker) {
        Write-LabLog "Altlast verwaiste SID ($($Item.SamAccountName)) besteht bereits."
        return
    }
    $user = Get-ADUser -Filter "SamAccountName -eq '$($Item.SamAccountName)'" @AdParams
    if (-not $user) {
        New-ADUser -Name "$($Item.GivenName) $($Item.Surname)" -SamAccountName $Item.SamAccountName -GivenName $Item.GivenName -Surname $Item.Surname -DisplayName "$($Item.GivenName) $($Item.Surname)" -Description $Item.Description -Path "$($Item.OrganizationalUnit),$script:CompanyDn" -Enabled $false @AdParams
        $user = Get-ADUser -Identity $Item.SamAccountName @AdParams
    }
    $sid = $user.SID.Value

    foreach ($relative in $Item.Paths) {
        $path = Get-SharePath -Config $Config -RelativePath $relative
        if ($relative -like "$($Config.HomeFolders.Path)\*") {
            if ($Item.SampleSource) {
                Copy-SampleFile -Source (Get-SharePath -Config $Config -RelativePath $Item.SampleSource) -Destination (Join-Path $path $Item.DocumentsFolder)
            }
            Invoke-IcaclsCommand -Arguments @($path, '/setowner', "*$sid", '/T', '/C', '/Q') -AllowFileErrors
        }
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Invoke-IcaclsCommand -Arguments @($path, '/grant', "*${sid}:(OI)(CI)$($Item.Rights)")
    }

    Remove-ADUser -Identity $user -Confirm:$false @AdParams
    Set-Content -Path $marker -Value $sid -Encoding ASCII
    Write-LabLog "Altlast verwaiste SID: $($Item.SamAccountName) ($sid) berechtigt und geloescht."
}

function Add-LegacyPermission {
    param([Parameter(Mandatory)][hashtable] $Config)

    foreach ($item in $Config.Legacy) {
        try {
            switch ($item.Type) {
                'UserAce' {
                    $path = Get-SharePath -Config $Config -RelativePath $item.Path
                    New-Item -Path $path -ItemType Directory -Force | Out-Null
                    Invoke-IcaclsCommand -Arguments @($path, '/grant', ('*{0}:(OI)(CI){1}' -f (Resolve-LabPrincipalSid -Name $item.Principal), $item.Rights))
                    Write-LabLog "Altlast direkter Benutzer: $($item.Principal) auf $($item.Path)."
                }
                'BrokenInheritance' {
                    $path = Get-SharePath -Config $Config -RelativePath $item.Path
                    New-Item -Path $path -ItemType Directory -Force | Out-Null
                    Invoke-IcaclsCommand -Arguments @($path, '/inheritance:d', '/grant', ('*{0}:(OI)(CI){1}' -f (Resolve-LabPrincipalSid -Name $item.Principal), $item.Rights))
                    Write-LabLog "Altlast unterbrochene Vererbung: $($item.Path) mit $($item.Principal)."
                }
                'OrphanedSid' {
                    Add-OrphanedSid -Config $Config -Item $item
                }
                'OwnerOnly' {
                    $marker = Join-Path $LabRoot 'fs-owneronly.done'
                    if (Test-Path -Path $marker) { break }
                    $path = Get-SharePath -Config $Config -RelativePath $item.Path
                    New-Item -Path $path -ItemType Directory -Force | Out-Null
                    $sid = Resolve-LabPrincipalSid -Name $item.Principal
                    Invoke-IcaclsCommand -Arguments @($path, '/setowner', "*$sid", '/T', '/C', '/Q') -AllowFileErrors
                    # SYSTEM bleibt (Sicherung, Wiederholungslauf), die Administratoren fehlen.
                    Invoke-IcaclsCommand -Arguments @($path, '/inheritance:r', '/grant:r', "*${sid}:(OI)(CI)F", "*${SidSystem}:(OI)(CI)F")
                    Set-Content -Path $marker -Value (Get-Date -Format o) -Encoding ASCII
                    Write-LabLog "Altlast ohne Administratoren: $($item.Path) nur fuer $($item.Principal)."
                }
                'EveryoneFull' {
                    $share = $Config.Shares | Where-Object Name -EQ $item.Share
                    $everyone = Get-LocalizedAccountName -Sid $SidEveryone
                    Grant-SmbShareAccess -Name $share.Name -AccountName $everyone -AccessRight Full -Force | Out-Null
                    Invoke-IcaclsCommand -Arguments @((Get-SharePath -Config $Config -RelativePath $share.Path), '/grant', "*${SidEveryone}:(OI)(CI)F")
                    Write-LabLog "Altlast Jeder Vollzugriff: Freigabe und NTFS $($share.Name)."
                }
                default { throw "Unbekannter Altlast-Typ $($item.Type)." }
            }
        }
        catch {
            # Altlasten sind Uebungsmaterial, ein Fehler darf den Fileserver nicht unbrauchbar machen.
            Write-LabLog "WARNUNG: Altlast $($item.Type) nicht eingerichtet: $($_.Exception.Message)"
        }
    }
}

function Register-LabUpdateTask {
    param(
        [Parameter(Mandatory)][string] $ScriptContent,
        [Parameter(Mandatory)][string] $TaskName
    )
    $scriptPath = Join-Path $ScriptDir 'Update-LabServer.ps1'
    Set-Content -Path $scriptPath -Value $ScriptContent -Encoding ASCII
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Write-LabLog "Update-Task $TaskName existiert bereits."
        return
    }
    if (Test-Path -Path (Join-Path $LabRoot 'update-runs.txt')) {
        Write-LabLog 'Update-Lauf hat bereits stattgefunden, kein neuer Task.'
        return
    }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -TaskName $TaskName"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = 'PT5M'
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4) -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Write-LabLog "Update-Task $TaskName registriert und gestartet."
}

function Register-ResizeTask {
    # Verkleinert die VM, sobald Beispieldokumente, Einrichtung und Updates fertig sind (Resize-FileServer.ps1).
    if (-not $FinalVmSize -or -not $ResizeScriptB64) {
        Write-LabLog 'Keine Dauergroesse angegeben, die VM-Groesse bleibt.'
        return
    }
    $scriptPath = Join-Path $ScriptDir 'Resize-FileServer.ps1'
    Set-Content -Path $scriptPath -Value (ConvertFrom-Base64String $ResizeScriptB64) -Encoding ASCII
    $wait = if ($WaitForSampleDocuments -eq 'false') { '$false' } else { '$true' }
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& ''{0}'' -TargetSize {1} -WaitForSampleDocuments {2}"' -f $scriptPath, $FinalVmSize, $wait
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $atStartup = New-ScheduledTaskTrigger -AtStartup
    $atStartup.Delay = 'PT10M'
    $repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(15) -RepetitionInterval (New-TimeSpan -Minutes 15)
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -StartWhenAvailable -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $ResizeTaskName -Action $action -Trigger @($atStartup, $repeat) -Principal $principal -Settings $settings -Force | Out-Null
    Write-LabLog "Task $ResizeTaskName registriert: Verkleinerung auf $FinalVmSize nach Beispieldokumenten und Updates."
}

# Texte der Lab-Info je Sprache. Der Generator schreibt seinen Status auf Deutsch (Resize-FileServer.ps1 wertet ihn aus).
$LabInfoText = @{
    de = @{
        NoStatus = 'keine (Generator nicht gelaufen)'; Status = '{0}: {1:N1} von {2} GB, {3} Dateien (Stand {4})'; StatusError = 'Status nicht lesbar: {0}'
        States = @{}; DataDrive = 'Datenlaufwerk'; Samples = 'Beispieldaten'; VmSize = 'VM-Groesse:    nach Beispieldaten und Updates automatisch {0} (Resize-FileServer.log)'
        Shares = 'FREIGABEN (zugriffsbasierte Aufzaehlung aktiv)'; Agdlp = 'BERECHTIGUNGEN NACH AGDLP'
        AgdlpLine = '  Benutzer -> globale Gruppe GG-* -> domaenenlokale Gruppe DL-FS-<Bereich>-M (Aendern) / -R (Lesen) -> NTFS'; Empty = '(leer)'
        Home = 'BASISORDNER: {0} = \\{1}\{2}\<Benutzer> (AD-Attribute HomeDrive/HomeDirectory)'
        Tail = @(
            'ROLLEN: Dateiserver, Ressourcen-Manager fuer Dateiserver (FSRM).'
            'Deduplizierung, Schattenkopien, Laufwerkszuordnung per GPO und DFS sind Uebungen.'
            'Einige Berechtigungen sind absichtlich falsch gesetzt (Altlasten fuer Uebungen).'
            ''
            'LOGS: C:\ExchangeLab\Logs (Initialize-FileServer-*.log, New-SampleDocuments.log)'
        )
    }
    en = @{
        NoStatus = 'none (generator has not run)'; Status = '{0}: {1:N1} of {2} GB, {3} files (as of {4})'; StatusError = 'status not readable: {0}'
        States = @{ 'laeuft' = 'running'; 'wird im Hintergrund fortgesetzt' = 'continuing in the background'; 'fertig' = 'done' }
        DataDrive = 'Data drive'; Samples = 'Sample data'; VmSize = 'VM size:      after sample data and updates automatically {0} (Resize-FileServer.log)'
        Shares = 'SHARES (access-based enumeration enabled)'; Agdlp = 'PERMISSIONS (AGDLP)'
        AgdlpLine = '  user -> global group GG-* -> domain local group DL-FS-<area>-M (modify) / -R (read) -> NTFS'; Empty = '(empty)'
        Home = 'HOME FOLDERS: {0} = \\{1}\{2}\<user> (AD attributes HomeDrive/HomeDirectory)'
        Tail = @(
            'ROLES: File Server, File Server Resource Manager (FSRM).'
            'Deduplication, shadow copies, drive mapping by GPO and DFS are exercises.'
            'Some permissions are deliberately wrong (legacy issues for exercises).'
            ''
            'LOGS: C:\ExchangeLab\Logs (Initialize-FileServer-*.log, New-SampleDocuments.log)'
        )
    }
}[$LabLanguage]

function Get-SampleStatusText {
    if (-not (Test-Path -Path $SampleStatusFile)) {
        return $LabInfoText.NoStatus
    }
    try {
        $status = Get-Content -Path $SampleStatusFile -Raw | ConvertFrom-Json
        $state = if ($LabInfoText.States.ContainsKey([string]$status.State)) { $LabInfoText.States[[string]$status.State] } else { $status.State }
        return $LabInfoText.Status -f $state, $status.WrittenGB, $status.TargetGB, $status.Files, $status.Updated
    }
    catch {
        return $LabInfoText.StatusError -f $_.Exception.Message
    }
}

function Publish-FileServerDesktop {
    param([Parameter(Mandatory)][hashtable] $Config)

    try {
        $desktop = Join-Path $env:PUBLIC 'Desktop'
        $lines = @(
            "FILESERVER $env:COMPUTERNAME"
            ''
            '{0,-15}{1}' -f 'Domain:', "$DomainName (NetBIOS $NetbiosName)"
            '{0,-15}{1}' -f "$($LabInfoText.DataDrive):", $Config.Root
            '{0,-15}{1}' -f "$($LabInfoText.Samples):", (Get-SampleStatusText)
            $(if ($FinalVmSize) { $LabInfoText.VmSize -f $FinalVmSize } else { '' })
            ''
            $LabInfoText.Shares
        )
        foreach ($share in $Config.Shares) {
            $lines += '  {0,-40} {1}' -f "\\$env:COMPUTERNAME\$($share.Name)", $share.Description
        }
        $lines += ''
        $lines += $LabInfoText.Agdlp
        $lines += $LabInfoText.AgdlpLine
        foreach ($group in $Config.GlobalGroups) {
            $members = if ($group.Members) { $group.Members -join ', ' } else { $LabInfoText.Empty }
            $lines += '  {0,-24} {1}' -f $group.Name, $members
        }
        $lines += ''
        $lines += $LabInfoText.Home -f $Config.HomeFolders.DriveLetter, $env:COMPUTERNAME, $Config.HomeFolders.Share
        $lines += ''
        $lines += $LabInfoText.Tail
        Write-Utf8File -Path (Join-Path $desktop 'Lab-Info.txt') -Content ($lines -join "`r`n")
        Write-LabLog "Lab-Info auf $desktop abgelegt."
    }
    catch {
        Write-LabLog "WARNUNG: Lab-Info nicht abgelegt: $($_.Exception.Message)"
    }
}

function Invoke-CompletePhase {
    foreach ($name in 'DomainName', 'NetbiosName', 'AdminUser', 'AdminPasswordB64', 'DcComputerName', 'CompanyOu', 'UpdateScriptB64') {
        if (-not (Get-Variable -Name $name -ValueOnly)) {
            throw "Parameter $name fehlt (Phase Complete)."
        }
    }
    $config = Import-PowerShellDataFile -Path $FileServerFile
    $labData = Import-PowerShellDataFile -Path $LabUsersFile

    Wait-DomainJoinComplete
    Install-FileServerRole
    Import-Module -Name ActiveDirectory
    $password = ConvertTo-SecureString -String (ConvertFrom-Base64String $AdminPasswordB64) -AsPlainText -Force
    # Alle AD-Aufrufe gegen den ersten DC, damit neu angelegte Objekte sofort lesbar sind.
    $script:AdParams = @{
        Server     = "$DcComputerName.$DomainName"
        Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$NetbiosName\$AdminUser", $password
    }
    $domain = Get-ADDomain @AdParams
    $script:DomainSid = $domain.DomainSID.Value
    $script:CompanyDn = "OU=$CompanyOu,$($domain.DistinguishedName)"

    Wait-LabUser -SamAccountName @($labData.Users | ForEach-Object SamAccountName)
    Register-FileServerPtrRecord
    Initialize-LabGroup -Config $config
    Initialize-FolderAcl -Config $config
    Initialize-LabShare -Config $config
    Initialize-HomeFolder -Config $config -LabData $labData
    Enable-LabRecycleBin
    Add-LegacyPermission -Config $config
    Register-LabUpdateTask -ScriptContent (ConvertFrom-Base64String $UpdateScriptB64) -TaskName $UpdateTaskName
    Publish-FileServerDesktop -Config $config
    Set-Content -Path $CompleteMarker -Value (Get-Date -Format 's') -Encoding ASCII
    Register-ResizeTask
}

#endregion

try {
    Write-LabLog 'Start.'
    switch ($Phase) {
        'Prepare' { Invoke-PreparePhase }
        'Complete' { Invoke-CompletePhase }
    }
    Write-LabLog 'Ende ohne Fehler.'
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    Write-LabLog $_.ScriptStackTrace
    exit 1
}
