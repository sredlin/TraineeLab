<#
.SYNOPSIS
    Richtet den Windows-11-Client des Exchange-Labs ein.

.DESCRIPTION
    Phase 'Prepare' (Azure Managed Run Command als LocalSystem, vor dem Domaenenbeitritt, parallel zum DC-Aufbau):
      - aktive Nutzungszeit 06-23 Uhr per Richtlinie: Windows Update startet waehrend des Aufbaus und
        tagsueber nicht neu, Neustarts fallen auf das abendliche Herunterfahren
      - BlockAADWorkplaceJoin: Die Office-Aktivierung mit dem Konto aus dem Microsoft-365-Demo-Tenant
        registriert den Lab-Client nicht in Entra ID
      - Sprache nach LabLanguage: de = Sprachpaket de-DE als Anzeigesprache, en = Oberflaeche en-US mit
        Formaten en-GB; Zeitzone, Gebietsschema, deutsche Tastatur
      - Microsoft 365 Apps (de-de bzw. en-gb, 64 Bit, Monthly Enterprise Channel) per Office Deployment Tool,
        ohne Access, Publisher, Teams, Skype/Lync, Groove und Bing
      - Devolutions Remote Desktop Manager Free mit .NET Desktop Runtime 10, Richtlinien (kein Onboarding,
        keine Update-/Konto-Hinweise), PowerShell 7 und dem Modul Devolutions.PowerShell
      - winget-Pakete (Parameter WingetPackages, Standard VS Code) maschinenweit in der neuesten Version ueber das
        Modul Microsoft.WinGet.Client unter PowerShell 7 (die winget-CLI ist im SYSTEM-Kontext nicht supportet).
        Der Task TraineeLab-WinGetUpdate haelt sie aktuell (beim Start und taeglich 12:00). VS Code meldet per
        Richtlinie keine Updates, weil Lab-Benutzer ohne Adminrechte sie nicht installieren koennen.

    Phase 'Complete' (Run Command nach dem Domaenenbeitritt):
      - wartet, bis Domaenenbeitritt und Secure Channel stehen
      - Domaenen-Benutzer in die lokale Gruppe Remotedesktopbenutzer (per SID, unabhaengig von der Sprache)
      - gemeinsame RDM-Datenquelle (XML) mit RDP-Verbindungen zu allen Lab-Servern und den Domain-Admin-
        Zugangsdaten; Active Setup bindet sie bei der ersten Anmeldung jedes Benutzers als Arbeitsbereich ein.
        RDM verschluesselt Passwoerter mit einem eingebauten Schluessel: Jeder Benutzer des Clients kann das
        Admin-Passwort auslesen (bewusste Entscheidung fuer den Lab-Komfort).
        Dazu Web-Eintraege OWA und ECP ohne Zugangsdaten, sie oeffnen im Standardbrowser.
      - Lab-Info.txt und OWA-Verknuepfung auf dem oeffentlichen Desktop

    Fehler bei Sprachpaket, Office, Remote Desktop Manager und winget-Paketen sind nicht fatal: Das Lab bleibt
    nutzbar, das Log nennt die Ursache.
    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'AdminPasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[CmdletBinding()]
