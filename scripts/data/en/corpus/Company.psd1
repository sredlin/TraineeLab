# Drehbuch der fiktiven Contoso Ltd, englische Variante (siehe README.md).
# Jahresangaben sind relativ zum Stichtag der Erzeugung (YearsAgo). Alle Daten sind fiktiv:
# Domains nur *.example.com/org/net, Rufnummern nur aus den Ofcom-Bereichen fuer TV- und Radio-Produktionen.
@{
    Company       = @{
        Name     = 'Contoso Ltd'
        Short    = 'Contoso'
        Claim    = 'Communication and design agency'
        ClaimOld = 'Advertising that gets through.'
        Web      = 'www.contoso.example.com'
        Domain   = 'contoso.example.com'
        Bank     = 'Thames Bank London'
        Register = 'Registered in England and Wales, Company No. 00000000'
        VatId    = 'VAT Reg. No. GB 000 0000 00'
        Managers = 'Directors: Fred Bloggs, Jane Bloggs'
        Support  = '+44 20 7946 0777'
        # Logo der neuen CI: Wortmarke in zwei Zeilen.
        Wordmark = @('Contoso', 'Agency')
        # Key: HQ = Zentrale, Branch = Niederlassung. Code = Kuerzel in Geraetenamen, Dial = Durchwahl ({0} = Nebenstelle).
        Sites    = @(
            @{ Key = 'HQ'; Code = 'LON'; Name = 'London'; Street = '1 Market Way'; OldStreet = '8 Chestnut Avenue'; PostalCode = 'EC2A 1AA'; City = 'London'; Phone = '+44 20 7946 0000'; Fax = '+44 20 7946 0099'; Dial = '+44 20 7946 0{0:D3}'; OpenedYearsAgo = 12; Lead = 'FBloggs' }
            @{ Key = 'Branch'; Code = 'MAN'; Name = 'Manchester'; Street = '1 Mill Lane'; PostalCode = 'M1 1AA'; City = 'Manchester'; Phone = '+44 161 496 0000'; Fax = '+44 161 496 0099'; Dial = '+44 161 496 0{0:D3}'; OpenedYearsAgo = 7; Lead = 'CWhitfield' }
        )
    }

    # Sprache und Land (Bedeutung der Schluessel siehe deutsches Drehbuch). Dr in Salutations: "Dr Karin Vogt" -> "Dear Dr Vogt".
    Locale        = @{
        Culture = 'en-GB'; Country = 'GB'; Date = 'dd/MM/yyyy'; ReceiptDate = 'dd/MM/yyyy  HH:mm'; Money = '£{0}'; ListSeparator = ','; PdfZone = '+00''00'''
        StreetLine = '{1} {0}'; CityLine = '{1} {0}'
        XlsxDate = 'dd/mm/yyyy'; XlsxMoney = '[$£-809]#,##0.00'
        Vat = 0.2; Mileage = 0.45; Distance = 'miles'; Allowance = 25; Tax = 0.2; Social = 0.08
        Salutations = @{ Ms = 'Dear Ms'; Mr = 'Dear Mr'; Dr = 'Dear' }
        Mobiles = @(@{ Format = '+44 7700 900{0:D3}'; Min = 100; Span = 900 })
        PostalCodes = @{ London = @('E{0} 7AB', 1, 18); Manchester = @('M{0} 4CD', 1, 40); Croydon = @('CR{0} 2EF', 0, 9) }; PostalCode = 'AB1 2CD'
        TaxClasses = @('1257L', '1257L', 'BR', '1257L', 'K475', 'D0')
        # Musterperson: erhaelt dieses Geburtsdatum (Musternummern erzeugt der Generator je Country).
        Specimen = @{ Name = 'Jane Bloggs'; Birth = '1974-08-12' }
    }

    # Freigabepfade relativ zu Root aus FileServer.psd1 (Test). Im Archiv heisst ein Bereich wie der letzte Pfadteil.
    Paths         = @{
        Management = 'Departments\Management'; Marketing = 'Departments\Marketing'; Accounting = 'Departments\Accounts'; HR = 'Departments\HR'
        Sales = 'Departments\Sales'; IT = 'Departments\IT'; General = 'Departments\General'; Projects = 'Projects'; Home = 'Home'; Scans = 'Scans'; Archive = 'Archive'
    }

    # Wer welche Aufgabe im Drehbuch hat (SamAccountName aus Employees). Liste = Nachfolge.
    Roles         = @{ Ceo = 'FBloggs'; ManagingDirector = 'JBloggs'; Accountant = @('DHarris', 'PradeepG'); Office = @('NClarke', 'JoniS'); Designer = 'ECollins'; PrivateFiles = 'WHughes'; Intern = 'ITern' }

    # Anzeigenamen der IDs; Industries erscheinen mitten im Satz ({Branche}), daher klein.
    Departments   = @{ Management = 'Management'; Marketing = 'Marketing'; Accounting = 'Accounts'; HR = 'HR'; Sales = 'Sales'; IT = 'IT' }
    Industries    = @{ Retail = 'retail'; Hospitality = 'hospitality'; Hotel = 'hotels'; Crafts = 'skilled trades'; Health = 'healthcare'; Education = 'education'; Leisure = 'leisure'; RealEstate = 'real estate'; Energy = 'energy'; IT = 'IT'; Club = 'clubs and charities'; Culture = 'arts and culture' }

    # Regulaere Ausdruecke auf Vornamen, Kontakte, Projektnamen und Texte. Seasons: erster Treffer bestimmt den Startmonat.
    Patterns      = @{
        Female = '^(Jane|Emily|Sophie|Charlotte|Zofia|Rachel|Natalie|Sarah|Amy|Aisha|Patti|Lidia|Miriam|Megan|Henrietta|Joni|Adele|Lynne|Johanna|Amelia|Chloe|Freya|Grace|Hannah|Isla|Lucy|Olivia|Priya|Ruby|Ella|Mia)$'
        AcademicTitle = '^(Dr|Prof)\.?$'; Report = 'campaign|promotion|mailing|social|start of season|new year'; Thanks = 'Thank'; Invitation = 'Invitation'
        Agreements = @{ Move = 'Lease'; Scanner = 'Leasing'; FrameworkContract = 'Framework' }
        Seasons = @(
            @{ Match = 'Christmas'; Month = 9; Spread = 2 }
            @{ Match = 'spring|start of season'; Month = 1; Spread = 2 }
            @{ Match = 'summer|open day|beer festival'; Month = 4; Spread = 2 }
            @{ Match = 'new year'; Month = 11 }
            @{ Match = 'season brochure|programme'; Month = 5; Spread = 2 }
        )
    }

    # Namen in Office-Dateien wie in der englischen Oberflaeche.
    Office        = @{
        Picture = 'Picture'; Sheet = 'Sheet'; Title = 'Title'; Subtitle = 'Subtitle'; Content = 'Content'; Text = 'Text'; Image = 'Image'
        TitlePlaceholder = 'Title Placeholder'; TextPlaceholder = 'Text Placeholder'; SlideImage = 'Slide Image Placeholder'; Notes = 'Notes Placeholder'
        MasterTitle = 'Click to edit Master title style'; MasterText = 'Click to edit Master text styles'; Levels = @('Second level', 'Third level', 'Fourth level', 'Fifth level')
        AccentBar = 'Accent Bar'; AccentLine = 'Accent Line'; TitleArea = 'Title Area'; TitleBar = 'Title Bar'; Band = 'Band'
        Footer = 'Footer'; FooterCompany = 'Footer Company'; Marking = 'Classification'; Sender = 'Sender'
        Layouts = @{ Title = 'Title Slide'; Content = 'Title and Content'; ImageRight = 'Content with Caption'; ImageFull = 'Picture full page'; Section = 'Section Header'; Closing = 'Closing' }
    }

    # Corporate Identity vor und nach dem Rebranding (wie im deutschen Drehbuch).
    Ci            = @{
        RebrandYearsAgo = 4
        New             = @{ Primary = @(0, 84, 97); Accent = @(232, 119, 34); Light = @(242, 242, 242); Dark = @(51, 51, 51); Font = 'Arial'; TitleFont = 'Segoe UI'; Mark = 'Signet' }
        Old             = @{ Primary = @(128, 30, 40); Accent = @(166, 140, 110); Light = @(246, 241, 234); Dark = @(40, 40, 40); Font = 'Times New Roman'; TitleFont = 'Georgia'; Mark = 'Wordmark' }
    }

    # Firmenereignisse (Event-IDs wie im deutschen Drehbuch; Hamburg = Eroeffnung der Niederlassung).
    Timeline      = @(
        @{ Event = 'Founding'; YearsAgo = 12; Month = 3 }
        @{ Event = 'Homeoffice'; YearsAgo = 6; Month = 3 }
        @{ Event = 'Hamburg'; YearsAgo = 7; Month = 9 }
        @{ Event = 'Move'; YearsAgo = 5; Month = 6 }
        @{ Event = 'Rebranding'; YearsAgo = 4; Month = 2 }
        @{ Event = 'Scanner'; YearsAgo = 3; Month = 11 }
        @{ Event = 'CustomerLost'; YearsAgo = 3; Month = 5; Customer = 'Anytown Energy' }
        @{ Event = 'Anniversary'; YearsAgo = 2; Month = 3 }
        @{ Event = 'FrameworkContract'; YearsAgo = 2; Month = 9; Customer = 'Canalside' }
        @{ Event = 'FileServer'; YearsAgo = 1; Month = 10 }
        @{ Event = 'Christmas'; Month = 11 }
        @{ Event = 'Summer'; Month = 6 }
    )

    # Ergaenzt LabUsers.psd1 (gleiche SamAccountName) und nennt ehemalige Mitarbeitende.
    # Entry/Leave = Jahre vor dem Stichtag, Leave 0 = noch da. Salary = Monatsbrutto in Pfund.
    Employees     = @(
        @{ Sam = 'FBloggs'; Role = 'CEO'; Department = 'Management'; Site = 'London'; Entry = 12; Leave = 0; Salary = 6250; Born = 1971; Grade = 1 }
        @{ Sam = 'JBloggs'; Role = 'Managing Director, Marketing'; Department = 'Management'; Site = 'London'; Entry = 12; Leave = 0; Salary = 6100; Born = 1974; Grade = 1 }
        @{ Sam = 'OBennett'; Role = 'Head of Marketing'; Department = 'Marketing'; Site = 'London'; Entry = 12; Leave = 0; Salary = 4300; Born = 1983; Grade = 1 }
        @{ Sam = 'HCarter'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'London'; Entry = 10; Leave = 0; Salary = 3100; Born = 1986; Grade = 2 }
        @{ Sam = 'ECollins'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'London'; Entry = 8; Leave = 0; Salary = 3050; Born = 1990; Grade = 1 }
        @{ Sam = 'SPatel'; Role = 'Junior Designer'; Department = 'Marketing'; Site = 'London'; Entry = 2; Leave = 0; Salary = 2300; Born = 2001; Grade = 2 }
        @{ Sam = 'CWhitfield'; Role = 'Head of Manchester Office'; Department = 'Management'; Site = 'Manchester'; Entry = 7; Leave = 0; Salary = 4700; Born = 1979; Grade = 1 }
        @{ Sam = 'GTurner'; Role = 'Senior Designer'; Department = 'Marketing'; Site = 'Manchester'; Entry = 7; Leave = 0; Salary = 3700; Born = 1966; Grade = 2 }
        @{ Sam = 'WHughes'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'Manchester'; Entry = 6; Leave = 0; Salary = 3100; Born = 1988; Grade = 2 }
        @{ Sam = 'TWright'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'Manchester'; Entry = 5; Leave = 0; Salary = 2950; Born = 1992; Grade = 2 }
        @{ Sam = 'ZNowak'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'Manchester'; Entry = 3; Leave = 0; Salary = 2900; Born = 1994; Grade = 1 }
        @{ Sam = 'DPrice'; Role = 'Junior Designer'; Department = 'Marketing'; Site = 'Manchester'; Entry = 1; Leave = 0; Salary = 2250; Born = 2002; Grade = 3 }
        # Microsoft-Demo-Personas (Namen aus LabUsers.psd1). Female, wo der Vorname die Erkennung taeuscht.
        @{ Sam = 'PattiF'; Role = 'Head of Sales'; Department = 'Sales'; Site = 'London'; Entry = 9; Leave = 0; Salary = 4500; Born = 1978; Grade = 1; Female = $true }
        @{ Sam = 'IsaiahL'; Role = 'Account Manager'; Department = 'Sales'; Site = 'London'; Entry = 5; Leave = 0; Salary = 3300; Born = 1989; Grade = 2 }
        @{ Sam = 'LidiaH'; Role = 'Project Manager'; Department = 'Sales'; Site = 'London'; Entry = 6; Leave = 0; Salary = 3450; Born = 1986; Grade = 1 }
        @{ Sam = 'MiriamG'; Role = 'Creative Director'; Department = 'Marketing'; Site = 'London'; Entry = 8; Leave = 0; Salary = 4900; Born = 1980; Grade = 1; Female = $true }
        @{ Sam = 'MeganB'; Role = 'Marketing Manager'; Department = 'Marketing'; Site = 'London'; Entry = 7; Leave = 0; Salary = 3600; Born = 1987; Grade = 1; Female = $true }
        @{ Sam = 'AlexW'; Role = 'Marketing Assistant'; Department = 'Marketing'; Site = 'London'; Entry = 2; Leave = 0; Salary = 2400; Born = 1998; Grade = 2 }
        @{ Sam = 'HenriettaM'; Role = 'Web Developer'; Department = 'Marketing'; Site = 'London'; Entry = 3; Leave = 0; Salary = 3500; Born = 1991; Grade = 1 }
        @{ Sam = 'NestorW'; Role = 'Head of Production'; Department = 'Marketing'; Site = 'London'; Entry = 6; Leave = 0; Salary = 3900; Born = 1976; Grade = 2 }
        @{ Sam = 'DiegoS'; Role = 'HR Manager'; Department = 'HR'; Site = 'London'; Entry = 4; Leave = 0; Salary = 4150; Born = 1979; Grade = 1 }
        @{ Sam = 'JoniS'; Role = 'Executive Assistant'; Department = 'HR'; Site = 'London'; Entry = 2; Leave = 0; Salary = 2650; Born = 1995; Grade = 2; Female = $true }
        @{ Sam = 'PradeepG'; Role = 'Accountant'; Department = 'Accounting'; Site = 'London'; Entry = 3; Leave = 0; Salary = 3100; Born = 1984; Grade = 1 }
        @{ Sam = 'AdeleV'; Role = 'Account Manager'; Department = 'Sales'; Site = 'Manchester'; Entry = 4; Leave = 0; Salary = 3200; Born = 1990; Grade = 1 }
        @{ Sam = 'LeeG'; Role = 'Head of Digital'; Department = 'Marketing'; Site = 'Manchester'; Entry = 5; Leave = 0; Salary = 4000; Born = 1983; Grade = 1; Female = $false }
        @{ Sam = 'GradyA'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'Manchester'; Entry = 4; Leave = 0; Salary = 3050; Born = 1992; Grade = 2 }
        @{ Sam = 'LynneR'; Role = 'Media Planner'; Department = 'Marketing'; Site = 'Manchester'; Entry = 3; Leave = 0; Salary = 2950; Born = 1993; Grade = 2 }
        @{ Sam = 'JohannaL'; Role = 'Copywriter'; Department = 'Marketing'; Site = 'Manchester'; Entry = 2; Leave = 0; Salary = 2800; Born = 1996; Grade = 1 }
        @{ Sam = 'DHarris'; GivenName = 'David'; Surname = 'Harris'; Role = 'Bookkeeper (part-time)'; Department = 'Accounting'; Site = 'London'; Entry = 12; Leave = 3; Salary = 1900; Born = 1962; Grade = 1 }
        @{ Sam = 'RTaylor'; GivenName = 'Rachel'; Surname = 'Taylor'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'London'; Entry = 11; Leave = 4; Salary = 2800; Born = 1985; Grade = 1 }
        @{ Sam = 'NClarke'; GivenName = 'Natalie'; Surname = 'Clarke'; Role = 'Office Manager'; Department = 'HR'; Site = 'London'; Entry = 10; Leave = 1; Salary = 2500; Born = 1980; Grade = 2 }
        @{ Sam = 'MEvans'; GivenName = 'Mark'; Surname = 'Evans'; Role = 'Copywriter'; Department = 'Marketing'; Site = 'London'; Entry = 9; Leave = 6; Salary = 2700; Born = 1982; Grade = 2 }
        @{ Sam = 'SMurphy'; GivenName = 'Sarah'; Surname = 'Murphy'; Role = 'Project Manager'; Department = 'Sales'; Site = 'London'; Entry = 8; Leave = 2; Salary = 3350; Born = 1987; Grade = 1 }
        @{ Sam = 'LWalker'; GivenName = 'Liam'; Surname = 'Walker'; Role = 'Apprentice Designer'; Department = 'Marketing'; Site = 'London'; Entry = 6; Leave = 3; Salary = 900; Born = 2001; Grade = 2 }
        @{ Sam = 'JMorris'; GivenName = 'James'; Surname = 'Morris'; Role = 'Graphic Designer'; Department = 'Marketing'; Site = 'Manchester'; Entry = 7; Leave = 5; Salary = 2900; Born = 1984; Grade = 3 }
        @{ Sam = 'AKing'; GivenName = 'Amy'; Surname = 'King'; Role = 'Office Assistant, Manchester'; Department = 'HR'; Site = 'Manchester'; Entry = 6; Leave = 2; Salary = 2300; Born = 1978; Grade = 2 }
        @{ Sam = 'AKhan'; GivenName = 'Aisha'; Surname = 'Khan'; Role = 'Placement Student, Social Media'; Department = 'Marketing'; Site = 'Manchester'; Entry = 4; Leave = 3; Salary = 900; Born = 1999; Grade = 1 }
        @{ Sam = 'ITern'; GivenName = 'Ian'; Surname = 'Tern'; Role = 'Marketing Intern'; Department = 'Marketing'; Site = 'London'; Entry = 1; Leave = 0.5; Salary = 500; Born = 2004; Grade = 2 }
    )

    # Kunden: Since/Until = Jahre vor dem Stichtag (Until 0 = aktiv), Owner = Betreuung (SamAccountName),
    # Colors = zwei Hausfarben (RRGGBB), Yearly = wiederkehrendes Projekt, Projects = typische Projekte.
    Customers     = @(
        @{ Name = 'Crumb & Crust Bakery Ltd'; Short = 'Crumb and Crust'; Industry = 'Hospitality'; City = 'London'; Contact = 'Mr Tobias Lenz'; Domain = 'crumb-crust.example.com'; Product = 'sourdough bread'; Since = 12; Until = 0; Owner = 'JBloggs'; Colors = '7A3E1D F2C14E'; Yearly = 'Christmas mailing'; Projects = @('Grand opening', 'Summer promotion') }
        @{ Name = 'Wharfside Cycle Works Ltd'; Short = 'Wharfside'; Industry = 'Retail'; City = 'London'; Contact = 'Ms Annika Boehm'; Domain = 'wharfside-cycles.example.com'; Product = 'cargo bikes'; Since = 11; Until = 0; Owner = 'OBennett'; Colors = '1F4E79 F2A900'; Yearly = 'Spring campaign'; Projects = @('Product catalogue', 'Trade fair stand', 'Website relaunch') }
        @{ Name = 'Anytown Energy Ltd'; Short = 'Anytown Energy'; Industry = 'Energy'; City = 'Anytown'; Contact = 'Dr Karin Vogt'; Domain = 'anytown-energy.example.org'; Product = 'green electricity tariffs'; Since = 10; Until = 3; Owner = 'FBloggs'; Colors = '00796B FFD54F'; Yearly = 'Customer magazine'; Projects = @('Tariff campaign', 'Corporate brochure', 'Annual report') }
        @{ Name = 'White Dental Care'; Short = 'White Dental'; Industry = 'Health'; City = 'London'; Contact = 'Dr Lena White'; Domain = 'white-dental.example.com'; Product = 'preventive dental care'; Since = 10; Until = 6; Owner = 'HCarter'; Colors = '4FC3F7 FFFFFF'; Projects = @('Practice leaflet', 'Website relaunch') }
        @{ Name = 'Corner Coffee Roasters Ltd'; Short = 'Corner Coffee'; Industry = 'Hospitality'; City = 'London'; Contact = 'Ms Mira Yilmaz'; Domain = 'cornercoffee.example.com'; Product = 'espresso roasts'; Since = 9; Until = 0; Owner = 'ECollins'; Colors = '3E2723 FF8A65'; Yearly = 'Christmas mailing'; Projects = @('Packaging design', 'Social media campaign') }
        @{ Name = 'Woodworm Furniture Ltd'; Short = 'Woodworm'; Industry = 'Retail'; City = 'Anytown'; Contact = 'Mr Keith Brand'; Domain = 'woodworm-furniture.example.com'; Product = 'solid wood furniture'; Since = 9; Until = 4; Owner = 'OBennett'; Colors = '5D4037 A5D6A7'; Projects = @('Showroom brochure', 'Anniversary campaign') }
        @{ Name = 'Sunshine Day Nursery CIC'; Short = 'Sunshine Nursery'; Industry = 'Education'; City = 'London'; Contact = 'Ms Sally Hart'; Domain = 'sunshine-nursery.example.org'; Product = 'nursery places'; Since = 8; Until = 0; Owner = 'SPatel'; Colors = 'FFB300 43A047'; Projects = @('Recruitment campaign', 'Brochure for parents', 'Summer fete') }
        @{ Name = 'Greenery Landscapes Ltd'; Short = 'Greenery'; Industry = 'Crafts'; City = 'London'; Contact = 'Mr Marco Fisher'; Domain = 'greenery-landscapes.example.net'; Product = 'green roofs'; Since = 8; Until = 0; Owner = 'HCarter'; Colors = '2E7D32 C5E1A5'; Projects = @('Recruitment campaign', 'Vehicle livery', 'Corporate brochure') }
        @{ Name = 'Orbital Motors Ltd'; Short = 'Orbital Motors'; Industry = 'Retail'; City = 'London'; Contact = 'Mr Steven Cook'; Domain = 'orbital-motors.example.com'; Product = 'electric cars'; Since = 7; Until = 0; Owner = 'OBennett'; Colors = '263238 00BCD4'; Yearly = 'Spring campaign'; Projects = @('Test drive promotion', 'Ad series') }
        @{ Name = 'Thames Gold Brewery Ltd'; Short = 'Thames Gold'; Industry = 'Hospitality'; City = 'London'; Contact = 'Mr Luke Bowman'; Domain = 'thamesgold.example.com'; Product = 'craft beer'; Since = 7; Until = 0; Owner = 'HCarter'; Colors = 'B71C1C FFE082'; Yearly = 'Summer promotion'; Projects = @('Label design', 'Beer festival') }
        @{ Name = 'The Seagull Hotel Ltd'; Short = 'Seagull Hotel'; Industry = 'Hotel'; City = 'Manchester'; Contact = 'Ms Joanna Peters'; Domain = 'seagull-hotel.example.com'; Product = 'spa weekends'; Since = 7; Until = 0; Owner = 'CWhitfield'; Colors = '0D47A1 E3F2FD'; Yearly = 'Summer promotion'; Projects = @('Website relaunch', 'Corporate brochure') }
        @{ Name = 'Warehouse Tea Merchants Ltd'; Short = 'Warehouse Tea'; Industry = 'Retail'; City = 'Manchester'; Contact = 'Ms Hannah Cooper'; Domain = 'warehouse-tea.example.com'; Product = 'loose-leaf tea blends'; Since = 7; Until = 0; Owner = 'GTurner'; Colors = '33691E D7CCC8'; Yearly = 'Christmas mailing'; Projects = @('Packaging design', 'Product catalogue') }
        @{ Name = 'Westwind Sailing Club'; Short = 'Westwind'; Industry = 'Club'; City = 'Manchester'; Contact = 'Mr Owen Harding'; Domain = 'westwind-sailing.example.org'; Product = 'sailing courses'; Since = 6; Until = 0; Owner = 'TWright'; Colors = '01579B FFFFFF'; Yearly = 'Start of season'; Projects = @('Membership drive', 'Club magazine') }
        @{ Name = 'TechNova Systems Ltd'; Short = 'TechNova'; Industry = 'IT'; City = 'Manchester'; Contact = 'Mr Dennis Wolfe'; Domain = 'technova.example.net'; Product = 'IT support contracts'; Since = 6; Until = 0; Owner = 'WHughes'; Colors = '311B92 64FFDA'; Projects = @('Trade fair stand', 'Website relaunch', 'Recruitment campaign') }
        @{ Name = 'ClearView Opticians'; Short = 'ClearView'; Industry = 'Health'; City = 'Manchester'; Contact = 'Ms Nina Scholes'; Domain = 'clearview-opticians.example.com'; Product = 'varifocal glasses'; Since = 6; Until = 2; Owner = 'ZNowak'; Colors = '006064 FFAB91'; Projects = @('Ad series', 'Grand opening') }
        @{ Name = 'Tempo Music School'; Short = 'Tempo'; Industry = 'Culture'; City = 'London'; Contact = 'Mr Paul Newbury'; Domain = 'tempo-music.example.org'; Product = 'instrument lessons'; Since = 6; Until = 0; Owner = 'SPatel'; Colors = '4A148C FFCA28'; Yearly = 'Concert posters'; Projects = @('Website relaunch') }
        @{ Name = 'Sunny Slope Vineyard'; Short = 'Sunny Slope'; Industry = 'Hospitality'; City = 'Exampleton'; Contact = 'Ms Maria Rowe'; Domain = 'sunnyslope-vineyard.example.net'; Product = 'English sparkling wine'; Since = 5; Until = 0; Owner = 'GTurner'; Colors = '880E4F F8BBD0'; Yearly = 'Christmas mailing'; Projects = @('Label design', 'Vineyard open day') }
        @{ Name = 'Canalside Estates Ltd'; Short = 'Canalside'; Industry = 'RealEstate'; City = 'Manchester'; Contact = 'Ms Julia Moore'; Domain = 'canalside-estates.example.com'; Product = 'new-build flats'; Since = 5; Until = 0; Owner = 'CWhitfield'; Colors = '37474F B0BEC5'; Projects = @('Property particulars', 'Site hoarding', 'Website relaunch') }
        @{ Name = 'Powerhouse Gym'; Short = 'Powerhouse'; Industry = 'Leisure'; City = 'London'; Contact = 'Mr Tim Scriven'; Domain = 'powerhouse-gym.example.com'; Product = 'gym memberships'; Since = 5; Until = 1; Owner = 'ECollins'; Colors = '212121 FF3D00'; Yearly = 'New Year promotion'; Projects = @('Social media campaign') }
        @{ Name = 'Sutton Organic Farm'; Short = 'Sutton Farm'; Industry = 'Retail'; City = 'Exampleton'; Contact = 'Mr Jim Sutton'; Domain = 'sutton-farm.example.org'; Product = 'organic veg boxes'; Since = 4; Until = 0; Owner = 'HCarter'; Colors = '558B2F FFF59D'; Projects = @('Farm shop opening', 'Subscription campaign') }
        @{ Name = 'Canal Theatre Trust'; Short = 'Canal Theatre'; Industry = 'Culture'; City = 'London'; Contact = 'Ms Leonie Graves'; Domain = 'canal-theatre.example.org'; Product = 'season tickets'; Since = 4; Until = 0; Owner = 'JBloggs'; Colors = '000000 E53935'; Yearly = 'Season brochure'; Projects = @('Poster series') }
        @{ Name = 'Move Well Physiotherapy'; Short = 'Move Well'; Industry = 'Health'; City = 'Manchester'; Contact = 'Mr Matt Jensen'; Domain = 'movewell-physio.example.com'; Product = 'back pain classes'; Since = 4; Until = 0; Owner = 'DPrice'; Colors = '00897B FFFFFF'; Projects = @('Practice leaflet', 'Website relaunch') }
        @{ Name = 'Oak & Ash Joinery Ltd'; Short = 'Oak and Ash'; Industry = 'Crafts'; City = 'Manchester'; Contact = 'Mr Henry Clayton'; Domain = 'oak-ash-joinery.example.net'; Product = 'bespoke fitted furniture'; Since = 3; Until = 0; Owner = 'WHughes'; Colors = '6D4C41 FFCC80'; Projects = @('Recruitment campaign', 'Vehicle livery') }
        @{ Name = 'Anytown Adult Education Centre'; Short = 'Anytown Adult Learning'; Industry = 'Education'; City = 'Anytown'; Contact = 'Ms Pat Linden'; Domain = 'anytown-adultlearning.example.org'; Product = 'evening and weekend courses'; Since = 3; Until = 0; Owner = 'ECollins'; Yearly = 'Course programme'; Colors = 'C62828 ECEFF1'; Projects = @('Ad series') }
        @{ Name = 'SunWorks North Ltd'; Short = 'SunWorks'; Industry = 'Energy'; City = 'Manchester'; Contact = 'Mr Fabian Olsen'; Domain = 'sunworks-north.example.com'; Product = 'plug-in solar panels'; Since = 3; Until = 0; Owner = 'TWright'; Colors = 'F9A825 263238'; Projects = @('Tariff campaign', 'Trade fair stand', 'Social media campaign') }
        @{ Name = 'Summit Climbing Centre'; Short = 'Summit'; Industry = 'Leisure'; City = 'London'; Contact = 'Ms Jana Wilkes'; Domain = 'summit-climbing.example.com'; Product = 'climbing courses'; Since = 2; Until = 0; Owner = 'SPatel'; Colors = 'FF6F00 37474F'; Projects = @('Grand opening', 'Social media campaign') }
        @{ Name = 'The Galley Harbour Café'; Short = 'The Galley'; Industry = 'Hospitality'; City = 'Manchester'; Contact = 'Mr Okan Demir'; Domain = 'thegalley.example.com'; Product = 'fish finger sandwiches and daily specials'; Since = 2; Until = 0; Owner = 'ZNowak'; Colors = '1A237E FFEB3B'; Projects = @('Menu', 'Delivery service launch') }
        @{ Name = 'CloudWorks Software Ltd'; Short = 'CloudWorks'; Industry = 'IT'; City = 'London'; Contact = 'Ms Sophia Brandon'; Domain = 'cloudworks.example.net'; Product = 'accounting software'; Since = 1; Until = 0; Owner = 'OBennett'; Colors = '1565C0 76FF03'; Projects = @('Website relaunch', 'Recruitment campaign') }
        @{ Name = 'Irwell View Property Management Ltd'; Short = 'Irwell View'; Industry = 'RealEstate'; City = 'Manchester'; Contact = 'Mr Tony Nash'; Domain = 'irwellview-pm.example.com'; Product = 'residential lettings management'; Since = 1; Until = 0; Owner = 'DPrice'; Colors = '455A64 80CBC4'; Projects = @('Corporate brochure') }
    )

    # Posten: Text|Preis von|Preis bis|Einheit|Menge bis (Menge fehlt = 1). Role = TaxAdvisor: Steuerkanzlei.
    Suppliers     = @(
        @{ Name = 'Northern Lights Print Ltd'; City = 'Manchester'; Domain = 'northernlights.example.com'; Items = @('Flyers A5, 4/4 colour, 135 gsm, 5,000 copies|150|350|flat', 'Posters A1, 4/0 colour, 100 copies|200|450|flat', 'Brochure 16 pp A4, perfect bound, 1,000 copies|1150|2300|flat', 'Business cards 85 x 55 mm, 350 gsm, 250 cards|25|39|pc|6', 'Roll-up banner 85 x 200 cm incl. case|75|120|pc|3') }
        @{ Name = 'Harbour Accountants'; Role = 'TaxAdvisor'; City = 'Manchester'; Domain = 'harbour-accountants.example.org'; Items = @('Bookkeeping as agreed|300|500|month', 'Payroll per employee|15|22|pc|14', 'VAT return (Making Tax Digital)|150|280|flat') }
        @{ Name = 'Central Paper Co.'; City = 'London'; Domain = 'centralpaper.example.com'; Items = @('Copier paper A4, 80 gsm, 5 x 500 sheets|16|24|box|6', 'Black toner for multifunction printer|55|110|pc|3', 'Lever arch files, pack of 10|15|26|pack|3', 'Layout pad A3|5|10|pc|8') }
        @{ Name = 'Riverside Stands Ltd'; City = 'Manchester'; Domain = 'riverside-stands.example.com'; Items = @('Exhibition stand 12 sq m, modular system|1900|3800|flat', 'Graphic wall 3 x 2.5 m, printed|550|1000|pc|2', 'Stand build and breakdown|500|950|flat', 'Storage of stand parts|35|70|month') }
        @{ Name = 'Brightside Photography'; City = 'London'; Domain = 'brightside-photo.example.com'; Items = @('Product photo shoot, day rate|750|1100|day|2', 'Retouching per image|20|50|pc|20', 'Usage rights print and online, 2 years|250|700|flat') }
        @{ Name = 'Eastside IT Services Ltd'; City = 'London'; Domain = 'eastside-it.example.net'; Items = @('Server support contract|150|230|month', 'Replacement workstation hard drive|110|210|pc', 'Image editing licence (1 year)|230|580|pc|4', 'Engineer on site|70|90|hr|6') }
        @{ Name = 'Lightning Bike Couriers'; City = 'London'; Domain = 'lightning-couriers.example.com'; Items = @('Courier run within London|10|22|pc|9', 'Express delivery from the printers|28|52|pc|3', 'Monthly courier retainer|95|145|month') }
        @{ Name = 'Pixel Sea Images'; City = 'Manchester'; Domain = 'pixelsea.example.com'; Items = @('Standard image licence, web|15|39|pc|8', 'Extended licence, print up to 50,000|95|230|pc|3', 'Subscription, 25 images|119|159|month') }
        @{ Name = 'Smith Office Supplies Ltd'; City = 'London'; Domain = 'smith-office.example.com'; Items = @('Lease payment multifunction printer|105|150|month', 'Copier maintenance fee|28|48|month', 'Ergonomic office chair|310|550|pc|2') }
        @{ Name = 'Central Property Management Ltd'; City = 'London'; Domain = 'central-pm.example.com'; Items = @('Office rent|2550|2900|month', 'Service charge on account|430|580|month', 'Underground parking space|70|95|month|2') }
    )

    Services      = @(
        @{ Text = 'Concept and strategy'; Unit = 'hr'; Min = 85; Max = 105 }
        @{ Text = 'Graphic design'; Unit = 'hr'; Min = 75; Max = 90 }
        @{ Text = 'Artwork and print file preparation'; Unit = 'hr'; Min = 60; Max = 70 }
        @{ Text = 'Copywriting and proofreading'; Unit = 'hr'; Min = 70; Max = 80 }
        @{ Text = 'Project management'; Unit = 'hr'; Min = 65; Max = 75 }
        @{ Text = 'Photo shoot incl. retouching'; Unit = 'day'; Min = 750; Max = 1100 }
        @{ Text = 'Social media management'; Unit = 'month'; Min = 700; Max = 1450 }
        @{ Text = 'Website maintenance'; Unit = 'hr'; Min = 75; Max = 85 }
        @{ Text = 'Print management (third-party)'; Unit = 'flat'; Min = 250; Max = 3600 }
        @{ Text = 'Media planning and booking'; Unit = 'flat'; Min = 650; Max = 2000 }
        @{ Text = 'Logo development incl. usage rights'; Unit = 'flat'; Min = 1450; Max = 3600 }
    )

    Audiences     = @('families with children', 'young professionals in the city', 'regular customers over 50', 'students', 'local businesses', 'tourists and day visitors', 'eco-conscious households', 'skilled tradespeople')
    Channels      = @('posters around town', 'Instagram', 'newsletter', 'ads in the local paper', 'radio spot', 'point-of-sale flyers', 'landing page', 'trade fairs and events', 'Facebook', 'cinema advertising')
    FirstNames    = @('Amelia', 'Ben', 'Chloe', 'Ethan', 'Freya', 'Harvey', 'Grace', 'Isaac', 'Hannah', 'Jack', 'Isla', 'Leo', 'Lucy', 'Noah', 'Olivia', 'Oscar', 'Priya', 'Samuel', 'Ruby', 'Yusuf', 'Ella', 'Arjun', 'Mia', 'Finn')
    LastNames     = @('Abbott', 'Baker', 'Chaudhry', 'Dawson', 'Ellis', 'Fletcher', 'Gibson', 'Hall', 'Jenkins', 'Kelly', 'Lloyd', 'Marshall', 'Osei', 'Parker', 'Reid', 'Shaw', 'Thompson', 'Wood', 'Young', 'Ahmed', 'Brooks', 'Murray', 'Webb', 'Doyle')
    Streets       = @('High Street', 'Station Road', 'Market Street', 'Lime Avenue', 'Harbour Way', 'Park Road', 'School Lane', 'Church Street', 'Mill Road', 'Victoria Road', 'Birch Grove', 'Canal Street')
    Hotels        = @('Market Hotel', 'Lakeview Guest House', 'City Centre Hotel', 'The Linden Tree Inn')
    # Kassenbons im Belegordner (aufgeklebt): Laden, Posten mit Preisspanne in Pfund.
    Shops         = @(
        @{ Name = 'Crumb & Crust Bakery'; Items = @('Coffee to go|2.20|3.60', 'Bread rolls|0.40|0.80', 'Cake for the team|12|24') }
        @{ Name = 'Central Paper Co.'; Items = @('C4 envelopes|3.90|7.50', 'Sticky tape|1.00|2.90', 'Printer paper A4|4.90|8.50') }
        @{ Name = 'Example Square Car Park'; Items = @('Parking|3.00|12') }
        @{ Name = 'Bypass Filling Station'; Items = @('Unleaded petrol|30|70', 'Screen wash|3.20|5.80') }
        @{ Name = 'Example Post Office'; Items = @('Stamps|7.00|14', 'Signed-for postage|2.20|4.00') }
        @{ Name = 'Trattoria Example'; Items = @('Client lunch|32|115') }
        @{ Name = 'Central Taxis'; Items = @('Taxi fare|9|30') }
    )
    Banks         = @('Thames Bank London', 'Northern Example Bank', 'Anytown Building Society', 'Exampleton Savings Bank')
    Insurers      = @('Example Workplace Pensions', 'Northgate Mutual Pensions', 'Thameside Pension Trust', 'Sample Life & Pensions')
    Positions     = @('Graphic Designer (Digital and Print)', 'Junior Art Director', 'Placement Student, Social Media', 'Communications Project Manager', 'Apprentice Designer', 'Copywriter', 'Office Manager (part-time)')
    Bookings      = @('Office rent', 'Lease multifunction printer', 'Phone and internet', 'Vehicle insurance', 'Bank charges', 'TV licence', 'Office electricity', 'Salaries')
    BwaRows       = @('Turnover', 'Bought-in services', 'Staff costs', 'Premises costs', 'Marketing and travel', 'IT costs', 'Other overheads', 'Provisional profit')
    DeviceTypes   = @('Workstation', 'Laptop', 'Printer', 'Multifunction printer', 'Firewall', 'Switch', 'Access point', 'Server')
    Software      = @('Office suite', 'Image editing', 'Layout software', 'Antivirus', 'Remote support', 'Font library', 'Video editing')
    Systems       = @('Webmail', 'Office router', 'Agency social media account', 'Pixel Sea Images', 'Print supplier portal', 'Domain management', 'Guest Wi-Fi')
    Months        = @('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
    # Geburtsorte im Personalbogen, Wohnorte im Gewinnspiel, Projektphasen im Zeitplan, Menue im Screendesign,
    # Kreditkartenposten, Woerter alter Kennwoerter, Dateinamen der Notizen im Basisordner.
    BirthPlaces   = @('London', 'Manchester', 'Croydon', 'Leeds', 'Bristol', 'Liverpool', 'Brighton', 'Anytown')
    LocalCities   = @('London', 'Manchester', 'Croydon')
    Phases        = @('Concept', 'Design', 'Review', 'Production')
    WebMenu       = @('Home', 'Services', 'Team', 'News', 'Contact', 'Careers', 'Press', 'FAQ')
    CardBookings  = @('Pixel Sea Images', 'Market Hotel', 'Rail ticket', 'Software subscription', 'Font licence', 'Trade fair admission')
    PasswordWords = @('Summer', 'Agency', 'London', 'Harbour', 'Coffee')
    NoteNames     = @('Notes', 'ToDo', 'Ideas', 'Important', 'Draft', 'Filing')
    Motifs        = @(
        @{ Name = 'Flyer A5'; Format = 'Flyer'; File = 'Flyer'; Shape = 'Portrait' }
        @{ Name = 'Poster A1'; Format = 'Poster'; File = 'Poster'; Shape = 'Portrait' }
        @{ Name = 'Local newspaper ad'; Format = 'Ad'; File = 'Ad'; Shape = 'Portrait' }
        @{ Name = 'Social media post'; Format = 'SocialPost'; File = 'Social-Post'; Shape = 'Square' }
        @{ Name = 'Website banner'; Format = 'Banner'; File = 'Banner'; Shape = 'Landscape' }
        # Projekttypische Lieferungen: nur, wenn Match auf den Projektnamen passt. \blaunch trifft nicht "relaunch".
        @{ Name = 'Brochure A4'; Format = 'Brochure'; File = 'Brochure'; Pages = 12; Layout = 'Brochure'; Match = 'brochure|catalogue|report|magazine|programme|menu|particulars' }
        @{ Name = 'Exhibition wall 3 x 2.5 m'; Format = 'TradeShowWall'; File = 'Exhibition-Wall'; Match = 'trade fair|exhibition' }
        @{ Name = 'Site board 3 x 2 m'; Format = 'SiteSign'; File = 'Site-Board'; Match = 'site sign|site board|hoarding' }
        @{ Name = 'Vehicle livery, side view'; Format = 'Vehicle'; File = 'Vehicle'; Match = 'vehicle' }
        @{ Name = 'Die-cut sheet A2'; Format = 'DieCut'; File = 'Die-Cut'; Match = 'packaging|label' }
        @{ Name = 'Poster series A1'; Format = 'PosterSeries'; File = 'Poster-Series'; Pages = 4; Layout = 'Series'; Match = 'poster series|campaign|opening' }
        @{ Name = 'Ad series'; Format = 'AdSeries'; File = 'Ad-Series'; Pages = 4; Layout = 'Series'; Match = 'ad series|recruitment|tariff' }
        @{ Name = 'Social media series'; Format = 'SocialSeries'; File = 'Social-Series'; Pages = 12; Layout = 'Series'; Match = 'social|promotion|festival|fete|\blaunch|start|anniversary|membership|open day' }
        @{ Name = 'Website screen design'; Format = 'WebDesign'; File = 'Screen-Design'; Pages = 8; Layout = 'Web'; Match = 'website|relaunch|landing page|delivery|subscription' }
    )

    Labels        = @{
        Invoice = 'Invoice'; Offer = 'Quote'; Confirmation = 'Order confirmation'; Reminder = 'Payment reminder'; Dunning = 'Final notice'; Delivery = 'Delivery note'
        Date = 'Date'; Number = 'Number'; CustomerNo = 'Client no.'; Pos = 'Item'; Description = 'Description'; Quantity = 'Qty'; Unit = 'Unit'
        Price = 'Unit price'; Amount = 'Amount'; Net = 'Subtotal'; Vat = '+ 20% VAT'; Total = 'Total due'; Sum = 'Total'; Page = 'Page {0} of {1}'
        Received = 'RECEIVED'; Booked = 'POSTED'; Paid = 'PAID'; Released = 'APPROVED'; Copy = 'Copy of '; Draft = 'Draft'; Variant = 'Option'; Version = 'As at'
        Regards = 'Kind regards'; Salutation = 'Dear Sir or Madam'; Attendees = 'Attendees'; Agenda = 'Agenda'; Minutes = 'Minutes'
        Tasks = 'Actions'; Task = 'Action'; Owner = 'Owner'; Due = 'Due'; Statement = 'Bank statement'; Balance = 'Balance'; Booking = 'Details'
        OldBalance = 'Opening balance'; NewBalance = 'Closing balance'; Salary = 'Payslip'; Gross = 'Gross pay'; NetSalary = 'Net pay'
        Tax = 'Income tax (PAYE)'; Social = 'National Insurance (employee)'; Travel = 'Travel expenses claim'; Purpose = 'Purpose of trip'; Mileage = 'Mileage (45p per mile)'
        Allowance = 'Subsistence'; Hotel = 'Accommodation'; Receipt = 'Receipt'; Contract = 'Contract of employment'; Reference = 'Reference'; Cv = 'CV'
        Application = 'Application for the role of {0}'; Report = 'Campaign report'; Press = 'Press release'; Briefing = 'Briefing'; Concept = 'Concept'; Presentation = 'Presentation'
        Bwa = 'Management accounts'; Kpi = 'Category'; Plan = 'Plan'; Actual = 'Actual'; Month = 'Month'; Cumulative = 'Year to date'; Signature = 'Signature'
        Customer = 'Client'; Contact = 'Contact'; Project = 'Project'; Schedule = 'Schedule'; Budget = 'Budget'; Phase = 'Phase'; Week = 'Wk'; Moodboard = 'Moodboard'
        NextSteps = 'Next steps'; Position = 'Position'; Name = 'Name'; Period = 'Period'; Device = 'Device'; Hostname = 'Network name'; IpAddress = 'IP address'
        Location = 'Location'; Product = 'Product'; Licenses = 'Seats'; ValidUntil = 'Valid until'; Network = 'Network overview'; LicenseList = 'Licence overview'
        ReceivedGoods = 'Goods received complete and undamaged'; VersionOf = 'Version {0} dated {1}'; Employee = 'Employee'; Motifs = 'Visuals'; Thanks = 'Thank you!'
        Questions = 'Questions and answers'; Correction = 'Corrections'; PrintRelease = 'Print approval'; Request = 'Enquiry'; Calculation = 'Costing'; Hours = 'Hours'
        Rate = 'Hourly rate'; MediaPlan = 'Media plan'; Timesheet = 'Timesheet'; Revenue = 'Turnover'; Vacation = 'Holiday planner'; Birthdays = 'Team birthdays'
        PhoneList = 'Phone list'; CustomerList = 'Client list'; Inventory = 'Inventory'; Applicants = 'Applications'; Status = 'Status'; Comment = 'Comment'
        PersonnelSheet = 'Personnel record'; BirthDate = 'Date of birth'; BirthPlace = 'Place of birth'; Address = 'Address'; TaxId = 'Tax ref. (UTR)'; TaxClass = 'Tax code'
        SocialNo = 'NI number'; IdCard = 'Passport no.'; Insurance = 'Pension scheme'; Confession = 'Religion (optional)'; Marital = 'Marital status'; Children = 'Children'
        Iban = 'IBAN'; Bank = 'Bank'; Phone = 'Phone'; Mobile = 'Mobile'; Email = 'Email'; SickNote = 'Fit note'; From = 'From'; To = 'To'
        CreditCard = 'Credit card statement'; CardNumber = 'Card number'; Mandate = 'Direct Debit Instruction'; Raffle = 'Prize draw'; Participants = 'Entrants'
        Credentials = 'Login details'; Password = 'Password'; Username = 'Username'; System = 'System'; Payroll = 'Payroll summary'; Entry = 'Start date'; Leave = 'Leaving date'
        Public = 'Public'; Internal = 'Internal'; Confidential = 'Confidential'; Secret = 'Strictly confidential'; Classification = 'Classification'
        Single = 'single'; Married = 'married'; NoConfession = 'none'; Catholic = 'Roman Catholic'; Protestant = 'Church of England'; Holder = 'Account holder'
        Branding = 'Branding'; Palette = 'Colour palette'; Contactsheet = 'Contact sheet'; Invitation = 'Invitation'; Placeholder = 'Image placeholder'; Motif = 'Visual'
        Background = 'Background'; Goal = 'Objective'; Audience = 'Target audience'; Mandatory = 'Mandatories'; Timing = 'Timing'; Situation = 'Starting point'
        Idea = 'Core idea'; Goals = 'Objectives'; Measures = 'Activities'; Risks = 'Risks and open points'; Feedback = 'Client comments'; Note = 'Note'
        PrintData = 'Print files'; Cancelled = 'cancelled'; Results = 'Results'; Learnings = 'Learnings'; Agenda2 = 'Agenda'; Welcome = 'Welcome'
        Margin = 'Margin'; ExternalCosts = 'Third-party costs'; Overview = 'Overview'; Policy = 'Policy'; Announcement = 'Announcement'; Template = 'Template'
        Industry = 'Sector'; Days = 'Days'; Purchase = 'Purchased'; IdDocument = 'Passport no.'; Interview = 'Interview'; Rejection = 'Rejection'
        Hour = 'hr'; Day = 'day'; Piece = 'pc'; Night = 'night'; Review = 'Appraisal'; Warning = 'Formal written warning'; Doctor = 'Dr {0} & Partners'; OnBehalf = 'p.p. {0}'
        ReadMore = 'Read more >'; WebFooter = 'Terms | Privacy | Cookie settings'; Teaser = 'Teaser headline'; ProofNote = 'colours not binding'
        ReceiptTotal = 'TOTAL GBP'; ReceiptVat = 'VAT 20%'; ReceiptNo = 'Receipt no. {0}'; Copier = 'Copier scan-to-email'; LayoutApp = 'Layout software'; PdfExport = 'PDF export'
        Anniversary = '10 years'; NewLook = 'Our new look'; CiHandbook = 'Corporate-Design-Handbook'; CiTitle = 'Corporate Design'; Letterhead = 'Letterhead'
        # Platzhalter der Vorlagen (Briefbogen, Praesentation, Kalkulation)
        TemplateAddress = @('Company', 'Name', 'Street', 'Town Postcode'); DateMask = 'DD/MM/YYYY'; Subject = 'Subject'; Point = 'Bullet point'
        # Nummernkreise (QU-2024-0001 ...) und Postfaecher in Mailadressen
        OfferId = 'QU-'; OrderId = 'OC-'; InvoiceId = 'INV-'; CustomerId = 'C-'; SupplierRef = 'SR-'; MailContact = 'contact'; MailInvoice = 'accounts'
        # Teile von Dateinamen
        PayslipFile = 'Payslip'; BwaFile = 'MgmtAccounts'; ReviewFile = 'Appraisal'; PressFile = 'PR'; SalaryList = 'Salaries'; CopyFile = 'Copy'; ReplyFile = 'Reply'; OldFile = 'old'; FinalNew = 'final_NEW'
        BrandBackground = 'background'; BrandHeader = 'logo_header'; BrandLight = 'logo_square_light'; BrandDark = 'logo_square_dark'; BrandTaskbar = 'edge_taskbar'; BrandNegative = 'negative'
        BrandOld = 'Old_CI_archive\Logo_old_DO_NOT_USE'; BrandGuide = 'Guide_Entra_Branding'; BrandSignIn = 'Sign-in_Page_Texts'
    }

    # Unterordner unterhalb der Freigaben aus FileServer.psd1. Travel und Applications muessen zu den Altlast-Pfaden passen (Test).
    FolderNames   = @{
        Incoming = 'Purchase Invoices'; Outgoing = 'Sales Invoices'; Reminders = 'Reminders'; Statements = 'Bank Statements'; Delivery = 'Delivery Notes'
        Travel = 'Travel Expenses'; CreditCard = 'Credit Card'; Payroll = 'Payroll'; Mandates = 'Direct Debits'; Offers = 'Quotes'; Orders = 'Orders'
        Customers = 'Clients'; Minutes = 'Minutes'; Press = 'Press Releases'; Reports = 'Reports'; Presentations = 'Presentations'
        Files = 'Personnel Files'; Payslips = 'Payslips'; SickNotes = 'Sick Notes'; Applications = 'Applications'; References = 'References'
        Policies = 'Policies'; Docs = 'Documentation'; Bwa = 'Management Accounts'; Agreements = 'Contracts'; Templates = 'Templates'; Ci = 'Corporate Design'
        Branding = 'Branding'; Announcements = 'Announcements'; Events = 'Events'; Documents = 'Documents'; Private = 'Private'; Backup = 'Backup'
        Former = '_Former Staff'; Onboarding = 'Onboarding'; Kickoff = 'Annual Kick-off'; Receipts = 'Receipts'; Proofs = 'Proofs'; Letters = 'Correspondence'
        ProjectSteps = @('01_Quote', '02_Briefing', '03_Concept', '04_Drafts', '05_Presentation', '06_Invoicing')
    }
}
