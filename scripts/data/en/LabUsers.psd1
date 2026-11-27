# OU-Struktur, Lab-Benutzer und Beispielempfaenger des Exchange-Labs, englische Variante (Contoso Ltd, UK).
# Gleicher Aufbau wie scripts/data/de/LabUsers.psd1; die 16 Microsoft-Demo-Personas sind in beiden Sprachen gleich.
# Pfade sind relativ zur Firmen-OU "LEARN-<trainee>" unterhalb der Domain.
# Reihenfolge der OUs: uebergeordnete OU immer vor untergeordneter OU.
# Benutzerverweise (Manager, Mitglieder, Berechtigungen) nutzen den SamAccountName.
# Aliase: nur Kleinbuchstaben, Ziffern und Bindestriche, hoechstens 20 Zeichen (zugleich SamAccountName).
# Rufnummern: nur Ofcom-Nummern fuer TV- und Radio-Produktionen (Drama-Nummern), London 020 7946 0000..0999,
# Manchester 0161 496 0000..0999, Mobil 07700 900000..900999. Fax je Standort 0099.
@{
    # AD-Attribute company und c/co/countryCode aller Lab-Benutzer.
    Company             = 'Contoso Ltd'
    Country             = @{ Code = 'GB'; Name = 'United Kingdom'; Number = 826 }

    OrganizationalUnits = @(
        'OU=Branch'
        'OU=London,OU=Branch'
        'OU=Users,OU=London,OU=Branch'
        'OU=Groups,OU=London,OU=Branch'
        'OU=Computers,OU=London,OU=Branch'
        'OU=Manchester,OU=Branch'
        'OU=Users,OU=Manchester,OU=Branch'
        'OU=Groups,OU=Manchester,OU=Branch'
        'OU=Computers,OU=Manchester,OU=Branch'
        'OU=Administration'
        'OU=Resources,OU=Administration'
        'OU=ServiceAccounts,OU=Administration'
        'OU=Contacts,OU=Administration'
        'OU=DistributionLists,OU=Administration'
        'OU=Groups,OU=Administration'
    )

    # Standortdaten der Lab-Benutzer (Feld Site): OU, Anschrift und Fax je Standort, einmal statt je Benutzer.
    Sites               = @{
        HQ     = @{ OrganizationalUnit = 'OU=Users,OU=London,OU=Branch'; StreetAddress = '1 Market Way'; City = 'London'; PostalCode = 'EC2A 1AA'; Fax = '+44 20 7946 0099' }
        Branch = @{ OrganizationalUnit = 'OU=Users,OU=Manchester,OU=Branch'; StreetAddress = '1 Mill Lane'; City = 'Manchester'; PostalCode = 'M1 1AA'; Fax = '+44 161 496 0099' }
    }

    Users               = @(
        @{ SamAccountName = 'FBloggs'; GivenName = 'Fred'; Surname = 'Bloggs'; Site = 'HQ'; Office = '10'; Title = 'CEO'; Department = ''; OfficePhone = '+44 20 7946 0100'; MobilePhone = '+44 7700 900000' }
        @{ SamAccountName = 'JBloggs'; GivenName = 'Jane'; Surname = 'Bloggs'; Site = 'HQ'; Office = '10'; Title = 'Managing Director'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0500'; MobilePhone = '+44 7700 900001' }
        @{ SamAccountName = 'OBennett'; GivenName = 'Oliver'; Surname = 'Bennett'; Site = 'HQ'; Office = '15'; Title = 'Head of Marketing'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0510'; MobilePhone = '+44 7700 900002' }
        @{ SamAccountName = 'HCarter'; GivenName = 'Harry'; Surname = 'Carter'; Site = 'HQ'; Office = '15'; Title = 'Designer'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0511'; MobilePhone = '+44 7700 900003' }
        @{ SamAccountName = 'ECollins'; GivenName = 'Emily'; Surname = 'Collins'; Site = 'HQ'; Office = '15'; Title = 'Designer'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0512'; MobilePhone = '+44 7700 900004' }
        @{ SamAccountName = 'SPatel'; GivenName = 'Sophie'; Surname = 'Patel'; Site = 'HQ'; Office = '15'; Title = 'Junior Designer'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0513'; MobilePhone = '+44 7700 900005' }
        @{ SamAccountName = 'CWhitfield'; GivenName = 'Charlotte'; Surname = 'Whitfield'; Site = 'Branch'; Office = '10'; Title = 'Head of Manchester office'; Department = ''; OfficePhone = '+44 161 496 0100'; MobilePhone = '+44 7700 900006' }
        @{ SamAccountName = 'GTurner'; GivenName = 'George'; Surname = 'Turner'; Site = 'Branch'; Office = '10'; Title = 'Senior Designer'; Department = 'Marketing'; OfficePhone = '+44 161 496 0500'; MobilePhone = '+44 7700 900007' }
        @{ SamAccountName = 'WHughes'; GivenName = 'William'; Surname = 'Hughes'; Site = 'Branch'; Office = '15'; Title = 'Designer'; Department = 'Marketing'; OfficePhone = '+44 161 496 0510'; MobilePhone = '+44 7700 900008' }
        @{ SamAccountName = 'TWright'; GivenName = 'Tom'; Surname = 'Wright'; Site = 'Branch'; Office = '15'; Title = 'Designer'; Department = 'Marketing'; OfficePhone = '+44 161 496 0511'; MobilePhone = '+44 7700 900009' }
        @{ SamAccountName = 'ZNowak'; GivenName = 'Zofia'; Surname = 'Nowak'; Site = 'Branch'; Office = '15'; Title = 'Designer'; Department = 'Marketing'; OfficePhone = '+44 161 496 0512'; MobilePhone = '+44 7700 900010' }
        @{ SamAccountName = 'DPrice'; GivenName = 'Daniel'; Surname = 'Price'; Site = 'Branch'; Office = '15'; Title = 'Junior Designer'; Department = 'Marketing'; OfficePhone = '+44 161 496 0513'; MobilePhone = '+44 7700 900011' }
        # Microsoft-Demo-Personas (gleiche Namen und Konten wie in M365-Demo-Tenants, z. B. fuer das Mapping bei einer Migration).
        @{ SamAccountName = 'PattiF'; GivenName = 'Patti'; Surname = 'Fernandez'; Site = 'HQ'; Office = '20'; Title = 'Head of Sales'; Department = 'Sales'; OfficePhone = '+44 20 7946 0400'; MobilePhone = '+44 7700 900012' }
        @{ SamAccountName = 'IsaiahL'; GivenName = 'Isaiah'; Surname = 'Langer'; Site = 'HQ'; Office = '20'; Title = 'Account Manager'; Department = 'Sales'; OfficePhone = '+44 20 7946 0410'; MobilePhone = '+44 7700 900013' }
        @{ SamAccountName = 'LidiaH'; GivenName = 'Lidia'; Surname = 'Holloway'; Site = 'HQ'; Office = '20'; Title = 'Project Manager'; Department = 'Sales'; OfficePhone = '+44 20 7946 0411'; MobilePhone = '+44 7700 900014' }
        @{ SamAccountName = 'MiriamG'; GivenName = 'Miriam'; Surname = 'Graham'; Site = 'HQ'; Office = '15'; Title = 'Creative Director'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0520'; MobilePhone = '+44 7700 900015' }
        @{ SamAccountName = 'MeganB'; GivenName = 'Megan'; Surname = 'Bowen'; Site = 'HQ'; Office = '15'; Title = 'Marketing Manager'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0514'; MobilePhone = '+44 7700 900016' }
        @{ SamAccountName = 'AlexW'; GivenName = 'Alex'; Surname = 'Wilber'; Site = 'HQ'; Office = '15'; Title = 'Marketing Assistant'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0515'; MobilePhone = '+44 7700 900017' }
        @{ SamAccountName = 'HenriettaM'; GivenName = 'Henrietta'; Surname = 'Mueller'; Site = 'HQ'; Office = '15'; Title = 'Web Developer'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0516'; MobilePhone = '+44 7700 900018' }
        @{ SamAccountName = 'NestorW'; GivenName = 'Nestor'; Surname = 'Wilke'; Site = 'HQ'; Office = '15'; Title = 'Head of Production'; Department = 'Marketing'; OfficePhone = '+44 20 7946 0517'; MobilePhone = '+44 7700 900019' }
        @{ SamAccountName = 'DiegoS'; GivenName = 'Diego'; Surname = 'Siciliani'; Site = 'HQ'; Office = '12'; Title = 'HR Manager'; Department = 'HR'; OfficePhone = '+44 20 7946 0300'; MobilePhone = '+44 7700 900020' }
        @{ SamAccountName = 'JoniS'; GivenName = 'Joni'; Surname = 'Sherman'; Site = 'HQ'; Office = '10'; Title = 'Executive Assistant'; Department = 'HR'; OfficePhone = '+44 20 7946 0110'; MobilePhone = '+44 7700 900021' }
        @{ SamAccountName = 'PradeepG'; GivenName = 'Pradeep'; Surname = 'Gupta'; Site = 'HQ'; Office = '12'; Title = 'Accountant'; Department = 'Accounts'; OfficePhone = '+44 20 7946 0310'; MobilePhone = '+44 7700 900022' }
        @{ SamAccountName = 'AdeleV'; GivenName = 'Adele'; Surname = 'Vance'; Site = 'Branch'; Office = '20'; Title = 'Account Manager'; Department = 'Sales'; OfficePhone = '+44 161 496 0410'; MobilePhone = '+44 7700 900023' }
        @{ SamAccountName = 'LeeG'; GivenName = 'Lee'; Surname = 'Gu'; Site = 'Branch'; Office = '15'; Title = 'Head of Digital'; Department = 'Marketing'; OfficePhone = '+44 161 496 0520'; MobilePhone = '+44 7700 900024' }
        @{ SamAccountName = 'GradyA'; GivenName = 'Grady'; Surname = 'Archie'; Site = 'Branch'; Office = '15'; Title = 'Graphic Designer'; Department = 'Marketing'; OfficePhone = '+44 161 496 0514'; MobilePhone = '+44 7700 900025' }
        @{ SamAccountName = 'LynneR'; GivenName = 'Lynne'; Surname = 'Robbins'; Site = 'Branch'; Office = '15'; Title = 'Media Planner'; Department = 'Marketing'; OfficePhone = '+44 161 496 0515'; MobilePhone = '+44 7700 900026' }
        @{ SamAccountName = 'JohannaL'; GivenName = 'Johanna'; Surname = 'Lorenz'; Site = 'Branch'; Office = '15'; Title = 'Copywriter'; Department = 'Marketing'; OfficePhone = '+44 161 496 0516'; MobilePhone = '+44 7700 900027' }
    )

    # Ziel-OU fuer den optionalen Windows-11-Client (tritt zunaechst in den Standardcontainer bei).
    ClientOrganizationalUnit = 'OU=Computers,OU=London,OU=Branch'

    # Vorgesetzte (Benutzer = Manager), sichtbar im Adressbuch und im Organigramm von OWA.
    Managers            = @{
        JBloggs    = 'FBloggs'
        OBennett   = 'JBloggs'
        HCarter    = 'OBennett'
        ECollins   = 'OBennett'
        SPatel     = 'OBennett'
        CWhitfield = 'FBloggs'
        GTurner    = 'CWhitfield'
        WHughes    = 'CWhitfield'
        TWright    = 'CWhitfield'
        ZNowak     = 'CWhitfield'
        DPrice     = 'CWhitfield'
        PattiF     = 'FBloggs'
        IsaiahL    = 'PattiF'
        LidiaH     = 'PattiF'
        AdeleV     = 'PattiF'
        MiriamG    = 'JBloggs'
        MeganB     = 'OBennett'
        AlexW      = 'MeganB'
        HenriettaM = 'MiriamG'
        NestorW    = 'MiriamG'
        LeeG       = 'CWhitfield'
        GradyA     = 'CWhitfield'
        LynneR     = 'CWhitfield'
        JohannaL   = 'CWhitfield'
        DiegoS     = 'JBloggs'
        JoniS      = 'FBloggs'
        PradeepG   = 'FBloggs'
    }

    DistributionGroups  = @(
        @{ Name = 'Management'; Alias = 'management'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('FBloggs', 'JBloggs', 'CWhitfield') }
        @{ Name = 'Marketing London'; Alias = 'marketing-london'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('JBloggs', 'OBennett', 'HCarter', 'ECollins', 'SPatel', 'MiriamG', 'MeganB', 'AlexW', 'HenriettaM', 'NestorW') }
        @{ Name = 'Marketing Manchester'; Alias = 'marketing-manchester'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('GTurner', 'WHughes', 'TWright', 'ZNowak', 'DPrice', 'LeeG', 'GradyA', 'LynneR', 'JohannaL') }
        @{ Name = 'Sales'; Alias = 'sales'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('PattiF', 'IsaiahL', 'LidiaH', 'AdeleV') }
        @{ Name = 'All Staff'; Alias = 'all-staff'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('FBloggs', 'JBloggs', 'OBennett', 'HCarter', 'ECollins', 'SPatel', 'CWhitfield', 'GTurner', 'WHughes', 'TWright', 'ZNowak', 'DPrice', 'PattiF', 'IsaiahL', 'LidiaH', 'MiriamG', 'MeganB', 'AlexW', 'HenriettaM', 'NestorW', 'DiegoS', 'JoniS', 'PradeepG', 'AdeleV', 'LeeG', 'GradyA', 'LynneR', 'JohannaL') }
    )

    SharedMailboxes     = @(
        @{ Name = 'Info'; Alias = 'info'; OrganizationalUnit = 'OU=Resources,OU=Administration'; FullAccess = @('JBloggs', 'CWhitfield', 'JoniS'); SendAs = @('JBloggs', 'JoniS') }
        @{ Name = 'Accounts'; Alias = 'accounts'; OrganizationalUnit = 'OU=Resources,OU=Administration'; FullAccess = @('FBloggs', 'PradeepG'); SendAs = @('FBloggs', 'PradeepG') }
    )

    RoomMailboxes       = @(
        @{ Name = 'Meeting Room London'; Alias = 'room-london'; OrganizationalUnit = 'OU=Resources,OU=Administration'; Capacity = 10 }
        @{ Name = 'Meeting Room Manchester'; Alias = 'room-manchester'; OrganizationalUnit = 'OU=Resources,OU=Administration'; Capacity = 8 }
    )

    # Externe Kontakte, nur reservierte Beispiel-Domains (RFC 2606).
    Contacts            = @(
        @{ Name = 'Northern Lights Print'; Alias = 'northern-lights'; OrganizationalUnit = 'OU=Contacts,OU=Administration'; ExternalEmailAddress = 'orders@northernlights.example.com'; City = 'Manchester'; Phone = '+44 161 496 0320'; Fax = '+44 161 496 0329' }
        @{ Name = 'Harbour Accountants'; Alias = 'harbour-accountants'; OrganizationalUnit = 'OU=Contacts,OU=Administration'; ExternalEmailAddress = 'contact@harbour-accountants.example.org'; City = 'Manchester'; Phone = '+44 161 496 0310'; Fax = '+44 161 496 0319' }
    )
}