param(
    [ValidateSet('Prepare', 'Complete')]
    [string] $Phase = 'Prepare',

    # Sprache der Lab-Daten: de = Sprachpaket und Formate de-DE, Office de-de; en = Oberflaeche en-US aus dem
    # Image, Formate en-GB, Office en-gb; deutsche Tastatur in beiden Faellen. Bestimmt auch die Lab-Info.
    [ValidateSet('de', 'en')]
    [string] $LabLanguage = 'de',

    # Nur Phase 'Prepare':
    [ValidateSet('O365ProPlusRetail', 'O365BusinessRetail')]
    [string] $OfficeProductId = 'O365ProPlusRetail',

    [ValidateSet('Install', 'Skip')]
    [string] $RemoteDesktopManager = 'Install',

    # Komma-getrennte winget-Paket-IDs, maschinenweit installiert und per Task aktuell gehalten.
    [string] $WingetPackages = '',

    # Nur Phase 'Complete':
    [string] $DomainName,
    [string] $NetbiosName,
    [string] $PublicDomainName,
    [string] $AdminUser,
    [string] $AdminPasswordB64,
    [string] $DcComputerName,
    [string] $ExchangeComputerName,
    [string] $SecondDcComputerName = '',
    [string] $FileServerComputerName = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$InstallDir = Join-Path $LabRoot 'Install'
$OdtDir = Join-Path $InstallDir 'OfficeDeploymentTool'
$OutlookExe = Join-Path $env:ProgramFiles 'Microsoft Office\root\Office16\OUTLOOK.EXE'

# Office Deployment Tool, Quelle: Microsoft Download Center (URL und SHA256 aus dem winget-Manifest
# Microsoft.OfficeDeploymentTool, Datei von Microsoft signiert). Beim Aktualisieren beides gemeinsam aendern.
$OfficeDeploymentTool = @{
    Version = '16.0.20430.20146'
    Url     = 'https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20430-20146.exe'
    Sha256  = 'af1594121ab610cd8abc3dd6ff0a504e0cbc6ce54372e5c3813926352d1179c6'
}

# Remote Desktop Manager und seine Voraussetzungen. Beim Aktualisieren jeweils URL und Hash gemeinsam aendern.
# .NET Desktop Runtime 10, Quelle: Microsoft (URL und SHA512 aus
# https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json, Microsoft veroeffentlicht nur SHA512).
$DotNetDesktopRuntime = @{
    Version = '10.0.15'
    Url     = 'https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/10.0.15/windowsdesktop-runtime-10.0.15-win-x64.exe'
    Sha512  = 'f838960962172f1a769c49fa600e6f60f56f8d08a28e3cb878890ffc2e3a7a2e1b65697588e23efa767b8b8e8523ec01f55e875120507dde16d9a0869102dab3'
}

# Devolutions Remote Desktop Manager (Free nutzt dasselbe MSI wie die Bezahlversion), Quelle: Devolutions-CDN
# (URL und SHA256 aus https://devolutions.net/productinfo.json, RDMWindows.Current, x64-MSI).
$RdmInstaller = @{
    Version = '2026.3.19.0'
    Url     = 'https://cdn.devolutions.net/download/Setup.RemoteDesktopManager.win-x64.2026.3.19.0.msi'
    Sha256  = 'F84774C4C66086620BC5611B9BEB82D1A1C44A43F02608D731AA0A5198F01FA0'
}

# PowerShell 7 LTS fuer das RDM-Modul (Devolutions.PowerShell laeuft nur unter PowerShell 7.6), gleicher Pin wie in
# Initialize-ExchangeServer.ps1. Quelle: GitHub-Release PowerShell/PowerShell (SHA256 aus den Release-Assets).
$PowerShell7 = @{
    Url       = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.9/PowerShell-7.6.9-win-x64.msi'
    Sha256    = '50d33c7494aaf82b987cfd4de3f232d04f91fdd4c0deeca8a669cced3e7cf8f9'
    Arguments = '/quiet /norestart ADD_PATH=1 DISABLE_TELEMETRY=1 USE_MU=0 ENABLE_MU=0'
}

# RDM-PowerShell-Modul aus der PowerShell Gallery: legt Datenquelle und Verbindungen ohne Oberflaeche an.
$RdmModule = @{
    Name    = 'Devolutions.PowerShell'
    Version = '2026.3.4'
}

# winget-Pakete: Modul Microsoft.WinGet.Client in fester Version (gleicher Pin wie in Initialize-ExchangeServer.ps1),
# die Pakete selbst immer in der neuesten Version. Skript und Paketliste liegen fuer den Update-Task in einem
# Ordner, den nur SYSTEM und Administratoren aendern duerfen (der Task laeuft als SYSTEM).
$WinGetClientVersion = '1.29.380'
$WinGetDir = Join-Path $env:ProgramData 'TraineeLab\WinGet'
$WinGetToolFile = Join-Path $WinGetDir 'WinGetTool.ps1'
$WinGetIdFile = Join-Path $WinGetDir 'Packages.txt'
$WinGetUpdateTaskName = 'TraineeLab-WinGetUpdate'

# Sprache je Lab-Sprache. Englisch: Oberflaeche en-US bleibt (kein Sprachpaket, schneller), Formate en-GB.
# Tastatur in beiden Faellen Deutsch, weil die Azubis an deutschen Tastaturen sitzen.
$ClientLanguage = @{
    de = @{ LanguagePack = 'de-DE'; Culture = 'de-DE'; GeoId = 94; InputMethod = '0407:00000407'; Office = 'de-de'; SampleUser = 'mmustermann' }
    en = @{ LanguagePack = ''; Culture = 'en-GB'; GeoId = 242; InputMethod = '0809:00000407'; Office = 'en-gb'; SampleUser = 'fbloggs' }
}[$LabLanguage]

$RdmExe = Join-Path $env:ProgramFiles 'Devolutions\Remote Desktop Manager\RemoteDesktopManager.exe'
$PwshExe = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
$RdmPolicyKey = 'HKLM:\SOFTWARE\Policies\Devolutions\RemoteDesktopManager'
$RdmDataDir = Join-Path $env:ProgramData 'TraineeLab\RemoteDesktopManager'
$RdmWorkspaceFile = Join-Path $RdmDataDir 'Lab-Server.xml'
$RdmActiveSetupKey = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\TraineeLab-RemoteDesktopManager'

# Laeuft unter PowerShell 7 als SYSTEM: legt die XML-Datenquelle mit den Verbindungen neu an.
# Server, Web-Eintraege und Passwort kommen per Umgebungsvariable (nicht in der Kommandozeile, Windows
# PowerShell 5.1 wuerde die Anfuehrungszeichen im JSON beim Aufruf von pwsh verlieren). Ein fehlerhafter
# Web-Eintrag meldet WEBERROR, die RDP-Verbindungen bleiben.
$RdmCreateWorkspaceScript = @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module -Name Devolutions.PowerShell
$path = $env:TRAINEELAB_RDM_FILE
if (Test-Path -Path $path) { Remove-Item -Path $path -Force }
$workspace = New-RDMDataSource -XML -Name 'Lab-Server' -Filename $path -Set
Set-RDMCurrentDataSource -ID $workspace.ID
$password = ConvertTo-SecureString -String $env:TRAINEELAB_RDM_PASSWORD -AsPlainText -Force
foreach ($server in ($env:TRAINEELAB_RDM_SERVERS | ConvertFrom-Json)) {
    $entry = New-RDMEntry -Name $server.Name -Host $server.Host -Type RDPConfigured
    $entry = $entry | Set-RDMEntryUsername -UserName $server.UserName -PassThru
    $entry = $entry | Set-RDMEntryDomain -Domain $server.Domain -PassThru
    $entry = $entry | Set-RDMEntryPassword -Password $password -PassThru
    Set-RDMEntry -InputObject $entry
}
foreach ($web in ($env:TRAINEELAB_RDM_WEB | ConvertFrom-Json)) {
    try {
        # Ohne Zugangsdaten, extern im Standardbrowser des Benutzers.
        $entry = New-RDMEntry -Name $web.Name -Host $web.Url -Type WebBrowser
        $entry.WebBrowserUrl = $web.Url
        $entry.OpenEmbedded = $false
        Set-RDMEntry -InputObject $entry
    }
    catch {
        'WEBERROR|{0}: {1}' -f $web.Name, $_.Exception.Message
    }
}
'ENTRIES|' + ((Get-RDMEntry | ForEach-Object { $_.Name }) -join ',')
'@

# Laeuft per Active Setup einmal pro Benutzer bei der Anmeldung (PowerShell 7, Benutzerkontext): bindet die
# gemeinsame Datenquelle als Standard-Arbeitsbereich ein. Manuell erneut ausfuehrbar.
$RdmRegisterWorkspaceScript = @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$logDir = Join-Path $env:LOCALAPPDATA 'TraineeLab'
New-Item -Path $logDir -ItemType Directory -Force | Out-Null
$log = Join-Path $logDir 'Register-LabWorkspace.log'
try {
    Import-Module -Name Devolutions.PowerShell
    $workspace = Get-RDMDataSource | Where-Object { $_.Name -eq 'Lab-Server' }
    if (-not $workspace) {
        $workspace = New-RDMDataSource -XML -Name 'Lab-Server' -Filename (Join-Path $PSScriptRoot 'Lab-Server.xml') -Set
    }
    Set-RDMCurrentDataSource -ID $workspace.ID
    $count = @(Get-RDMEntry).Count
    Add-Content -Path $log -Value ('{0:yyyy-MM-dd HH:mm:ss} Arbeitsbereich Lab-Server eingebunden, {1} Verbindungen.' -f (Get-Date), $count)
}
catch {
    Add-Content -Path $log -Value ('{0:yyyy-MM-dd HH:mm:ss} FEHLER: {1}' -f (Get-Date), $_.Exception.Message)
    exit 1
}
'@

# Laeuft unter PowerShell 7 als SYSTEM: installiert die Pakete aus IdFile maschinenweit, mit -Update bringt es
# installierte Pakete auf die neueste Version (Task TraineeLab-WinGetUpdate, Ausgabe dann in LogFile).
# Ausgabe fuer den Aufrufer: RESULT|<id>|<status>|<detail> und INFO|<text>.
$WinGetHelperScript = @'
param(
    [Parameter(Mandatory)][string] $IdFile,
    [Parameter(Mandatory)][string] $ModuleVersion,
    [switch] $Update,
    [string] $LogFile = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$failed = 0

function Write-Log([string] $Message) {
    if ($LogFile) { Add-Content -Path $LogFile -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message) }
}

function Write-Result([string] $Id, [string] $Status, [string] $Detail) {
    'RESULT|{0}|{1}|{2}' -f $Id, $Status, $Detail
    if ($Status -eq 'Ok') { Write-Log "${Id}: $Detail" }
    else {
        $script:failed++
        Write-Log "WARNUNG: $Id -> $Status ($Detail)"
    }
}

function Invoke-Package([string] $Id) {
    $installed = @(Get-WinGetPackage -Id $Id -MatchOption EqualsCaseInsensitive) | Select-Object -First 1
    if ($installed -and -not ($Update -and $installed.IsUpdateAvailable)) {
        Write-Result -Id $Id -Status 'Ok' -Detail "Version $($installed.InstalledVersion)"
        return
    }
    if ($installed) {
        $result = Update-WinGetPackage -Id $Id -Source winget -MatchOption EqualsCaseInsensitive -Mode Silent -Force
        $action = "aktualisiert von $($installed.InstalledVersion)"
    }
    else {
        $result = Install-WinGetPackage -Id $Id -Source winget -MatchOption EqualsCaseInsensitive -Mode Silent -Scope SystemOrUnknown -Force
        $action = 'installiert'
    }
    Write-Result -Id $Id -Status $result.Status -Detail "$action, Installer-Code $($result.InstallerErrorCode)"
}

$ids = @(Get-Content -Path $IdFile | ForEach-Object { $_.Trim() } | Where-Object { $_ })
Write-Log ('Start, Pakete: {0}' -f ($ids -join ', '))
try {
    if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client | Where-Object { $_.Version -eq [version]$ModuleVersion })) {
        Install-PSResource -Name Microsoft.WinGet.Client -Version $ModuleVersion -Scope AllUsers -TrustRepository
    }
    Import-Module -Name Microsoft.WinGet.Client -RequiredVersion $ModuleVersion
}
catch {
    $message = "Modul Microsoft.WinGet.Client $ModuleVersion nicht verfuegbar: $($_.Exception.Message)"
    foreach ($id in $ids) { Write-Result -Id $id -Status 'Error' -Detail $message }
    exit 1
}

