<#
.SYNOPSIS
    Bereitet die Exchange-VM vor dem Domaenenbeitritt vor.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) parallel zum Aufbau des Domain Controllers.
    Startet keinen Neustart: offene Neustarts erledigt der anschliessende Domaenenbeitritt.

      - Auslagerungsdatei fest auf 25 % RAM (Vorgabe Exchange Server SE)
      - Datendisk F: als ReFS (64K, Integrity Streams aus) fuer Datenbanken und Logs
      - deutsche Regionaleinstellungen
      - Windows-Features laut Exchange-SE-Voraussetzungen (Mailbox-Rolle, ohne ADLDS)
      - Remote Registry auf Automatisch (Exchange-Voraussetzung)
      - winget (Modul Microsoft.WinGet.Client, im SYSTEM-Kontext supportet):
        VC++ 2012/2013, IIS URL Rewrite und optionale Tools
      - Exchange-SE-ISO laden und entpacken, UCMA 4.0 aus \UCMARedist installieren
      - optional Let's-Encrypt-Wildcard-Zertifikat ueber die Managed Identity der VM

    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $PublicDomainName,

    [Parameter(Mandatory)]
    [string] $IsoUri,

    [Parameter(Mandatory)]
    [string] $SubscriptionId,

    # Komma-getrennte winget-Paket-IDs fuer optionale Tools.
    [string] $WingetPackages = '',

    [ValidateSet('true', 'false')]
    [string] $EnableLetsEncrypt = 'true',

    [ValidateSet('true', 'false')]
    [string] $LetsEncryptStaging = 'false'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$InstallDir = Join-Path $LabRoot 'Install'
$MediaDir = Join-Path $LabRoot 'Media\ExchangeSE'
$CertDir = 'C:\Certificates'
$PoshAcmeHome = 'C:\ProgramData\Posh-ACME'

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
    Get-CimInstance -ClassName Win32_PageFileSetting | Where-Object Name -NE 'C:\pagefile.sys' | Remove-CimInstance
    $setting = Get-CimInstance -ClassName Win32_PageFileSetting | Where-Object Name -EQ 'C:\pagefile.sys'
    if ($setting) {
        Set-CimInstance -InputObject $setting -Property @{ InitialSize = $sizeMb; MaximumSize = $sizeMb }
    }
    else {
        New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = 'C:\pagefile.sys'; InitialSize = $sizeMb; MaximumSize = $sizeMb } | Out-Null
    }
    Write-LabLog "Auslagerungsdatei C:\pagefile.sys fest auf $sizeMb MB (25 % RAM)."
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
    Set-TimeZone -Id 'W. Europe Standard Time'
    Set-WinSystemLocale -SystemLocale de-DE
    Set-WinHomeLocation -GeoId 94
    Set-Culture -CultureInfo de-DE
    Set-WinUserLanguageList -LanguageList de-DE -Force
    if (Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    }
    Write-LabLog 'Deutsche Regionaleinstellungen gesetzt.'
}

