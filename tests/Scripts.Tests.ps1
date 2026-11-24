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
    $labUsers = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath 'scripts/LabUsers.psd1')
    $fileServer = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath 'scripts/FileServer.psd1')
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

    It 'nutzt nur fiktive Rufnummern der Bundesnetzagentur (Medienproduktionen, Mitteilung 148/2021)' {
        # Echte Anschluesse duerfen weder im Adressbuch noch auf Beispieldokumenten auftauchen.
        $numbers = @($labUsers.Users.OfficePhone) + @($labUsers.Users.MobilePhone)
        ($numbers | Select-Object -Unique).Count | Should -Be $numbers.Count
        foreach ($user in $labUsers.Users) {
            $user.OfficePhone | Should -Match '^\+49 (30 23125|40 66969)-\d{3}$' -Because "$($user.SamAccountName) braucht eine Festnetznummer aus Berlin 030 23125 oder Hamburg 040 66969"
            $user.MobilePhone | Should -Match '^\+49 171 39200\d{2}$' -Because "$($user.SamAccountName) braucht eine Mobilnummer aus 0171 39200-00..99"
        }
    }

    It 'legt jede Benutzer-OU in der OU-Liste an' {
        foreach ($user in $labUsers.Users) {
            $labUsers.OrganizationalUnits | Should -Contain $user.OrganizationalUnit
        }
    }

    It 'verweist bei Vorgesetzten nur auf vorhandene Benutzer' {
        $names = $labUsers.Users.SamAccountName
        foreach ($entry in $labUsers.Managers.GetEnumerator()) {
            $names | Should -Contain $entry.Key
            $names | Should -Contain $entry.Value
            $entry.Value | Should -Not -Be $entry.Key
        }
    }

    It 'hat gueltige, eindeutige Aliase fuer alle Beispielempfaenger' {
        $recipients = @($labUsers.DistributionGroups) + @($labUsers.SharedMailboxes) + @($labUsers.RoomMailboxes) + @($labUsers.Contacts)
        $aliases = $recipients.Alias
        ($aliases | Select-Object -Unique).Count | Should -Be $aliases.Count
        foreach ($alias in $aliases) {
            # Alias dient zugleich als SamAccountName (max. 20 Zeichen) und Adressteil.
            $alias | Should -Match '^[a-z0-9-]{1,20}$'
            $labUsers.Users.SamAccountName | Should -Not -Contain $alias
        }
        foreach ($recipient in $recipients) {
            $labUsers.OrganizationalUnits | Should -Contain $recipient.OrganizationalUnit
        }
    }

    It 'verweist bei Mitgliedern und Berechtigungen nur auf vorhandene Benutzer' {
        $names = $labUsers.Users.SamAccountName
        $references = @($labUsers.DistributionGroups.Members) + @($labUsers.SharedMailboxes.FullAccess) + @($labUsers.SharedMailboxes.SendAs)
        $references | Should -Not -BeNullOrEmpty
        foreach ($reference in $references) {
            $names | Should -Contain $reference
        }
    }

    It 'hat eine vorhandene Ziel-OU fuer den Client' {
        $labUsers.OrganizationalUnits | Should -Contain $labUsers.ClientOrganizationalUnit
    }

    It 'nutzt fuer externe Kontakte nur reservierte Beispiel-Domains' {
        foreach ($contact in $labUsers.Contacts) {
            $contact.ExternalEmailAddress | Should -Match '@([a-z0-9-]+\.)*example\.(com|org|net)$'
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

Describe 'FileServer.psd1' {
    BeforeAll {
        $groupNames = @($fileServer.GlobalGroups.Name)
        $folderPaths = @($fileServer.Folders.Path)
        $specialPrincipals = '@DomainUsers', '@Everyone', '@AuthenticatedUsers'
    }

    It 'hat eindeutige globale Gruppen mit Mitgliedern aus LabUsers.psd1' {
        ($groupNames | Select-Object -Unique).Count | Should -Be $groupNames.Count
        foreach ($group in $fileServer.GlobalGroups) {
            $group.Name | Should -Match '^GG-[A-Za-z-]+$'
            $labUsers.OrganizationalUnits | Should -Contain $group.OrganizationalUnit
            foreach ($member in $group.Members) {
                $labUsers.Users.SamAccountName | Should -Contain $member -Because "$($group.Name) verweist auf $member"
            }
        }
        $labUsers.OrganizationalUnits | Should -Contain $fileServer.DomainLocalGroupOrganizationalUnit
    }

    It 'listet jeden Ordner einmal und uebergeordnete Ordner vor untergeordneten' {
        ($folderPaths | Select-Object -Unique).Count | Should -Be $folderPaths.Count
        $seen = @()
        foreach ($path in $folderPaths) {
            if ($path -match '\\') {
                $seen | Should -Contain (Split-Path -Path $path -Parent) -Because "$path braucht zuerst den uebergeordneten Ordner"
            }
            $seen += $path
        }
    }

    It 'berechtigt nur bekannte Gruppen und Sonderprinzipale (AGDLP: keine Benutzer im Soll-Zustand)' {
        foreach ($folder in $fileServer.Folders) {
            foreach ($principal in @($folder.Modify) + @($folder.Read) + @($folder.List) | Where-Object { $_ }) {
                ($groupNames + $specialPrincipals) | Should -Contain $principal -Because "$($folder.Path) nutzt $principal"
            }
            if ($folder.Stem) {
                # DL-FS-<Stem>-M ist der laengste Name, SamAccountName darf hoechstens 64 Zeichen haben.
                ('DL-FS-{0}-M' -f $folder.Stem).Length | Should -BeLessOrEqual 64
            }
        }
        $stems = @($fileServer.Folders | Where-Object { $_.Stem } | ForEach-Object Stem)
        ($stems | Select-Object -Unique).Count | Should -Be $stems.Count
    }

    It 'gibt nur Ordner frei, die als geschuetzte Wurzel definiert sind' {
        $shareNames = @($fileServer.Shares.Name)
        ($shareNames | Select-Object -Unique).Count | Should -Be $shareNames.Count
        foreach ($share in $fileServer.Shares) {
            $root = $fileServer.Folders | Where-Object Path -EQ $share.Path
            $root | Should -Not -BeNullOrEmpty -Because "Freigabe $($share.Name) braucht einen Ordner"
            $root.Protected | Should -BeTrue -Because "Freigabe $($share.Name) darf keine Rechte von F:\ erben"
        }
        ($fileServer.Shares | Where-Object Name -EQ $fileServer.HomeFolders.Share).Path | Should -Be $fileServer.HomeFolders.Path
    }

    It 'definiert Altlasten mit gueltigen Zielen' {
        $fileServer.Legacy | Should -Not -BeNullOrEmpty
        foreach ($item in $fileServer.Legacy) {
            $item.Type | Should -BeIn @('UserAce', 'BrokenInheritance', 'OrphanedSid', 'OwnerOnly', 'EveryoneFull')
            $paths = @($item.Path) + @($item.Paths) + @($item.SampleSource) | Where-Object { $_ }
            foreach ($path in $paths) {
                # Jeder Pfad liegt unter einer Freigabe-Wurzel aus der Ordnerliste.
                $folderPaths | Should -Contain ($path -split '\\')[0]
            }
            if ($item.Type -in 'UserAce', 'OwnerOnly') {
                $labUsers.Users.SamAccountName | Should -Contain $item.Principal
            }
            if ($item.Type -eq 'OrphanedSid') {
                $labUsers.Users.SamAccountName | Should -Not -Contain $item.SamAccountName -Because 'der Praktikant wird geloescht und darf kein Lab-Benutzer sein'
                $labUsers.OrganizationalUnits | Should -Contain $item.OrganizationalUnit
            }
            if ($item.Type -eq 'EveryoneFull') {
                $fileServer.Shares.Name | Should -Contain $item.Share
            }
        }
    }
}

Describe 'azuredeploy.json' {
    It 'enthaelt keine abgekuendigten oder entfernten Komponenten' {
        $templateText | Should -Not -Match '"type":\s*"DSC"'                # DSC-Extension
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
        # Literal-JSON und, bei bedingten Regeln, ARM-Ausdruck createObject('sourceAddressPrefix', '*').
        $templateText | Should -Not -Match '"sourceAddressPrefix": "\*"'
        $templateText | Should -Not -Match "'sourceAddressPrefix', '\*'"
        $templateText | Should -Match "'sourceAddressPrefix', parameters\('allowedRdpSourcePrefix'\)"
    }

    It 'nutzt Windows Server 2025 fuer alle VMs' {
        $skus = [regex]::Matches($templateText, '"sku": "([^"]+datacenter[^"]*)"') | ForEach-Object { $_.Groups[1].Value }
        $skus | Should -Not -BeNullOrEmpty
        $skus | ForEach-Object { $_ | Should -BeLike '2025-datacenter*' }
    }

    It 'nutzt azadmin als Standard-Administrator' {
        $template.parameters.adminUsername.defaultValue | Should -Be 'azadmin'
    }

    It 'deklariert Passwoerter als securestring' {
        $template.parameters.adminPassword.type | Should -Be 'securestring'
        $template.parameters.labUserPassword.type | Should -Be 'securestring'
    }

    It 'verlangt ein eigenes Passwort fuer die Lab-Benutzer (kein Rueckfall auf das Admin-Passwort)' {
        $template.parameters.labUserPassword.PSObject.Properties.Name | Should -Not -Contain 'defaultValue'
    }

    It 'trennt SMTP von HTTP/HTTPS in der NSG' {
        $templateText | Should -Match "'name', 'Allow-Exchange-Web'"
        $templateText | Should -Match "'name', 'Allow-Exchange-SMTP'"
        $templateText | Should -Not -Match 'Allow-Exchange-Published'
    }

    It 'uebergibt das Wartungsskript an die Exchange-Installation' {
        $templateText | Should -Match 'MaintenanceScriptB64'
    }

    It 'stellt standardmaessig einen Windows-11-Client mit Multitenant Hosting Rights bereit' {
        $template.parameters.deployClient.defaultValue | Should -BeTrue
        $template.parameters.clientImageSku.defaultValue | Should -BeLike 'win11-*'
        $templateText | Should -Match '"publisher": "MicrosoftWindowsDesktop"'
        $templateText | Should -Match '"offer": "windows-11"'
        $templateText | Should -Match '"licenseType": "Windows_Client"'
    }

    It 'erlaubt nur Office-Produkte mit Benutzeraktivierung' {
        $template.parameters.officeProductId.allowedValues | Should -Be @('O365ProPlusRetail', 'O365BusinessRetail')
    }

    It 'stellt den zweiten DC nur auf Wunsch bereit' {
        $template.parameters.deploySecondDc.defaultValue | Should -BeFalse
        $templateText | Should -Match 'Install-ADDSDomainController'
    }

    It 'veroeffentlicht SPF und DMARC fuer die Lab-Domain' {
        $templateText | Should -Match 'v=spf1 mx -all'
        $templateText | Should -Match 'v=DMARC1; p=none'
    }

    It 'stellt standardmaessig einen Fileserver ohne Public IP bereit' {
        $template.parameters.deployFileServer.defaultValue | Should -BeTrue
        $templateText | Should -Match 'Complete-FileServer'
        $fileServerModule = ($template.resources | Where-Object name -EQ 'file-server').properties.template
        $nic = $fileServerModule.resources | Where-Object type -EQ 'Microsoft.Network/networkInterfaces'
        $nic | Should -Not -BeNullOrEmpty
        $nic.properties.ipConfigurations[0].properties.PSObject.Properties.Name | Should -Not -Contain 'publicIPAddress'
    }

    It 'erzeugt die Beispieldokumente vor dem Domaenenbeitritt, mit Korpus in der userData' {
        $template.parameters.fileServerDataSizeGB.defaultValue | Should -Be 60
        $template.parameters.fileServerDataSizeGB.maxValue | Should -Be 120
        $fileServerModule = ($template.resources | Where-Object name -EQ 'file-server').properties.template
        $vm = $fileServerModule.resources | Where-Object type -EQ 'Microsoft.Compute/virtualMachines'
        $vm.properties.userData | Should -Not -BeNullOrEmpty
        $vm.properties.userData.Length | Should -BeLessOrEqual 65536
        $vm.properties.storageProfile.dataDisks[0].diskSizeGB | Should -Not -BeNullOrEmpty
        $fileServerModule.parameters.dataDiskSizeGB.defaultValue | Should -Be 256
        $generator = $fileServerModule.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match 'New-SampleDocuments' }
        $generator | Should -Not -BeNullOrEmpty
        ($generator.dependsOn -join ' ') | Should -Match 'Initialize-FileServer'
        $generator.properties.treatFailureAsDeploymentFailure | Should -BeTrue
        # Der Neustart des Beitritts wuerde die Erzeugung abbrechen: Beitritt erst nach dem Modul file-server.
        $join = $template.resources | Where-Object name -EQ 'file-server-join'
        ($join.dependsOn -join ' ') | Should -Match 'file-server'
    }

    It 'erzeugt mit D4s_v5 und verkleinert den Fileserver danach selbst auf B2ms' {
        $template.parameters.fileServerVmSize.defaultValue | Should -Be 'Standard_D4s_v5'
        $template.parameters.fileServerFinalVmSize.defaultValue | Should -Be 'Standard_B2ms'
        $fileServerModule = ($template.resources | Where-Object name -EQ 'file-server').properties.template
        $vm = $fileServerModule.resources | Where-Object type -EQ 'Microsoft.Compute/virtualMachines'
        $vm.identity.type | Should -Be 'SystemAssigned'
        $role = $fileServerModule.resources | Where-Object type -EQ 'Microsoft.Authorization/roleAssignments'
        $role | Should -Not -BeNullOrEmpty
        $role.properties.roleDefinitionId | Should -Match 'vmContributorRoleId'
        $fileServerModule.variables.vmContributorRoleId | Should -Be '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'  # Virtual Machine Contributor
        $templateText | Should -Match 'TraineeLab-FileServerResize'
        $templateText | Should -Match 'ResizeScriptB64'
    }
}

Describe 'Beispieldokumente (Korpus, Artefakte, Generator)' {
    BeforeAll {
        function Expand-GzipByte([byte[]] $Bytes) {
            $packed = New-Object -TypeName System.IO.MemoryStream -ArgumentList (, $Bytes)
            $gzip = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $packed, ([IO.Compression.CompressionMode]::Decompress)
            $plain = New-Object -TypeName System.IO.MemoryStream
            $gzip.CopyTo($plain)
            $gzip.Dispose()
            , $plain.ToArray()
        }
        $corpusDir = Join-Path $repoRoot 'scripts/corpus'
        $corpusFiles = @(Get-ChildItem -Path $corpusDir -Filter '*.psd1' -File | Sort-Object -Property Name)
        $corpusText = ($corpusFiles | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $company = Import-PowerShellDataFile -Path (Join-Path $corpusDir 'Company.psd1')
        $generatorPath = Join-Path $repoRoot 'scripts/New-SampleDocuments.ps1'
        $generatorText = [IO.File]::ReadAllText($generatorPath)
        $rebuild = 'tools/Build-SampleArtifacts.ps1 ausfuehren und die Artefakte committen'
    }

    It 'SampleCorpus.gz passt in die userData und entspricht den Quellen' {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'scripts/SampleCorpus.gz'))
        [Convert]::ToBase64String($bytes).Length | Should -BeLessOrEqual 65536
        $json = [Text.Encoding]::UTF8.GetString((Expand-GzipByte $bytes)) | ConvertFrom-Json
        @($json.PSObject.Properties.Name) | Should -Be @($corpusFiles.Name) -Because $rebuild
        foreach ($file in $corpusFiles) {
            $json.($file.Name) | Should -BeExactly ([IO.File]::ReadAllText($file.FullName).Replace("`r`n", "`n")) -Because $rebuild
        }
    }

    It 'Start-SampleDocuments.ps1 enthaelt den aktuellen Generator' {
        $start = [IO.File]::ReadAllText((Join-Path $repoRoot 'scripts/Start-SampleDocuments.ps1'))
        $payload = [regex]::Match($start, "\`$payload = '([A-Za-z0-9+/=]+)'").Groups[1].Value
        $payload | Should -Not -BeNullOrEmpty
        $unpacked = Expand-GzipByte ([Convert]::FromBase64String($payload))
        [Convert]::ToBase64String($unpacked) | Should -BeExactly ([Convert]::ToBase64String([IO.File]::ReadAllBytes($generatorPath))) -Because $rebuild
    }

    It 'laedt alle Korpus-Dateien und kennt die Pflichtbereiche des Drehbuchs' {
        foreach ($file in $corpusFiles) { { Import-PowerShellDataFile -Path $file.FullName } | Should -Not -Throw -Because $file.Name }
        foreach ($key in 'Company', 'Ci', 'Timeline', 'Employees', 'Customers', 'Suppliers', 'Shops', 'Motifs', 'Labels', 'FolderNames') {
            $company.Keys | Should -Contain $key
        }
        # Drehbuch und LabUsers.psd1 beschreiben dieselben Lab-Benutzer.
        foreach ($sam in @($company.Employees | Where-Object { $labUsers.Users.SamAccountName -contains $_.Sam } | ForEach-Object Sam)) {
            $labUsers.Users.SamAccountName | Should -Contain $sam
        }
    }

    It 'nutzt nur reservierte Domains (RFC 2606)' {
        $domains = [regex]::Matches($corpusText, '(?i)\b(?:[a-z0-9-]+\.)+(?:com|org|net|de|eu|io|info|biz)\b') | ForEach-Object Value | Select-Object -Unique
        foreach ($domain in $domains) { $domain | Should -Match '(^|\.)example\.(com|org|net)$' }
    }

    It 'nutzt nur Rufnummern fuer Medienproduktionen (Bundesnetzagentur)' {
        $numbers = [regex]::Matches(($corpusText + "`n" + $generatorText), '\+49 [\d \-]+\d') | ForEach-Object Value | Select-Object -Unique
        $numbers | Should -Not -BeNullOrEmpty
        foreach ($number in $numbers) { $number | Should -Match '^\+49 (30 23125|40 66969|221 4710|89 99998|69 90009|171 39200|176 040690)' }
    }

    It 'nutzt nur Platzhalter, die der Generator fuellt' {
        $names = [regex]::Matches($corpusText, '\{([A-Za-z][A-Za-z0-9]*)\}') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        $context = [regex]::Match($generatorText, '(?s)function Get-TextContext \{.*?\n\}').Value
        foreach ($name in $names) { $context | Should -Match "\b$name = " -Because "{$name} braucht einen Wert in Get-TextContext" }
        $apostrophes = '[{0}{1}{2}]' -f [char]0x2018, [char]0x2019, [char]0x201A
        $corpusText | Should -Not -Match $apostrophes -Because 'typografische Apostrophe beenden Strings in PowerShell'
    }

    It 'nutzt nur Labels, Ordnernamen und Motivformate aus dem Drehbuch' {
        foreach ($key in [regex]::Matches($generatorText, '\$L\.([A-Za-z]+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique) {
            $company.Labels.Keys | Should -Contain $key
        }
        foreach ($key in [regex]::Matches($generatorText, '\$F\.([A-Za-z]+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique) {
            $company.FolderNames.Keys | Should -Contain $key
        }
        $shapes = [regex]::Match($generatorText, '(?s)\$ShapeSizes = @\{.*?\n\}').Value
        foreach ($motif in $company.Motifs) { $shapes | Should -Match ("'?{0}'?\s*=\s*@\{{" -f [regex]::Escape($motif.File)) }
    }

    It 'legt die Altlasten in Ordner, die der Generator befuellt' {
        $folderNames = @($company.FolderNames.Values | ForEach-Object { $_ })
        foreach ($item in $fileServer.Legacy | Where-Object { $_.Type -in 'UserAce', 'BrokenInheritance', 'OwnerOnly' }) {
            $folderNames | Should -Contain (Split-Path -Path ($item.Path -replace '\\', '/') -Leaf)
        }
    }

    It 'erzeugt ohne Rastergrafik gueltige Dateien ohne offene Platzhalter (Smoke-Test)' {
        $target = Join-Path $TestDrive 'daten'
        $labRoot = Join-Path $TestDrive 'lab'
        $arguments = @('-NoProfile', '-NonInteractive', '-File', $generatorPath, '-TargetPath', $target, '-TargetSizeMB', '6', '-LabRoot', $labRoot,
            '-CorpusPath', $corpusDir, '-LabUsersPath', (Join-Path $repoRoot 'scripts/LabUsers.psd1'), '-ReferenceDate', '2026-11-24',
            '-WorkerCount', '1', '-NoRaster', '-TimeBudgetMinutes', '0')
        & (Get-Process -Id $PID).Path @arguments | Out-Null
        $LASTEXITCODE | Should -Be 0 -Because (Get-Content -Path (Join-Path $labRoot 'Logs/New-SampleDocuments.log') -Raw)
        (Get-Content -Path (Join-Path $labRoot 'Logs/New-SampleDocuments.log') -Raw) | Should -Not -MatchExactly 'WARNUNG:|FEHLER:'
        $files = @(Get-ChildItem -Path $target -Recurse -File)
        foreach ($extension in '.docx', '.xlsx', '.pptx', '.pdf') { @($files | Where-Object Extension -EQ $extension).Count | Should -BeGreaterThan 0 -Because "$extension fehlt" }
        @($files | Where-Object Name -Match '\{[A-Za-z]+\}') | Should -BeNullOrEmpty
        $years = @($files | ForEach-Object { $_.LastWriteTime.Year } | Select-Object -Unique)
        $years.Count | Should -BeGreaterThan 5
        Add-Type -AssemblyName System.IO.Compression
        foreach ($file in $files | Where-Object Extension -In '.docx', '.xlsx', '.pptx' | Select-Object -First 40) {
            $zip = [IO.Compression.ZipFile]::OpenRead($file.FullName)
            try {
                @($zip.Entries.FullName) | Should -Contain '[Content_Types].xml'
                foreach ($entry in $zip.Entries | Where-Object { $_.FullName -match '\.(xml|rels)$' }) {
                    $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $entry.Open()
                    $xml = $reader.ReadToEnd()
                    $reader.Dispose()
                    { [xml]$xml } | Should -Not -Throw -Because "$($file.Name)/$($entry.FullName)"
                    $xml | Should -Not -Match '\{[A-Z][A-Za-z0-9]+\}' -Because "$($file.Name)/$($entry.FullName) hat einen offenen Platzhalter"
                }
            }
            finally { $zip.Dispose() }
        }
        foreach ($file in $files | Where-Object Extension -EQ '.pdf' | Select-Object -First 40) {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            [Text.Encoding]::ASCII.GetString($bytes, 0, 5) | Should -Be '%PDF-'
            [Text.Encoding]::ASCII.GetString($bytes, $bytes.Length - 6, 6) | Should -Match '%%EOF'
        }
    }
}

Describe 'infra/main.bicep' {
    BeforeAll {
        $mainBicep = Get-Content -Path (Join-Path $repoRoot 'infra/main.bicep') -Raw
        $shutdownModules = @([regex]::Matches($mainBicep, "(?ms)^module \w+ 'modules/auto-shutdown\.bicep'.*?^\}") | ForEach-Object Value)
    }

    It 'schaltet die Exchange-VM automatisch ab' {
        ($shutdownModules -join "`n") | Should -Match 'names\.exchangeVm'
    }

    It 'schaltet den Fileserver automatisch ab' {
        ($shutdownModules -join "`n") | Should -Match 'names\.fsVm'
    }

    It 'deallokiert den ersten DC nie automatisch (SYSVOL waere danach nicht-autoritativ)' {
        $shutdownModules | Should -Not -BeNullOrEmpty
        foreach ($module in $shutdownModules) {
            $module | Should -Not -Match 'names\.dcVm\b'
        }
    }
}
