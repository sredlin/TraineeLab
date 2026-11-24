# OU-Struktur, Lab-Benutzer und Beispielempfaenger des Exchange-Labs.
# Pfade sind relativ zur Firmen-OU "LEARN-<trainee>" unterhalb der Domain.
# Reihenfolge der OUs: uebergeordnete OU immer vor untergeordneter OU.
# Benutzerverweise (Manager, Mitglieder, Berechtigungen) nutzen den SamAccountName.
# Aliase: nur Kleinbuchstaben, Ziffern und Bindestriche, hoechstens 20 Zeichen (zugleich SamAccountName).
# Rufnummern: nur fiktive Nummern der Bundesnetzagentur fuer Medienproduktionen (Mitteilung 148/2021),
# Berlin 030 23125-000..999, Hamburg 040 66969-000..999, Mobil 0171 39200-00..99.
@{
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

    Users               = @(
        @{ SamAccountName = 'MMustermann'; GivenName = 'Max'; Surname = 'Mustermann'; OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Berlin'; PostalCode = '10117'; Office = '10'; Title = 'CEO'; Department = ''; OfficePhone = '+49 30 23125-100'; MobilePhone = '+49 171 3920000' }
        @{ SamAccountName = 'EMustermann'; GivenName = 'Erika'; Surname = 'Mustermann'; OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Berlin'; PostalCode = '10117'; Office = '10'; Title = 'Geschäftsführerin'; Department = 'Marketing'; OfficePhone = '+49 30 23125-500'; MobilePhone = '+49 171 3920001' }
        @{ SamAccountName = 'JDoe'; GivenName = 'John'; Surname = 'Doe'; OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Berlin'; PostalCode = '10117'; Office = '15'; Title = 'Leiter Marketing'; Department = 'Marketing'; OfficePhone = '+49 30 23125-510'; MobilePhone = '+49 171 3920002' }
        @{ SamAccountName = 'KAnders'; GivenName = 'Karl'; Surname = 'Anders'; OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Berlin'; PostalCode = '10117'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 30 23125-511'; MobilePhone = '+49 171 3920003' }
        @{ SamAccountName = 'VSpula'; GivenName = 'Veronika'; Surname = 'Spula'; OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Berlin'; PostalCode = '10117'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 30 23125-512'; MobilePhone = '+49 171 3920004' }
        @{ SamAccountName = 'LMayer'; GivenName = 'Lea'; Surname = 'Mayer'; OrganizationalUnit = 'OU=Users,OU=Berlin,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Berlin'; PostalCode = '10117'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 30 23125-513'; MobilePhone = '+49 171 3920005' }
        @{ SamAccountName = 'CHerz'; GivenName = 'Celina'; Surname = 'Herz'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '10'; Title = 'Leitung - Hamburg'; Department = ''; OfficePhone = '+49 40 66969-100'; MobilePhone = '+49 171 3920006' }
        @{ SamAccountName = 'WErnst'; GivenName = 'Wolfgang'; Surname = 'Ernst'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '10'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-500'; MobilePhone = '+49 171 3920007' }
        @{ SamAccountName = 'JFrick'; GivenName = 'Johann'; Surname = 'Frick'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-510'; MobilePhone = '+49 171 3920008' }
        @{ SamAccountName = 'SHarz'; GivenName = 'Sascha'; Surname = 'Harz'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-511'; MobilePhone = '+49 171 3920009' }
        @{ SamAccountName = 'WLonska'; GivenName = 'Wioletta'; Surname = 'Lonska'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-512'; MobilePhone = '+49 171 3920010' }
        @{ SamAccountName = 'RJung'; GivenName = 'Robert'; Surname = 'Jung'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '+49 40 66969-513'; MobilePhone = '+49 171 3920011' }
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
    }

    DistributionGroups  = @(
        @{ Name = 'Geschäftsleitung'; Alias = 'geschaeftsleitung'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('MMustermann', 'EMustermann', 'CHerz') }
        @{ Name = 'Marketing Berlin'; Alias = 'marketing-berlin'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('EMustermann', 'JDoe', 'KAnders', 'VSpula', 'LMayer') }
        @{ Name = 'Marketing Hamburg'; Alias = 'marketing-hamburg'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('WErnst', 'JFrick', 'SHarz', 'WLonska', 'RJung') }
        @{ Name = 'Alle Mitarbeiter'; Alias = 'alle'; OrganizationalUnit = 'OU=DistributionLists,OU=Administration'; Members = @('MMustermann', 'EMustermann', 'JDoe', 'KAnders', 'VSpula', 'LMayer', 'CHerz', 'WErnst', 'JFrick', 'SHarz', 'WLonska', 'RJung') }
    )

    SharedMailboxes     = @(
        @{ Name = 'Info'; Alias = 'info'; OrganizationalUnit = 'OU=Resources,OU=Administration'; FullAccess = @('EMustermann', 'CHerz'); SendAs = @('EMustermann') }
        @{ Name = 'Buchhaltung'; Alias = 'buchhaltung'; OrganizationalUnit = 'OU=Resources,OU=Administration'; FullAccess = @('MMustermann'); SendAs = @('MMustermann') }
    )

    RoomMailboxes       = @(
        @{ Name = 'Konferenzraum Berlin'; Alias = 'raum-berlin'; OrganizationalUnit = 'OU=Resources,OU=Administration'; Capacity = 10 }
        @{ Name = 'Konferenzraum Hamburg'; Alias = 'raum-hamburg'; OrganizationalUnit = 'OU=Resources,OU=Administration'; Capacity = 8 }
    )

    # Externe Kontakte, nur reservierte Beispiel-Domains (RFC 2606).
    Contacts            = @(
        @{ Name = 'Nordlicht Druckerei'; Alias = 'nordlicht-druckerei'; OrganizationalUnit = 'OU=Contacts,OU=Administration'; ExternalEmailAddress = 'auftrag@nordlicht.example.com' }
        @{ Name = 'Steuerkanzlei Hanse'; Alias = 'kanzlei-hanse'; OrganizationalUnit = 'OU=Contacts,OU=Administration'; ExternalEmailAddress = 'kontakt@kanzlei-hanse.example.org' }
    )
}
