#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

# Tests gegen die Fehlerklassen aus den Testdeployments: Run-Command-Parameter, Argumente geplanter Tasks,
# Formatstrings der Lab-Info, native Befehle unter Windows PowerShell 5.1, Zeitlimits und DPAPI.
# Laufen unter pwsh 7 (Linux, Windows) und Windows PowerShell 5.1; Laufzeittests mit Windows-Werkzeugen
# (icacls, DPAPI) nur unter Windows. Die Datei enthaelt bewusst nur ASCII-Zeichen.

BeforeDiscovery {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    $scriptFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -Filter '*.ps1' | Where-Object Name -NE 'Start-SampleDocuments.ps1' | ForEach-Object {
            @{ Name = $_.Name; Path = $_.FullName }
        })
    $nativeScripts = @($scriptFiles | Where-Object { (Get-Content -Path $_.Path -Raw) -match 'function Invoke-NativeCommand \{' })

    # Run Commands aus den Bicep-Modulen: Skriptdatei, uebergebene Parameter und feste Werte.
    $runCommands = @(foreach ($module in Get-ChildItem -Path (Join-Path $repoRoot 'infra/modules') -Filter '*.bicep') {
            $text = (Get-Content -Path $module.FullName -Raw) -replace "`r`n", "`n"
            foreach ($match in [regex]::Matches($text, "(?ms)^resource \w+ 'Microsoft\.Compute/virtualMachines/runCommands@[^']+' = .*?^\}\]?$")) {
                $block = $match.Value
                $literals = @{}
                foreach ($literal in [regex]::Matches($block, "(?m)^\s{8,}name: '([^']+)'\n\s*value: '([^']*)'")) {
                    $literals[$literal.Groups[1].Value] = $literal.Groups[2].Value
                }
                @{
                    Module     = $module.Name
                    RunCommand = [regex]::Match($block, "(?m)^  name: '([^']+)'").Groups[1].Value
                    ScriptFile = [regex]::Match($block, "loadTextContent\('\.\./\.\./scripts/([^']+\.ps1)'\)").Groups[1].Value
                    Passed     = @([regex]::Matches($block, "(?m)^\s{8,}name: '([^']+)'") | ForEach-Object { $_.Groups[1].Value })
                    Literals   = $literals
                }
            }
        })
}

