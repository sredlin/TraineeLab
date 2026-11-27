<#
.SYNOPSIS
    Prueft ein bereitgestelltes Lab vollstaendig: Deployment, DNS-Delegation, VMs und Hintergrundarbeiten.

.DESCRIPTION
    Liest Sprache und Optionen aus dem letzten Lab-Deployment der Ressourcengruppe und prueft:
      - alle Deployments und Run Commands erfolgreich
      - Delegation der oeffentlichen DNS-Zone in der Parent-Zone
      - Groesse des Fileservers nach der automatischen Verkleinerung
      - je VM die Rollenpruefung aus tools/LabChecks (per az vm run-command invoke): DC, Exchange, Fileserver,
        Client, jeweils mit Suche nach WARNUNG/FEHLER in allen Logs unter C:\ExchangeLab\Logs

    Jede Pruefung ist OK, FAIL oder PENDING (Hintergrundarbeit laeuft noch: Update-Lauf, Beispieldaten,
    Verkleinerung). Mit -Wait wiederholt das Werkzeug die Pruefung, bis nichts mehr PENDING ist.

    Exit-Code: 0 = alles OK (Abnahme bestanden), 1 = mindestens ein FAIL, 2 = noch PENDING.
    Braucht die Azure CLI mit Anmeldung (az login) und Leserechte plus Run Command auf der Ressourcengruppe.

.EXAMPLE
    ./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-abc

.EXAMPLE
    ./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-abc -Wait -WaitMinutes 300
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroup,

    [string] $Subscription = '',

    # Wiederholen, bis keine Pruefung mehr PENDING ist (oder WaitMinutes abgelaufen sind).
    [switch] $Wait,

    [int] $WaitMinutes = 360,

    [int] $IntervalMinutes = 10
)

$ErrorActionPreference = 'Stop'
$checkDir = Join-Path $PSScriptRoot 'LabChecks'

function Invoke-Az {
    # Azure CLI mit JSON-Ausgabe; wirft bei Exit-Code ungleich 0.
    param([Parameter(Mandatory)][string[]] $Arguments)
    $all = $Arguments + @('-o', 'json')
    if ($Subscription) { $all += @('--subscription', $Subscription) }
    # Hinweise der Azure CLI auf stderr verwerfen; unter Windows PowerShell 5.1 waeren sie sonst Fehler.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & az @all 2>$null }
    finally { $ErrorActionPreference = $previous }
    if ($LASTEXITCODE -ne 0) { throw "az $($Arguments -join ' ') endete mit $LASTEXITCODE." }
    if ($output) { ($output -join "`n") | ConvertFrom-Json } else { $null }
}

function ConvertTo-CheckResult {
    param([string] $Target, [string] $Id, [string] $State, [string] $Detail)
    [pscustomobject]@{ Target = $Target; Id = $Id; State = $State; Detail = $Detail }
}

function ConvertTo-PsLiteral {
    # Hashtable mit Zeichenketten, Zahlen und Wahrheitswerten als PowerShell-Quelltext fuer das Pruefskript.
    param([Parameter(Mandatory)][hashtable] $Value)
    $pairs = foreach ($key in $Value.Keys | Sort-Object) {
        $item = $Value[$key]
        $text = if ($item -is [bool]) { if ($item) { '$true' } else { '$false' } }
        elseif ($item -is [int] -or $item -is [long]) { "$item" }
        else { "'{0}'" -f ("$item" -replace "'", "''") }
        "$key = $text"
    }
    '@{ ' + ($pairs -join '; ') + ' }'
}

