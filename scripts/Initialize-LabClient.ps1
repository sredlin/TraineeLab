<#
.SYNOPSIS
    Richtet den Windows-11-Client des Exchange-Labs ein.

.DESCRIPTION
    Phase 'Prepare' (Azure Managed Run Command als LocalSystem, vor dem Domaenenbeitritt, parallel zum DC-Aufbau):
      - aktive Nutzungszeit 06-23 Uhr per Richtlinie: Windows Update startet waehrend des Aufbaus und
        tagsueber nicht neu, Neustarts fallen auf das abendliche Herunterfahren
      - BlockAADWorkplaceJoin: Die Office-Aktivierung mit dem Firmenkonto registriert den Lab-Client nicht
        im Entra ID der Firma
      - Sprachpaket de-DE als Anzeigesprache, Zeitzone, Gebietsschema, Tastatur
      - Microsoft 365 Apps (de-de, 64 Bit, Monthly Enterprise Channel) per Office Deployment Tool,
        ohne Access, Publisher, Teams, Skype/Lync, Groove und Bing

    Phase 'Complete' (Run Command nach dem Domaenenbeitritt):
      - wartet, bis Domaenenbeitritt und Secure Channel stehen
      - Domaenen-Benutzer in die lokale Gruppe Remotedesktopbenutzer (per SID, unabhaengig von der Sprache)
      - Lab-Info.txt und OWA-Verknuepfung auf dem oeffentlichen Desktop

    Fehler bei Sprachpaket und Office sind nicht fatal: Das Lab bleibt nutzbar, das Log nennt die Ursache.
    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [ValidateSet('Prepare', 'Complete')]
    [string] $Phase = 'Prepare',

    # Nur Phase 'Prepare':
    [ValidateSet('O365ProPlusRetail', 'O365BusinessRetail')]
    [string] $OfficeProductId = 'O365ProPlusRetail',

    # Nur Phase 'Complete':
    [string] $DomainName,
    [string] $NetbiosName,
    [string] $PublicDomainName,
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

New-Item -Path $LogDir, $InstallDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir "Initialize-LabClient-$Phase.log"

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Phase, $Message
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

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Content)
    # Mit BOM, damit Editor und Windows PowerShell 5.1 Umlaute korrekt lesen.
    [IO.File]::WriteAllText($Path, $Content, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true))
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

function Initialize-ClientLanguage {
    Set-TimeZone -Id 'W. Europe Standard Time'
    try {
        if ((Get-InstalledLanguage -Language de-DE -ErrorAction SilentlyContinue)) {
            Write-LabLog 'Sprachpaket de-DE bereits installiert.'
        }
        else {
            Write-LabLog 'Installiere Sprachpaket de-DE (dauert einige Minuten).'
            Invoke-WithRetry -Activity 'Install-Language de-DE' -Attempts 2 -DelaySeconds 60 -ScriptBlock {
                Install-Language -Language de-DE -CopyToSettings | Out-Null
            }
        }
        Set-SystemPreferredUILanguage -Language de-DE
        Write-LabLog 'Anzeigesprache de-DE gesetzt, aktiv nach dem Neustart beim Domaenenbeitritt.'
    }
    catch {
        Write-LabLog "WARNUNG: Sprachpaket de-DE nicht installiert, Oberflaeche bleibt Englisch: $($_.Exception.Message)"
    }

    Set-WinSystemLocale -SystemLocale de-DE
    Set-WinHomeLocation -GeoId 94
    Set-Culture -CultureInfo de-DE
    Set-WinUserLanguageList -LanguageList de-DE -Force
    if (Get-Command -Name Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    }
    Write-LabLog 'Deutsche Regionaleinstellungen gesetzt.'
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
            '      <Language ID="de-de" />'
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

        Write-LabLog "Installiere Microsoft 365 Apps ($OfficeProductId, de-de, Monthly Enterprise Channel)."
        $setup = Start-Process -FilePath (Join-Path $OdtDir 'setup.exe') -ArgumentList '/configure', "`"$configFile`"" -Wait -PassThru
        if ($setup.ExitCode -ne 0 -or -not (Test-Path -Path $OutlookExe)) {
            throw "Office-Setup mit Exit-Code $($setup.ExitCode) beendet, Outlook nicht gefunden. Details: C:\Windows\Temp\*.log"
        }
        Write-LabLog 'Microsoft 365 Apps installiert.'
    }
    catch {
        Write-LabLog "WARNUNG: Microsoft 365 Apps nicht installiert: $($_.Exception.Message)"
        Set-Content -Path (Join-Path $LabRoot 'office-failed.txt') -Value $_.Exception.Message -Encoding ASCII
    }
}

function Invoke-PreparePhase {
    Initialize-ClientPolicy
    Initialize-ClientLanguage
    Install-OfficeApp
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
    $computerAccount = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList "$NetbiosName\$env:COMPUTERNAME`$"
    $domainSid = $computerAccount.Translate([System.Security.Principal.SecurityIdentifier]).AccountDomainSid
    $domainUsersSid = '{0}-513' -f $domainSid.Value
    $group = Get-LocalGroup -SID 'S-1-5-32-555'

    $members = @(Get-LocalGroupMember -Group $group -ErrorAction SilentlyContinue | ForEach-Object { $_.SID.Value })
    if ($members -contains $domainUsersSid) {
        Write-LabLog "Domaenen-Benutzer sind bereits Mitglied von $($group.Name)."
        return
    }
    Add-LocalGroupMember -Group $group -Member $domainUsersSid
    Write-LabLog "Domaenen-Benutzer ($domainUsersSid) zu $($group.Name) hinzugefuegt."
}

