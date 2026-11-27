<#
.SYNOPSIS
    Bereitet die Exchange-VM vor dem Domaenenbeitritt vor.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) parallel zum Aufbau des Domain Controllers.
    Startet keinen Neustart: offene Neustarts erledigt der anschliessende Domaenenbeitritt.

      - Auslagerungsdatei fest auf 25 % RAM (Vorgabe Exchange Server SE)
      - Datendisk F: als ReFS (64K, Integrity Streams aus) fuer Datenbanken und Logs
      - deutsche Regionaleinstellungen
      - Windows-Features laut Exchange-SE-Voraussetzungen (Mailbox-Rolle, ohne ADLDS),
        dazu DNS-Konsole und GPMC fuer die Verwaltung vom Jump-Host aus
      - Remote Registry auf Automatisch (Exchange-Voraussetzung)
      - PowerShell 7 (LTS) als Laufzeit fuer winget: Die winget-CLI ist im SYSTEM-Kontext nicht
        supportet, das Modul Microsoft.WinGet.Client laeuft nur unter PowerShell 7.
        Exchange nutzt weiterhin nur Windows PowerShell 5.1 (Side-by-Side ist zulaessig).
      - winget: VC++ 2012/2013, IIS URL Rewrite und optionale Tools,
        Fallback fuer die Exchange-Voraussetzungen: Microsoft-Download mit SHA256-Pruefung
      - CSS-Exchange-Diagnose (HealthChecker, SetupAssist, SetupLogReviewer) nach C:\ExchangeLab\Tools
      - Exchange-SE-ISO laden (SHA256-Pruefung, Neudownload bei Abweichung) und entpacken,
        UCMA 4.0 aus \UCMARedist installieren
      - optional Let's-Encrypt-Wildcard-Zertifikat ueber die Managed Identity der VM

    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $PublicDomainName,

    [Parameter(Mandatory)]
    [string] $IsoUri,

    # SHA256 des ISO; leer = keine Pruefung (eigenes ISO ohne bekannten Hash).
    [string] $IsoSha256 = '',

    [Parameter(Mandatory)]
    [string] $SubscriptionId,

    # Komma-getrennte winget-Paket-IDs fuer optionale Tools.
    [string] $WingetPackages = '',

    [ValidateSet('true', 'false')]
    [string] $EnableLetsEncrypt = 'true',

    [ValidateSet('true', 'false')]
    [string] $LetsEncryptStaging = 'false',

    # Sprache der Lab-Daten: Gebietsschema der VM (de = de-DE, en = en-GB mit deutscher Tastatur).
    [ValidateSet('de', 'en')]
    [string] $LabLanguage = 'de'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$InstallDir = Join-Path $LabRoot 'Install'
$MediaDir = Join-Path $LabRoot 'Media\ExchangeSE'
$CertDir = 'C:\Certificates'
$ToolsDir = Join-Path $LabRoot 'Tools'
$PoshAcmeHome = 'C:\ProgramData\Posh-ACME'
$PwshExe = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
# Feste Modulversionen aus der PowerShell Gallery (getestet), damit eine neue Version kein Deployment bricht.
$PoshAcmeVersion = '4.35.0'
$WinGetClientVersion = '1.29.380'

# Diagnose-Skripte aus microsoft/CSS-Exchange, festes Release (SHA256 aus den Release-Assets,
# Dateien von Microsoft signiert). Beim Aktualisieren Tag und Hashes gemeinsam aendern.
$CssExchangeRelease = 'v26.11.03.2200'
$LabTools = @(
    @{ Name = 'HealthChecker.ps1'; Sha256 = '512532445dc02b2b0a37d5ab6b7520f9cf5697df11797de3677c47136ebaaa18' }
    @{ Name = 'SetupAssist.ps1'; Sha256 = '5a94860b765e233ecee6080e55ee6a9e8e31d184f1956385ab372cb8ae1c9d5e' }
    @{ Name = 'SetupLogReviewer.ps1'; Sha256 = '9df2e070c6899278d49c4142e05b24641a53bba5daec7848ea19d3f13fa340c8' }
) | ForEach-Object {
    $_.Url = 'https://github.com/microsoft/CSS-Exchange/releases/download/{0}/{1}' -f $CssExchangeRelease, $_.Name
    $_
}