BeforeAll {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

    function Get-ScriptAst {
        param([Parameter(Mandatory)][string] $Path)
        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    }

    function Get-ParameterAst {
        # param()-Block eines Skripts; mit 'Datei#Variable' der eines eingebetteten Skripts (Here-String).
        param([Parameter(Mandatory)][string] $Target)
        $file, $variable = $Target -split '#', 2
        $ast = Get-ScriptAst -Path (Join-Path $repoRoot "scripts/$file")
        if ($variable) {
            $assignment = $ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.VariablePath.UserPath -eq $variable
                }, $true)
            $inner = $assignment.Right.Find({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($inner.Value, [ref]$null, [ref]$null)
        }
        @($ast.ParamBlock.Parameters)
    }

    function Import-ScriptFunction {
        # Liefert den Quelltext von Funktionen eines Skripts zum Dot-Sourcen im Test.
        param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string[]] $Name)
        $ast = Get-ScriptAst -Path $Path
        $text = foreach ($functionName in $Name) {
            $function = $ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
                }, $true)
            if (-not $function) { throw "Funktion $functionName fehlt in $Path." }
            $function.Extent.Text
        }
        [scriptblock]::Create(($text -join "`n"))
    }

    function Get-MaxPlaceholder {
        # Hoechster Index eines Formatplatzhalters ({0}, {1,-15}, {2:N1}); -1 ohne Platzhalter.
        param([string] $Format)
        $clean = $Format -replace '\{\{', '' -replace '\}\}', ''
        $indexes = @([regex]::Matches($clean, '\{(\d+)(?:,[^}:]*)?(?::[^}]*)?\}') | ForEach-Object { [int]$_.Groups[1].Value })
        if ($indexes) { ($indexes | Measure-Object -Maximum).Maximum } else { -1 }
    }

    function Get-FunctionMinute {
        # Groesste feste Wartezeit (AddMinutes(n)) in einer Funktion.
        param([Parameter(Mandatory)][string] $ScriptFile, [Parameter(Mandatory)][string] $Function)
        $ast = Get-ScriptAst -Path (Join-Path $repoRoot "scripts/$ScriptFile")
        $node = $ast.Find({
                param($candidate)
                $candidate -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $candidate.Name -eq $Function
            }, $true)
        if (-not $node) { throw "Funktion $Function fehlt in $ScriptFile." }
        $minutes = @([regex]::Matches($node.Extent.Text, 'AddMinutes\((\d+)\)') | ForEach-Object { [int]$_.Groups[1].Value })
        if (-not $minutes) { throw "Keine feste Wartezeit in $Function ($ScriptFile)." }
        ($minutes | Measure-Object -Maximum).Maximum
    }

    function Get-ParameterDefault {
        param([Parameter(Mandatory)][string] $Target, [Parameter(Mandatory)][string] $Name)
        $parameter = Get-ParameterAst -Target $Target | Where-Object { $_.Name.VariablePath.UserPath -eq $Name }
        if (-not $parameter.DefaultValue) { throw "$Name hat in $Target keinen Standardwert." }
        [int]$parameter.DefaultValue.Value
    }

    function Get-FunctionParameterDefault {
        param([Parameter(Mandatory)][string] $ScriptFile, [Parameter(Mandatory)][string] $Function, [Parameter(Mandatory)][string] $Name)
        $ast = Get-ScriptAst -Path (Join-Path $repoRoot "scripts/$ScriptFile")
        $node = $ast.Find({
                param($candidate)
                $candidate -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $candidate.Name -eq $Function
            }, $true)
        $parameter = @($node.Body.ParamBlock.Parameters) | Where-Object { $_.Name.VariablePath.UserPath -eq $Name }
        [int]$parameter.DefaultValue.Value
    }

    function Get-RunCommandTimeout {
        param([Parameter(Mandatory)][string] $Module, [Parameter(Mandatory)][string] $RunCommand)
        $text = (Get-Content -Path (Join-Path $repoRoot "infra/modules/$Module") -Raw) -replace "`r`n", "`n"
        $block = [regex]::Matches($text, "(?ms)^resource \w+ 'Microsoft\.Compute/virtualMachines/runCommands@[^']+' = .*?^\}\]?$") |
            Where-Object { $_.Value -match "(?m)^  name: '$([regex]::Escape($RunCommand))'" } | Select-Object -First 1
        if (-not $block) { throw "Run Command $RunCommand fehlt in $Module." }
        [int][regex]::Match($block.Value, 'timeoutInSeconds: (\d+)').Groups[1].Value
    }

    function Get-NativeTestCommand {
        # Programm, das auf stderr schreibt und mit dem Exit-Code endet (Windows: cmd.exe, sonst sh).
        param([int] $ExitCode)
        if ($isWindowsHost) { @{ FilePath = 'cmd.exe'; ArgumentList = @('/c', "echo stoerung 1>&2 & exit $ExitCode") } }
        else { @{ FilePath = 'sh'; ArgumentList = @('-c', "echo stoerung >&2; exit $ExitCode") } }
    }
}