function Publish-ClientDesktop {
    $desktop = Join-Path $env:PUBLIC 'Desktop'
    $owaUrl = "https://mail.$PublicDomainName/owa"
    $officeStatus = if (Test-Path -Path $OutlookExe) { 'installiert' } else { 'FEHLT, siehe C:\ExchangeLab\office-failed.txt' }
    $lines = @(
        "LAB-CLIENT $env:COMPUTERNAME"
        ''
        "Domain:       $DomainName (NetBIOS $NetbiosName)"
        "Anmeldung:    $NetbiosName\mmustermann (oder ein anderer Lab-Benutzer), Kennwort = Deployment-Parameter labUserPassword"
        "OWA:          $owaUrl"
        "Office:       Microsoft 365 Apps $officeStatus"
        "Fileserver:   $(if ($FileServerComputerName) { "\\$FileServerComputerName, Basisordner H: = \\$FileServerComputerName\Home$\<Benutzer>" } else { 'keiner' })"
        ''
        'OFFICE AKTIVIEREN'
        '  Beim ersten Start von Word oder Outlook mit dem eigenen Firmenkonto anmelden (Lizenz der Firma).'
        '  Eine Registrierung des Lab-Clients in der Firma ist per Richtlinie blockiert.'
        '  Meldet Office eine fehlende Lizenz, das Lab mit officeProductId = O365BusinessRetail neu bereitstellen.'
        ''
        'OUTLOOK'
        '  Outlook (klassisch) starten. Das Profil fuer das Lab-Postfach legt Autodiscover automatisch an.'
        '  Das neue Outlook unterstuetzt kein Exchange on Premises, der Umschalter ist per GPO ausgeblendet.'
        '  Autodiscover testen: Strg + Rechtsklick auf das Outlook-Symbol im Infobereich,'
        '  "E-Mail-AutoKonfiguration testen".'
        ''
        'LOGS: C:\ExchangeLab\Logs'
    )
    Write-Utf8File -Path (Join-Path $desktop 'Lab-Info.txt') -Content ($lines -join "`r`n")
    Set-Content -Path (Join-Path $desktop 'OWA.url') -Value "[InternetShortcut]`r`nURL=$owaUrl" -Encoding ASCII
    Write-LabLog "Lab-Info und OWA-Verknuepfung auf $desktop abgelegt."
}

function Invoke-CompletePhase {
    foreach ($name in 'DomainName', 'NetbiosName', 'PublicDomainName') {
        if (-not (Get-Variable -Name $name -ValueOnly)) {
            throw "Parameter $name fehlt (Phase Complete)."
        }
    }
    Wait-DomainJoin
    Add-DomainUsersToRemoteDesktop
    Publish-ClientDesktop
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
