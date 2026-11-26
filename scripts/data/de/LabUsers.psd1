# OU-Struktur, Lab-Benutzer und Beispielempfaenger des Exchange-Labs.
# Pfade sind relativ zur Firmen-OU "LEARN-<trainee>" unterhalb der Domain.
# Reihenfolge der OUs: uebergeordnete OU immer vor untergeordneter OU.
# Benutzerverweise (Manager, Mitglieder, Berechtigungen) nutzen den SamAccountName.
# Aliase: nur Kleinbuchstaben, Ziffern und Bindestriche, hoechstens 20 Zeichen (zugleich SamAccountName).
# Rufnummern: nur fiktive Nummern der Bundesnetzagentur fuer Medienproduktionen (Mitteilung 148/2021),
# Berlin 030 23125-000..999, Hamburg 040 66969-000..999, Mobil 0171 39200-00..99. Fax je Standort -099.
@{
    # AD-Attribute company und c/co/countryCode aller Lab-Benutzer.
    Company             = 'Mustermann Medien GmbH'
    Country             = @{ Code = 'DE'; Name = 'Deutschland'; Number = 276 }

    OrganizationalUnits = @(
        'OU=Branch'
        'OU=Berlin,OU=Branch'
        'OU=Users,OU=Berlin,OU=Branch'
        'OU=Groups,OU=Berlin,OU=Branch'
        'OU=Computers,OU=Berlin,OU=Branch'
        'OU=Hamburg,OU=Branch'
        'OU=Users,OU=Hamburg,OU=Branch'
        'OU=Groups,OU=Hamburg,OU=Branch'
        'OU=Computers,OU=Hamburg,OU=Branch'
        'OU=Administration'
        'OU=Resources,OU=Administration'
        'OU=ServiceAccounts,OU=Administration'
        'OU=Contacts,OU=Administration'
        'OU=DistributionLists,OU=Administration'
        'OU=Groups,OU=Administration'
    )

    # Standortdaten der Lab-Benutzer (Feld Site): OU, Anschrift und Fax je Standort, einmal statt je Benutzer.
    Sites               = @{
        HQ     = @{ OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Berlin'; PostalCode = '10117'; Fax = '+49 30 23125-099' }
        Branch = @{ OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Fax = '+49 40 66969-099' }
    }

    Users               = @(
        @{ SamAccountName = 'MMustermann'; GivenName = 'Max'; Surname = 'Mustermann'; Site = 'HQ'; Office = '10'; Title = 'CEO'; Department = ''; OfficePhone = '+49 30 23125-100'; MobilePhone = '+49 171 3920000' }
        @{ SamAccountName = 'EMustermann'; GivenName = 'Erika'; Surname = 'Mustermann'; Site = 'HQ'; Office = '10'; Title = 'Geschäftsführerin'; Department = 'Marketing'; OfficePhone = '+49 30 23125-500'; MobilePhone = '+49 171 3920001' }
        @{ SamAccountName = 'JDoe'; GivenName = 'John'; Surname = 'Doe'; Site = 'HQ'; Office = '15'; Title = 'Leiter Marketing'; Department = 'Marketing'; OfficePhone = '+49 30 23125-510'; MobilePhone = '+49 171 3920002' }
        @{ SamAccountName = 'KAnders'; GivenName = 'Karl'; Surname = 'Anders'; Site = 'HQ'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 30 23125-511'; MobilePhone = '+49 171 3920003' }
        @{ SamAccountName = 'VSpula'; GivenName = 'Veronika'; Surname = 'Spula'; Site = 'HQ'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 30 23125-512'; MobilePhone = '+49 171 3920004' }
        @{ SamAccountName = 'LMayer'; GivenName = 'Lea'; Surname = 'Mayer'; Site = 'HQ'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 30 23125-513'; MobilePhone = '+49 171 3920005' }
        @{ SamAccountName = 'CHerz'; GivenName = 'Celina'; Surname = 'Herz'; Site = 'Branch'; Office = '10'; Title = 'Leitung - Hamburg'; Department = ''; OfficePhone = '+49 40 66969-100'; MobilePhone = '+49 171 3920006' }
        @{ SamAccountName = 'WErnst'; GivenName = 'Wolfgang'; Surname = 'Ernst'; Site = 'Branch'; Office = '10'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-500'; MobilePhone = '+49 171 3920007' }
        @{ SamAccountName = 'JFrick'; GivenName = 'Johann'; Surname = 'Frick'; Site = 'Branch'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-510'; MobilePhone = '+49 171 3920008' }
        @{ SamAccountName = 'SHarz'; GivenName = 'Sascha'; Surname = 'Harz'; Site = 'Branch'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-511'; MobilePhone = '+49 171 3920009' }
        @{ SamAccountName = 'WLonska'; GivenName = 'Wioletta'; Surname = 'Lonska'; Site = 'Branch'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-512'; MobilePhone = '+49 171 3920010' }
        @{ SamAccountName = 'RJung'; GivenName = 'Robert'; Surname = 'Jung'; Site = 'Branch'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-513'; MobilePhone = '+49 171 3920011' }
        # Microsoft-Demo-Personas (gleiche Namen und Konten wie in M365-Demo-Tenants, z. B. fuer das Mapping bei einer Migration).
        @{ SamAccountName = 'PattiF'; GivenName = 'Patti'; Surname = 'Fernandez'; Site = 'HQ'; Office = '20'; Title = 'Leiterin Vertrieb'; Department = 'Vertrieb'; OfficePhone = '+49 30 23125-400'; MobilePhone = '+49 171 3920012' }
        @{ SamAccountName = 'IsaiahL'; GivenName = 'Isaiah'; Surname = 'Langer'; Site = 'HQ'; Office = '20'; Title = 'Kundenberater'; Department = 'Vertrieb'; OfficePhone = '+49 30 23125-410'; MobilePhone = '+49 171 3920013' }
        @{ SamAccountName = 'LidiaH'; GivenName = 'Lidia'; Surname = 'Holloway'; Site = 'HQ'; Office = '20'; Title = 'Projektmanagerin'; Department = 'Vertrieb'; OfficePhone = '+49 30 23125-411'; MobilePhone = '+49 171 3920014' }
        @{ SamAccountName = 'MiriamG'; GivenName = 'Miriam'; Surname = 'Graham'; Site = 'HQ'; Office = '15'; Title = 'Kreativdirektorin'; Department = 'Marketing'; OfficePhone = '+49 30 23125-520'; MobilePhone = '+49 171 3920015' }
        @{ SamAccountName = 'MeganB'; GivenName = 'Megan'; Surname = 'Bowen'; Site = 'HQ'; Office = '15'; Title = 'Marketingmanagerin'; Department = 'Marketing'; OfficePhone = '+49 30 23125-514'; MobilePhone = '+49 171 3920016' }
        @{ SamAccountName = 'AlexW'; GivenName = 'Alex'; Surname = 'Wilber'; Site = 'HQ'; Office = '15'; Title = 'Marketing-Assistent'; Department = 'Marketing'; OfficePhone = '+49 30 23125-515'; MobilePhone = '+49 171 3920017' }
        @{ SamAccountName = 'HenriettaM'; GivenName = 'Henrietta'; Surname = 'Mueller'; Site = 'HQ'; Office = '15'; Title = 'Webentwicklerin'; Department = 'Marketing'; OfficePhone = '+49 30 23125-516'; MobilePhone = '+49 171 3920018' }
        @{ SamAccountName = 'NestorW'; GivenName = 'Nestor'; Surname = 'Wilke'; Site = 'HQ'; Office = '15'; Title = 'Leiter Produktion'; Department = 'Marketing'; OfficePhone = '+49 30 23125-517'; MobilePhone = '+49 171 3920019' }
        @{ SamAccountName = 'DiegoS'; GivenName = 'Diego'; Surname = 'Siciliani'; Site = 'HQ'; Office = '12'; Title = 'Personalleiter'; Department = 'Personal'; OfficePhone = '+49 30 23125-300'; MobilePhone = '+49 171 3920020' }
        @{ SamAccountName = 'JoniS'; GivenName = 'Joni'; Surname = 'Sherman'; Site = 'HQ'; Office = '10'; Title = 'Assistenz der Geschäftsführung'; Department = 'Personal'; OfficePhone = '+49 30 23125-110'; MobilePhone = '+49 171 3920021' }
        @{ SamAccountName = 'PradeepG'; GivenName = 'Pradeep'; Surname = 'Gupta'; Site = 'HQ'; Office = '12'; Title = 'Buchhalter'; Department = 'Buchhaltung'; OfficePhone = '+49 30 23125-310'; MobilePhone = '+49 171 3920022' }
        @{ SamAccountName = 'AdeleV'; GivenName = 'Adele'; Surname = 'Vance'; Site = 'Branch'; Office = '20'; Title = 'Kundenberaterin'; Department = 'Vertrieb'; OfficePhone = '+49 40 66969-410'; MobilePhone = '+49 171 3920023' }
        @{ SamAccountName = 'LeeG'; GivenName = 'Lee'; Surname = 'Gu'; Site = 'Branch'; Office = '15'; Title = 'Leiter Digital'; Department = 'Marketing'; OfficePhone = '+49 40 66969-520'; MobilePhone = '+49 171 3920024' }
        @{ SamAccountName = 'GradyA'; GivenName = 'Grady'; Surname = 'Archie'; Site = 'Branch'; Office = '15'; Title = 'Grafiker'; Department = 'Marketing'; OfficePhone = '+49 40 66969-514'; MobilePhone = '+49 171 3920025' }
        @{ SamAccountName = 'LynneR'; GivenName = 'Lynne'; Surname = 'Robbins'; Site = 'Branch'; Office = '15'; Title = 'Mediaplanerin'; Department = 'Marketing'; OfficePhone = '+49 40 66969-515'; MobilePhone = '+49 171 3920026' }
        @{ SamAccountName = 'JohannaL'; GivenName = 'Johanna'; Surname = 'Lorenz'; Site = 'Branch'; Office = '15'; Title = 'Texterin'; Department = 'Marketing'; OfficePhone = '+49 40 66969-516'; MobilePhone = '+49 171 3920027' }
    )

    # Ziel-OU fuer den optionalen Windows-11-Client (tritt zunaechst in den Standardcontainer bei).
    ClientOrganizationalUnit = 'OU=Computers,OU=Berlin,OU=Branch'

    # Vorgesetzte (Benutzer = Manager), sichtbar im Adressbuch und im Organigramm von OWA.
    Managers            = @{
        EMustermann = 'MMustermann'
        JDoe        = 'EMustermann'
        KAnders     = 'JDoe'
        VSpula      = 'JDoe'
        LMayer      = 'JDoe'
        CHerz       = 'MMustermann'
        WErnst      = 'CHerz'
        JFrick      = 'CHerz'
        SHarz       = 'CHerz'
        WLonska     = 'CHerz'
        RJung       = 'CHerz'
        PattiF      = 'MMustermann'
        IsaiahL     = 'PattiF'
        LidiaH      = 'PattiF'
        AdeleV      = 'PattiF'
        MiriamG     = 'EMustermann'
        MeganB      = 'JDoe'
        AlexW       = 'MeganB'
        HenriettaM  = 'MiriamG'
        NestorW     = 'MiriamG'
        LeeG        = 'CHerz'
        GradyA      = 'CHerz'
        LynneR      = 'CHerz'
        JohannaL    = 'CHerz'
        DiegoS      = 'EMustermann'
        JoniS       = 'MMustermann'
        PradeepG    = 'MMustermann'
    }

    DistributionGroups  = @(
        @{ Name = 'Geschäftsleitung'; Alias = 'geschaeftsleitung'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('MMustermann', 'EMustermann', 'CHerz') }
        @{ Name = 'Marketing Berlin'; Alias = 'marketing-berlin'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('EMustermann', 'JDoe', 'KAnders', 'VSpula', 'LMayer', 'MiriamG', 'MeganB', 'AlexW', 'HenriettaM', 'NestorW') }
        @{ Name = 'Marketing Hamburg'; Alias = 'marketing-hamburg'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('WErnst', 'JFrick', 'SHarz', 'WLonska', 'RJung', 'LeeG', 'GradyA', 'LynneR', 'JohannaL') }
        @{ Name = 'Vertrieb'; Alias = 'vertrieb'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('PattiF', 'IsaiahL', 'LidiaH', 'AdeleV') }
        @{ Name = 'Alle Mitarbeiter'; Alias = 'alle'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('MMustermann', 'EMustermann', 'JDoe', 'KAnders', 'VSpula', 'LMayer', 'CHerz', 'WErnst', 'JFrick', 'SHarz', 'WLonska', 'RJung', 'PattiF', 'IsaiahL', 'LidiaH', 'MiriamG', 'MeganB', 'AlexW', 'HenriettaM', 'NestorW', 'DiegoS', 'JoniS', 'PradeepG', 'AdeleV', 'LeeG', 'GradyA', 'LynneR', 'JohannaL') }
    )

    SharedMailboxes     = @(
        @{ Name = 'Info'; Alias = 'info'; OrganizationalUnit = 'OU=Resources,OU=Administration'; FullAccess = @('EMustermann', 'CHerz', 'JoniS'); SendAs = @('EMustermann', 'JoniS') }
        @{ Name = 'Buchhaltung'; Alias = 'buchhaltung'; OrganizationalUnit = 'OU=Resources,OU=Administration'; FullAccess = @('MMustermann', 'PradeepG'); SendAs = @('MMustermann', 'PradeepG') }
    )

    RoomMailboxes       = @(
        @{ Name = 'Konferenzraum Berlin'; Alias = 'raum-berlin'; OrganizationalUnit = 'OU=Resources,OU=Administration'; Capacity = 10 }
        @{ Name = 'Konferenzraum Hamburg'; Alias = 'raum-hamburg'; OrganizationalUnit = 'OU=Resources,OU=Administration'; Capacity = 8 }
    )

    # Externe Kontakte, nur reservierte Beispiel-Domains (RFC 2606).
    Contacts            = @(
        @{ Name = 'Nordlicht Druckerei'; Alias = 'nordlicht-druckerei'; OrganizationalUnit = 'OU=Contacts,OU=Administration'; ExternalEmailAddress = 'auftrag@nordlicht.example.com'; City = 'Hamburg'; Phone = '+49 40 66969-320'; Fax = '+49 40 66969-329' }
        @{ Name = 'Steuerkanzlei Hanse'; Alias = 'kanzlei-hanse'; OrganizationalUnit = 'OU=Contacts,OU=Administration'; ExternalEmailAddress = 'kontakt@kanzlei-hanse.example.org'; City = 'Hamburg'; Phone = '+49 40 66969-310'; Fax = '+49 40 66969-319' }
    )
}