$repaired = $false
foreach ($id in $ids) {
    try {
        Invoke-Package -Id $id
        continue
    }
    catch { $message = $_.Exception.Message }
    if (-not $repaired) {
        # winget (App Installer) fuer SYSTEM nicht nutzbar, z. B. auf einem frischen Image: einmal reparieren.
        $repaired = $true
        "INFO|${id}: $message - starte Repair-WinGetPackageManager"
        Write-Log "${id}: $message - starte Repair-WinGetPackageManager"
        try {
            Repair-WinGetPackageManager -AllUsers -Force -Latest | Out-Null
            Invoke-Package -Id $id
            continue
        }
        catch { $message = $_.Exception.Message }
    }
    Write-Result -Id $id -Status 'Error' -Detail $message
}
if ($failed) { exit 1 }
'@

New-Item -Path $LogDir, $InstallDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir "Initialize-LabClient-$Phase.log"

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Phase, $Message
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

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Content)
    # Mit BOM, damit Editor und Windows PowerShell 5.1 Umlaute korrekt lesen.
    [IO.File]::WriteAllText($Path, $Content, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true))
}

function Initialize-ReadOnlyFolderAcl {
    # Nur SYSTEM und Administratoren aendern, Benutzer lesen: Aus diesen Ordnern startet SYSTEM Skripte. Ohne eigene
    # ACL erbten Ordner z. B. unter C:\ das Aendern-Recht der authentifizierten Benutzer.
    param([Parameter(Mandatory)][string] $Path)
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $acl = New-Object -TypeName System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($entry in @(@('S-1-5-18', 'FullControl'), @('S-1-5-32-544', 'FullControl'), @('S-1-5-32-545', 'ReadAndExecute'))) {
        $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $entry[0]
        $acl.AddAccessRule((New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $sid, $entry[1], $inherit, 'None', 'Allow'))
    }
    Set-Acl -Path $Path -AclObject $acl
}

#region Phase Prepare

function Initialize-ClientPolicy {
    # Richtlinie "Automatischen Neustart waehrend der Nutzungszeit deaktivieren" (maximal 18 Stunden).
    $updateKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    New-Item -Path $updateKey -Force | Out-Null
    Set-ItemProperty -Path $updateKey -Name 'SetActiveHours' -Value 1 -Type DWord
    Set-ItemProperty -Path $updateKey -Name 'ActiveHoursStart' -Value 6 -Type DWord
    Set-ItemProperty -Path $updateKey -Name 'ActiveHoursEnd' -Value 23 -Type DWord
    Write-LabLog 'Aktive Nutzungszeit 06-23 Uhr gesetzt, keine Update-Neustarts in dieser Zeit.'

    # Ohne diesen Schalter bietet Office bei der Anmeldung "Allow my organization to manage my device" an
    # und der Lab-Client landet im Entra ID (ggf. Intune) der Firma.
    $workplaceJoinKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin'
    New-Item -Path $workplaceJoinKey -Force | Out-Null
    Set-ItemProperty -Path $workplaceJoinKey -Name 'BlockAADWorkplaceJoin' -Value 1 -Type DWord
    Write-LabLog 'Entra-Registrierung des Clients (Workplace Join) blockiert.'
}

