#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules PSScriptAnalyzer

BeforeDiscovery {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $scriptFiles = Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -Filter '*.ps1' | ForEach-Object {
        @{ Name = $_.Name; Path = $_.FullName }
    }
    $toolFiles = Get-ChildItem -Path (Join-Path $repoRoot 'tools') -Filter '*.ps1' -Recurse | ForEach-Object {
        @{ Name = $_.Name; Path = $_.FullName }
    }
    # Lab-Daten je Sprache unter scripts/data/<Sprache>.
    $languages = @(@{ Language = 'de' }, @{ Language = 'en' })
    # Rastergrafik (System.Drawing) gibt es nur unter Windows.
    $isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
}

BeforeAll {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $labUsers = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath 'scripts/data/de/LabUsers.psd1')
    $fileServer = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath 'scripts/data/de/FileServer.psd1')
    $templateText = Get-Content -Path (Join-Path $repoRoot 'azuredeploy.json') -Raw
    # ConvertFrom-Json -Depth gibt es erst ab PowerShell 6; Windows PowerShell 5.1 hat keine Tiefengrenze.
    $template = if ($PSVersionTable.PSVersion.Major -ge 6) { $templateText | ConvertFrom-Json -Depth 100 } else { $templateText | ConvertFrom-Json }
    # Nur fiktive Rufnummern: Deutsch Bundesnetzagentur (Medienproduktionen, Mitteilung 148/2021), Englisch Ofcom
    # (Drama-Nummern fuer TV und Radio). Echte Anschluesse duerfen weder im Adressbuch noch auf Dokumenten stehen.
    # Zugelassene Verben: "Build" kennt erst PowerShell 6. Der Lauf unter pwsh 7 prueft die Verben weiter.
    $analyzerExclude = if ($PSVersionTable.PSVersion.Major -lt 6) { @('PSUseApprovedVerbs') } else { @() }
    $phonePattern = @{
        de = @{ Fixed = '^\+49 (30 23125|40 66969)-\d{3}$'; Mobile = '^\+49 171 39200\d{2}$'; Source = 'Bundesnetzagentur: Berlin 030 23125, Hamburg 040 66969, Mobil 0171 39200' }
        en = @{ Fixed = '^\+44 (20 7946 0|161 496 0)\d{3}$'; Mobile = '^\+44 7700 900\d{3}$'; Source = 'Ofcom: London 020 7946 0, Manchester 0161 496 0, Mobil 07700 900' }
    }
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
        Invoke-ScriptAnalyzer -Path $Path -Settings $settings | Where-Object { $analyzerExclude -notcontains $_.RuleName } | Should -BeNullOrEmpty
    }

    It 'endet mit einem expliziten Exit-Code' {
        (Get-Content -Path $Path -Raw) | Should -Match 'exit 0'
    }
}

Describe 'Werkzeug <Name>' -ForEach $toolFiles {
    It 'enthaelt nur ASCII-Zeichen (Pruefskripte laufen per Run Command unter Windows PowerShell 5.1)' {
        ([IO.File]::ReadAllBytes($Path) | Where-Object { $_ -gt 127 }) | Should -BeNullOrEmpty
    }

    It 'laesst sich fehlerfrei parsen' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }

    It 'hat keine PSScriptAnalyzer-Befunde' {
        $settings = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'PSScriptAnalyzerSettings.psd1'
        Invoke-ScriptAnalyzer -Path $Path -Settings $settings | Where-Object { $analyzerExclude -notcontains $_.RuleName } | Should -BeNullOrEmpty
    }
}