Describe 'Run Command <RunCommand> (<Module>)' -ForEach @($runCommands | Where-Object { $_.ScriptFile }) {
    BeforeAll {
        $parameters = Get-ParameterAst -Target $ScriptFile
        $names = @($parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    }

    It 'uebergibt nur Parameter, die <ScriptFile> kennt' {
        foreach ($name in $Passed) {
            $names | Should -Contain $name -Because "$Module uebergibt $name an $ScriptFile"
        }
    }

    It 'uebergibt alle Pflichtparameter von <ScriptFile>' {
        foreach ($parameter in $parameters) {
            $mandatory = $parameter.Attributes | Where-Object {
                $_.TypeName.Name -eq 'Parameter' -and ($_.NamedArguments | Where-Object ArgumentName -EQ 'Mandatory')
            }
            if ($mandatory) {
                $Passed | Should -Contain $parameter.Name.VariablePath.UserPath -Because "$ScriptFile verlangt $($parameter.Name.VariablePath.UserPath)"
            }
        }
    }

    It 'haelt bei festen Werten das ValidateSet von <ScriptFile> ein' {
        foreach ($entry in $Literals.GetEnumerator()) {
            $parameter = $parameters | Where-Object { $_.Name.VariablePath.UserPath -eq $entry.Key }
            $set = $parameter.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' }
            if ($set) {
                @($set.PositionalArguments | ForEach-Object { $_.Value }) | Should -Contain $entry.Value
            }
        }
    }
}

Describe 'Argumente geplanter Tasks und Hilfsprozesse' {
    It '<Source> (<Function>) passt zum param()-Block von <Target>' -ForEach @(
        @{ Source = 'Install-ExchangeServer.ps1'; Function = 'Invoke-InstallTask'; Target = 'Install-ExchangeServer.ps1' }
        @{ Source = 'Install-ExchangeServer.ps1'; Function = 'Register-LabUpdateTask'; Target = 'Update-LabServer.ps1' }
        @{ Source = 'Install-DomainController.ps1'; Function = 'Register-PhaseTask'; Target = 'Install-DomainController.ps1' }
        @{ Source = 'Initialize-FileServer.ps1'; Function = 'Register-ResizeTask'; Target = 'Resize-FileServer.ps1' }
        @{ Source = 'Initialize-FileServer.ps1'; Function = 'Register-LabUpdateTask'; Target = 'Update-LabServer.ps1' }
        @{ Source = 'Initialize-ExchangeServer.ps1'; Function = 'Invoke-WinGetInstall'; Target = 'Initialize-ExchangeServer.ps1#WinGetHelperScript' }
        @{ Source = 'Initialize-LabClient.ps1'; Function = 'Invoke-WinGetTool'; Target = 'Initialize-LabClient.ps1#WinGetHelperScript' }
        @{ Source = 'Initialize-LabClient.ps1'; Function = 'Register-WinGetUpdateTask'; Target = 'Initialize-LabClient.ps1#WinGetHelperScript' }
        @{ Source = 'Start-LabUpdate.ps1'; Function = ''; Target = 'Update-LabServer.ps1' }
        @{ Source = 'New-SampleDocuments.ps1'; Function = 'Invoke-MainPhase'; Target = 'New-SampleDocuments.ps1' }
        @{ Source = 'New-SampleDocuments.ps1'; Function = 'Register-ContinuationTask'; Target = 'New-SampleDocuments.ps1' }
    ) {
        $ast = Get-ScriptAst -Path (Join-Path $repoRoot "scripts/$Source")
        $scope = if ($Function) {
            $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Function }, $true)
        }
        else { $ast }
        $scope | Should -Not -BeNullOrEmpty
        $strings = @($scope.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
                }, $true) | ForEach-Object { $_.Value })
        # Argumentlisten: Zeichenketten mit -File/-Command oder einzelne Argumente wie ' -NoRaster' bzw. '-Ids'.
        $argumentText = ($strings | Where-Object { $_ -match '-File |-Command ' -or $_ -match '^\s*-[A-Z]' }) -join ' '
        $used = @([regex]::Matches($argumentText, '(?<=^|\s|")-([A-Z][A-Za-z0-9]+)') | ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -notin 'NoProfile', 'NonInteractive', 'ExecutionPolicy', 'File', 'Command' } | Select-Object -Unique)
        $used | Should -Not -BeNullOrEmpty
        $known = @(Get-ParameterAst -Target $Target | ForEach-Object { $_.Name.VariablePath.UserPath })
        foreach ($name in $used) {
            $known | Should -Contain $name -Because "$Source uebergibt -$name an $Target"
        }
    }
}