function Invoke-LanguageInstall {
    # Eigener Prozess mit Zeitlimit: Install-Language laedt aus dem Store und kann bei Stoerungen haengen.
    param([Parameter(Mandatory)][string] $Language, [int] $TimeoutMinutes = 35)
    $job = Start-Job -ScriptBlock {
        Install-Language -Language $using:Language -CopyToSettings -ErrorAction Stop | Out-Null
    }
    try {
        if (-not (Wait-Job -Job $job -Timeout ($TimeoutMinutes * 60))) {
            Stop-Job -Job $job
            throw "Install-Language $Language nach $TimeoutMinutes Minuten abgebrochen."
        }
        Receive-Job -Job $job -ErrorAction Stop | Out-Null
        if ($job.State -ne 'Completed') {
            throw "Install-Language $Language endete mit Status $($job.State)."
        }
    }
    finally {
        Remove-Job -Job $job -Force
    }
}

function Initialize-ClientLanguage {
    Set-TimeZone -Id 'W. Europe Standard Time'
    if ($ClientLanguage.LanguagePack) {
        $pack = $ClientLanguage.LanguagePack
        try {
            if ((Get-InstalledLanguage -Language $pack -ErrorAction SilentlyContinue)) {
                Write-LabLog "Sprachpaket $pack bereits installiert."
            }
            else {
                Write-LabLog "Installiere Sprachpaket $pack (dauert einige Minuten)."
                Invoke-WithRetry -Activity "Install-Language $pack" -Attempts 2 -DelaySeconds 60 -ScriptBlock {
                    Invoke-LanguageInstall -Language $pack
                }
            }
            Set-SystemPreferredUILanguage -Language $pack
            Write-LabLog "Anzeigesprache $pack gesetzt, aktiv nach dem Neustart beim Domaenenbeitritt."
        }
        catch {
            Write-LabLog "WARNUNG: Sprachpaket $pack nicht installiert, Oberflaeche bleibt Englisch: $($_.Exception.Message)"
        }
    }
    else {
        Write-LabLog 'Kein Sprachpaket noetig, die Oberflaeche bleibt Englisch (Image).'
    }

    Set-WinSystemLocale -SystemLocale $ClientLanguage.Culture
    Set-WinHomeLocation -GeoId $ClientLanguage.GeoId
    Set-Culture -CultureInfo $ClientLanguage.Culture
    $languageList = New-WinUserLanguageList -Language $ClientLanguage.Culture
    $languageList[0].InputMethodTips.Clear()
    $languageList[0].InputMethodTips.Add($ClientLanguage.InputMethod)
    Set-WinUserLanguageList -LanguageList $languageList -Force
    if (Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    }
    Write-LabLog "Regionaleinstellungen $($ClientLanguage.Culture) gesetzt (Tastatur $($ClientLanguage.InputMethod))."
}

function Install-OfficeApp {
    if (Test-Path -Path $OutlookExe) {
        Write-LabLog "Microsoft 365 Apps bereits installiert ($OutlookExe)."
        return
    }

    try {
        $odtExe = Join-Path $InstallDir ('officedeploymenttool_{0}.exe' -f $OfficeDeploymentTool.Version)
        Invoke-WithRetry -Activity 'Download Office Deployment Tool' -ScriptBlock {
            Invoke-WebRequest -Uri $OfficeDeploymentTool.Url -OutFile $odtExe -UseBasicParsing
        }
        $hash = (Get-FileHash -Path $odtExe -Algorithm SHA256).Hash
        if ($hash -ne $OfficeDeploymentTool.Sha256) {
            Remove-Item -Path $odtExe -Force
            throw "SHA256 des Office Deployment Tool passt nicht (erwartet $($OfficeDeploymentTool.Sha256), erhalten $hash)."
        }

        New-Item -Path $OdtDir -ItemType Directory -Force | Out-Null
        $extract = Start-Process -FilePath $odtExe -ArgumentList '/quiet', "/extract:`"$OdtDir`"" -Wait -PassThru
        if ($extract.ExitCode -ne 0) {
            throw "Entpacken des Office Deployment Tool mit Exit-Code $($extract.ExitCode) beendet."
        }

        $configuration = @(
            '<Configuration>'
            '  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise">'
            ('    <Product ID="{0}">' -f $OfficeProductId)
            ('      <Language ID="{0}" />' -f $ClientLanguage.Office)
            '      <ExcludeApp ID="Access" />'
            '      <ExcludeApp ID="Bing" />'
            '      <ExcludeApp ID="Groove" />'
            '      <ExcludeApp ID="Lync" />'
            '      <ExcludeApp ID="Publisher" />'
            '      <ExcludeApp ID="Teams" />'
            '    </Product>'
            '  </Add>'
            '  <Property Name="SharedComputerLicensing" Value="0" />'
            '  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />'
            '  <Updates Enabled="TRUE" />'
            '  <RemoveMSI />'
            '  <Display Level="None" AcceptEULA="TRUE" />'
            '</Configuration>'
        ) -join "`r`n"
        $configFile = Join-Path $OdtDir 'LabConfiguration.xml'
        Set-Content -Path $configFile -Value $configuration -Encoding UTF8

        Write-LabLog "Installiere Microsoft 365 Apps ($OfficeProductId, $($ClientLanguage.Office), Monthly Enterprise Channel)."
        # Hoechstens 60 Minuten; ein schnell gescheitertes Setup (z. B. Download vom CDN) wird einmal wiederholt.
        $deadline = (Get-Date).AddMinutes(60)
        for ($attempt = 1; ; $attempt++) {
            $setup = Start-Process -FilePath (Join-Path $OdtDir 'setup.exe') -ArgumentList '/configure', "`"$configFile`"" -PassThru
            $null = $setup.Handle
            $remaining = [int][Math]::Max(0, ($deadline - (Get-Date)).TotalMilliseconds)
            if (-not $setup.WaitForExit($remaining)) {
                throw 'Office-Setup nach 60 Minuten nicht beendet. Details: C:\Windows\Temp\*.log'
            }
            if ($setup.ExitCode -eq 0 -and (Test-Path -Path $OutlookExe)) { break }
            if ($attempt -ge 2 -or (Get-Date) -gt $deadline.AddMinutes(-20)) {
                throw "Office-Setup mit Exit-Code $($setup.ExitCode) beendet, Outlook nicht gefunden. Details: C:\Windows\Temp\*.log"
            }
            Write-LabLog "Office-Setup mit Exit-Code $($setup.ExitCode) beendet, zweiter Versuch in 2 Minuten."
            Start-Sleep -Seconds 120
        }
        Remove-Item -Path (Join-Path $LabRoot 'office-failed.txt') -Force -ErrorAction SilentlyContinue
        Write-LabLog 'Microsoft 365 Apps installiert.'
    }
    catch {
        Write-LabLog "WARNUNG: Microsoft 365 Apps nicht installiert: $($_.Exception.Message)"
        Set-Content -Path (Join-Path $LabRoot 'office-failed.txt') -Value $_.Exception.Message -Encoding ASCII
    }
}