Describe 'LabUsers.psd1 (<Language>)' -ForEach $languages {
    BeforeAll {
        $labUsers = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath "scripts/data/$Language/LabUsers.psd1")
    }

    It 'enthaelt 28 Lab-Benutzer, davon die 16 Microsoft-Demo-Personas mit ihren Demo-Tenant-Konten' {
        $labUsers.Users.Count | Should -Be 28
        $personas = 'Adele Vance', 'Alex Wilber', 'Diego Siciliani', 'Grady Archie', 'Henrietta Mueller', 'Isaiah Langer', 'Johanna Lorenz', 'Joni Sherman',
        'Lee Gu', 'Lidia Holloway', 'Lynne Robbins', 'Megan Bowen', 'Miriam Graham', 'Nestor Wilke', 'Patti Fernandez', 'Pradeep Gupta'
        foreach ($persona in $personas) {
            $given, $surname = $persona -split ' ', 2
            $user = $labUsers.Users | Where-Object { $_.GivenName -eq $given -and $_.Surname -eq $surname }
            $user | Should -Not -BeNullOrEmpty -Because "$persona fehlt"
            # Konto wie im M365-Demo-Tenant: Vorname plus Initiale des Nachnamens.
            $user.SamAccountName | Should -BeExactly ($given + $surname.Substring(0, 1))
        }
    }

    It 'hat eindeutige SamAccountNames mit hoechstens 20 Zeichen' {
        $names = $labUsers.Users.SamAccountName
        ($names | Select-Object -Unique).Count | Should -Be $names.Count
        $names | ForEach-Object { $_.Length | Should -BeLessOrEqual 20 }
    }

    It 'hat fuer jeden Benutzer alle Pflichtattribute und einen Standort mit Anschrift' {
        $required = 'SamAccountName', 'GivenName', 'Surname', 'Site', 'Office', 'Title', 'OfficePhone', 'MobilePhone'
        foreach ($user in $labUsers.Users) {
            foreach ($key in $required) {
                $user[$key] | Should -Not -BeNullOrEmpty -Because "$($user.SamAccountName) braucht $key"
            }
            $labUsers.Sites.Keys | Should -Contain $user.Site -Because "$($user.SamAccountName) verweist auf Standort $($user.Site)"
        }
        @($labUsers.Sites.Keys | Sort-Object) | Should -Be @('Branch', 'HQ')
        foreach ($site in $labUsers.Sites.GetEnumerator()) {
            foreach ($key in 'OrganizationalUnit', 'StreetAddress', 'City', 'PostalCode', 'Fax') {
                $site.Value[$key] | Should -Not -BeNullOrEmpty -Because "Standort $($site.Key) braucht $key"
            }
        }
        # Die Client-OU liegt beim Hauptstandort (Initialize-LabClient, Move-LabClientComputer).
        $labUsers.ClientOrganizationalUnit | Should -Be ($labUsers.Sites.HQ.OrganizationalUnit -replace '^OU=Users,', 'OU=Computers,')
    }

    It 'nennt Firma und Land fuer die AD-Attribute company, c, co und countryCode' {
        $labUsers.Company | Should -Not -BeNullOrEmpty
        $labUsers.Country.Code | Should -Match '^[A-Z]{2}$'
        $labUsers.Country.Name | Should -Not -BeNullOrEmpty
        $labUsers.Country.Number | Should -BeOfType [int]
    }

    It 'nutzt nur fiktive Rufnummern fuer Medienproduktionen' {
        $pattern = $phonePattern[$Language]
        $numbers = @($labUsers.Users.OfficePhone) + @($labUsers.Users.MobilePhone)
        ($numbers | Select-Object -Unique).Count | Should -Be $numbers.Count
        foreach ($user in $labUsers.Users) {
            $user.OfficePhone | Should -Match $pattern.Fixed -Because "$($user.SamAccountName) braucht eine Festnetznummer ($($pattern.Source))"
            $user.MobilePhone | Should -Match $pattern.Mobile -Because "$($user.SamAccountName) braucht eine Mobilnummer ($($pattern.Source))"
        }
        foreach ($site in $labUsers.Sites.GetEnumerator()) {
            $site.Value.Fax | Should -Match $pattern.Fixed -Because "Standort $($site.Key) braucht eine Faxnummer"
        }
        foreach ($contact in $labUsers.Contacts) {
            foreach ($number in $contact.Phone, $contact.Fax) {
                $number | Should -Match $pattern.Fixed -Because "Kontakt $($contact.Alias) braucht Telefon und Fax aus den fiktiven Bereichen"
            }
        }
    }

    It 'legt jede Benutzer-OU in der OU-Liste an' {
        foreach ($site in $labUsers.Sites.Values) {
            $labUsers.OrganizationalUnits | Should -Contain $site.OrganizationalUnit
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

Describe 'FileServer.psd1 (<Language>)' -ForEach $languages {
    BeforeAll {
        $labUsers = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath "scripts/data/$Language/LabUsers.psd1")
        $fileServer = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath "scripts/data/$Language/FileServer.psd1")
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
                # Nicht Split-Path: Unter Linux (CI) ist der Backslash kein Pfadtrenner.
                $seen | Should -Contain $path.Substring(0, $path.LastIndexOf('\')) -Because "$path braucht zuerst den uebergeordneten Ordner"
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

    It 'beschriftet Datenlaufwerk und domaenenlokale Gruppen' {
        $fileServer.VolumeLabel | Should -Not -BeNullOrEmpty
        foreach ($suffix in 'M', 'R') {
            # {0} = Server, {1} = Ordnerpfad (Initialize-LabGroup).
            $fileServer.DomainLocalGroupDescription[$suffix] | Should -Match '\{0\}.*\{1\}'
        }
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
                $item.Description | Should -Not -BeNullOrEmpty
                $item.DocumentsFolder | Should -Not -BeNullOrEmpty
            }
            if ($item.Type -eq 'EveryoneFull') {
                $fileServer.Shares.Name | Should -Contain $item.Share
            }
        }
    }
}

Describe 'Lab-Daten Deutsch und Englisch gleich aufgebaut' {
    BeforeAll {
        $data = @{}
        foreach ($language in 'de', 'en') {
            $data[$language] = @{
                Users      = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath "scripts/data/$language/LabUsers.psd1")
                FileServer = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath "scripts/data/$language/FileServer.psd1")
            }
        }
    }

    It 'hat dieselben Schluessel und Mengen in LabUsers.psd1' {
        @($data.de.Users.Keys | Sort-Object) | Should -Be @($data.en.Users.Keys | Sort-Object)
        foreach ($key in 'OrganizationalUnits', 'Users', 'DistributionGroups', 'SharedMailboxes', 'RoomMailboxes', 'Contacts') {
            @($data.en.Users[$key]).Count | Should -Be @($data.de.Users[$key]).Count -Because "$key braucht in beiden Sprachen gleich viele Eintraege"
        }
        $data.en.Users.Managers.Count | Should -Be $data.de.Users.Managers.Count
    }

    It 'hat dieselben Personas mit denselben Konten' {
        $personas = { param($d) @($d.Users.Users | Where-Object { $_.SamAccountName -ceq ($_.GivenName + $_.Surname.Substring(0, 1)) } | ForEach-Object { '{0}|{1}|{2}' -f $_.SamAccountName, $_.GivenName, $_.Surname } | Sort-Object) }
        $de = & $personas $data.de
        $de.Count | Should -Be 16
        & $personas $data.en | Should -Be $de
    }

    It 'hat dieselbe Struktur in FileServer.psd1 (Gruppen, Ordner, Freigaben, Altlasten)' {
        @($data.de.FileServer.Keys | Sort-Object) | Should -Be @($data.en.FileServer.Keys | Sort-Object)
        foreach ($key in 'GlobalGroups', 'Folders', 'Shares') {
            @($data.en.FileServer[$key]).Count | Should -Be @($data.de.FileServer[$key]).Count -Because "$key braucht in beiden Sprachen gleich viele Eintraege"
        }
        @($data.en.FileServer.Legacy.Type) | Should -Be @($data.de.FileServer.Legacy.Type)
        @($data.en.FileServer.Folders | Where-Object { $_.Stem }).Count | Should -Be @($data.de.FileServer.Folders | Where-Object { $_.Stem }).Count
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

    It 'stellt standardmaessig den Remote Desktop Manager auf dem Client bereit' {
        $template.parameters.clientRemoteDesktopManager.defaultValue | Should -BeTrue
        $clientModule = ($template.resources | Where-Object name -EQ 'client').properties.template
        $prepare = $clientModule.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match 'Initialize-LabClient' }
        # Parameterliste ist ein ARM-Ausdruck (concat), WingetPackages wird nur bei Bedarf angehaengt.
        ($prepare.properties.parameters | ConvertTo-Json -Depth 20) | Should -Match '(["'']|\\u0027)RemoteDesktopManager(["'']|\\u0027)'
    }

    It 'installiert winget-Pakete auf dem Client, nicht auf dem Exchange-Server' {
        $template.parameters.clientWingetPackages.defaultValue | Should -Contain 'Microsoft.VisualStudioCode'
        $template.parameters.PSObject.Properties.Name | Should -Not -Contain 'wingetPackages'
        $clientModule = ($template.resources | Where-Object name -EQ 'client').properties.template
        $prepare = $clientModule.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match 'Initialize-LabClient' }
        ($prepare.properties.parameters | ConvertTo-Json -Depth 20) | Should -Match '(["'']|\\u0027)WingetPackages(["'']|\\u0027)'
        $exchangeModule = ($template.resources | Where-Object name -EQ 'exchange-server').properties.template
        $initialize = $exchangeModule.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match 'Initialize-ExchangeServer' }
        $initialize | Should -Not -BeNullOrEmpty
        ($initialize.properties.parameters | ConvertTo-Json -Depth 20) | Should -Not -Match 'WingetPackages'
    }

    It 'uebergibt das Admin-Passwort fuer die RDM-Verbindungen nur geschuetzt an Complete-LabClient' {
        $join = $template.resources | Where-Object name -EQ 'client-join'
        $join.properties.parameters.PSObject.Properties.Name | Should -Contain 'dcComputerName'
        $join.properties.parameters.PSObject.Properties.Name | Should -Contain 'exchangeComputerName'
        $join.properties.parameters.PSObject.Properties.Name | Should -Contain 'secondDcComputerName'
        $complete = $join.properties.template.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match 'Complete-LabClient' }
        $complete.properties.protectedParameters.name | Should -Contain 'AdminPasswordB64'
        ($complete.properties.parameters | ConvertTo-Json -Depth 20) | Should -Not -Match 'adminPassword'
    }

    It 'waehlt die Sprache der Lab-Daten (Standard Deutsch)' {
        $template.parameters.labLanguage.allowedValues | Should -Be @('de', 'en')
        $template.parameters.labLanguage.defaultValue | Should -Be 'de'
    }

    It 'uebergibt die Lab-Sprache an <Script> im Modul <Module>' -ForEach @(
        @{ Module = 'domain-controller'; Script = 'Install-DomainController' }
        @{ Module = 'exchange-server'; Script = 'Initialize-ExchangeServer' }
        @{ Module = 'exchange-install'; Script = 'Install-ExchangeServer' }
        @{ Module = 'client'; Script = 'Initialize-LabClient' }
        @{ Module = 'client-join'; Script = 'Complete-LabClient' }
        @{ Module = 'file-server'; Script = 'Initialize-FileServer' }
        @{ Module = 'file-server-join'; Script = 'Complete-FileServer' }
    ) {
        $deployment = $template.resources | Where-Object name -EQ $Module
        $deployment.properties.parameters.labLanguage.value | Should -Be "[parameters('labLanguage')]"
        $runCommand = $deployment.properties.template.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match "'$Script'" }
        $runCommand | Should -Not -BeNullOrEmpty
        # Windows PowerShell 5.1 maskiert ' in ConvertTo-Json als '.
        ($runCommand.properties.parameters | ConvertTo-Json -Depth 20) | Should -Match '(["'']|\\u0027)LabLanguage(["'']|\\u0027)'
    }

    It 'haelt die Base64-Parameter jedes Run Commands unter der Windows-Kommandozeilengrenze' {
        # Run Commands uebergeben Parameter auf der Kommandozeile (max. 32.767 Zeichen). Darueber startet PowerShell
        # nicht (Exit 1 ohne Ausgabe, Testdeployment 2026-11-26). Reserve fuer Pfad und uebrige Parameter.
        $b64 = { param([string[]] $Files) ($Files | ForEach-Object { [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $repoRoot $_))).Length } | Measure-Object -Sum).Sum }
        $largest = { param([string] $Name) @('de', 'en' | ForEach-Object { & $b64 "scripts/data/$_/$Name" }) | Sort-Object -Descending | Select-Object -First 1 }
        (& $b64 'scripts/Update-LabServer.ps1', 'scripts/Invoke-LabMaintenance.ps1') | Should -BeLessThan 31000 -Because 'Install-ExchangeServer'
        ((& $largest 'LabUsers.psd1') + (& $largest 'FileServer.psd1')) | Should -BeLessThan 28000 -Because 'Initialize-FileServer (Prepare); Reserve fuer weiteres Wachstum (Sites statt Anschrift je Benutzer)'
        (& $b64 'scripts/Update-LabServer.ps1', 'scripts/Resize-FileServer.ps1') | Should -BeLessThan 31000 -Because 'Complete-FileServer'
        # LabUsers.psd1 erreicht Exchange deshalb ueber die userData der VM.
        $exchangeModule = ($template.resources | Where-Object name -EQ 'exchange-server').properties.template
        ($exchangeModule.resources | Where-Object type -EQ 'Microsoft.Compute/virtualMachines').properties.userData | Should -Match "labLanguage"
        $install = ($template.resources | Where-Object name -EQ 'exchange-install').properties.template.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match "'Install-ExchangeServer'" }
        ($install.properties.parameters | ConvertTo-Json -Depth 20) | Should -Not -Match 'LabUsersB64'
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
        # 90 % der Datendisk; der Generator haelt zusaetzlich 8 % frei (Test-VolumeFull).
        $template.parameters.fileServerDataPercent.defaultValue | Should -Be 90
        $template.parameters.fileServerDataPercent.maxValue | Should -Be 90
        $fileServerModule = ($template.resources | Where-Object name -EQ 'file-server').properties.template
        $sampleRun = $fileServerModule.resources | Where-Object { $_.type -eq 'Microsoft.Compute/virtualMachines/runCommands' -and $_.name -match 'New-SampleDocuments' }
        $sampleRun.properties.parameters.name | Should -Contain 'TargetPercent'
        $vm = $fileServerModule.resources | Where-Object type -EQ 'Microsoft.Compute/virtualMachines'
        # Je Sprache ein Korpus-Paket (Groesse prueft der Block Beispieldokumente), Auswahl ueber labLanguage.
        $vm.properties.userData | Should -Match "^\[if\(equals\(parameters\('labLanguage'\), 'en'\)"
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

    It 'erzeugt mit D4s_v5 und verkleinert den Fileserver danach selbst auf B2s_v2 (gleicher Hardware-Cluster)' {
        $template.parameters.fileServerVmSize.defaultValue | Should -Be 'Standard_D4s_v5'
        $template.parameters.fileServerFinalVmSize.defaultValue | Should -Be 'Standard_B2s_v2'
        # Die alte B-Serie laeuft nicht auf den Dsv5-Clustern, ein Resize im Betrieb scheitert dorthin.
        $template.parameters.fileServerFinalVmSize.allowedValues | Should -Not -Contain 'Standard_B2ms'
        $template.variables.fileServerResizeTo | Should -Match "startsWith\(parameters\('fileServerVmSize'\), 'Standard_B'\)"
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

    It 'startet nach dem Domaenenbeitritt von <_> erst nach dessen Neustart weitere Skripte' -ForEach 'exchange-install', 'client-join', 'file-server-join' {
        # JsonADDomainExtension meldet Erfolg vor dem Neustart, ein direkt folgender Run Command wuerde abgebrochen.
        $module = ($template.resources | Where-Object name -EQ $_).properties.template
        $runCommands = @($module.resources | Where-Object type -EQ 'Microsoft.Compute/virtualMachines/runCommands')
        $afterJoin = @($runCommands | Where-Object { ($_.dependsOn -join ' ') -match "'JoinDomain'" })
        $afterJoin.Count | Should -Be 1
        $afterJoin[0].name | Should -Match 'Wait-DomainJoinReboot'
        $afterJoin[0].properties.treatFailureAsDeploymentFailure | Should -BeFalse
        @($runCommands | Where-Object { ($_.dependsOn -join ' ') -match "'Wait-DomainJoinReboot'" }).Count | Should -Be 1
    }
}

