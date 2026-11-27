<#
.SYNOPSIS
    Verkleinert den Fileserver nach der Erzeugung der Beispieldokumente auf seine Dauergroesse.

.DESCRIPTION
    Laeuft als geplanter Task (SYSTEM, beim Start und alle 15 Minuten), registriert von
    Initialize-FileServer.ps1 in der Phase Complete. Die VM wird mit mehr vCPUs bereitgestellt,
    damit die Beispieldokumente schnell entstehen, und danach automatisch verkleinert.

    Geaendert wird erst, wenn
      - die Beispieldokumente fertig sind (C:\ExchangeLab\sample-documents.json, State 'fertig'),
      - die Einrichtung abgeschlossen ist (Marker fs-complete.done),
      - der Update-Task fertig ist und kein Neustart aussteht,
      - die VM seit mindestens MinUptimeMinutes laeuft und kein Run Command auf ihr laeuft
        (kein Konflikt mit einem laufenden Deployment).

    Die Groesse setzt die verwaltete Identitaet der VM (Rolle 'Virtual Machine Contributor' nur auf
    diese VM) ueber die ARM-API. Azure startet die VM dafuer einmal neu. Eine Groessenaenderung ohne
    Deallokieren geht nur auf Groessen, die der aktuelle Hardware-Cluster anbietet. Fehlt die Zielgroesse
    dort (im Abnahmetest 2026-11-26 fuer Standard_B2s_v2 nachgewiesen), nimmt das Skript die 2-vCPU-Groesse
    derselben Familie (z. B. Standard_D4s_v5 -> Standard_D2s_v5), die der Cluster praktisch immer anbietet.
    Erst wenn auch die fehlt, bleibt die VM unveraendert und das Log nennt die Befehle fuer die Hand.

    Nur ASCII (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $TargetSize,

    # $true: erst nach fertigen Beispieldokumenten verkleinern.
    [bool] $WaitForSampleDocuments = $true,

    [int] $MinUptimeMinutes = 30,

    [string] $UpdateTaskName = 'ExchangeLab-InitialUpdates'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$LogFile = Join-Path $LogDir 'Resize-FileServer.log'
$StatusFile = Join-Path $LabRoot 'sample-documents.json'
$CompleteMarker = Join-Path $LabRoot 'fs-complete.done'
$ArmApiVersion = '2024-07-01'

New-Item -Path $LogDir -ItemType Directory -Force | Out-Null

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function Get-ComputeInfo {
    Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01' -Headers @{ Metadata = 'true' } -TimeoutSec 15
}

function Get-ArmToken {
    $uri = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
    (Invoke-RestMethod -Uri $uri -Headers @{ Metadata = 'true' } -TimeoutSec 15).access_token
}

function Get-WaitReason {
    # Liefert den Grund, warum noch nicht verkleinert wird, oder $null.
    if ($WaitForSampleDocuments) {
        if (-not (Test-Path -Path $StatusFile)) { return 'Beispieldokumente noch nicht gestartet' }
        $status = Get-Content -Path $StatusFile -Raw | ConvertFrom-Json
        if ($status.State -ne 'fertig') { return ('Beispieldokumente: {0}, {1} von {2} GB' -f $status.State, $status.WrittenGB, $status.TargetGB) }
    }
    if (-not (Test-Path -Path $CompleteMarker)) { return 'Einrichtung (Complete-FileServer) noch nicht abgeschlossen' }
    if (Get-ScheduledTask -TaskName $UpdateTaskName -ErrorAction SilentlyContinue) { return "Update-Task $UpdateTaskName laeuft noch" }
    foreach ($key in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        if (Test-Path -Path $key) { return 'Neustart steht aus' }
    }
    $uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    if ($uptime.TotalMinutes -lt $MinUptimeMinutes) { return ('VM laeuft erst {0:N0} Minuten' -f $uptime.TotalMinutes) }
    $null
}

try {
    $compute = Get-ComputeInfo
    # Ersatzgroesse: 2 vCPU derselben Familie wie die aktuelle Groesse.
    $fallbackSize = $compute.vmSize -replace '^(Standard_[A-Za-z]+)\d+', '${1}2'
    if ($compute.vmSize -eq $TargetSize -or $compute.vmSize -eq $fallbackSize) {
        Write-Verbose -Message "Groesse $($compute.vmSize) bereits gesetzt."
        exit 0
    }
    $reason = Get-WaitReason
    if ($reason) {
        Write-LabLog "Warte ($($compute.vmSize) -> $TargetSize): $reason."
        exit 0
    }

    $vmUri = 'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/virtualMachines/{2}' -f $compute.subscriptionId, $compute.resourceGroupName, $compute.name
    $headers = @{ Authorization = "Bearer $(Get-ArmToken)" }

    # Der Neustart der Groessenaenderung wuerde einen laufenden Run Command (z. B. aus einem erneuten Deployment) abbrechen.
    $runCommands = @((Invoke-RestMethod -Uri "$vmUri/runCommands?`$expand=instanceView&api-version=$ArmApiVersion" -Headers $headers -TimeoutSec 60).value)
    $busy = @($runCommands | Where-Object {
            $_.properties.provisioningState -notin 'Succeeded', 'Failed', 'Canceled' -or
            "$($_.properties.instanceView.executionState)" -in 'Pending', 'Running'
        } | ForEach-Object { $_.name })
    if ($busy) {
        Write-LabLog "Warte ($($compute.vmSize) -> $TargetSize): Run Command $($busy -join ', ') laeuft."
        exit 0
    }

    $available = @((Invoke-RestMethod -Uri "$vmUri/vmSizes?api-version=$ArmApiVersion" -Headers $headers -TimeoutSec 60).value.name)
    if ($available -contains $TargetSize) {
        $newSize = $TargetSize
    }
    elseif ($available -contains $fallbackSize) {
        $newSize = $fallbackSize
        Write-LabLog "Hinweis: $TargetSize bietet der aktuelle Cluster nicht an, nutze $fallbackSize (gleiche Familie wie $($compute.vmSize))."
    }
    else {
        Write-LabLog ('WARNUNG: Weder {0} noch {4} sind im aktuellen Cluster verfuegbar, die VM bleibt {1}. Von Hand: az vm deallocate, az vm resize --size {0}, az vm start (-g {2} -n {3}).' -f $TargetSize, $compute.vmSize, $compute.resourceGroupName, $compute.name, $fallbackSize)
        exit 0
    }

    $body = @{ properties = @{ hardwareProfile = @{ vmSize = $newSize } } } | ConvertTo-Json -Depth 5
    Write-LabLog "Aendere die Groesse von $($compute.vmSize) auf $newSize. Azure startet die VM dafuer neu."
    Invoke-RestMethod -Method Patch -Uri "${vmUri}?api-version=$ArmApiVersion" -Headers $headers -Body $body -ContentType 'application/json' -TimeoutSec 120 | Out-Null
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    exit 0
}
