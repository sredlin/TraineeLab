# Gemeinsame Funktionen der Lab-Pruefskripte (tools/LabChecks). Test-LabDeployment.ps1 setzt davor $Lab
# (Sprache, Domains, Optionen) und haengt das Rollenskript an; das Ganze laeuft per Run Command als SYSTEM
# unter Windows PowerShell 5.1. Ausgabe je Pruefung eine Zeile: CHECK|<id>|OK|FAIL|PENDING|<detail>
#   OK      = erfuellt
#   FAIL    = Fehler, die Abnahme ist nicht bestanden
#   PENDING = Hintergrundarbeit laeuft noch (Update-Lauf, Beispieldaten, Verkleinerung)
# Nur ASCII-Zeichen (Run Command liest UTF-8 ohne BOM als ANSI).

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$LabRoot = 'C:\ExchangeLab'
$Cultures = @{ de = 'de-DE'; en = 'en-GB' }

function Write-Check {
    param([Parameter(Mandatory)][string] $Id, [Parameter(Mandatory)][string] $State, [string] $Detail = '')
    $text = ($Detail -replace '[\r\n|]+', ' ').Trim()
    if ($text.Length -gt 220) { $text = $text.Substring(0, 217) + '...' }
    'CHECK|{0}|{1}|{2}' -f $Id, $State, $text
}

function Invoke-Check {
    # Die Pruefung liefert @(Status, Detail). Ein Fehler darin ergibt FAIL, die weiteren Pruefungen laufen weiter.
    # PendingReason: Hintergrundarbeit laeuft (z. B. Update-Lauf mit gestoppten Diensten), ein FAIL zaehlt dann als PENDING.
    param([Parameter(Mandatory)][string] $Id, [Parameter(Mandatory)][scriptblock] $ScriptBlock, [string] $PendingReason = '')
    try {
        $result = @(& $ScriptBlock)
        $state = $result[0]
        $detail = "$($result[1])"
    }
    catch {
        $state = 'FAIL'
        $detail = $_.Exception.Message
    }
    if ($state -eq 'FAIL' -and $PendingReason) {
        $state = 'PENDING'
        $detail = "${PendingReason}: $detail"
    }
    Write-Check -Id $Id -State $state -Detail $detail
}

function Test-RebootPending {
    (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
    (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
}

function Invoke-CommonCheck {
    # Pruefungen fuer jede Lab-VM: Logs ohne WARNUNG/FEHLER, Gebietsschema, optional Update-Lauf und Lab-Info.
    param([switch] $UpdateRun, [switch] $LabInfo)

    Invoke-Check 'logs' {
        $hits = @(Get-ChildItem -Path (Join-Path $LabRoot 'Logs') -Filter '*.log' -ErrorAction SilentlyContinue |
                Select-String -Pattern '(WARNUNG|FEHLER):' -CaseSensitive)
        if (-not $hits) { return 'OK', 'keine WARNUNG/FEHLER' }
        $first = @($hits | Select-Object -First 2 | ForEach-Object { '{0}:{1} {2}' -f $_.Filename, $_.LineNumber, $_.Line.Trim() })
        'FAIL', ('{0} Treffer: {1}' -f $hits.Count, ($first -join ' || '))
    }

    Invoke-Check 'culture' {
        $culture = (Get-Culture).Name
        if ($culture -eq $Cultures[$Lab.Language]) { 'OK', $culture } else { 'FAIL', "Gebietsschema $culture statt $($Cultures[$Lab.Language])" }
    }

    if ($UpdateRun) {
        Invoke-Check 'updates' {
            $runs = Join-Path $LabRoot 'update-runs.txt'
            $task = Get-ScheduledTask -TaskName 'ExchangeLab-InitialUpdates' -ErrorAction SilentlyContinue
            if ($task) {
                $count = if (Test-Path -Path $runs) { (Get-Content -Path $runs -Raw).Trim() } else { 0 }
                return 'PENDING', "Update-Lauf noch nicht fertig (Durchlauf $count, Task $($task.State))"
            }
            if (-not (Test-Path -Path $runs)) { return 'FAIL', 'kein Update-Lauf (update-runs.txt und Task fehlen)' }
            if (Test-RebootPending) { return 'PENDING', 'Update-Lauf fertig, Neustart steht aus' }
            $last = Get-Content -Path (Join-Path $LabRoot 'Logs\Update-LabServer.log') -Tail 1 -ErrorAction SilentlyContinue
            'OK', "fertig: $last"
        }
    }

    if ($LabInfo) {
        Invoke-Check 'labinfo' {
            $path = Join-Path $env:PUBLIC 'Desktop\Lab-Info.txt'
            if (-not (Test-Path -Path $path)) { return 'FAIL', 'Lab-Info.txt fehlt' }
            $text = Get-Content -Path $path -Raw
            if ($text -match '\{\d+[^}]*\}') { return 'FAIL', "offener Platzhalter: $($Matches[0])" }
            'OK', ('{0} Zeilen' -f @(Get-Content -Path $path).Count)
        }
    }
}