Describe 'Lab-Sprache in den Skripten' {
    BeforeAll {
        $dcScript = Get-Content -Path (Join-Path $repoRoot 'scripts/Install-DomainController.ps1') -Raw
        $exchangeInstallScript = Get-Content -Path (Join-Path $repoRoot 'scripts/Install-ExchangeServer.ps1') -Raw
    }

    It 'reicht LabLanguage an die Folgephasen weiter (geplante Tasks)' {
        # Fehlt der Parameter im Argumentstring, laeuft die naechste Phase mit dem Standard 'de'.
        [regex]::Match($dcScript, '(?s)function Register-PhaseTask \{.*?\n\}').Value | Should -Match '-LabLanguage \{\d+\}'
        [regex]::Match($exchangeInstallScript, '(?s)function Invoke-InstallTask \{.*?\n\}').Value | Should -Match '-LabLanguage \{\d+\}'
    }

    It 'benennt die AD-Standorte wie die Standort-OUs in LabUsers.psd1 (<_>)' -ForEach 'de', 'en' {
        $data = Import-PowerShellDataFile -Path (Join-Path $repoRoot "scripts/data/$_/LabUsers.psd1")
        $block = [regex]::Match($dcScript, "(?m)^\s+$_ = @\{ Headquarters = '([^']+)'; Branch = '([^']+)'")
        $block.Success | Should -BeTrue
        foreach ($site in $block.Groups[1].Value, $block.Groups[2].Value) {
            $data.OrganizationalUnits | Should -Contain "OU=$site,OU=Branch"
        }
    }
}