function Save-VerifiedDownload {
    # Laedt eine Datei und prueft den Hash. Bei Abweichung wird die Datei geloescht und abgebrochen.
    param(
        [Parameter(Mandatory)][string] $Url,
        [Parameter(Mandatory)][string] $Hash,
        [ValidateSet('SHA256', 'SHA512')][string] $Algorithm = 'SHA256'
    )
    $target = Join-Path $InstallDir (Split-Path -Path $Url -Leaf)
    if ((Test-Path -Path $target) -and (Get-FileHash -Path $target -Algorithm $Algorithm).Hash -eq $Hash) {
        return $target
    }
    Invoke-WithRetry -Activity "Download $(Split-Path -Path $Url -Leaf)" -ScriptBlock {
        Invoke-WebRequest -Uri $Url -OutFile $target -UseBasicParsing
    }
    $actual = (Get-FileHash -Path $target -Algorithm $Algorithm).Hash
    if ($actual -ne $Hash) {
        Remove-Item -Path $target -Force -ErrorAction SilentlyContinue
        throw "$Algorithm von $(Split-Path -Path $Url -Leaf) passt nicht (erwartet $Hash, erhalten $actual)."
    }
    return $target
}

function Install-Msi {
    param([Parameter(Mandatory)][string] $Path, [string] $Arguments = '/qn /norestart', [Parameter(Mandatory)][string] $Name)
    $msiLog = Join-Path $LogDir ('{0}-msi.log' -f $Name)
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$Path`" $Arguments /l*v `"$msiLog`"" -Wait -PassThru
    if ($process.ExitCode -notin 0, 1638, 3010) {
        throw "Installation von $Name mit Exit-Code $($process.ExitCode) beendet, Details: $msiLog"
    }
    Write-LabLog "$Name installiert (Exit-Code $($process.ExitCode))."
}

function Install-DotNetDesktopRuntime {
    $runtimeDir = Join-Path $env:ProgramFiles ('dotnet\shared\Microsoft.WindowsDesktop.App\{0}' -f $DotNetDesktopRuntime.Version)
    if (Test-Path -Path $runtimeDir) {
        Write-LabLog ".NET Desktop Runtime $($DotNetDesktopRuntime.Version) bereits installiert."
        return
    }
    $installer = Save-VerifiedDownload -Url $DotNetDesktopRuntime.Url -Hash $DotNetDesktopRuntime.Sha512 -Algorithm SHA512
    $runtimeLog = Join-Path $LogDir 'dotnet-desktop-runtime.log'
    $process = Start-Process -FilePath $installer -ArgumentList '/install', '/quiet', '/norestart', '/log', "`"$runtimeLog`"" -Wait -PassThru
    if ($process.ExitCode -notin 0, 1638, 3010) {
        throw ".NET Desktop Runtime mit Exit-Code $($process.ExitCode) beendet, Details: $runtimeLog"
    }
    Write-LabLog ".NET Desktop Runtime $($DotNetDesktopRuntime.Version) installiert (Exit-Code $($process.ExitCode))."
}

function Initialize-RdmPolicy {
    # Kein Onboarding-Assistent, keine Update-, Feedback- und Konto-Hinweise: Lab-Benutzer haben keine Adminrechte,
    # die RDM-Version pflegt das Repository ($RdmInstaller).
    New-Item -Path $RdmPolicyKey -Force | Out-Null
    foreach ($name in 'DisableOnboarding', 'HideWhatsNewPage', 'DisableQuickStart', 'DisableFeedbackPrompts', 'DisableAnalytics', 'DisableOnlineAccount', 'DisableUpdate') {
        Set-ItemProperty -Path $RdmPolicyKey -Name $name -Value 1 -Type DWord
    }
    # 4 = Updates nur manuell suchen
    Set-ItemProperty -Path $RdmPolicyKey -Name 'EnforceAutoUpdateFrequency' -Value 4 -Type DWord
    Write-LabLog "RDM-Richtlinien unter $RdmPolicyKey gesetzt."
}

function Install-PowerShell7 {
    if (Test-Path -Path $PwshExe) {
        Write-LabLog "PowerShell 7 bereits vorhanden: $PwshExe"
        return
    }
    $msi = Save-VerifiedDownload -Url $PowerShell7.Url -Hash $PowerShell7.Sha256
    Install-Msi -Path $msi -Arguments $PowerShell7.Arguments -Name 'PowerShell7'
    if (-not (Test-Path -Path $PwshExe)) {
        throw "PowerShell 7 nach der Installation nicht gefunden ($PwshExe)."
    }
}

function Install-RdmModule {
    $command = "`$ProgressPreference = 'SilentlyContinue'; " +
    "if (-not (Get-Module -ListAvailable -Name '$($RdmModule.Name)' | Where-Object { `$_.Version -eq [version]'$($RdmModule.Version)' })) { " +
    "Install-PSResource -Name '$($RdmModule.Name)' -Version '$($RdmModule.Version)' -Scope AllUsers -TrustRepository -ErrorAction Stop }"
    Invoke-WithRetry -Activity "Install-PSResource $($RdmModule.Name)" -ScriptBlock {
        Invoke-NativeCommand -FilePath $PwshExe -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', $command) | Out-Null
    }
    Write-LabLog "Modul $($RdmModule.Name) $($RdmModule.Version) fuer alle Benutzer installiert."
}