# PowerShell 7 LTS, Quelle: GitHub-Release PowerShell/PowerShell (SHA256 aus den Release-Assets).
$PowerShell7 = @{
    Id        = 'Microsoft.PowerShell'
    Url       = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.9/PowerShell-7.6.9-win-x64.msi'
    Sha256    = '50d33c7494aaf82b987cfd4de3f232d04f91fdd4c0deeca8a669cced3e7cf8f9'
    Arguments = '/quiet /norestart ADD_PATH=1 DISABLE_TELEMETRY=1 USE_MU=0 ENABLE_MU=0'
}

# Laeuft unter PowerShell 7 als SYSTEM und installiert die uebergebenen winget-Pakete maschinenweit.
$WinGetHelperScript = @'
param([Parameter(Mandatory)][string] $Ids, [Parameter(Mandatory)][string] $ModuleVersion)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client | Where-Object { $_.Version -eq [version]$ModuleVersion })) {
    Install-Module -Name Microsoft.WinGet.Client -RequiredVersion $ModuleVersion -Scope AllUsers -Force
}
Import-Module -Name Microsoft.WinGet.Client -RequiredVersion $ModuleVersion
foreach ($id in $Ids.Split(',')) {
    try {
        $result = Install-WinGetPackage -Id $id -Source winget -MatchOption Equals -Mode Silent -Scope SystemOrUnknown -Force
        'RESULT|{0}|{1}|{2}' -f $id, $result.Status, $result.InstallerErrorCode
    }
    catch {
        'RESULT|{0}|Error|{1}' -f $id, $_.Exception.Message
    }
}
'@

New-Item -Path $LogDir, $InstallDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir 'Initialize-ExchangeServer.log'

# Voraussetzungen fuer Exchange Server SE (Mailbox, Desktop Experience), Quelle:
# https://learn.microsoft.com/exchange/plan-and-deploy/prerequisites
$ExchangeWindowsFeatures = @(
    'Server-Media-Foundation', 'NET-Framework-45-Core', 'NET-Framework-45-ASPNET', 'NET-WCF-HTTP-Activation45',
    'NET-WCF-Pipe-Activation45', 'NET-WCF-TCP-Activation45', 'NET-WCF-TCP-PortSharing45', 'RPC-over-HTTP-proxy',
    'RSAT-Clustering', 'RSAT-Clustering-CmdInterface', 'RSAT-Clustering-Mgmt', 'RSAT-Clustering-PowerShell',
    'WAS-Process-Model', 'Web-Asp-Net45', 'Web-Basic-Auth', 'Web-Client-Auth', 'Web-Digest-Auth', 'Web-Dir-Browsing',
    'Web-Dyn-Compression', 'Web-Http-Errors', 'Web-Http-Logging', 'Web-Http-Redirect', 'Web-Http-Tracing',
    'Web-ISAPI-Ext', 'Web-ISAPI-Filter', 'Web-Metabase', 'Web-Mgmt-Console', 'Web-Mgmt-Service', 'Web-Net-Ext45',
    'Web-Request-Monitor', 'Web-Server', 'Web-Stat-Compression', 'Web-Static-Content', 'Web-Windows-Auth', 'Web-WMI',
    'Windows-Identity-Foundation', 'RSAT-ADDS', 'RSAT-AD-PowerShell'
)

# Keine Exchange-Voraussetzung: DNS-Konsole und GPMC, damit der Exchange-Server als Jump-Host
# fuer DNS und Gruppenrichtlinien reicht und niemand dafuer auf den DC muss.
$AdminToolFeatures = @('RSAT-DNS-Server', 'GPMC')

