#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules PSScriptAnalyzer

BeforeDiscovery {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $scriptFiles = Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -Filter '*.ps1' | ForEach-Object {
        @{ Name = $_.Name; Path = $_.FullName }
    }
}

BeforeAll {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $labUsers = Import-PowerShellDataFile -Path (Join-Path $repoRoot 'scripts\LabUsers.psd1')
    $templateText = Get-Content -Path (Join-Path $repoRoot 'azuredeploy.json') -Raw
    $template = $templateText | ConvertFrom-Json -Depth 100
}

Describe 'Skript <Name>' -ForEach $scriptFiles {
    It 'laesst sich fehlerfrei parsen' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }

    It 'enthaelt nur ASCII-Zeichen (Run Command / Windows PowerShell 5.1 liest UTF-8 ohne BOM als ANSI)' {
        $bytes = [IO.File]::ReadAllBytes($Path)
        ($bytes | Where-Object { $_ -gt 127 }) | Should -BeNullOrEmpty
    }

    It 'hat keine PSScriptAnalyzer-Befunde' {
        $settings = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'PSScriptAnalyzerSettings.psd1'
        Invoke-ScriptAnalyzer -Path $Path -Settings $settings | Should -BeNullOrEmpty
    }

    It 'endet mit einem expliziten Exit-Code' {
        (Get-Content -Path $Path -Raw) | Should -Match 'exit 0'
    }
}

Describe 'LabUsers.psd1' {
    It 'enthaelt 12 Lab-Benutzer' {
        $labUsers.Users.Count | Should -Be 12
    }

    It 'hat eindeutige SamAccountNames mit hoechstens 20 Zeichen' {
        $names = $labUsers.Users.SamAccountName
        ($names | Select-Object -Unique).Count | Should -Be $names.Count
        $names | ForEach-Object { $_.Length | Should -BeLessOrEqual 20 }
    }

    It 'hat fuer jeden Benutzer alle Pflichtattribute' {
        $required = 'SamAccountName', 'GivenName', 'Surname', 'OrganizationalUnit', 'StreetAddress', 'City', 'PostalCode', 'Office', 'Title', 'OfficePhone', 'MobilePhone'
        foreach ($user in $labUsers.Users) {
            foreach ($key in $required) {
                $user[$key] | Should -Not -BeNullOrEmpty -Because "$($user.SamAccountName) braucht $key"
            }
        }
    }

    It 'legt jede Benutzer-OU in der OU-Liste an' {
        foreach ($user in $labUsers.Users) {
            $labUsers.OrganizationalUnits | Should -Contain $user.OrganizationalUnit
        }
    }

    It 'listet uebergeordnete OUs vor untergeordneten' {
        $seen = @()
        foreach ($ou in $labUsers.OrganizationalUnits) {
            $parts = $ou -split ',', 2
            if ($parts.Count -gt 1) {
                $seen | Should -Contain $parts[1] -Because "$ou braucht zuerst $($parts[1])"
            }
            $seen += $ou
        }
    }
}

Describe 'azuredeploy.json' {
    It 'enthaelt keine abgekuendigten oder entfernten Komponenten' {
        $templateText | Should -Not -Match 'Microsoft\.Powershell'          # DSC-Extension
        $templateText | Should -Not -Match 'Microsoft\.Azure\.Diagnostics'  # WAD
        $templateText | Should -Not -Match 'CustomScriptExtension'
        $templateText | Should -Not -Match 'raw\.githubusercontent\.com'
        $templateText | Should -Not -Match 'dns\.hosting\.portal\.azure\.net'
        $templateText | Should -Not -Match 'Microsoft\.Storage/storageAccounts'
    }

    It 'enthaelt keine Basic-Public-IP' {
        $templateText | Should -Match '"name": "Standard"'
        $templateText | Should -Not -Match '"publicIPAllocationMethod": "Dynamic"'
    }

    It 'enthaelt keine NSG-Regel mit beliebiger Quelle' {
        $templateText | Should -Not -Match '"sourceAddressPrefix": "\*"'
    }

    It 'nutzt Windows Server 2025 fuer alle VMs' {
        $skus = [regex]::Matches($templateText, '"sku": "([^"]+datacenter[^"]*)"') | ForEach-Object { $_.Groups[1].Value }
        $skus | Should -Not -BeNullOrEmpty
        $skus | ForEach-Object { $_ | Should -BeLike '2025-datacenter*' }
    }

    It 'deklariert Passwoerter als securestring' {
        $template.parameters.adminPassword.type | Should -Be 'securestring'
        $template.parameters.labUserPassword.type | Should -Be 'securestring'
    }
}