function Install-ExchangeWindowsFeature {
    $result = Install-WindowsFeature -Name $ExchangeWindowsFeatures
    if (-not $result.Success) {
        throw 'Installation der Windows-Features fuer Exchange fehlgeschlagen.'
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

function Initialize-WinGet {
    Initialize-PowerShellGallery
    if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {
        Invoke-WithRetry -Activity 'Install-Module Microsoft.WinGet.Client' -ScriptBlock {
            Install-Module -Name Microsoft.WinGet.Client -Scope AllUsers -Force
        }
    }
    Import-Module -Name Microsoft.WinGet.Client

    try {
        Write-LabLog "WinGet-Version: $(Get-WinGetVersion)"
    }
    catch {
        Write-LabLog "WinGet nicht bereit ($($_.Exception.Message)), repariere Paketmanager."
        Repair-WinGetPackageManager -AllUsers -Force -Latest
        Write-LabLog "WinGet-Version nach Reparatur: $(Get-WinGetVersion)"
    }
}

function Install-PackageFromDownload {
    param([Parameter(Mandatory)][hashtable] $Package)

    $fileName = Split-Path -Path $Package.Url -Leaf
    $target = Join-Path $InstallDir ("{0}-{1}" -f $Package.Id, $fileName)
    Invoke-WithRetry -Activity "Download $($Package.Id)" -ScriptBlock {
        Invoke-WebRequest -Uri $Package.Url -OutFile $target -UseBasicParsing
    }

    $hash = (Get-FileHash -Path $target -Algorithm SHA256).Hash
    if ($hash -ne $Package.Sha256) {
        throw "SHA256 von $($Package.Id) passt nicht (erwartet $($Package.Sha256), erhalten $hash)."
    }

    if ($target -like '*.msi') {
        $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$target`" $($Package.Arguments)" -Wait -PassThru
    }
    else {
        $process = Start-Process -FilePath $target -ArgumentList $Package.Arguments -Wait -PassThru
    }
    if ($process.ExitCode -notin 0, 1638, 3010) {
        throw "Installation von $($Package.Id) per Download fehlgeschlagen (Exit-Code $($process.ExitCode))."
    }
    Write-LabLog "$($Package.Id) per Microsoft-Download installiert (Exit-Code $($process.ExitCode))."
}

function Install-LabPackage {
    param(
        [Parameter(Mandatory)][string] $Id,
        [hashtable] $Fallback
    )

    try {
        $result = Install-WinGetPackage -Id $Id -Source winget -MatchOption Equals -Mode Silent -Scope SystemOrUnknown -Force
        if ($result.Status -ne 'Ok') {
            throw "Status $($result.Status), Installer-Code $($result.InstallerErrorCode)"
        }
        Write-LabLog "winget: $Id installiert (Neustart erforderlich: $($result.RebootRequired))."
    }
    catch {
        if (-not $Fallback) {
            throw "winget-Installation von $Id fehlgeschlagen: $($_.Exception.Message)"
        }
        Write-LabLog "winget-Installation von $Id fehlgeschlagen ($($_.Exception.Message)), nutze Microsoft-Download."
        Install-PackageFromDownload -Package $Fallback
    }
}

function Install-LabSoftware {
    $wingetReady = $true
    try {
        Initialize-WinGet
    }
    catch {
        $wingetReady = $false
        Write-LabLog "WinGet nicht verfuegbar: $($_.Exception.Message)"
    }

    foreach ($package in $RequiredPackages) {
        if ($wingetReady) {
            Install-LabPackage -Id $package.Id -Fallback $package
        }
        else {
            Install-PackageFromDownload -Package $package
        }
    }

    $optional = $WingetPackages.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    foreach ($id in $optional) {
        if (-not $wingetReady) {
            Write-LabLog "WARNUNG: $id uebersprungen, WinGet nicht verfuegbar."
            continue
        }
        try {
            Install-LabPackage -Id $id
        }
        catch {
            # Optionale Tools duerfen das Lab nicht blockieren.
            Write-LabLog "WARNUNG: $($_.Exception.Message)"
        }
    }
}

function Get-ExchangeMedium {
    $setupExe = Join-Path $MediaDir 'Setup.exe'
    if (Test-Path -Path $setupExe) {
        Write-LabLog "Exchange-Medium bereits vorhanden: $setupExe"
        return
    }

    $isoPath = Join-Path $InstallDir (Split-Path -Path $IsoUri -Leaf)
    if (-not (Test-Path -Path $isoPath)) {
        Write-LabLog "Lade Exchange-ISO von $IsoUri."
        Invoke-WithRetry -Activity 'Download Exchange-ISO' -Attempts 3 -DelaySeconds 60 -ScriptBlock {
            try {
                Start-BitsTransfer -Source $IsoUri -Destination $isoPath -Priority Foreground
            }
            catch {
                # BITS ist im SYSTEM-Kontext nicht immer verfuegbar.
                Write-LabLog "BITS nicht nutzbar ($($_.Exception.Message)), lade per WebClient."
                $client = New-Object -TypeName System.Net.WebClient
                try { $client.DownloadFile($IsoUri, $isoPath) } finally { $client.Dispose() }
            }
        }
    }

    Write-LabLog 'Entpacke Exchange-ISO.'
    $image = Mount-DiskImage -ImagePath $isoPath -PassThru
    try {
        $driveLetter = ($image | Get-Volume).DriveLetter
        New-Item -Path $MediaDir -ItemType Directory -Force | Out-Null
        & robocopy.exe "${driveLetter}:\" $MediaDir /E /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy meldet Exit-Code $LASTEXITCODE."
        }
    }
    finally {
        Dismount-DiskImage -ImagePath $isoPath | Out-Null
    }
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
    $process = Start-Process -FilePath $ucmaSetup -ArgumentList '/quiet /norestart' -Wait -PassThru
    if ($process.ExitCode -notin 0, 3010) {
        throw "UCMA-Installation fehlgeschlagen (Exit-Code $($process.ExitCode))."
    }
    Write-LabLog "UCMA 4.0 installiert (Exit-Code $($process.ExitCode))."
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
        if (-not (Get-Module -ListAvailable -Name Posh-ACME)) {
            Invoke-WithRetry -Activity 'Install-Module Posh-ACME' -ScriptBlock {
                Install-Module -Name Posh-ACME -Scope AllUsers -Force
            }
        }
        Import-Module -Name Posh-ACME

        if ($LetsEncryptStaging -eq 'true') { Set-PAServer -DirectoryUrl LE_STAGE } else { Set-PAServer -DirectoryUrl LE_PROD }

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
        & icacls.exe $CertDir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' | Out-Null
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