function Get-LabContext {
    $deployments = @(Invoke-Az -Arguments @('deployment', 'group', 'list', '-g', $ResourceGroup))
    $main = $deployments | Where-Object { $_.properties.parameters.trainee } | Sort-Object { [datetime]$_.properties.timestamp } -Descending | Select-Object -First 1
    if (-not $main) { throw "Kein Lab-Deployment (Parameter trainee) in $ResourceGroup gefunden." }
    $p = $main.properties.parameters
    $trainee = "$($p.trainee.value)".ToLowerInvariant()
    $vmSize = "$($p.fileServerVmSize.value)"
    $finalSize = "$($p.fileServerFinalVmSize.value)"
    # Wie in main.bicep: keine Verkleinerung bei gleicher Groesse oder wenn schon eine B-Serie bereitgestellt wird.
    $resizeTo = if ($finalSize -eq $vmSize -or $vmSize.StartsWith('Standard_B')) { '' } else { $finalSize }
    [pscustomobject]@{
        Deployment           = $main
        Deployments          = $deployments
        Trainee              = $trainee
        Language             = "$($p.labLanguage.value)"
        Domain               = "$trainee.intern"
        Public               = "$trainee.$($p.parentDnsZoneName.value)"
        ParentZone           = "$($p.parentDnsZoneName.value)"
        ParentResourceGroup  = "$($p.parentDnsZoneResourceGroup.value)"
        SecondDc             = [bool]$p.deploySecondDc.value
        Client               = [bool]$p.deployClient.value
        FileServer           = [bool]$p.deployFileServer.value
        RemoteDesktopManager = [bool]$p.clientRemoteDesktopManager.value
        # Als Zeichenkette: Das Pruefskript bekommt nur einfache Werte (ConvertTo-PsLiteral).
        WingetPackages       = (@($p.clientWingetPackages.value) | Where-Object { $_ }) -join ','
        LetsEncrypt          = [bool]$p.enableLetsEncrypt.value
        FileServerPercent    = [int]$p.fileServerDataPercent.value
        FileServerResizeTo   = $resizeTo
        # Ersatz, wenn der Cluster die Dauergroesse nicht anbietet (siehe Resize-FileServer.ps1).
        FileServerFallback   = $vmSize -replace '^(Standard_[A-Za-z]+)\d+', '${1}2'
    }
}

function Get-AzureResult {
    param([Parameter(Mandatory)] $Lab)
    $results = @()

    $main = $Lab.Deployment
    $results += ConvertTo-CheckResult 'Azure' 'deployment' $(if ($main.properties.provisioningState -eq 'Succeeded') { 'OK' } else { 'FAIL' }) "$($main.name): $($main.properties.provisioningState)"
    $mainNames = @($Lab.Deployments | Where-Object { $_.properties.parameters.trainee } | ForEach-Object name)
    $failed = @($Lab.Deployments | Where-Object { $mainNames -notcontains $_.name -and $_.properties.provisioningState -ne 'Succeeded' })
    $results += ConvertTo-CheckResult 'Azure' 'modules' $(if ($failed) { 'FAIL' } else { 'OK' }) $(if ($failed) { ($failed | ForEach-Object { "$($_.name): $($_.properties.provisioningState)" }) -join '; ' } else { "$(@($Lab.Deployments).Count - $mainNames.Count) Module ok" })

    try {
        $zone = Invoke-Az -Arguments @('network', 'dns', 'zone', 'show', '-g', $ResourceGroup, '-n', $Lab.Public)
        $ns = Invoke-Az -Arguments @('network', 'dns', 'record-set', 'ns', 'show', '-g', $Lab.ParentResourceGroup, '-z', $Lab.ParentZone, '-n', $Lab.Trainee)
        $expected = @($zone.nameServers | ForEach-Object { $_.TrimEnd('.').ToLowerInvariant() } | Sort-Object)
        $actual = @($ns.NSRecords | ForEach-Object { $_.nsdname.TrimEnd('.').ToLowerInvariant() } | Sort-Object)
        $same = ($expected -join ',') -eq ($actual -join ',')
        $results += ConvertTo-CheckResult 'Azure' 'dns.delegation' $(if ($same) { 'OK' } else { 'FAIL' }) "$($Lab.Trainee).$($Lab.ParentZone): $($actual -join ', ')"
    }
    catch {
        $results += ConvertTo-CheckResult 'Azure' 'dns.delegation' 'FAIL' $_.Exception.Message
    }

    foreach ($vm in @(Invoke-Az -Arguments @('vm', 'list', '-d', '-g', $ResourceGroup))) {
        $runCommands = @(Invoke-Az -Arguments @('vm', 'run-command', 'list', '-g', $ResourceGroup, '--vm-name', $vm.name))
        # Wait-DomainJoinReboot darf vom Neustart abgebrochen werden (treatFailureAsDeploymentFailure false).
        $bad = @($runCommands | Where-Object { $_.provisioningState -ne 'Succeeded' -and $_.name -ne 'Wait-DomainJoinReboot' })
        $results += ConvertTo-CheckResult $vm.name 'runcommands' $(if ($bad) { 'FAIL' } else { 'OK' }) $(if ($bad) { ($bad | ForEach-Object { "$($_.name): $($_.provisioningState)" }) -join '; ' } else { "$($runCommands.Count) Run Commands ok" })
        if ($vm.powerState -ne 'VM running') {
            $results += ConvertTo-CheckResult $vm.name 'power' 'PENDING' "$($vm.powerState) (Pruefung auf der VM erst nach dem Start)"
        }
        if ($vm.name -eq "vm-$($Lab.Trainee)-fs01" -and $Lab.FileServerResizeTo) {
            $size = $vm.hardwareProfile.vmSize
            $state = if ($size -eq $Lab.FileServerResizeTo -or $size -eq $Lab.FileServerFallback) { 'OK' } else { 'PENDING' }
            $results += ConvertTo-CheckResult $vm.name 'size' $state "$size (Ziel $($Lab.FileServerResizeTo), Ersatz $($Lab.FileServerFallback))"
        }
    }
    $results
}