Describe 'Zweiter DC waehrend der Erstreplikation' {
    It 'fuehrt das Exchange-Setup gegen den ersten DC aus und wartet auf den zweiten' {
        $script = Get-Content -Path (Join-Path $repoRoot 'scripts/Install-ExchangeServer.ps1') -Raw
        [regex]::Match($script, '(?s)function Invoke-ExchangeSetup \{.*?\n\}').Value | Should -Match '/DomainController:\$DcComputerName\.\$DomainName'
        [regex]::Match($script, '(?s)function Install-Exchange \{.*?\n\}').Value | Should -Match 'Wait-SecondDomainController'
    }

    It 'wiederholt icacls, solange neue Gruppen noch nicht repliziert sind' {
        $script = Get-Content -Path (Join-Path $repoRoot 'scripts/Initialize-FileServer.ps1') -Raw
        [regex]::Match($script, '(?s)function Invoke-IcaclsCommand \{.*?\n\}').Value | Should -Match '1332'
    }
}

Describe 'Remote Desktop Manager auf dem Client' {
    BeforeAll {
        $clientScript = Get-Content -Path (Join-Path $repoRoot 'scripts/Initialize-LabClient.ps1') -Raw
        $exchangeScript = Get-Content -Path (Join-Path $repoRoot 'scripts/Initialize-ExchangeServer.ps1') -Raw
    }

    It 'nutzt denselben PowerShell-7-Pin wie der Exchange-Server' {
        $pattern = "Url\s*=\s*'https://github\.com/PowerShell/PowerShell/releases/download/[^']+'\s+Sha256\s*=\s*'[0-9a-f]{64}'"
        $clientPin = [regex]::Match($clientScript, $pattern)
        $exchangePin = [regex]::Match($exchangeScript, $pattern)
        $clientPin.Success | Should -BeTrue
        ($clientPin.Value -replace '\s+', ' ') | Should -Be ($exchangePin.Value -replace '\s+', ' ')
    }

    It 'laedt RDM mit fester Version und SHA256 aus dem Devolutions-CDN' {
        $clientScript | Should -Match "Url\s*=\s*'https://cdn\.devolutions\.net/download/Setup\.RemoteDesktopManager\.win-x64\.\d+\.\d+\.\d+\.\d+\.msi'\s+Sha256\s*=\s*'[0-9A-F]{64}'"
    }

    It 'prueft die .NET Desktop Runtime mit dem von Microsoft veroeffentlichten SHA512' {
        $clientScript | Should -Match "Url\s*=\s*'https://builds\.dotnet\.microsoft\.com/dotnet/WindowsDesktop/10\.[^']+-win-x64\.exe'\s+Sha512\s*=\s*'[0-9a-f]{128}'"
    }

    It 'installiert das RDM-Modul in fester Version' {
        $clientScript | Should -Match "Name\s*=\s*'Devolutions\.PowerShell'\s+Version\s*=\s*'\d+\.\d+\.\d+'"
    }
}