# Pflicht-Pakete. Fallback-Daten (URL, SHA256) stammen aus den winget-Manifesten.
$RequiredPackages = @(
    @{
        Id        = 'Microsoft.VCRedist.2012.x64'
        Url       = 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe'
        Sha256    = '681be3e5ba9fd3da02c09d7e565adfa078640ed66a0d58583efad2c1e3cc4064'
        Arguments = '/install /quiet /norestart'
    }
    @{
        Id        = 'Microsoft.VCRedist.2013.x64'
        Url       = 'https://download.visualstudio.microsoft.com/download/pr/10912041/cee5d6bca2ddbcd039da727bf4acb48a/vcredist_x64.exe'
        Sha256    = 'a4bba7701e355ae29c403431f871a537897c363e215cafe706615e270984f17c'
        Arguments = '/install /quiet /norestart'
    }
    @{
        Id        = 'Microsoft.IIS.URLRewrite'
        Url       = 'https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi'
        Sha256    = '37342ff2f585f263f34f48e9de59eb1051d61015a8e967dbde4075716230a32a'
        Arguments = '/quiet /norestart'
    }
)

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
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
    try { $raw = @(& $FilePath @ArgumentList 2>&1) }
    finally { $ErrorActionPreference = $previousPreference }
    $exitCode = $LASTEXITCODE
    $output = @($raw | ForEach-Object { "$_" })
    # stdout allein (z. B. Zusammenfassungen): Die Reihenfolge gegenueber stderr ist bei 2>&1 nicht garantiert.
    $stdOut = @($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
    if ($SuccessExitCodes -notcontains $exitCode -and -not $NoThrow) {
        throw ('{0} endete mit Exit-Code {1}: {2}' -f (Split-Path -Path $FilePath -Leaf), $exitCode, (($output | Select-Object -Last 5) -join ' '))
    }
    [pscustomobject]@{ ExitCode = $exitCode; Output = $output; StdOut = $stdOut }
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

function Initialize-PageFile {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $sizeMb = [uint32][math]::Floor($computerSystem.TotalPhysicalMemory / 1MB * 0.25)

    if ($computerSystem.AutomaticManagedPagefile) {
        Set-CimInstance -InputObject $computerSystem -Property @{ AutomaticManagedPagefile = $false }
    }
    # Direkt in der Registry statt per Win32_PageFileSetting: New-CimInstance scheitert dort mit
    # "Generic failure". Wirksam nach dem naechsten Neustart (Domaenenbeitritt).
    $memoryKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    Set-ItemProperty -Path $memoryKey -Name 'PagingFiles' -Value @("C:\pagefile.sys $sizeMb $sizeMb") -Type MultiString
    Write-LabLog "Auslagerungsdatei C:\pagefile.sys fest auf $sizeMb MB (25 % RAM), aktiv nach Neustart."
}

function Initialize-DataDisk {
    if (Get-Volume -DriveLetter 'F' -ErrorAction SilentlyContinue) {
        Write-LabLog 'Laufwerk F: existiert bereits.'
        return
    }

    $cdrom = Get-CimInstance -ClassName Win32_Volume -Filter "DriveType = 5 AND DriveLetter = 'F:'"
    if ($cdrom) {
        Set-CimInstance -InputObject $cdrom -Property @{ DriveLetter = 'Z:' }
    }

    $disk = Get-Disk | Where-Object PartitionStyle -EQ 'RAW' | Sort-Object Number | Select-Object -First 1
    if (-not $disk) {
        throw 'Keine uninitialisierte Datendisk gefunden.'
    }

    Initialize-Disk -Number $disk.Number -PartitionStyle GPT
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter 'F' | Out-Null
    Format-Volume -DriveLetter 'F' -FileSystem ReFS -AllocationUnitSize 65536 -SetIntegrityStreams $false -NewFileSystemLabel 'ExchangeData' -Confirm:$false | Out-Null
    Write-LabLog "Datendisk $($disk.Number) als F: (ReFS, 64K, Integrity Streams aus) formatiert."
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

function Install-ExchangeWindowsFeature {
    # Wiederholt, weil der Servicing Stack kurz nach dem Start noch beschaeftigt sein kann.
    $result = Invoke-WithRetry -Activity 'Windows-Features' -Attempts 3 -DelaySeconds 120 -ScriptBlock {
        $featureResult = Install-WindowsFeature -Name ($ExchangeWindowsFeatures + $AdminToolFeatures)
        if (-not $featureResult.Success) {
            throw "Installation der Windows-Features fuer Exchange und Verwaltung fehlgeschlagen (Exit-Code $($featureResult.ExitCode))."
        }
        $featureResult
    }
    Write-LabLog "Windows-Features installiert (Neustart erforderlich: $($result.RestartNeeded))."

    Set-Service -Name RemoteRegistry -StartupType Automatic
    Start-Service -Name RemoteRegistry
    Write-LabLog 'Remote Registry auf Automatisch gesetzt und gestartet.'
}

function Initialize-PowerShellGallery {
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue | Where-Object Version -GE '2.8.5.201')) {
        Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope AllUsers | Out-Null
    }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

function Save-VerifiedDownload {
    # Laedt eine Datei und prueft den SHA256. Bei Abweichung wird die Datei geloescht und abgebrochen.
    param(
        [Parameter(Mandatory)][string] $Url,
        [Parameter(Mandatory)][string] $Destination,
        [Parameter(Mandatory)][string] $Sha256,
        [Parameter(Mandatory)][string] $Name
    )
    Invoke-WithRetry -Activity "Download $Name" -ScriptBlock {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }

    $hash = (Get-FileHash -Path $Destination -Algorithm SHA256).Hash
    if ($hash -ne $Sha256) {
        Remove-Item -Path $Destination -Force -ErrorAction SilentlyContinue
        throw "SHA256 von $Name passt nicht (erwartet $Sha256, erhalten $hash)."
    }
}

function Invoke-Installer {
    # Exit 1618: Eine andere Installation laeuft gerade (z. B. Windows Update im Hintergrund). Dann warten und wiederholen.
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [Parameter(Mandatory)][string] $ArgumentList,
        [Parameter(Mandatory)][string] $Name
    )
    $attempts = 15
    for ($attempt = 1; ; $attempt++) {
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru
        if ($process.ExitCode -ne 1618 -or $attempt -ge $attempts) { return $process.ExitCode }
        Write-LabLog "${Name}: andere Installation laeuft (Exit-Code 1618), neuer Versuch in 60 Sekunden ($attempt/$attempts)."
        Start-Sleep -Seconds 60
    }
}

