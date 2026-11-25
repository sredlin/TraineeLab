<#
.SYNOPSIS
    Wartet nach dem Domaenenbeitritt, bis der Neustart der JsonADDomainExtension erfolgt ist.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) direkt nach der Extension JoinDomain.
    Die Extension meldet Erfolg und startet die VM erst danach neu. Faehrt Windows langsam herunter
    (beim Fileserver nach 60 GB Beispieldaten ueber eine Minute), startet der naechste Run Command
    noch vor dem Neustart und wird von ihm abgebrochen.

    Dieser Run Command faengt das ab: Er endet sofort, wenn der Neustart schon erfolgt ist, und wartet
    sonst, bis ihn der Neustart beendet. Im Template steht treatFailureAsDeploymentFailure = false,
    der Abbruch laesst das Deployment also nicht scheitern. Der folgende Run Command startet in beiden
    Faellen erst nach dem Neustart.

    Das Skript enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[CmdletBinding()]
param(
    [int] $TimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'
$LogDir = 'C:\ExchangeLab\Logs'
$LogFile = Join-Path $LogDir 'Wait-DomainJoinReboot.log'

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

try {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    # Den Schluessel legt der Domaenenbeitritt an, erst der Neustart entfernt ihn.
    $joinKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain'
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    if (Test-Path -Path $joinKey) {
        Write-LabLog 'Neustart nach Domaenenbeitritt steht aus, warte darauf.'
    }
    while (Test-Path -Path $joinKey) {
        if ((Get-Date) -gt $deadline) {
            throw "Neustart nach Domaenenbeitritt nach $TimeoutMinutes Minuten nicht erfolgt."
        }
        Start-Sleep -Seconds 10
    }

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    Write-LabLog "Neustart nach Domaenenbeitritt erfolgt (Domain: $($computerSystem.Domain))."
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    exit 1
}
