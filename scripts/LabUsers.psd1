# OU-Struktur und Lab-Benutzer des Exchange-Labs.
# Pfade sind relativ zur Firmen-OU "LEARN-<trainee>" unterhalb der Domain.
# Reihenfolge der OUs: uebergeordnete OU immer vor untergeordneter OU.
@{
    OrganizationalUnits = @(
        'OU=Branch'
        'OU=Kiel,OU=Branch'
        'OU=Users,OU=Kiel,OU=Branch'
        'OU=Groups,OU=Kiel,OU=Branch'
        'OU=Computers,OU=Kiel,OU=Branch'
        'OU=Hamburg,OU=Branch'
        'OU=Users,OU=Hamburg,OU=Branch'
        'OU=Groups,OU=Hamburg,OU=Branch'
        'OU=Computers,OU=Hamburg,OU=Branch'
        'OU=Administration'
        'OU=ServiceAccounts,OU=Administration'
        'OU=Contacts,OU=Administration'
        'OU=DistributionLists,OU=Administration'
        'OU=Groups,OU=Administration'
    )

    Users               = @(
        @{ SamAccountName = 'MMustermann'; GivenName = 'Max'; Surname = 'Mustermann'; OrganizationalUnit = 'OU=Users,OU=Kiel,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Kiel'; PostalCode = '24145'; Office = '10'; Title = 'CEO'; Department = ''; OfficePhone = '0049 431 555 123 100'; MobilePhone = '0049 160 555 123 100' }
        @{ SamAccountName = 'EMustermann'; GivenName = 'Erika'; Surname = 'Mustermann'; OrganizationalUnit = 'OU=Users,OU=Kiel,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Kiel'; PostalCode = '24145'; Office = '10'; Title = 'Geschäftsführerin'; Department = 'Marketing'; OfficePhone = '0049 431 555 123 500'; MobilePhone = '0049 160 555 123 500' }
        @{ SamAccountName = 'JDoe'; GivenName = 'John'; Surname = 'Doe'; OrganizationalUnit = 'OU=Users,OU=Kiel,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Kiel'; PostalCode = '24145'; Office = '15'; Title = 'Leiter Marketing'; Department = 'Marketing'; OfficePhone = '0049 431 555 123 510'; MobilePhone = '0049 160 555 123 510' }
        @{ SamAccountName = 'KAnders'; GivenName = 'Karl'; Surname = 'Anders'; OrganizationalUnit = 'OU=Users,OU=Kiel,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Kiel'; PostalCode = '24145'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 431 555 123 511'; MobilePhone = '0049 160 555 123 511' }
        @{ SamAccountName = 'VSpula'; GivenName = 'Veronika'; Surname = 'Spula'; OrganizationalUnit = 'OU=Users,OU=Kiel,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Kiel'; PostalCode = '24145'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 431 555 123 512'; MobilePhone = '0049 160 555 123 512' }
        @{ SamAccountName = 'LMayer'; GivenName = 'Lea'; Surname = 'Mayer'; OrganizationalUnit = 'OU=Users,OU=Kiel,OU=Branch'; StreetAddress = 'Weg 1'; City = 'Kiel'; PostalCode = '24145'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 431 555 123 513'; MobilePhone = '0049 160 555 123 513' }
        @{ SamAccountName = 'CHerz'; GivenName = 'Celina'; Surname = 'Herz'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '10'; Title = 'Leitung - Hamburg'; Department = ''; OfficePhone = '0049 040 655 123 100'; MobilePhone = '0049 160 655 123 100' }
        @{ SamAccountName = 'WErnst'; GivenName = 'Wolfgang'; Surname = 'Ernst'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '10'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 040 655 123 500'; MobilePhone = '0049 160 655 123 500' }
        @{ SamAccountName = 'JFrick'; GivenName = 'Johann'; Surname = 'Frick'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 040 655 123 510'; MobilePhone = '0049 160 655 123 510' }
        @{ SamAccountName = 'SHarz'; GivenName = 'Sascha'; Surname = 'Harz'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 040 655 123 511'; MobilePhone = '0049 160 655 123 511' }
        @{ SamAccountName = 'WLonska'; GivenName = 'Wioletta'; Surname = 'Lonska'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 040 655 123 512'; MobilePhone = '0049 160 655 123 512' }
        @{ SamAccountName = 'RJung'; GivenName = 'Robert'; Surname = 'Jung'; OrganizationalUnit = 'OU=Users,OU=Hamburg,OU=Branch'; StreetAddress = 'Ring 1'; City = 'Hamburg'; PostalCode = '20257'; Office = '15'; Title = 'Artist'; Department = 'Marketing'; OfficePhone = '0049 040 655 123 513'; MobilePhone = '0049 160 655 123 513' }
    )
}