function Install-PackageFromDownload {
    param([Parameter(Mandatory)][hashtable] $Package)

    $fileName = Split-Path -Path $Package.Url -Leaf
    $target = Join-Path $InstallDir ("{0}-{1}" -f $Package.Id, $fileName)
    Save-VerifiedDownload -Url $Package.Url -Destination $target -Sha256 $Package.Sha256 -Name $Package.Id

    if ($target -like '*.msi') {
        $exitCode = Invoke-Installer -FilePath 'msiexec.exe' -ArgumentList "/i `"$target`" $($Package.Arguments)" -Name $Package.Id
    }
    else {
        $exitCode = Invoke-Installer -FilePath $target -ArgumentList $Package.Arguments -Name $Package.Id
    }
    if ($exitCode -notin 0, 1638, 3010) {
        throw "Installation von $($Package.Id) per Download fehlgeschlagen (Exit-Code $exitCode)."
    }
    Write-LabLog "$($Package.Id) per Microsoft-Download installiert (Exit-Code $exitCode)."
}

function Save-LabTool {
    # Nicht fatal: Die Diagnose-Skripte sind Komfort fuer die Azubis und duerfen das Lab nicht blockieren.
    New-Item -Path $ToolsDir -ItemType Directory -Force | Out-Null
    foreach ($tool in $LabTools) {
        $target = Join-Path $ToolsDir $tool.Name
        if ((Test-Path -Path $target) -and (Get-FileHash -Path $target -Algorithm SHA256).Hash -eq $tool.Sha256) {
            Write-LabLog "$($tool.Name) bereits vorhanden."
            continue
        }
        try {
            Save-VerifiedDownload -Url $tool.Url -Destination $target -Sha256 $tool.Sha256 -Name $tool.Name
            Write-LabLog "$($tool.Name) nach $ToolsDir geladen."
        }
        catch {
            Write-LabLog "WARNUNG: $($tool.Name) nicht geladen: $($_.Exception.Message)"
        }
    }
}

function Install-PowerShell7 {
    if (Test-Path -Path $PwshExe) {
        Write-LabLog "PowerShell 7 bereits vorhanden: $PwshExe"
        return
    }
    Install-PackageFromDownload -Package $PowerShell7
    if (-not (Test-Path -Path $PwshExe)) {
        throw "PowerShell 7 nach der Installation nicht gefunden ($PwshExe)."
    }
}

function Invoke-WinGetInstall {
    param([Parameter(Mandatory)][string[]] $Ids)

    $helper = Join-Path $InstallDir 'Install-WinGetPackage.ps1'
    Set-Content -Path $helper -Value $WinGetHelperScript -Encoding ASCII
    $output = (Invoke-NativeCommand -FilePath $PwshExe -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $helper, '-Ids', ($Ids -join ','), '-ModuleVersion', $WinGetClientVersion) -NoThrow).Output

    $status = @{}
    foreach ($line in $output) {
        $text = "$line"
        if ($text -like 'RESULT|*') {
            $parts = $text.Split('|', 4)
            $status[$parts[1]] = $parts[2]
            Write-LabLog "winget: $($parts[1]) -> $($parts[2]) ($($parts[3]))"
        }
        elseif ($text) {
            Write-LabLog "winget-Hilfsskript: $text"
        }
    }
    return $status
}

function Install-LabSoftware {
    $optional = @($WingetPackages.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $status = @{}
    try {
        Install-PowerShell7
        $requiredIds = @($RequiredPackages | ForEach-Object { $_.Id })
        $status = Invoke-WinGetInstall -Ids ($requiredIds + $optional)
    }
    catch {
        Write-LabLog "WARNUNG: winget nicht nutzbar: $($_.Exception.Message)"
    }

    foreach ($package in $RequiredPackages) {
        if ($status[$package.Id] -ne 'Ok') {
            Write-LabLog "$($package.Id) nicht per winget installiert, nutze Microsoft-Download."
            Install-PackageFromDownload -Package $package
        }
    }
    foreach ($id in $optional) {
        if ($status[$id] -ne 'Ok') {
            # Optionale Tools duerfen das Lab nicht blockieren.
            Write-LabLog "WARNUNG: optionales Paket $id nicht installiert."
        }
    }
}

function Test-IsoHash {
    param([Parameter(Mandatory)][string] $Path)
    if (-not $IsoSha256) { return $true }
    $hash = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
    if ($hash -eq $IsoSha256) { return $true }
    Write-LabLog "SHA256 des Exchange-ISO passt nicht (erwartet $IsoSha256, erhalten $hash)."
    return $false
}

function Get-ExchangeMedium {
    # Fertig-Marke statt "Setup.exe vorhanden": Eine abgebrochene Kopie wird beim naechsten Lauf vervollstaendigt.
    $setupExe = Join-Path $MediaDir 'Setup.exe'
    $completeMarker = Join-Path $MediaDir 'lab-media-complete.txt'
    if (Test-Path -Path $completeMarker) {
        Write-LabLog "Exchange-Medium bereits vorhanden: $setupExe"
        return
    }

    $isoPath = Join-Path $InstallDir (Split-Path -Path $IsoUri -Leaf)
    if ((Test-Path -Path $isoPath) -and -not (Test-IsoHash -Path $isoPath)) {
        Remove-Item -Path $isoPath -Force
    }
    if (-not (Test-Path -Path $isoPath)) {
        Write-LabLog "Lade Exchange-ISO von $IsoUri."
        Invoke-WithRetry -Activity 'Download Exchange-ISO' -Attempts 3 -DelaySeconds 60 -ScriptBlock {
            Remove-Item -Path $isoPath -Force -ErrorAction SilentlyContinue
            try {
                Start-BitsTransfer -Source $IsoUri -Destination $isoPath -Priority Foreground
            }
            catch {
                # BITS ist im SYSTEM-Kontext nicht immer verfuegbar.
                Write-LabLog "BITS nicht nutzbar ($($_.Exception.Message)), lade per WebClient."
                $client = New-Object -TypeName System.Net.WebClient
                try { $client.DownloadFile($IsoUri, $isoPath) } finally { $client.Dispose() }
            }
            if (-not (Test-IsoHash -Path $isoPath)) {
                Remove-Item -Path $isoPath -Force
                throw 'Exchange-ISO unvollstaendig oder veraendert.'
            }
        }
        Write-LabLog 'Exchange-ISO geladen.'
    }

    Write-LabLog 'Entpacke Exchange-ISO.'
    # Aus einem abgebrochenen Lauf kann das ISO noch eingebunden sein.
    $image = Get-DiskImage -ImagePath $isoPath
    if (-not $image.Attached) {
        $image = Mount-DiskImage -ImagePath $isoPath -PassThru
    }
    try {
        $driveLetter = ($image | Get-Volume).DriveLetter
        New-Item -Path $MediaDir -ItemType Directory -Force | Out-Null
        # robocopy: Exit 0-7 = Erfolg (Bits fuer kopiert/zusaetzlich/abweichend), ab 8 Fehler.
        Invoke-NativeCommand -FilePath 'robocopy.exe' -ArgumentList @("${driveLetter}:\", $MediaDir, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -SuccessExitCodes (0..7) | Out-Null
    }
    finally {
        Dismount-DiskImage -ImagePath $isoPath | Out-Null
    }
    if (-not (Test-Path -Path $setupExe)) {
        throw "Setup.exe fehlt nach dem Entpacken ($MediaDir)."
    }
    Set-Content -Path $completeMarker -Value (Get-Date -Format o) -Encoding ASCII
    Remove-Item -Path $isoPath -Force

    $version = (Get-Item -Path $setupExe).VersionInfo.ProductVersion
    Write-LabLog "Exchange-Medium bereit, Setup-Version $version."
}

function Install-Ucma {
    $installed = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like '*Unified Communications Managed API 4.0*' }
    if ($installed) {
        Write-LabLog 'UCMA 4.0 bereits installiert.'
        return
    }

    $ucmaSetup = Join-Path $MediaDir 'UCMARedist\Setup.exe'
    $exitCode = Invoke-Installer -FilePath $ucmaSetup -ArgumentList '/quiet /norestart' -Name 'UCMA 4.0'
    if ($exitCode -notin 0, 3010) {
        throw "UCMA-Installation fehlgeschlagen (Exit-Code $exitCode)."
    }
    Write-LabLog "UCMA 4.0 installiert (Exit-Code $exitCode)."
}

function Request-LabCertificate {
    if ($EnableLetsEncrypt -ne 'true') {
        Write-LabLog "Let's Encrypt deaktiviert, kein Zertifikat angefordert."
        return
    }

    try {
        [Environment]::SetEnvironmentVariable('POSHACME_HOME', $PoshAcmeHome, 'Machine')
        $env:POSHACME_HOME = $PoshAcmeHome
        New-Item -Path $PoshAcmeHome, $CertDir -ItemType Directory -Force | Out-Null

        Initialize-PowerShellGallery
        if (-not (Get-Module -ListAvailable -Name Posh-ACME | Where-Object { $_.Version -eq [version]$PoshAcmeVersion })) {
            Invoke-WithRetry -Activity "Install-Module Posh-ACME $PoshAcmeVersion" -ScriptBlock {
                Install-Module -Name Posh-ACME -RequiredVersion $PoshAcmeVersion -Scope AllUsers -Force
            }
        }
        Import-Module -Name Posh-ACME -RequiredVersion $PoshAcmeVersion

        if ($LetsEncryptStaging -eq 'true') { Set-PAServer -DirectoryUrl LE_STAGE } else { Set-PAServer -DirectoryUrl LE_PROD }
        # Ohne Konto wirft Get-PACertificate einen terminierenden Fehler.
        if (-not (Get-PAAccount)) {
            New-PAAccount -AcceptTOS | Out-Null
            Write-LabLog 'ACME-Konto angelegt.'
        }

        $domain = "*.$PublicDomainName"
        $certificate = Get-PACertificate -MainDomain $domain -ErrorAction SilentlyContinue
        if (-not $certificate -or $certificate.NotAfter -lt (Get-Date).AddDays(30)) {
            $pluginArgs = @{ AZSubscriptionId = $SubscriptionId; AZUseIMDS = $true }
            # Mehrere Versuche: die Rollenzuweisung der Managed Identity kann einige Minuten brauchen.
            $certificate = Invoke-WithRetry -Activity "Let's-Encrypt-Zertifikat $domain" -Attempts 5 -DelaySeconds 120 -ScriptBlock {
                New-PACertificate -Domain $domain -AcceptTOS -Plugin Azure -PluginArgs $pluginArgs -Force
            }
        }

        foreach ($file in @($certificate.CertFile, $certificate.KeyFile, $certificate.ChainFile, $certificate.FullChainFile, $certificate.PfxFile, $certificate.PfxFullChain)) {
            if ($file -and (Test-Path -Path $file)) {
                Copy-Item -Path $file -Destination $CertDir -Force
            }
        }
        # Privater Schluessel: nur Administratoren und SYSTEM.
        Invoke-NativeCommand -FilePath 'icacls.exe' -ArgumentList @($CertDir, '/inheritance:r', '/grant:r', '*S-1-5-32-544:(OI)(CI)F', '*S-1-5-18:(OI)(CI)F') | Out-Null
        Write-LabLog "Zertifikat $domain (gueltig bis $($certificate.NotAfter)) nach $CertDir kopiert."
    }
    catch {
        # Nicht fatal: Exchange laeuft mit dem selbstsignierten Zertifikat weiter.
        Write-LabLog "WARNUNG: Let's-Encrypt-Zertifikat konnte nicht erstellt werden: $($_.Exception.Message)"
        Set-Content -Path (Join-Path $LabRoot 'letsencrypt-failed.txt') -Value $_.Exception.Message -Encoding ASCII
    }
}

try {
    Write-LabLog "Start (oeffentliche Domain $PublicDomainName)."
    Initialize-PageFile
    Initialize-DataDisk
    Initialize-RegionalSetting
    Install-ExchangeWindowsFeature
    Install-LabSoftware
    Save-LabTool
    Get-ExchangeMedium
    Install-Ucma
    Request-LabCertificate
    Write-LabLog 'Ende ohne Fehler.'
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    Write-LabLog $_.ScriptStackTrace
    exit 1
}