function Install-RemoteDesktopManager {
    if ($RemoteDesktopManager -eq 'Skip') {
        Write-LabLog 'Remote Desktop Manager per Parameter abgewaehlt.'
        return
    }
    $marker = Join-Path $LabRoot 'rdm-failed.txt'
    try {
        Install-DotNetDesktopRuntime
        $installed = (Test-Path -Path $RdmExe) -and (Get-Item -Path $RdmExe).VersionInfo.ProductVersion -like "$($RdmInstaller.Version)*"
        if ($installed) {
            Write-LabLog "Remote Desktop Manager $($RdmInstaller.Version) bereits installiert."
        }
        else {
            Write-LabLog "Installiere Remote Desktop Manager $($RdmInstaller.Version)."
            $msi = Save-VerifiedDownload -Url $RdmInstaller.Url -Hash $RdmInstaller.Sha256
            Install-Msi -Path $msi -Arguments '/qn /norestart INSTALLMODE=Complete' -Name 'RemoteDesktopManager'
        }
        # Das MSI legt nur eine Verknuepfung im Startmenue an.
        $startMenuLink = Get-ChildItem -Path (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs') -Recurse -Filter 'Remote Desktop Manager*.lnk' | Select-Object -First 1
        if ($startMenuLink) {
            Copy-Item -Path $startMenuLink.FullName -Destination (Join-Path $env:PUBLIC 'Desktop\Remote Desktop Manager.lnk') -Force
        }
        Initialize-RdmPolicy
        Install-PowerShell7
        Install-RdmModule
        Remove-Item -Path $marker -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-LabLog "WARNUNG: Remote Desktop Manager nicht vollstaendig installiert: $($_.Exception.Message)"
        Set-Content -Path $marker -Value $_.Exception.Message -Encoding ASCII
    }
}

function Initialize-VSCodePolicy {
    # Das systemweite VS Code kann sich ohne Adminrechte nicht aktualisieren, das uebernimmt der Update-Task.
    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\VSCode'
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name 'UpdateMode' -Value 'none' -Type String
    Write-LabLog "VS-Code-Richtlinie UpdateMode = none gesetzt, Updates per Task $WinGetUpdateTaskName."
}

function Invoke-WinGetTool {
    # Ergebnis: Hashtable Paket-ID -> Status (Ok, Error, InstallError, ...).
    $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $WinGetToolFile, '-IdFile', $WinGetIdFile, '-ModuleVersion', $WinGetClientVersion)
    $output = (Invoke-NativeCommand -FilePath $PwshExe -ArgumentList $arguments -NoThrow).Output
    $status = @{}
    foreach ($text in $output) {
        if ($text -like 'RESULT|*') {
            $parts = $text.Split('|', 4)
            $status[$parts[1]] = $parts[2]
            Write-LabLog "winget: $($parts[1]) -> $($parts[2]) ($($parts[3]))"
        }
        elseif ($text) {
            Write-LabLog "winget-Hilfsskript: $($text -replace '^INFO\|', '')"
        }
    }
    return $status
}

function Register-WinGetUpdateTask {
    $logFile = Join-Path $LogDir 'Update-WinGetTool.log'
    $action = New-ScheduledTaskAction -Execute $PwshExe -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$WinGetToolFile`" -IdFile `"$WinGetIdFile`" -ModuleVersion $WinGetClientVersion -Update -LogFile `"$logFile`""
    # Beim Start vor den ersten Anmeldungen und mittags; StartWhenAvailable holt Laeufe nach, die der
    # Auto-Shutdown verpasst hat.
    $startup = New-ScheduledTaskTrigger -AtStartup
    $startup.Delay = 'PT5M'
    $daily = New-ScheduledTaskTrigger -Daily -At '12:00'
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) -StartWhenAvailable
    Register-ScheduledTask -TaskName $WinGetUpdateTaskName -Action $action -Trigger $startup, $daily -Principal $principal -Settings $settings -Force | Out-Null
    Write-LabLog "Task $WinGetUpdateTaskName registriert (beim Start und taeglich 12:00, Log $logFile)."
}

function Install-WinGetTool {
    $ids = @($WingetPackages.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $ids) {
        Write-LabLog 'Keine winget-Pakete angegeben.'
        return
    }
    $marker = Join-Path $LabRoot 'winget-failed.txt'
    try {
        Install-PowerShell7
        New-Item -Path $WinGetDir -ItemType Directory -Force | Out-Null
        Initialize-ReadOnlyFolderAcl -Path $WinGetDir
        Set-Content -Path $WinGetToolFile -Value $WinGetHelperScript -Encoding ASCII
        Set-Content -Path $WinGetIdFile -Value $ids -Encoding ASCII
        if ($ids -contains 'Microsoft.VisualStudioCode') { Initialize-VSCodePolicy }
        Write-LabLog "Installiere per winget: $($ids -join ', ')."
        $status = Invoke-WinGetTool
        Set-Content -Path (Join-Path $LabRoot 'winget-result.txt') -Value @($ids | ForEach-Object { '{0}|{1}' -f $_, $status[$_] }) -Encoding ASCII
        # Auch bei Fehlern: Der Task installiert fehlende Pakete beim naechsten Lauf nach.
        Register-WinGetUpdateTask
        $failed = @($ids | Where-Object { $status[$_] -ne 'Ok' })
        if ($failed) { throw "nicht installiert: $($failed -join ', ')" }
        Remove-Item -Path $marker -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-LabLog "WARNUNG: winget-Pakete nicht vollstaendig installiert: $($_.Exception.Message)"
        Set-Content -Path $marker -Value $_.Exception.Message -Encoding ASCII
    }
}

function Invoke-PreparePhase {
    Initialize-ClientPolicy
    Initialize-ClientLanguage
    Install-OfficeApp
    Install-RemoteDesktopManager
    Install-WinGetTool
}

#endregion

#region Phase Complete

function Wait-DomainJoin {
    $deadline = (Get-Date).AddMinutes(30)
    while ($true) {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        # Der Beitritt ist erst nach dem Neustart der Extension abgeschlossen.
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

function Add-DomainUsersToRemoteDesktop {
    # Gruppennamen sind sprachabhaengig (Remotedesktopbenutzer, Domain Users), SIDs nicht.
    # Beide Schritte fragen einen DC; kurz nach dem Beitritt oder waehrend eines DC-Neustarts wiederholen.
    $domainSid = Invoke-WithRetry -Activity 'Domaenen-SID ermitteln' -Attempts 10 -DelaySeconds 30 -ScriptBlock {
        $computerAccount = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList "$NetbiosName\$env:COMPUTERNAME`$"
        $computerAccount.Translate([System.Security.Principal.SecurityIdentifier]).AccountDomainSid
    }
    $domainUsersSid = '{0}-513' -f $domainSid.Value
    $group = Get-LocalGroup -SID 'S-1-5-32-555'

    Invoke-WithRetry -Activity "Domaenen-Benutzer in $($group.Name)" -Attempts 5 -DelaySeconds 30 -ScriptBlock {
        $members = @(Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue | ForEach-Object { $_.SID.Value })
        if ($members -contains $domainUsersSid) {
            Write-LabLog "Domaenen-Benutzer sind Mitglied von $($group.Name)."
            return
        }
        Add-LocalGroupMember -Group $group -Member $domainUsersSid
        Write-LabLog "Domaenen-Benutzer ($domainUsersSid) zu $($group.Name) hinzugefuegt."
    }
}

function ConvertFrom-Base64String {
    param([Parameter(Mandatory)][string] $Value)
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value)).TrimStart([char]0xFEFF)
}

