<#
.SYNOPSIS
    Prueft alle fest hinterlegten Downloads des Labs (Erreichbarkeit, Groesse, Hash).

.DESCRIPTION
    Die VM-Skripte laden feste Versionen mit Hash (PowerShell 7, VC++-Redistributables, IIS URL Rewrite,
    CSS-Exchange-Diagnose, Office Deployment Tool, .NET Desktop Runtime, Remote Desktop Manager) und feste
    Modulversionen aus der PowerShell Gallery. Entfernt ein Hersteller eine Version, scheitert das Deployment erst
    auf der VM. Dieses Werkzeug findet das vorher: vor jeder Abnahme und nach jeder Versionsaenderung ausfuehren.

    - Dateien bis MaxHashMB werden geladen und gegen den Hash im Skript geprueft.
    - Groessere Dateien (z. B. das Exchange-ISO) nur per HEAD: erreichbar, Groesse plausibel.
    - Module: Eintrag fuer Name und Version in der PowerShell Gallery vorhanden.

    Die Werte kommen direkt aus den Skripten (Zuweisungen per AST), nichts ist doppelt gepflegt.
    Blockiert das eigene Netz Downloads (z. B. GitHub-Release-Assets hinter einer Firmen-Firewall), prueft
    -ResourceGroup/-VmName stattdessen von einer laufenden Azure-VM aus (az vm run-command invoke).
    Exit-Code 0 = alles ok, 1 = mindestens ein Fehler.

.EXAMPLE
    ./tools/Test-Downloads.ps1

.EXAMPLE
    ./tools/Test-Downloads.ps1 -ResourceGroup rg-exlab-abc -VmName vm-abc-ex01
#>
[CmdletBinding()]
param(
    # Dateien bis zu dieser Groesse werden geladen und per Hash geprueft.
    [int] $MaxHashMB = 400,

    # Optional: Pruefung von dieser Azure-VM aus (Windows, Run Command).
    [string] $ResourceGroup = '',
    [string] $VmName = '',
    [string] $Subscription = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repoRoot = Split-Path -Path $PSScriptRoot -Parent

function Get-ScriptAssignment {
    # Wertet die Zuweisungen auf oberster Ebene eines Skripts fuer die genannten Variablen aus (nur eigene Repo-Skripte).
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string[]] $Name)
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    $values = @{}
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -isnot [System.Management.Automation.Language.AssignmentStatementAst]) { continue }
        $variable = $statement.Left.VariablePath.UserPath
        if ($Name -notcontains $variable) { continue }
        # Abhaengige Werte (z. B. $CssExchangeRelease in $LabTools) stehen im Skript vorher und sind schon gesetzt.
        foreach ($entry in $values.GetEnumerator()) { Set-Variable -Name $entry.Key -Value $entry.Value }
        $values[$variable] = & ([scriptblock]::Create($statement.Right.Extent.Text))
    }
    foreach ($missing in @($Name | Where-Object { -not $values.ContainsKey($_) })) { throw "$missing fehlt in $Path." }
    $values
}