function Get-VmTarget {
    param([Parameter(Mandatory)] $Lab)
    $dcCount = if ($Lab.SecondDc) { 2 } else { 1 }
    $common = @{
        Language = $Lab.Language; Domain = $Lab.Domain; Public = $Lab.Public; Trainee = $Lab.Trainee; ExchangeIp = '10.0.1.5'
        DcCount = $dcCount; LetsEncrypt = $Lab.LetsEncrypt; FileServerPercent = $Lab.FileServerPercent; RemoteDesktopManager = $Lab.RemoteDesktopManager
        WingetPackages = $Lab.WingetPackages
    }
    $targets = @(
        @{ Vm = "vm-$($Lab.Trainee)-dc01"; Role = 'DomainController'; Extra = @{ FirstDc = $true } }
        @{ Vm = "vm-$($Lab.Trainee)-ex01"; Role = 'Exchange'; Extra = @{} }
    )
    if ($Lab.SecondDc) { $targets += @{ Vm = "vm-$($Lab.Trainee)-dc02"; Role = 'DomainController'; Extra = @{ FirstDc = $false } } }
    if ($Lab.FileServer) { $targets += @{ Vm = "vm-$($Lab.Trainee)-fs01"; Role = 'FileServer'; Extra = @{} } }
    if ($Lab.Client) { $targets += @{ Vm = "vm-$($Lab.Trainee)-cl01"; Role = 'Client'; Extra = @{} } }
    foreach ($target in $targets) {
        $context = $common.Clone()
        foreach ($key in $target.Extra.Keys) { $context[$key] = $target.Extra[$key] }
        if (-not $context.ContainsKey('FirstDc')) { $context.FirstDc = $false }
        $script = @(
            ('$Lab = ' + (ConvertTo-PsLiteral -Value $context))
            (Get-Content -Path (Join-Path $checkDir 'Common.ps1') -Raw)
            (Get-Content -Path (Join-Path $checkDir "$($target.Role).ps1") -Raw)
        ) -join "`n"
        [pscustomobject]@{ Vm = $target.Vm; Role = $target.Role; Script = $script }
    }
}