function Get-LabServerList {
    # Reihenfolge wie in der Lab-Info: DCs, Exchange, Fileserver.
    @($DcComputerName, $SecondDcComputerName, $ExchangeComputerName, $FileServerComputerName) | Where-Object { $_ }
}

function Get-ExchangeWebEntry {
    # OWA und ECP ueber den oeffentlichen Namen (passt zum Zertifikat), fuer RDM, Lab-Info und Desktop.
    foreach ($app in 'owa', 'ecp') {
        [pscustomobject]@{ Name = $app.ToUpperInvariant(); Url = 'https://mail.{0}/{1}' -f $PublicDomainName, $app }
    }
}

function Initialize-RdmDataAcl {
    # Ordner: Benutzer lesen nur (das Registrierungsskript liegt hier). Die XML-Datei braucht Aendern: RDM schreibt
    # sie beim Laden jedes Benutzers neu (ChangeMasterKey), auch wenn sich der Inhalt nicht aendert.
    Initialize-ReadOnlyFolderAcl -Path $RdmDataDir

    $fileAcl = Get-Acl -Path $RdmWorkspaceFile
    $fileAcl.SetAccessRuleProtection($false, $false)
    $users = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-545'
    $fileAcl.AddAccessRule((New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $users, 'Modify', 'Allow'))
    Set-Acl -Path $RdmWorkspaceFile -AclObject $fileAcl
}

function Publish-RemoteConnection {
    # Ergebnis: Namen der Eintraege im RDM (Server, dann OWA/ECP), leer = nicht eingerichtet. Fehler sind nicht
    # fatal (Komfortfunktion).
    $moduleDir = Join-Path $env:ProgramFiles ('PowerShell\Modules\{0}\{1}' -f $RdmModule.Name, $RdmModule.Version)
    if (-not ((Test-Path -Path $RdmExe) -and (Test-Path -Path $PwshExe) -and (Test-Path -Path $moduleDir))) {
        Write-LabLog 'Remote Desktop Manager nicht installiert (abgewaehlt oder Fehler in Phase Prepare), keine Verbindungen.'
        return @()
    }
    try {
        New-Item -Path $RdmDataDir -ItemType Directory -Force | Out-Null
        # SYSTEM ist kein echter RDM-Benutzer: eigene Konfiguration bei jedem Lauf neu, keine doppelten Arbeitsbereiche.
        $systemConfig = Join-Path $env:SystemRoot 'System32\config\systemprofile\AppData\Local\Devolutions\RemoteDesktopManager'
        Remove-Item -Path $systemConfig -Recurse -Force -ErrorAction SilentlyContinue

        $servers = @(Get-LabServerList | ForEach-Object {
                [pscustomobject]@{ Name = $_; Host = '{0}.{1}' -f $_, $DomainName; UserName = $AdminUser; Domain = $NetbiosName }
            })
        $helper = Join-Path $InstallDir 'New-LabRdmWorkspace.ps1'
        Set-Content -Path $helper -Value $RdmCreateWorkspaceScript -Encoding ASCII
        $env:TRAINEELAB_RDM_FILE = $RdmWorkspaceFile
        $web = @(Get-ExchangeWebEntry)
        $env:TRAINEELAB_RDM_SERVERS = ConvertTo-Json -InputObject $servers -Compress
        $env:TRAINEELAB_RDM_WEB = ConvertTo-Json -InputObject $web -Compress
        $env:TRAINEELAB_RDM_PASSWORD = ConvertFrom-Base64String $AdminPasswordB64
        try {
            $result = Invoke-NativeCommand -FilePath $PwshExe -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $helper) -NoThrow
            $output = @($result.Output | ForEach-Object { "$_" })
            $exitCode = $result.ExitCode
        }
        finally {
            Remove-Item -Path Env:TRAINEELAB_RDM_PASSWORD, Env:TRAINEELAB_RDM_SERVERS, Env:TRAINEELAB_RDM_WEB, Env:TRAINEELAB_RDM_FILE -ErrorAction SilentlyContinue
        }
        $created = @($output | Where-Object { $_ -like 'ENTRIES|*' })
        if ($exitCode -ne 0 -or -not $created) {
            throw "Anlegen der Verbindungen fehlgeschlagen (Exit-Code $exitCode): $($output -join ' ')"
        }
        $entryNames = $created[0].Substring(8).Split(',')
        Write-LabLog "RDM-Datenquelle $RdmWorkspaceFile angelegt: $($entryNames -join ', ')"
        foreach ($line in $output | Where-Object { $_ -like 'WEBERROR|*' }) {
            Write-LabLog "WARNUNG: RDM-Web-Eintrag nicht angelegt: $($line.Substring(9))"
        }

        $registerScript = Join-Path $RdmDataDir 'Register-LabWorkspace.ps1'
        Set-Content -Path $registerScript -Value $RdmRegisterWorkspaceScript -Encoding ASCII
        Initialize-RdmDataAcl

        # Active Setup: Explorer startet StubPath bei der naechsten Anmeldung jedes Benutzers einmal.
        New-Item -Path $RdmActiveSetupKey -Force | Out-Null
        Set-ItemProperty -Path $RdmActiveSetupKey -Name '(default)' -Value 'TraineeLab Remote Desktop Manager'
        Set-ItemProperty -Path $RdmActiveSetupKey -Name 'StubPath' -Value ('"{0}" -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}"' -f $PwshExe, $registerScript)
        Set-ItemProperty -Path $RdmActiveSetupKey -Name 'Version' -Value '1,0,0,0'
        Set-ItemProperty -Path $RdmActiveSetupKey -Name 'IsInstalled' -Value 1 -Type DWord
        Write-LabLog 'Active Setup bindet den Arbeitsbereich Lab-Server bei der ersten Anmeldung jedes Benutzers ein.'
        return @($servers.Name) + @($web.Name | Where-Object { $entryNames -contains $_ })
    }
    catch {
        Write-LabLog "WARNUNG: Verbindungen im Remote Desktop Manager nicht eingerichtet: $($_.Exception.Message)"
        return @()
    }
}