# Die eigentliche Pruefung; laeuft lokal oder per Run Command auf einer VM (Windows PowerShell 5.1).
$check = {
    param([Parameter(Mandatory)][string] $ItemsJson, [int] $MaxHashMB)
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $items = $ItemsJson | ConvertFrom-Json
    $failed = 0
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('lab-downloads-{0}' -f [guid]::NewGuid().ToString('N'))
    New-Item -Path $temp -ItemType Directory -Force | Out-Null
    try {
        foreach ($file in $items.Files) {
            try {
                $head = Invoke-WebRequest -Uri $file.Url -Method Head -UseBasicParsing -MaximumRedirection 5
                $sizeMB = [long]"$($head.Headers['Content-Length'])" / 1MB
                if ($file.MinMB -and $sizeMB -lt $file.MinMB) { throw ('nur {0:N0} MB' -f $sizeMB) }
                $detail = '{0:N1} MB' -f $sizeMB
                $algorithm = if ($file.Sha512) { 'SHA512' } elseif ($file.Sha256) { 'SHA256' } else { '' }
                if ($algorithm -and $sizeMB -le $MaxHashMB) {
                    $target = Join-Path $temp ([IO.Path]::GetFileName(([uri]$file.Url).AbsolutePath))
                    Invoke-WebRequest -Uri $file.Url -OutFile $target -UseBasicParsing
                    $expected = if ($algorithm -eq 'SHA512') { $file.Sha512 } else { $file.Sha256 }
                    $actual = (Get-FileHash -Path $target -Algorithm $algorithm).Hash
                    if ($actual -ne $expected) { throw "$algorithm weicht ab (erwartet $expected, erhalten $actual)" }
                    Remove-Item -Path $target -Force
                    $detail += ", $algorithm ok"
                }
                'OK     {0,-28} {1}' -f $file.Name, $detail
            }
            catch {
                $failed++
                'FEHLER {0,-28} {1}: {2}' -f $file.Name, $file.Url, $_.Exception.Message
            }
        }
        foreach ($module in $items.Modules) {
            $url = "https://www.powershellgallery.com/api/v2/Packages(Id='{0}',Version='{1}')" -f $module.Name, $module.Version
            try {
                Invoke-WebRequest -Uri $url -UseBasicParsing | Out-Null
                'OK     {0,-28} {1} in der PowerShell Gallery' -f $module.Name, $module.Version
            }
            catch {
                $failed++
                'FEHLER {0,-28} {1}: {2}' -f $module.Name, $module.Version, $_.Exception.Message
            }
        }
    }
    finally {
        Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
    "FAILED=$failed"
}

$exchange = Get-ScriptAssignment -Path (Join-Path $repoRoot 'scripts/Initialize-ExchangeServer.ps1') -Name 'CssExchangeRelease', 'LabTools', 'PowerShell7', 'RequiredPackages', 'PoshAcmeVersion', 'WinGetClientVersion'
$client = Get-ScriptAssignment -Path (Join-Path $repoRoot 'scripts/Initialize-LabClient.ps1') -Name 'OfficeDeploymentTool', 'DotNetDesktopRuntime', 'RdmInstaller', 'PowerShell7', 'RdmModule'
$bicep = Get-Content -Path (Join-Path $repoRoot 'infra/main.bicep') -Raw
$isoUri = [regex]::Match($bicep, "param exchangeIsoUri string = '([^']+)'").Groups[1].Value

$files = @(
    @{ Name = 'Exchange-ISO'; Url = $isoUri; MinMB = 5000 }
    @{ Name = 'PowerShell 7 (Exchange)'; Url = $exchange.PowerShell7.Url; Sha256 = $exchange.PowerShell7.Sha256 }
    @{ Name = 'PowerShell 7 (Client)'; Url = $client.PowerShell7.Url; Sha256 = $client.PowerShell7.Sha256 }
    @{ Name = 'Office Deployment Tool'; Url = $client.OfficeDeploymentTool.Url; Sha256 = $client.OfficeDeploymentTool.Sha256 }
    @{ Name = '.NET Desktop Runtime'; Url = $client.DotNetDesktopRuntime.Url; Sha512 = $client.DotNetDesktopRuntime.Sha512 }
    @{ Name = 'Remote Desktop Manager'; Url = $client.RdmInstaller.Url; Sha256 = $client.RdmInstaller.Sha256 }
)
foreach ($package in $exchange.RequiredPackages) { $files += @{ Name = $package.Id; Url = $package.Url; Sha256 = $package.Sha256 } }
foreach ($tool in $exchange.LabTools) { $files += @{ Name = $tool.Name; Url = $tool.Url; Sha256 = $tool.Sha256 } }
$modules = @(
    @{ Name = 'Posh-ACME'; Version = $exchange.PoshAcmeVersion }
    @{ Name = 'Microsoft.WinGet.Client'; Version = $exchange.WinGetClientVersion }
    @{ Name = $client.RdmModule.Name; Version = $client.RdmModule.Version }
)
$itemsJson = @{ Files = $files; Modules = $modules } | ConvertTo-Json -Depth 5 -Compress

if ($VmName) {
    if (-not $ResourceGroup) { throw 'Mit -VmName ist auch -ResourceGroup noetig.' }
    $itemsB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($itemsJson))
    $remote = "`$json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$itemsB64'))`n& {`n$check`n} -ItemsJson `$json -MaxHashMB $MaxHashMB"
    $scriptFile = Join-Path ([IO.Path]::GetTempPath()) ('Test-Downloads-{0}.ps1' -f [guid]::NewGuid().ToString('N'))
    Set-Content -Path $scriptFile -Value $remote -Encoding ASCII
    try {
        $arguments = @('vm', 'run-command', 'invoke', '-g', $ResourceGroup, '-n', $VmName, '--command-id', 'RunPowerShellScript', '--scripts', "@$scriptFile", '--query', 'value[0].message', '-o', 'tsv')
        if ($Subscription) { $arguments += @('--subscription', $Subscription) }
        $output = @(& az @arguments)
        if ($LASTEXITCODE -ne 0) { throw "az vm run-command invoke endete mit $LASTEXITCODE." }
    }
    finally {
        Remove-Item -Path $scriptFile -Force -ErrorAction SilentlyContinue
    }
}
else {
    $output = @(& $check -ItemsJson $itemsJson -MaxHashMB $MaxHashMB)
}

$output | Where-Object { $_ -notlike 'FAILED=*' } | Write-Output
$failedLine = $output | Where-Object { $_ -like 'FAILED=*' } | Select-Object -Last 1
if (-not $failedLine) {
    Write-Output 'FEHLER: Pruefung ohne Ergebnis beendet.'
    exit 1
}
$failed = [int]($failedLine -replace '^FAILED=', '')
if ($failed) {
    Write-Output "$failed Download(s) fehlerhaft."
    exit 1
}
Write-Output 'Alle Downloads ok.'
exit 0
