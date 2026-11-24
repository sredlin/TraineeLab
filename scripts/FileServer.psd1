# Freigaben, Ordner, Gruppen und Berechtigungen des Fileservers <K>-FS01.
# Pfade sind relativ zu Root. OUs sind relativ zur Firmen-OU "LEARN-<trainee>" (siehe LabUsers.psd1).
# Berechtigungen nach AGDLP: Benutzer -> globale Gruppe (GG-*) -> domaenenlokale Gruppe (DL-FS-<Stem>-M/-R) -> NTFS.
# Sonderprinzipale: '@DomainUsers' (Domaenen-Benutzer), '@Everyone' (Jeder), '@AuthenticatedUsers'.
# Rechte: 'M' = Aendern, 'RX' = Lesen und Ausfuehren, 'F' = Vollzugriff.
@{
    DriveLetter          = 'F'
    Root                 = 'F:\Shares'

    GlobalGroups         = @(
        @{ Name = 'GG-Geschaeftsleitung'; OrganizationalUnit = 'OU=Groups,OU=Berlin,OU=Branch'; Description = 'Geschaeftsleitung'; Members = @('MMustermann', 'EMustermann', 'CHerz') }
        @{ Name = 'GG-Marketing-Berlin'; OrganizationalUnit = 'OU=Groups,OU=Berlin,OU=Branch'; Description = 'Marketing Standort Berlin'; Members = @('EMustermann', 'JDoe', 'KAnders', 'VSpula', 'LMayer') }
        @{ Name = 'GG-Marketing-Hamburg'; OrganizationalUnit = 'OU=Groups,OU=Hamburg,OU=Branch'; Description = 'Marketing Standort Hamburg'; Members = @('CHerz', 'WErnst', 'JFrick', 'SHarz', 'WLonska', 'RJung') }
        @{ Name = 'GG-Buchhaltung'; OrganizationalUnit = 'OU=Groups,OU=Berlin,OU=Branch'; Description = 'Buchhaltung'; Members = @('MMustermann') }
        @{ Name = 'GG-Personal'; OrganizationalUnit = 'OU=Groups,OU=Berlin,OU=Branch'; Description = 'Personalabteilung'; Members = @('EMustermann') }
        @{ Name = 'GG-Vertrieb'; OrganizationalUnit = 'OU=Groups,OU=Berlin,OU=Branch'; Description = 'Vertrieb und Kundenberatung'; Members = @('JDoe', 'CHerz') }
        @{ Name = 'GG-IT'; OrganizationalUnit = 'OU=Groups,OU=Berlin,OU=Branch'; Description = 'IT (noch ohne Mitglieder)'; Members = @() }
    )

    # OU der domaenenlokalen Ressourcengruppen DL-FS-*.
    DomainLocalGroupOrganizationalUnit = 'OU=Groups,OU=Administration'

    # Protected = Vererbung von F:\ entfernen (Administratoren und SYSTEM erhalten immer Vollzugriff).
    # List      = nur "Ordner auflisten" auf genau diesem Ordner (keine Vererbung), fuer den Einstieg in die Freigabe.
    # Stem      = legt DL-FS-<Stem>-M (Modify) und DL-FS-<Stem>-R (Read) an, Mitglieder aus Modify/Read.
    Folders              = @(
        @{ Path = 'Abteilungen'; Protected = $true; List = @('@DomainUsers') }
        @{ Path = 'Abteilungen\Allgemein'; Stem = 'Allgemein'; Modify = @('GG-Geschaeftsleitung'); Read = @('@DomainUsers') }
        @{ Path = 'Abteilungen\Geschaeftsleitung'; Stem = 'Geschaeftsleitung'; Modify = @('GG-Geschaeftsleitung'); Read = @() }
        @{ Path = 'Abteilungen\Buchhaltung'; Stem = 'Buchhaltung'; Modify = @('GG-Buchhaltung'); Read = @('GG-Geschaeftsleitung') }
        @{ Path = 'Abteilungen\Personal'; Stem = 'Personal'; Modify = @('GG-Personal'); Read = @('GG-Geschaeftsleitung') }
        @{ Path = 'Abteilungen\Marketing'; Stem = 'Marketing'; Modify = @(); Read = @('GG-Marketing-Berlin', 'GG-Marketing-Hamburg', 'GG-Geschaeftsleitung') }
        @{ Path = 'Abteilungen\Marketing\Berlin'; Stem = 'Marketing-Berlin'; Modify = @('GG-Marketing-Berlin'); Read = @() }
        @{ Path = 'Abteilungen\Marketing\Hamburg'; Stem = 'Marketing-Hamburg'; Modify = @('GG-Marketing-Hamburg'); Read = @() }
        @{ Path = 'Abteilungen\Vertrieb'; Stem = 'Vertrieb'; Modify = @('GG-Vertrieb'); Read = @('GG-Geschaeftsleitung', 'GG-Marketing-Berlin', 'GG-Marketing-Hamburg') }
        @{ Path = 'Abteilungen\IT'; Stem = 'IT'; Modify = @('GG-IT'); Read = @() }
        @{ Path = 'Projekte'; Protected = $true; Stem = 'Projekte'; Modify = @('GG-Marketing-Berlin', 'GG-Marketing-Hamburg', 'GG-Vertrieb', 'GG-Geschaeftsleitung'); Read = @('GG-Buchhaltung') }
        @{ Path = 'Projekte\Praktikum' }
        @{ Path = 'Archiv'; Protected = $true; Stem = 'Archiv'; Modify = @('GG-Geschaeftsleitung'); Read = @('@DomainUsers') }
        @{ Path = 'Scans'; Protected = $true; Stem = 'Scans'; Modify = @('@DomainUsers'); Read = @() }
        @{ Path = 'Home'; Protected = $true; List = @('@DomainUsers') }
    )

    # Freigabeberechtigung immer: Authentifizierte Benutzer Aendern, Administratoren Vollzugriff. NTFS steuert den Zugriff.
    Shares               = @(
        @{ Name = 'Abteilungen'; Path = 'Abteilungen'; Description = 'Abteilungsdaten Mustermann Medien' }
        @{ Name = 'Projekte'; Path = 'Projekte'; Description = 'Kundenprojekte' }
        @{ Name = 'Archiv'; Path = 'Archiv'; Description = 'Abgeschlossene Jahre, nur lesen' }
        @{ Name = 'Scans'; Path = 'Scans'; Description = 'Scan-Eingang der Multifunktionsgeraete' }
        @{ Name = 'Home$'; Path = 'Home'; Description = 'Basisordner der Benutzer' }
    )

    # Basisordner: Home\<SamAccountName>, Benutzer Aendern und Besitzer, AD-Attribute HomeDrive/HomeDirectory.
    HomeFolders          = @{ Path = 'Home'; Share = 'Home$'; DriveLetter = 'H:' }

    # Absichtliche Altlasten fuer Kapitel 8 der Uebungen (finden, bewerten, beheben).
    Legacy               = @(
        # Einzelner Benutzer direkt im ACL statt ueber eine Gruppe.
        @{ Type = 'UserAce'; Path = 'Abteilungen\Buchhaltung\Reisekosten'; Principal = 'KAnders'; Rights = 'M' }
        # Vererbung unterbrochen und Jeder darf Bewerbungen lesen (ABE zeigt den Ordner allen).
        @{ Type = 'BrokenInheritance'; Path = 'Abteilungen\Personal\Bewerbungen'; Principal = '@Everyone'; Rights = 'RX' }
        # Ehemaliger Praktikant: Konto geloescht (AD-Papierkorb), seine SID bleibt in den ACLs stehen.
        # SampleSource: aus diesem Ordner landen einige Dokumente in seinem Basisordner.
        @{ Type = 'OrphanedSid'; SamAccountName = 'PPraktikant'; GivenName = 'Paul'; Surname = 'Praktikant'; OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; Paths = @('Projekte\Praktikum', 'Home\PPraktikant'); SampleSource = 'Abteilungen\Marketing\Berlin'; Rights = 'M' }
        # Privater Ordner ohne Administratoren (nur Benutzer und SYSTEM): "Zugriff verweigert" fuer Domain-Admins.
        @{ Type = 'OwnerOnly'; Path = 'Home\JFrick\Privat'; Principal = 'JFrick' }
        # Scanner-Freigabe: Jeder Vollzugriff auf Freigabe und NTFS.
        @{ Type = 'EveryoneFull'; Share = 'Scans' }
    )
}