Describe 'Skript <Name> (statische Pruefungen)' -ForEach $scriptFiles {
    BeforeAll {
        $ast = Get-ScriptAst -Path $Path
    }

    It 'leitet stderr nur in Invoke-NativeCommand um (Windows PowerShell 5.1 wirft sonst vor dem Exit-Code)' {
        $redirections = @($ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.MergingRedirectionAst] -and "$($node.FromStream)" -eq 'Error'
                }, $true))
        foreach ($redirection in $redirections) {
            $owner = $redirection.Parent
            while ($owner -and $owner -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) { $owner = $owner.Parent }
            $owner.Name | Should -Be 'Invoke-NativeCommand' -Because "Zeile $($redirection.Extent.StartLineNumber)"
        }
    }

    It 'hat fuer jeden Formatstring genug Argumente, auch in den Sprachtabellen de/en' {
        # Sprachtabellen: $X = @{ de = @{ Key = '...' }; en = @{ Key = '...' } }[$LabLanguage]
        $tables = @{}
        foreach ($assignment in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
            $index = $assignment.Right.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.IndexExpressionAst] -and $node.Target -is [System.Management.Automation.Language.HashtableAst]
                }, $true)
            if (-not $index) { continue }
            $languages = @{}
            foreach ($pair in $index.Target.KeyValuePairs) {
                $inner = $pair.Item2.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $true)
                if (-not $inner) { continue }
                $values = @{}
                foreach ($entry in $inner.KeyValuePairs) {
                    $expression = $entry.Item2.PipelineElements[0].Expression
                    if ($expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $values[$entry.Item1.Value] = $expression.Value }
                }
                $languages[$pair.Item1.Value] = $values
            }
            if ($languages.ContainsKey('de') -and $languages.ContainsKey('en')) {
                $variable = $assignment.Left.VariablePath.UserPath
                @($languages.de.Keys | Sort-Object) | Should -Be @($languages.en.Keys | Sort-Object) -Because "Tabelle `$$variable braucht in beiden Sprachen dieselben Texte"
                $tables[$variable] = $languages
            }
        }

        $formats = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.BinaryExpressionAst] -and "$($node.Operator)" -eq 'Format'
            }, $true)
        foreach ($format in $formats) {
            if ($format.Right -is [System.Management.Automation.Language.VariableExpressionAst]) { continue }
            $count = if ($format.Right -is [System.Management.Automation.Language.ArrayLiteralAst]) { $format.Right.Elements.Count } else { 1 }
            $texts = @()
            $left = $format.Left
            if ($left -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $left -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                $texts += $left.Value
            }
            elseif ($left -is [System.Management.Automation.Language.MemberExpressionAst] -and $left.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $tables.ContainsKey($left.Expression.VariablePath.UserPath)) {
                foreach ($language in 'de', 'en') {
                    $text = $tables[$left.Expression.VariablePath.UserPath][$language]["$($left.Member.Value)"]
                    if ($null -ne $text) { $texts += $text }
                }
            }
            foreach ($text in $texts) {
                (Get-MaxPlaceholder -Format $text) | Should -BeLessThan $count -Because "Zeile $($format.Extent.StartLineNumber): '$text' mit $count Argument(en)"
            }
        }
    }
}