Describe 'winget-Pakete auf dem Client' {
    BeforeAll {
        $clientScript = Get-Content -Path (Join-Path $repoRoot 'scripts/Initialize-LabClient.ps1') -Raw
        $exchangeScript = Get-Content -Path (Join-Path $repoRoot 'scripts/Initialize-ExchangeServer.ps1') -Raw
        function Get-ClientFunctionText([string] $Name) { [regex]::Match($clientScript, "(?s)function $Name \{.*?\n\}").Value }
    }

    It 'nutzt denselben Microsoft.WinGet.Client-Pin wie der Exchange-Server' {
        $pattern = "\`$WinGetClientVersion\s*=\s*'(\d+\.\d+\.\d+)'"
        $clientPin = [regex]::Match($clientScript, $pattern)
        $clientPin.Success | Should -BeTrue
        $clientPin.Groups[1].Value | Should -Be ([regex]::Match($exchangeScript, $pattern).Groups[1].Value)
    }

    It 'legt Hilfsskript und Paketliste fuer den SYSTEM-Task in einem schreibgeschuetzten Ordner ab' {
        $clientScript | Should -Match "\`$WinGetDir\s*=\s*Join-Path \`$env:ProgramData"
        Get-ClientFunctionText 'Install-WinGetTool' | Should -Match 'Initialize-ReadOnlyFolderAcl -Path \$WinGetDir'
    }

    It 'registriert den Update-Task beim Start und taeglich, mit Nachholen' {
        $register = Get-ClientFunctionText 'Register-WinGetUpdateTask'
        $register | Should -Match 'New-ScheduledTaskTrigger -AtStartup'
        $register | Should -Match "New-ScheduledTaskTrigger -Daily -At '12:00'"
        $register | Should -Match '-StartWhenAvailable'
        $register | Should -Match "-UserId 'SYSTEM'"
        $register | Should -Match ' -Update '
    }

    It 'schaltet die Update-Meldung von VS Code per Richtlinie ab' {
        Get-ClientFunctionText 'Initialize-VSCodePolicy' | Should -Match "-Name 'UpdateMode' -Value 'none'"
        Get-ClientFunctionText 'Install-WinGetTool' | Should -Match "-contains 'Microsoft\.VisualStudioCode'"
    }
}

