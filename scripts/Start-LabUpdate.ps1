<#
.SYNOPSIS
    Registriert und startet den einmaligen Update-Lauf (Update-LabServer.ps1) auf einem Domain Controller.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) am Ende des Deployments (Modul lab-finalize), wenn Exchange,
    Client und Fileserver fertig sind. Die Neustarts der DCs treffen so keine VM mehr, die gerade beitritt oder
    sich einrichtet. Der Task startet sich nach jedem Neustart erneut, bis keine Updates mehr ausstehen.

    Idempotent: Hat der Update-Lauf schon begonnen (update-runs.txt) oder laeuft er, aendert sich nichts.
    Das Skript enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $UpdateScriptB64,

    [string] $TaskName = 'ExchangeLab-InitialUpdates'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$ScriptDir = Join-Path $LabRoot 'Scripts'
New-Item -Path $LogDir, $ScriptDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir 'Start-LabUpdate.log'

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

try {
    $scriptPath = Join-Path $ScriptDir 'Update-LabServer.ps1'
    Set-Content -Path $scriptPath -Value ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($UpdateScriptB64))) -Encoding ASCII

    if (Test-Path -Path (Join-Path $LabRoot 'update-runs.txt')) {
        Write-LabLog 'Update-Lauf hat bereits begonnen, nichts zu tun.'
        exit 0
    }
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Running') {
        Write-LabLog "Update-Task $TaskName laeuft bereits."
        exit 0
    }

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -TaskName $TaskName"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = 'PT5M'
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4) -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Write-LabLog "Update-Task $TaskName registriert und gestartet."
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    exit 1
}