Describe 'Zeitlimits der Run Commands' {
    It '<RunCommand> (<Module>): Zeitlimit liegt ueber den internen Wartezeiten' -ForEach @(
        @{ Module = 'dc-ready.bicep'; RunCommand = 'Wait-SecondDomainController'; Minutes = { Get-ParameterDefault 'Wait-SecondDomainController.ps1' 'TimeoutMinutes' } }
        @{ Module = 'domain-controller.bicep'; RunCommand = 'Wait-DomainController'; Minutes = { Get-ParameterDefault 'Wait-DomainController.ps1' 'TimeoutMinutes' } }
        @{ Module = 'exchange-install.bicep'; RunCommand = 'Wait-DomainController'; Minutes = { Get-ParameterDefault 'Wait-DomainController.ps1' 'TimeoutMinutes' } }
        @{ Module = 'client-join.bicep'; RunCommand = 'Wait-DomainController'; Minutes = { Get-ParameterDefault 'Wait-DomainController.ps1' 'TimeoutMinutes' } }
        @{ Module = 'file-server-join.bicep'; RunCommand = 'Wait-DomainController'; Minutes = { Get-ParameterDefault 'Wait-DomainController.ps1' 'TimeoutMinutes' } }
        # Beitritt, Start des Installationstasks (bis etwa 15 Minuten), Installationsphase
        @{ Module = 'exchange-install.bicep'; RunCommand = 'Install-ExchangeServer'; Minutes = { (Get-FunctionMinute 'Install-ExchangeServer.ps1' 'Wait-DomainJoinComplete') + 15 + (Get-ParameterDefault 'Install-ExchangeServer.ps1' 'TimeoutMinutes') } }
        # Beitritt, Lab-Benutzer, dazu Rechte, Freigaben und Basisordner (Reserve 30 Minuten)
        @{ Module = 'file-server-join.bicep'; RunCommand = 'Complete-FileServer'; Minutes = { (Get-FunctionMinute 'Initialize-FileServer.ps1' 'Wait-DomainJoinComplete') + (Get-ParameterDefault 'Initialize-FileServer.ps1' 'UserWaitMinutes') + 30 } }
        # Sprachpaket (2 Versuche), Office, Remote Desktop Manager (Reserve 15 Minuten)
        @{ Module = 'client.bicep'; RunCommand = 'Initialize-LabClient'; Minutes = { 2 * (Get-FunctionParameterDefault 'Initialize-LabClient.ps1' 'Invoke-LanguageInstall' 'TimeoutMinutes') + (Get-FunctionMinute 'Initialize-LabClient.ps1' 'Install-OfficeApp') + 15 } }
        @{ Module = 'client-join.bicep'; RunCommand = 'Complete-LabClient'; Minutes = { Get-FunctionMinute 'Initialize-LabClient.ps1' 'Wait-DomainJoin' } }
    ) {
        $internal = & $Minutes
        $internal | Should -BeGreaterThan 0
        (Get-RunCommandTimeout -Module $Module -RunCommand $RunCommand) | Should -BeGreaterThan ($internal * 60) -Because "interne Wartezeiten bis $internal Minuten"
    }
}

Describe 'Invoke-NativeCommand in <Name>' -ForEach $nativeScripts {
    BeforeAll {
        . (Import-ScriptFunction -Path $Path -Name 'Invoke-NativeCommand')
    }

    It 'liefert Exit-Code und stderr, ohne unter ErrorActionPreference Stop vorher zu werfen' {
        $ErrorActionPreference = 'Stop'
        $command = Get-NativeTestCommand -ExitCode 3
        $result = Invoke-NativeCommand -FilePath $command.FilePath -ArgumentList $command.ArgumentList -NoThrow
        $result.ExitCode | Should -Be 3
        ($result.Output -join ' ') | Should -Match 'stoerung'
    }

    It 'wirft bei unerwartetem Exit-Code und akzeptiert erlaubte Exit-Codes' {
        $ErrorActionPreference = 'Stop'
        $command = Get-NativeTestCommand -ExitCode 5
        { Invoke-NativeCommand -FilePath $command.FilePath -ArgumentList $command.ArgumentList } | Should -Throw '*Exit-Code 5*'
        (Invoke-NativeCommand -FilePath $command.FilePath -ArgumentList $command.ArgumentList -SuccessExitCodes 0, 5).ExitCode | Should -Be 5
    }

    It 'wirft bei einem fehlenden Programm statt einen alten Exit-Code zu melden' {
        $ErrorActionPreference = 'Stop'
        { Invoke-NativeCommand -FilePath 'gibt-es-nicht-lab.exe' -NoThrow } | Should -Throw
    }
}

