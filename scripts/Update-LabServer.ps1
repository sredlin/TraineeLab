<#
.SYNOPSIS
    Installiert einmalig alle verfuegbaren Updates (Windows und Microsoft Update inkl. Exchange-SU).

.DESCRIPTION
    Wird nach der Exchange-Installation als Startup-Task (SYSTEM) auf DC und Exchange-Server registriert.
    Nutzt die Windows-Update-COM-API, registriert vorher den Microsoft-Update-Dienst (fuer Exchange-SUs).
    Startet bei Bedarf neu und laeuft dann erneut, maximal MaxRuns-mal. Danach entfernt sich der Task.
    Weitere Updates sind danach Aufgabe der Administratoren (Patch-Modus der VMs ist 'Manual').

    Das Skript enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'ExchangeLab-InitialUpdates',

    [int] $MaxRuns = 4
)

$ErrorActionPreference = 'Stop'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$CounterFile = Join-Path $LabRoot 'update-runs.txt'
$MicrosoftUpdateServiceId = '7971f918-a847-4430-9279-4a52d1efe18d'

New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir 'Update-LabServer.log'

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function Unregister-UpdateTask {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-LabLog "Task $TaskName entfernt."
}

try {
    $run = 1
    if (Test-Path -Path $CounterFile) {
        $run = [int](Get-Content -Path $CounterFile -Raw) + 1
    }
    Set-Content -Path $CounterFile -Value $run -Encoding ASCII
    if ($run -gt $MaxRuns) {
        Write-LabLog "Maximale Anzahl Durchlaeufe ($MaxRuns) erreicht."
        Unregister-UpdateTask
        exit 0
    }
    Write-LabLog "Update-Durchlauf $run von maximal $MaxRuns."

    $serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $registered = @($serviceManager.Services | Where-Object { $_.ServiceID -eq $MicrosoftUpdateServiceId })
    if (-not $registered) {
        $serviceManager.AddService2($MicrosoftUpdateServiceId, 7, '') | Out-Null
        Write-LabLog 'Microsoft-Update-Dienst registriert.'
    }

    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $searcher.ServerSelection = 3
    $searcher.ServiceID = $MicrosoftUpdateServiceId
    $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

    if ($searchResult.Updates.Count -eq 0) {
        Write-LabLog 'Keine ausstehenden Updates.'
        Unregister-UpdateTask
        exit 0
    }

    $updates = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($update in $searchResult.Updates) {
        if (-not $update.EulaAccepted) {
            $update.AcceptEula()
        }
        Write-LabLog "Gefunden: $($update.Title)"
        $updates.Add($update) | Out-Null
    }

    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $updates
    $downloader.Download() | Out-Null

    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $updates
    $installResult = $installer.Install()
    Write-LabLog "Installation beendet, ResultCode $($installResult.ResultCode), Neustart erforderlich: $($installResult.RebootRequired)."

    if ($installResult.RebootRequired) {
        Write-LabLog 'Neustart in 60 Sekunden, danach naechster Durchlauf.'
        & shutdown.exe /r /t 60 /c 'ExchangeLab: Neustart nach Updates' /d p:2:17 | Out-Null
    }
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    exit 1
}