Describe 'Beispieldokumente (Korpus, Artefakte, Generator) (<Language>)' -ForEach $languages {
    BeforeAll {
        $labUsersPath = Join-Path -Path $repoRoot -ChildPath "scripts/data/$Language/LabUsers.psd1"
        $labUsers = Import-PowerShellDataFile -Path $labUsersPath
        $fileServer = Import-PowerShellDataFile -Path (Join-Path -Path $repoRoot -ChildPath "scripts/data/$Language/FileServer.psd1")
        # Nur fiktive Rufnummern; der Generator nutzt fuer Privatpersonen auch die uebrigen reservierten Bereiche.
        $corpusPhone = @{
            de = @{ Find = '\+49 [\d \-]+\d'; Allowed = '^\+49 (30 23125|40 66969|221 4710|89 99998|69 90009|171 39200|176 040690)'; Foreign = '\+44 ' }
            en = @{ Find = '\+44 [\d ]+\d'; Allowed = '^\+44 (20 7946 0|161 496 0|121 496 0|113 496 0|117 496 0|7700 900)'; Foreign = '\+49 ' }
        }[$Language]
        function Expand-GzipByte([byte[]] $Bytes) {
            $packed = New-Object -TypeName System.IO.MemoryStream -ArgumentList (, $Bytes)
            $gzip = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $packed, ([IO.Compression.CompressionMode]::Decompress)
            $plain = New-Object -TypeName System.IO.MemoryStream
            $gzip.CopyTo($plain)
            $gzip.Dispose()
            , $plain.ToArray()
        }
        $corpusDir = Join-Path $repoRoot "scripts/data/$Language/corpus"
        $corpusFiles = @(Get-ChildItem -Path $corpusDir -Filter '*.psd1' -File | Sort-Object -Property Name)
        $corpusText = ($corpusFiles | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $company = Import-PowerShellDataFile -Path (Join-Path $corpusDir 'Company.psd1')
        $generatorPath = Join-Path $repoRoot 'scripts/New-SampleDocuments.ps1'
        $generatorText = [IO.File]::ReadAllText($generatorPath)
        $rebuild = 'tools/Build-SampleArtifacts.ps1 ausfuehren und die Artefakte committen'
        # Wie tools/Build-SampleArtifacts.ps1: ohne Kommentarzeilen und Einrueckung.
        function Get-MinifiedCorpusText([string] $Path) {
            $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
            (($text -split "`n") | Where-Object { $_ -notmatch '^\s*#' } | ForEach-Object { $_.TrimStart() }) -join "`n"
        }
    }

    It 'SampleCorpus.<Language>.gz passt in die userData und entspricht den Quellen' {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot "scripts/SampleCorpus.$Language.gz"))
        [Convert]::ToBase64String($bytes).Length | Should -BeLessOrEqual 65536
        $json = [Text.Encoding]::UTF8.GetString((Expand-GzipByte $bytes)) | ConvertFrom-Json
        @($json.PSObject.Properties.Name) | Should -Be @($corpusFiles.Name) -Because $rebuild
        foreach ($file in $corpusFiles) {
            $json.($file.Name) | Should -BeExactly (Get-MinifiedCorpusText $file.FullName) -Because $rebuild
            # Das Kuerzen darf die Daten nicht aendern (z. B. eingerueckte Zeilen in mehrzeiligen Texten).
            $minified = Join-Path $TestDrive $file.Name
            [IO.File]::WriteAllText($minified, $json.($file.Name), (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true))
            (Import-PowerShellDataFile -Path $minified | ConvertTo-Json -Depth 30 -Compress) |
                Should -BeExactly (Import-PowerShellDataFile -Path $file.FullName | ConvertTo-Json -Depth 30 -Compress) -Because "$($file.Name) ohne Kommentare und Einrueckung"
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
        foreach ($key in 'Company', 'Ci', 'Timeline', 'Employees', 'Customers', 'Suppliers', 'Shops', 'Motifs', 'Labels', 'FolderNames',
            'Locale', 'Paths', 'Roles', 'Departments', 'Industries', 'Patterns', 'Office',
            'BirthPlaces', 'LocalCities', 'Phases', 'WebMenu', 'CardBookings', 'PasswordWords', 'NoteNames') {
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

    It 'nutzt nur Rufnummern fuer Medienproduktionen (Bundesnetzagentur bzw. Ofcom)' {
        $numbers = [regex]::Matches(($corpusText + "`n" + $generatorText), $corpusPhone.Find) | ForEach-Object Value | Select-Object -Unique
        $numbers | Should -Not -BeNullOrEmpty
        foreach ($number in $numbers) { $number | Should -Match $corpusPhone.Allowed }
        $corpusText | Should -Not -Match $corpusPhone.Foreign -Because 'Rufnummern des anderen Landes gehoeren nicht in diesen Korpus'
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
        foreach ($motif in $company.Motifs) { $shapes | Should -Match ("'?{0}'?\s*=\s*@\{{" -f [regex]::Escape($motif.Format)) }
    }

    It 'findet jeden Schluessel der sprachabhaengigen Bereiche im Drehbuch' {
        # Zugriff im Generator -> Bereich in Company.psd1 (AreaName hat dieselben Schluessel wie Paths).
        $sections = [ordered]@{
            '$Locale.' = 'Locale'; '$Paths.' = 'Paths'; '$AreaName.' = 'Paths'; '$Roles.' = 'Roles'; '$Office.' = 'Office'; '$Patterns.' = 'Patterns'
            '$C.Departments.' = 'Departments'; '$C.Company.' = 'Company'
        }
        foreach ($prefix in $sections.Keys) {
            $keys = @([regex]::Matches($generatorText, ('{0}([A-Za-z]+)' -f [regex]::Escape($prefix))) | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -cnotin 'Keys', 'Values', 'Count' } | Select-Object -Unique)
            $keys | Should -Not -BeNullOrEmpty -Because "der Generator nutzt $prefix"
            foreach ($key in $keys) { $company[$sections[$prefix]].Keys | Should -Contain $key -Because "$prefix$key" }
        }
        foreach ($layout in 'Title', 'Content', 'ImageRight', 'ImageFull', 'Section', 'Closing') { $company.Office.Layouts.Keys | Should -Contain $layout }
        foreach ($site in 'HQ', 'Branch') { @($company.Company.Sites.Key) | Should -Contain $site }
        foreach ($site in $company.Company.Sites) { foreach ($key in 'Key', 'Code', 'Name', 'City', 'Dial') { $site.Keys | Should -Contain $key } }
        foreach ($sam in @($company.Roles.Values | ForEach-Object { $_ })) { @($company.Employees.Sam) | Should -Contain $sam }
        @($company.Suppliers | Where-Object { $_.Role -eq 'TaxAdvisor' }) | Should -HaveCount 1
    }

    It 'nutzt sprachneutrale IDs fuer Abteilungen, Branchen, Richtlinien und Werbemittel' {
        foreach ($employee in $company.Employees) { $company.Departments.Keys | Should -Contain $employee.Department -Because $employee.Sam }
        $textFiles = ($corpusFiles | Where-Object Name -Like 'Texts-*' | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        $industries = @($company.Customers.Industry) + @([regex]::Matches($textFiles, "Industry = '([^']+)'") | ForEach-Object { $_.Groups[1].Value })
        foreach ($industry in $industries | Select-Object -Unique) { $company.Industries.Keys | Should -Contain $industry }
        $texture = [regex]::Match($generatorText, '\$IndustryTexture = @\{[^\n]*\}').Value
        foreach ($industry in $company.Industries.Keys) { $texture | Should -Match ("\b{0} = '" -f $industry) }
        $texts = Import-PowerShellDataFile -Path (Join-Path $corpusDir 'Texts-Company.psd1')
        foreach ($policy in $texts.Policy) {
            $company.Paths.Keys | Should -Contain $policy.Folder -Because $policy.Title
            $company.Labels.Keys | Should -Contain $policy.Classification -Because $policy.Title
        }
    }

    It 'legt nur in Ordner aus FileServer.psd1 ab (Paths)' {
        $folders = @($fileServer.Folders.Path)
        $targets = @($company.Paths.Values) + @($company.Company.Sites | ForEach-Object { '{0}\{1}' -f $company.Paths.Marketing, $_.Name })
        foreach ($path in $targets) {
            @($folders | Where-Object { $path -eq $_ -or $path.StartsWith($_ + '\') }) | Should -Not -BeNullOrEmpty -Because "$path fehlt in FileServer.psd1"
        }
    }

    It 'legt die Altlasten in Ordner, die der Generator befuellt' {
        $folderNames = @($company.FolderNames.Values | ForEach-Object { $_ })
        foreach ($item in $fileServer.Legacy | Where-Object { $_.Type -in 'UserAce', 'BrokenInheritance', 'OwnerOnly' }) {
            $folderNames | Should -Contain (Split-Path -Path ($item.Path -replace '\\', '/') -Leaf)
        }
    }

    It 'erzeugt <Variant> gueltige Dateien ohne offene Platzhalter (Smoke-Test)' -ForEach @(
        @{ Variant = 'ohne Rastergrafik'; Raster = $false; SizeMB = 6; Skip = $false }
        # Mit Rastergrafik sind die Dateien groesser, fuer alle Dateiarten braucht es mehr Volumen.
        @{ Variant = 'mit Rastergrafik'; Raster = $true; SizeMB = 20; Skip = -not $isWindowsHost }
    ) {
        if ($Skip) { Set-ItResult -Skipped -Because 'Rastergrafik (System.Drawing) nur unter Windows'; return }
        $target = Join-Path $TestDrive "daten-$Raster"
        $labRoot = Join-Path $TestDrive "lab-$Raster"
        $arguments = @('-NoProfile', '-NonInteractive', '-File', $generatorPath, '-TargetPath', $target, '-TargetSizeMB', "$SizeMB", '-LabRoot', $labRoot,
            '-CorpusPath', $corpusDir, '-LabUsersPath', $labUsersPath, '-ReferenceDate', '2026-11-24',
            '-WorkerCount', '1', '-TimeBudgetMinutes', '0')
        if (-not $Raster) { $arguments += '-NoRaster' }
        & (Get-Process -Id $PID).Path @arguments | Out-Null
        $LASTEXITCODE | Should -Be 0 -Because (Get-Content -Path (Join-Path $labRoot 'Logs/New-SampleDocuments.log') -Raw)
        (Get-Content -Path (Join-Path $labRoot 'Logs/New-SampleDocuments.log') -Raw) | Should -Not -MatchExactly 'WARNUNG:|FEHLER:'
        $files = @(Get-ChildItem -Path $target -Recurse -File)
        # Mit Rastergrafik fuellen Bilder das Volumen frueher, Praesentationen kommen dann erst spaeter an die Reihe.
        $expected = if ($Raster) { '.docx', '.xlsx', '.pdf', '.jpg', '.png' } else { '.docx', '.xlsx', '.pptx', '.pdf' }
        foreach ($extension in $expected) { @($files | Where-Object Extension -EQ $extension).Count | Should -BeGreaterThan 0 -Because "$extension fehlt" }
        @($files | Where-Object Name -Match '\{[A-Za-z]+\}') | Should -BeNullOrEmpty
        $years = @($files | ForEach-Object { $_.LastWriteTime.Year } | Select-Object -Unique)
        $years.Count | Should -BeGreaterThan 5
        # ZipFile liegt unter .NET Framework (Windows PowerShell 5.1) in einer eigenen Assembly.
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
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
                    if ($Language -eq 'en') {
                        # Englische Dokumente ohne deutsche Reste aus Generator oder Korpus.
                        $xml | Should -Not -Match '[äöüÄÖÜß€]|Mustermann|\+49 |\bSeite \d' -Because "$($file.Name)/$($entry.FullName) enthaelt Deutsches"
                    }
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