function Get-VmResult {
    # Rollenpruefungen parallel auf allen laufenden VMs (az vm run-command invoke, Ausgabe CHECK|id|state|detail).
    param([Parameter(Mandatory)][object[]] $Targets, [string[]] $RunningVms)
    $jobs = foreach ($target in $Targets | Where-Object { $RunningVms -contains $_.Vm }) {
        $file = Join-Path ([IO.Path]::GetTempPath()) ('LabCheck-{0}-{1}.ps1' -f $target.Vm, [guid]::NewGuid().ToString('N'))
        Set-Content -Path $file -Value $target.Script -Encoding ASCII
        $arguments = @('vm', 'run-command', 'invoke', '-g', $ResourceGroup, '-n', $target.Vm, '--command-id', 'RunPowerShellScript',
            '--scripts', "@$file", '--query', 'value[0].message', '-o', 'tsv')
        if ($Subscription) { $arguments += @('--subscription', $Subscription) }
        Start-Job -ScriptBlock {
            $azArguments = $using:arguments
            $output = & az @azArguments 2>&1
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output | ForEach-Object { "$_" }) }
        } | Add-Member -NotePropertyName Vm -NotePropertyValue $target.Vm -PassThru | Add-Member -NotePropertyName File -NotePropertyValue $file -PassThru
    }
    foreach ($job in @($jobs)) {
        $result = Receive-Job -Job $job -Wait -AutoRemoveJob
        Remove-Item -Path $job.File -Force -ErrorAction SilentlyContinue
        $lines = @($result.Output | ForEach-Object { $_ -split "`n" } | Where-Object { $_ -like 'CHECK|*' })
        if ($result.ExitCode -ne 0 -or -not $lines) {
            # VM startet gerade neu (Update-Lauf) oder Run Command belegt: beim naechsten Durchlauf erneut.
            ConvertTo-CheckResult $job.Vm 'checks' 'PENDING' ("Pruefung nicht ausfuehrbar: {0}" -f (($result.Output | Select-Object -Last 2) -join ' '))
            continue
        }
        foreach ($line in $lines) {
            $parts = $line.TrimEnd("`r").Split('|', 4)
            ConvertTo-CheckResult $job.Vm $parts[1] $parts[2] $parts[3]
        }
    }
}

$lab = Get-LabContext
Write-Output ('Lab {0} ({1}), Deployment {2}, Sprache {3}, DC02 {4}, Client {5}, Fileserver {6}' -f $lab.Trainee, $ResourceGroup, $lab.Deployment.name, $lab.Language, $lab.SecondDc, $lab.Client, $lab.FileServer)
$targets = @(Get-VmTarget -Lab $lab)
$deadline = (Get-Date).AddMinutes($WaitMinutes)

while ($true) {
    $azure = @(Get-AzureResult -Lab $lab)
    $running = @(Invoke-Az -Arguments @('vm', 'list', '-d', '-g', $ResourceGroup) | Where-Object { $_.powerState -eq 'VM running' } | ForEach-Object name)
    $results = $azure + @(Get-VmResult -Targets $targets -RunningVms $running)
    Write-Output ''
    Write-Output ('Stand {0:yyyy-MM-dd HH:mm}' -f (Get-Date))
    $results | Sort-Object Target, Id | Format-Table -Property State, Target, Id, Detail -AutoSize -Wrap | Out-String -Width 220 | Write-Output

    $fail = @($results | Where-Object State -EQ 'FAIL').Count
    $pending = @($results | Where-Object State -EQ 'PENDING').Count
    Write-Output ('{0} OK, {1} FAIL, {2} PENDING' -f @($results | Where-Object State -EQ 'OK').Count, $fail, $pending)
    if (-not $Wait -or -not $pending -or (Get-Date) -gt $deadline) { break }
    Write-Output "Naechste Pruefung in $IntervalMinutes Minuten (laengstens bis $('{0:HH:mm}' -f $deadline))."
    Start-Sleep -Seconds ($IntervalMinutes * 60)
    # Deployments koennen sich zwischenzeitlich aendern (z. B. erneuter Lauf).
    $lab = Get-LabContext
}

if ($fail) { exit 1 }
if ($pending) { exit 2 }
Write-Output 'Abnahme bestanden: alle Pruefungen OK.'
exit 0
