# Freigaben, Ordner, Gruppen und Berechtigungen des Fileservers <K>-FS01, englische Variante (Contoso Ltd, UK).
# Gleicher Aufbau wie scripts/data/de/FileServer.psd1 (Altlasten gleichen Typs, Ordner und Gruppen sinngemaess).
# Pfade sind relativ zu Root. OUs sind relativ zur Firmen-OU "LEARN-<trainee>" (siehe LabUsers.psd1).
# Berechtigungen nach AGDLP: Benutzer -> globale Gruppe (GG-*) -> domaenenlokale Gruppe (DL-FS-<Stem>-M/-R) -> NTFS.
# Sonderprinzipale: '@DomainUsers' (Domaenen-Benutzer), '@Everyone' (Jeder), '@AuthenticatedUsers'.
# Rechte: 'M' = Aendern, 'RX' = Lesen und Ausfuehren, 'F' = Vollzugriff.
@{
    DriveLetter          = 'F'
    VolumeLabel          = 'Data'
    Root                 = 'F:\Shares'

    GlobalGroups         = @(
        @{ Name = 'GG-Management'; OrganizationalUnit = 'OU=Groups,OU=London,OU=Branch'; Description = 'Management'; Members = @('FBloggs', 'JBloggs', 'CWhitfield') }
        @{ Name = 'GG-Marketing-London'; OrganizationalUnit = 'OU=Groups,OU=London,OU=Branch'; Description = 'Marketing, London office'; Members = @('JBloggs', 'OBennett', 'HCarter', 'ECollins', 'SPatel', 'MiriamG', 'MeganB', 'AlexW', 'HenriettaM', 'NestorW') }
        @{ Name = 'GG-Marketing-Manchester'; OrganizationalUnit = 'OU=Groups,OU=Manchester,OU=Branch'; Description = 'Marketing, Manchester office'; Members = @('CWhitfield', 'GTurner', 'WHughes', 'TWright', 'ZNowak', 'DPrice', 'LeeG', 'GradyA', 'LynneR', 'JohannaL') }
        @{ Name = 'GG-Accounts'; OrganizationalUnit = 'OU=Groups,OU=London,OU=Branch'; Description = 'Accounts'; Members = @('FBloggs', 'PradeepG') }
        @{ Name = 'GG-HR'; OrganizationalUnit = 'OU=Groups,OU=London,OU=Branch'; Description = 'Human resources'; Members = @('JBloggs', 'DiegoS', 'JoniS') }
        @{ Name = 'GG-Sales'; OrganizationalUnit = 'OU=Groups,OU=London,OU=Branch'; Description = 'Sales and account management'; Members = @('OBennett', 'CWhitfield', 'PattiF', 'IsaiahL', 'LidiaH', 'AdeleV') }
        @{ Name = 'GG-IT'; OrganizationalUnit = 'OU=Groups,OU=London,OU=Branch'; Description = 'IT (no members yet)'; Members = @() }
    )

    # OU und Beschreibung der domaenenlokalen Ressourcengruppen DL-FS-* ({0} = Server, {1} = Ordnerpfad).
    DomainLocalGroupOrganizationalUnit = 'OU=Groups,OU=Administration'
    DomainLocalGroupDescription        = @{ M = 'Modify on \\{0}\...\{1}'; R = 'Read on \\{0}\...\{1}' }

    # Protected = Vererbung von F:\ entfernen (Administratoren und SYSTEM erhalten immer Vollzugriff).
    # List      = nur "Ordner auflisten" auf genau diesem Ordner (keine Vererbung), fuer den Einstieg in die Freigabe.
    # Stem      = legt DL-FS-<Stem>-M (Modify) und DL-FS-<Stem>-R (Read) an, Mitglieder aus Modify/Read.
    Folders              = @(
        @{ Path = 'Departments'; Protected = $true; List = @('@DomainUsers') }
        @{ Path = 'Departments\General'; Stem = 'General'; Modify = @('GG-Management'); Read = @('@DomainUsers') }
        @{ Path = 'Departments\Management'; Stem = 'Management'; Modify = @('GG-Management'); Read = @() }
        @{ Path = 'Departments\Accounts'; Stem = 'Accounts'; Modify = @('GG-Accounts'); Read = @('GG-Management') }
        @{ Path = 'Departments\HR'; Stem = 'HR'; Modify = @('GG-HR'); Read = @('GG-Management') }
        @{ Path = 'Departments\Marketing'; Stem = 'Marketing'; Modify = @(); Read = @('GG-Marketing-London', 'GG-Marketing-Manchester', 'GG-Management') }
        @{ Path = 'Departments\Marketing\London'; Stem = 'Marketing-London'; Modify = @('GG-Marketing-London'); Read = @() }
        @{ Path = 'Departments\Marketing\Manchester'; Stem = 'Marketing-Manchester'; Modify = @('GG-Marketing-Manchester'); Read = @() }
        @{ Path = 'Departments\Sales'; Stem = 'Sales'; Modify = @('GG-Sales'); Read = @('GG-Management', 'GG-Marketing-London', 'GG-Marketing-Manchester') }
        @{ Path = 'Departments\IT'; Stem = 'IT'; Modify = @('GG-IT'); Read = @() }
        @{ Path = 'Projects'; Protected = $true; Stem = 'Projects'; Modify = @('GG-Marketing-London', 'GG-Marketing-Manchester', 'GG-Sales', 'GG-Management'); Read = @('GG-Accounts') }
        @{ Path = 'Projects\Internship' }
        @{ Path = 'Archive'; Protected = $true; Stem = 'Archive'; Modify = @('GG-Management'); Read = @('@DomainUsers') }
        @{ Path = 'Scans'; Protected = $true; Stem = 'Scans'; Modify = @('@DomainUsers'); Read = @() }
        @{ Path = 'Home'; Protected = $true; List = @('@DomainUsers') }
    )

    # Freigabeberechtigung immer: Authentifizierte Benutzer Aendern, Administratoren Vollzugriff. NTFS steuert den Zugriff.
    Shares               = @(
        @{ Name = 'Departments'; Path = 'Departments'; Description = 'Departmental data, Contoso' }
        @{ Name = 'Projects'; Path = 'Projects'; Description = 'Client projects' }
        @{ Name = 'Archive'; Path = 'Archive'; Description = 'Closed years, read only' }
        @{ Name = 'Scans'; Path = 'Scans'; Description = 'Scan inbox of the multifunction printers' }
        @{ Name = 'Home$'; Path = 'Home'; Description = 'User home folders' }
    )

    # Basisordner: Home\<SamAccountName>, Benutzer Aendern und Besitzer, AD-Attribute HomeDrive/HomeDirectory.
    HomeFolders          = @{ Path = 'Home'; Share = 'Home$'; DriveLetter = 'H:' }

    # Absichtliche Altlasten fuer Uebungen (finden, bewerten, beheben), gleiche Typen wie in der deutschen Variante.
    Legacy               = @(
        # Einzelner Benutzer direkt im ACL statt ueber eine Gruppe.
        @{ Type = 'UserAce'; Path = 'Departments\Accounts\Travel Expenses'; Principal = 'HCarter'; Rights = 'M' }
        # Vererbung unterbrochen und Jeder darf Bewerbungen lesen (ABE zeigt den Ordner allen).
        @{ Type = 'BrokenInheritance'; Path = 'Departments\HR\Applications'; Principal = '@Everyone'; Rights = 'RX' }
        # Ehemaliger Praktikant ("Ian Tern" = intern): Konto geloescht (AD-Papierkorb), seine SID bleibt in den ACLs stehen.
        # SampleSource: aus diesem Ordner landen einige Dokumente in seinem Basisordner (Unterordner DocumentsFolder).
        @{ Type = 'OrphanedSid'; SamAccountName = 'ITern'; GivenName = 'Ian'; Surname = 'Tern'; Description = 'Marketing internship, left'; OrganizationalUnit = 'OU=Users,OU=London,OU=Branch'; Paths = @('Projects\Internship', 'Home\ITern'); SampleSource = 'Departments\Marketing\London'; DocumentsFolder = 'Documents'; Rights = 'M' }
        # Privater Ordner ohne Administratoren (nur Benutzer und SYSTEM): "Zugriff verweigert" fuer Domain-Admins.
        @{ Type = 'OwnerOnly'; Path = 'Home\WHughes\Private'; Principal = 'WHughes' }
        # Scanner-Freigabe: Jeder Vollzugriff auf Freigabe und NTFS.
        @{ Type = 'EveryoneFull'; Share = 'Scans' }
    )
}