function Publish-ClientDesktop {
    param([string[]] $RdmServers = @())
    $desktop = Join-Path $env:PUBLIC 'Desktop'
    $web = @(Get-ExchangeWebEntry)
    $owaUrl = ($web | Where-Object { $_.Name -eq 'OWA' }).Url
    $text = @{
        de = @{
            Installed = 'installiert'; Missing = 'FEHLT, siehe C:\ExchangeLab\office-failed.txt'; None = 'keiner'
            Logon = 'Anmeldung:    {0}\{1} (oder ein anderer Lab-Benutzer), Kennwort = Deployment-Parameter labUserPassword'
            FileServer = '\\{0}, Basisordner H: = \\{0}\Home$\<Benutzer>'
            Body = @(
                'OFFICE AKTIVIEREN'
                '  Beim ersten Start von Word oder Outlook mit dem Konto aus dem Microsoft-365-Demo-Tenant anmelden.'
                '  Eine Registrierung des Lab-Clients in Entra ID ist per Richtlinie blockiert.'
                '  Meldet Office eine fehlende Lizenz, das Lab mit officeProductId = O365BusinessRetail neu bereitstellen.'
                ''
                'OUTLOOK'
                '  Outlook (klassisch) starten. Das Profil fuer das Lab-Postfach legt Autodiscover automatisch an.'
                '  Das neue Outlook unterstuetzt kein Exchange on Premises, der Umschalter ist per GPO ausgeblendet.'
                '  Autodiscover testen: Strg + Rechtsklick auf das Outlook-Symbol im Infobereich,'
                '  "E-Mail-AutoKonfiguration testen".'
                ''
                'REMOTE DESKTOP MANAGER'
            )
            Rdm = @(
                '  Desktop oder Startmenue: Remote Desktop Manager, Arbeitsbereich "Lab-Server".'
                '  Verbindungen: {0}'
                '  Anmeldung automatisch als {0} (Domain-Admin).'
                '  ACHTUNG: Jeder Benutzer dieses Clients kann das hinterlegte Admin-Passwort auslesen (Lab-Komfort).'
                '  RDM Free ist laut Devolutions fuer eine Einzelperson lizenziert.'
            )
            RdmWeb = '  OWA und ECP oeffnen im Standardbrowser, Anmeldung dort von Hand (OWA mit dem eigenen Lab-Benutzer).'
            NoRdm = '  nicht eingerichtet (Parameter clientRemoteDesktopManager oder Fehler, siehe Logs)'
        }
        en = @{
            Installed = 'installed'; Missing = 'MISSING, see C:\ExchangeLab\office-failed.txt'; None = 'none'
            Logon = 'Sign-in:      {0}\{1} (or another lab user), password = deployment parameter labUserPassword'
            FileServer = '\\{0}, home folder H: = \\{0}\Home$\<user>'
            Body = @(
                'ACTIVATE OFFICE'
                '  On the first start of Word or Outlook, sign in with your account from the Microsoft 365 demo tenant.'
                '  Registering the lab client in Entra ID is blocked by policy.'
                '  If Office reports a missing licence, redeploy the lab with officeProductId = O365BusinessRetail.'
                ''
                'OUTLOOK'
                '  Start Outlook (classic). Autodiscover creates the profile for the lab mailbox automatically.'
                '  The new Outlook does not support Exchange on-premises, its toggle is hidden by GPO.'
                '  Test Autodiscover: Ctrl + right-click the Outlook icon in the notification area,'
                '  "Test E-mail AutoConfiguration".'
                ''
                'REMOTE DESKTOP MANAGER'
            )
            Rdm = @(
                '  Desktop or Start menu: Remote Desktop Manager, workspace "Lab-Server".'
                '  Connections: {0}'
                '  Signs in automatically as {0} (domain admin).'
                '  WARNING: every user of this client can read the stored admin password (lab convenience).'
                '  According to Devolutions, RDM Free is licensed for a single person.'
            )
            RdmWeb = '  OWA and ECP open in the default browser, sign in there by hand (OWA with your own lab user).'
            NoRdm = '  not set up (parameter clientRemoteDesktopManager or an error, see logs)'
        }
    }[$LabLanguage]
    $officeStatus = if (Test-Path -Path $OutlookExe) { $text.Installed } else { $text.Missing }
    $lines = @(
        "LAB-CLIENT $env:COMPUTERNAME"
        ''
        "Domain:       $DomainName (NetBIOS $NetbiosName)"
        ($text.Logon -f $NetbiosName, $ClientLanguage.SampleUser)
    ) + @($web | ForEach-Object { '{0,-14}{1}' -f "$($_.Name):", $_.Url }) + @(
        "Office:       Microsoft 365 Apps $officeStatus"
        "Fileserver:   $(if ($FileServerComputerName) { $text.FileServer -f $FileServerComputerName } else { $text.None })"
        ''
    ) + $text.Body
    if ($RdmServers) {
        $lines += @($text.Rdm[0], ($text.Rdm[1] -f ($RdmServers -join ', ')), ($text.Rdm[2] -f "$NetbiosName\$AdminUser"))
        if ($RdmServers | Where-Object { $web.Name -contains $_ }) { $lines += $text.RdmWeb }
        $lines += @($text.Rdm[3], $text.Rdm[4])
    }
    else {
        $lines += $text.NoRdm
    }
    $lines += @(
        ''
        'LOGS: C:\ExchangeLab\Logs'
    )
    Write-Utf8File -Path (Join-Path $desktop 'Lab-Info.txt') -Content ($lines -join "`r`n")
    Set-Content -Path (Join-Path $desktop 'OWA.url') -Value "[InternetShortcut]`r`nURL=$owaUrl" -Encoding ASCII
    Write-LabLog "Lab-Info und OWA-Verknuepfung auf $desktop abgelegt."
}

function Invoke-CompletePhase {
    foreach ($name in 'DomainName', 'NetbiosName', 'PublicDomainName', 'AdminUser', 'AdminPasswordB64', 'DcComputerName', 'ExchangeComputerName') {
        if (-not (Get-Variable -Name $name -ValueOnly)) {
            throw "Parameter $name fehlt (Phase Complete)."
        }
    }
    Wait-DomainJoin
    Add-DomainUsersToRemoteDesktop
    $rdmServers = @(Publish-RemoteConnection)
    Publish-ClientDesktop -RdmServers $rdmServers
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