Describe 'Invoke-IcaclsCommand (Fileserver)' -Skip:(-not $isWindowsHost) {
    BeforeAll {
        . (Import-ScriptFunction -Path (Join-Path $repoRoot 'scripts/Initialize-FileServer.ps1') -Name 'Invoke-NativeCommand', 'Invoke-IcaclsCommand')
        $log = New-Object -TypeName System.Collections.Generic.List[string]
        function Write-LabLog { param([string] $Message) $log.Add($Message) }
        # Keine echten Wartezeiten im Test.
        function Start-Sleep { param([int] $Seconds) }
    }

    It 'wiederholt Exit 1332 (SID noch nicht repliziert) und wirft danach' {
        $ErrorActionPreference = 'Stop'
        $log.Clear()
        { Invoke-IcaclsCommand -Arguments @($TestDrive, '/grant', '*S-1-5-21-1-2-3-99999:(R)') } | Should -Throw '*1332*'
        @($log | Where-Object { $_ -like 'SID noch nicht aufloesbar*' }).Count | Should -Be 19
    }

    It 'nimmt Dateifehler mit -AllowFileErrors hin und wirft ohne' {
        $ErrorActionPreference = 'Stop'
        $missing = Join-Path $TestDrive 'fehlt'
        # Ohne /C: Exit 3 (Pfad nicht gefunden).
        { Invoke-IcaclsCommand -Arguments @($missing, '/setowner', '*S-1-5-18') } | Should -Throw
        { Invoke-IcaclsCommand -Arguments @($missing, '/setowner', '*S-1-5-18') -AllowFileErrors } | Should -Not -Throw
    }

    It 'protokolliert Dateifehler, die icacls mit /C trotz Exit 0 meldet' {
        $ErrorActionPreference = 'Stop'
        $log.Clear()
        $missing = Join-Path $TestDrive 'fehlt-auch'
        { Invoke-IcaclsCommand -Arguments @($missing, '/setowner', '*S-1-5-18', '/C') -AllowFileErrors } | Should -Not -Throw
        @($log | Where-Object { $_ -like '*1 Datei(en) nicht bearbeitet*' }).Count | Should -Be 1
    }
}

Describe 'DPAPI-Secrets' -Skip:(-not $isWindowsHost) {
    It 'Exchange: Save-InstallSecret und Get-InstallSecret ergeben die Kennwoerter wieder' {
        . (Import-ScriptFunction -Path (Join-Path $repoRoot 'scripts/Install-ExchangeServer.ps1') -Name 'ConvertFrom-Base64String', 'Save-InstallSecret', 'Get-InstallSecret')
        function Protect-Directory { param([string] $Path) New-Item -Path $Path -ItemType Directory -Force | Out-Null }
        $SecretDir = Join-Path $TestDrive 'secrets-ex'
        $SecretFile = Join-Path $SecretDir 'install.dat'
        $admin = 'Adm!n-' + [char]0x00E4 + [char]0x00DF + '-1'
        $AdminPasswordB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($admin))
        $LabUserPasswordB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('Lab-User-2'))
        Save-InstallSecret
        [IO.File]::ReadAllText($SecretFile) | Should -Not -Match 'Lab-User-2'
        $secret = Get-InstallSecret
        $secret.AdminPassword | Should -BeExactly $admin
        $secret.LabUserPassword | Should -BeExactly 'Lab-User-2'
    }

    It 'DC: Save-PromotionSecret und Get-PromotionSecret ergeben die Base64-Werte wieder' {
        . (Import-ScriptFunction -Path (Join-Path $repoRoot 'scripts/Install-DomainController.ps1') -Name 'Save-PromotionSecret', 'Get-PromotionSecret')
        # icacls wuerde dem Testbenutzer den Zugriff entziehen.
        function Invoke-NativeCommand { param([string] $FilePath, [string[]] $ArgumentList) }
        $SecretDir = Join-Path $TestDrive 'secrets-dc'
        $SecretFile = Join-Path $SecretDir 'promote.dat'
        $SafeModePasswordB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('Dsrm-3'))
        $AdminPasswordB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('Adm-4'))
        Save-PromotionSecret
        $secret = Get-PromotionSecret
        $secret.SafeModePasswordB64 | Should -BeExactly $SafeModePasswordB64
        $secret.AdminPasswordB64 | Should -BeExactly $AdminPasswordB64
    }
}
