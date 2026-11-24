# Drehbuch der fiktiven Mustermann Medien GmbH (siehe README.md).
# Jahresangaben sind relativ zum Stichtag der Erzeugung (YearsAgo). Alle Daten sind fiktiv:
# Domains nur *.example.com/org/net, Rufnummern nur aus den Bereichen der Bundesnetzagentur fuer Medienproduktionen.
@{
    Company       = @{
        Name     = 'Mustermann Medien GmbH'
        Short    = 'Mustermann Medien'
        Claim    = 'Agentur für Kommunikation und Design'
        ClaimOld = 'Werbung, die ankommt.'
        Web      = 'www.mustermann-medien.example.com'
        Domain   = 'mustermann-medien.example.com'
        Bank     = 'Spreebank Berlin'
        Register = 'Amtsgericht Berlin HRB 00000 B'
        VatId    = 'USt-IdNr. DE000000000'
        Managers = 'Geschäftsführung: Max Mustermann, Erika Mustermann'
        Support  = '+49 30 23125-777'
        Sites    = @(
            @{ Name = 'Berlin'; Street = 'Weg 1'; OldStreet = 'Kastanienallee 8'; PostalCode = '10117'; City = 'Berlin'; Phone = '+49 30 23125-000'; Fax = '+49 30 23125-099'; OpenedYearsAgo = 12; Lead = 'MMustermann' }
            @{ Name = 'Hamburg'; Street = 'Ring 1'; PostalCode = '20257'; City = 'Hamburg'; Phone = '+49 40 66969-000'; Fax = '+49 40 66969-099'; OpenedYearsAgo = 7; Lead = 'CHerz' }
        )
    }

    # Corporate Identity vor und nach dem Rebranding. Farben RGB, Schriften muessen unter Windows vorhanden sein.
    Ci            = @{
        RebrandYearsAgo = 4
        New             = @{ Primary = @(0, 84, 97); Accent = @(232, 119, 34); Light = @(242, 242, 242); Dark = @(51, 51, 51); Font = 'Arial'; TitleFont = 'Segoe UI'; Mark = 'Signet' }
        Old             = @{ Primary = @(128, 30, 40); Accent = @(166, 140, 110); Light = @(246, 241, 234); Dark = @(40, 40, 40); Font = 'Times New Roman'; TitleFont = 'Georgia'; Mark = 'Wortmarke' }
    }

    # Firmenereignisse; Christmas und Summer wiederholen sich jedes Jahr.
    Timeline      = @(
        @{ Event = 'Founding'; YearsAgo = 12; Month = 3 }
        @{ Event = 'Homeoffice'; YearsAgo = 6; Month = 3 }
        @{ Event = 'Hamburg'; YearsAgo = 7; Month = 9 }
        @{ Event = 'Move'; YearsAgo = 5; Month = 6 }
        @{ Event = 'Rebranding'; YearsAgo = 4; Month = 2 }
        @{ Event = 'Scanner'; YearsAgo = 3; Month = 11 }
        @{ Event = 'CustomerLost'; YearsAgo = 3; Month = 5; Customer = 'Stadtwerke' }
        @{ Event = 'Anniversary'; YearsAgo = 2; Month = 3 }
        @{ Event = 'FrameworkContract'; YearsAgo = 2; Month = 9; Customer = 'Alsterblick' }
        @{ Event = 'FileServer'; YearsAgo = 1; Month = 10 }
        @{ Event = 'Christmas'; Month = 11 }
        @{ Event = 'Summer'; Month = 6 }
    )

    # Ergaenzt LabUsers.psd1 (gleiche SamAccountName) und nennt ehemalige Mitarbeitende.
    # Entry/Leave = Jahre vor dem Stichtag, Leave 0 = noch da. Salary = Monatsbrutto in Euro.
    Employees     = @(
        @{ Sam = 'MMustermann'; Role = 'Geschäftsführer'; Department = 'Geschaeftsleitung'; Site = 'Berlin'; Entry = 12; Leave = 0; Salary = 7800; Born = 1971; Grade = 1 }
        @{ Sam = 'EMustermann'; Role = 'Geschäftsführerin Marketing'; Department = 'Geschaeftsleitung'; Site = 'Berlin'; Entry = 12; Leave = 0; Salary = 7600; Born = 1974; Grade = 1 }
        @{ Sam = 'JDoe'; Role = 'Leiter Marketing'; Department = 'Marketing'; Site = 'Berlin'; Entry = 12; Leave = 0; Salary = 5400; Born = 1983; Grade = 1 }
        @{ Sam = 'KAnders'; Role = 'Grafiker'; Department = 'Marketing'; Site = 'Berlin'; Entry = 10; Leave = 0; Salary = 3900; Born = 1986; Grade = 2 }
        @{ Sam = 'VSpula'; Role = 'Grafikerin'; Department = 'Marketing'; Site = 'Berlin'; Entry = 8; Leave = 0; Salary = 3800; Born = 1990; Grade = 1 }
        @{ Sam = 'LMayer'; Role = 'Junior-Grafikerin'; Department = 'Marketing'; Site = 'Berlin'; Entry = 2; Leave = 0; Salary = 2900; Born = 2001; Grade = 2 }
        @{ Sam = 'CHerz'; Role = 'Leitung Hamburg'; Department = 'Geschaeftsleitung'; Site = 'Hamburg'; Entry = 7; Leave = 0; Salary = 5900; Born = 1979; Grade = 1 }
        @{ Sam = 'WErnst'; Role = 'Senior-Grafiker'; Department = 'Marketing'; Site = 'Hamburg'; Entry = 7; Leave = 0; Salary = 4600; Born = 1966; Grade = 2 }
        @{ Sam = 'JFrick'; Role = 'Grafiker'; Department = 'Marketing'; Site = 'Hamburg'; Entry = 6; Leave = 0; Salary = 3900; Born = 1988; Grade = 2 }
        @{ Sam = 'SHarz'; Role = 'Grafiker'; Department = 'Marketing'; Site = 'Hamburg'; Entry = 5; Leave = 0; Salary = 3700; Born = 1992; Grade = 2 }
        @{ Sam = 'WLonska'; Role = 'Grafikerin'; Department = 'Marketing'; Site = 'Hamburg'; Entry = 3; Leave = 0; Salary = 3600; Born = 1994; Grade = 1 }
        @{ Sam = 'RJung'; Role = 'Junior-Grafiker'; Department = 'Marketing'; Site = 'Hamburg'; Entry = 1; Leave = 0; Salary = 2800; Born = 2002; Grade = 3 }
        @{ Sam = 'DHoffmann'; GivenName = 'Dirk'; Surname = 'Hoffmann'; Role = 'Buchhalter (Teilzeit)'; Department = 'Buchhaltung'; Site = 'Berlin'; Entry = 12; Leave = 3; Salary = 2400; Born = 1962; Grade = 1 }
        @{ Sam = 'TSchneider'; GivenName = 'Tanja'; Surname = 'Schneider'; Role = 'Grafikerin'; Department = 'Marketing'; Site = 'Berlin'; Entry = 11; Leave = 4; Salary = 3500; Born = 1985; Grade = 1 }
        @{ Sam = 'NPohl'; GivenName = 'Nadine'; Surname = 'Pohl'; Role = 'Office-Managerin'; Department = 'Personal'; Site = 'Berlin'; Entry = 10; Leave = 1; Salary = 3100; Born = 1980; Grade = 2 }
        @{ Sam = 'MBrenner'; GivenName = 'Markus'; Surname = 'Brenner'; Role = 'Texter'; Department = 'Marketing'; Site = 'Berlin'; Entry = 9; Leave = 6; Salary = 3400; Born = 1982; Grade = 2 }
        @{ Sam = 'SKowalski'; GivenName = 'Svenja'; Surname = 'Kowalski'; Role = 'Projektmanagerin'; Department = 'Vertrieb'; Site = 'Berlin'; Entry = 8; Leave = 2; Salary = 4200; Born = 1987; Grade = 1 }
        @{ Sam = 'LWeber'; GivenName = 'Lukas'; Surname = 'Weber'; Role = 'Auszubildender Mediengestalter'; Department = 'Marketing'; Site = 'Berlin'; Entry = 6; Leave = 3; Salary = 950; Born = 2001; Grade = 2 }
        @{ Sam = 'JPetersen'; GivenName = 'Jan'; Surname = 'Petersen'; Role = 'Grafiker'; Department = 'Marketing'; Site = 'Hamburg'; Entry = 7; Leave = 5; Salary = 3600; Born = 1984; Grade = 3 }
        @{ Sam = 'AKraemer'; GivenName = 'Anja'; Surname = 'Krämer'; Role = 'Assistenz Niederlassung'; Department = 'Personal'; Site = 'Hamburg'; Entry = 6; Leave = 2; Salary = 2900; Born = 1978; Grade = 2 }
        @{ Sam = 'MAydin'; GivenName = 'Merve'; Surname = 'Aydin'; Role = 'Werkstudentin Social Media'; Department = 'Marketing'; Site = 'Hamburg'; Entry = 4; Leave = 3; Salary = 1100; Born = 1999; Grade = 1 }
        @{ Sam = 'PPraktikant'; GivenName = 'Paul'; Surname = 'Praktikant'; Role = 'Praktikant Marketing'; Department = 'Marketing'; Site = 'Berlin'; Entry = 1; Leave = 0.5; Salary = 600; Born = 2004; Grade = 2 }
    )

    # Kunden: Since/Until = Jahre vor dem Stichtag (Until 0 = aktiv), Owner = Betreuung (SamAccountName),
    # Colors = zwei Hausfarben (RRGGBB), Yearly = wiederkehrendes Projekt, Projects = typische Projekte.
    Customers     = @(
        @{ Name = 'Bäckerei Krume & Kruste KG'; Short = 'Krume und Kruste'; Industry = 'Gastronomie'; City = 'Berlin'; Contact = 'Herr Tobias Lenz'; Domain = 'krume-kruste.example.com'; Product = 'Brot aus Natursauerteig'; Since = 12; Until = 0; Owner = 'EMustermann'; Colors = '7A3E1D F2C14E'; Yearly = 'Weihnachtsmailing'; Projects = @('Neueröffnung', 'Sommeraktion') }
        @{ Name = 'Spreeufer Fahrradmanufaktur GmbH'; Short = 'Spreeufer'; Industry = 'Handel'; City = 'Berlin'; Contact = 'Frau Annika Böhm'; Domain = 'spreeufer-rad.example.com'; Product = 'Lastenräder'; Since = 11; Until = 0; Owner = 'JDoe'; Colors = '1F4E79 F2A900'; Yearly = 'Frühjahrskampagne'; Projects = @('Produktkatalog', 'Messeauftritt', 'Website-Relaunch') }
        @{ Name = 'Stadtwerke Musterstadt GmbH'; Short = 'Stadtwerke'; Industry = 'Energie'; City = 'Musterstadt'; Contact = 'Frau Dr. Karin Vogt'; Domain = 'stadtwerke-musterstadt.example.org'; Product = 'Ökostromtarife'; Since = 10; Until = 3; Owner = 'MMustermann'; Colors = '00796B FFD54F'; Yearly = 'Kundenmagazin'; Projects = @('Tarifkampagne', 'Imagebroschüre', 'Jahresbericht') }
        @{ Name = 'Zahnarztpraxis Dr. Weiß'; Short = 'Praxis Weiß'; Industry = 'Gesundheit'; City = 'Berlin'; Contact = 'Frau Dr. Lena Weiß'; Domain = 'praxis-weiss.example.com'; Product = 'Prophylaxe und Zahnreinigung'; Since = 10; Until = 6; Owner = 'KAnders'; Colors = '4FC3F7 FFFFFF'; Projects = @('Praxisflyer', 'Website-Relaunch') }
        @{ Name = 'Kiezkaffee Rösterei GmbH'; Short = 'Kiezkaffee'; Industry = 'Gastronomie'; City = 'Berlin'; Contact = 'Frau Mira Yilmaz'; Domain = 'kiezkaffee.example.com'; Product = 'Espresso-Röstungen'; Since = 9; Until = 0; Owner = 'VSpula'; Colors = '3E2723 FF8A65'; Yearly = 'Weihnachtsmailing'; Projects = @('Verpackungsdesign', 'Social-Media-Kampagne') }
        @{ Name = 'Möbelhaus Holzwurm OHG'; Short = 'Holzwurm'; Industry = 'Handel'; City = 'Musterstadt'; Contact = 'Herr Klaus Brandt'; Domain = 'holzwurm-moebel.example.com'; Product = 'Massivholzmöbel'; Since = 9; Until = 4; Owner = 'JDoe'; Colors = '5D4037 A5D6A7'; Projects = @('Prospekt', 'Jubiläumskampagne') }
        @{ Name = 'Kita Sonnenschein gGmbH'; Short = 'Kita Sonnenschein'; Industry = 'Bildung'; City = 'Berlin'; Contact = 'Frau Sabine Hartmann'; Domain = 'kita-sonnenschein.example.org'; Product = 'Betreuungsplätze'; Since = 8; Until = 0; Owner = 'LMayer'; Colors = 'FFB300 43A047'; Projects = @('Recruiting-Kampagne', 'Elternbroschüre', 'Sommerfest') }
        @{ Name = 'Grünzeug Gartenbau GmbH'; Short = 'Grünzeug'; Industry = 'Handwerk'; City = 'Berlin'; Contact = 'Herr Marco Fischer'; Domain = 'gruenzeug.example.net'; Product = 'Dachbegrünung'; Since = 8; Until = 0; Owner = 'KAnders'; Colors = '2E7D32 C5E1A5'; Projects = @('Recruiting-Kampagne', 'Fahrzeugbeschriftung', 'Imagebroschüre') }
        @{ Name = 'Autohaus Ringbahn GmbH'; Short = 'Autohaus Ringbahn'; Industry = 'Handel'; City = 'Berlin'; Contact = 'Herr Stefan Kuhn'; Domain = 'autohaus-ringbahn.example.com'; Product = 'Elektroautos'; Since = 7; Until = 0; Owner = 'JDoe'; Colors = '263238 00BCD4'; Yearly = 'Frühjahrskampagne'; Projects = @('Probefahrt-Aktion', 'Anzeigenserie') }
        @{ Name = 'Brauhaus Spreegold GmbH'; Short = 'Spreegold'; Industry = 'Gastronomie'; City = 'Berlin'; Contact = 'Herr Lukas Bauer'; Domain = 'spreegold.example.com'; Product = 'Craft-Bier'; Since = 7; Until = 0; Owner = 'KAnders'; Colors = 'B71C1C FFE082'; Yearly = 'Sommeraktion'; Projects = @('Etikettendesign', 'Bierfest') }
        @{ Name = 'Hotel Elbstrand Möwe GmbH'; Short = 'Hotel Möwe'; Industry = 'Hotellerie'; City = 'Hamburg'; Contact = 'Frau Svenja Petersen'; Domain = 'hotel-moewe.example.com'; Product = 'Wellness-Wochenenden'; Since = 7; Until = 0; Owner = 'CHerz'; Colors = '0D47A1 E3F2FD'; Yearly = 'Sommeraktion'; Projects = @('Website-Relaunch', 'Imagebroschüre') }
        @{ Name = 'Speicherstadt Teehandel GmbH'; Short = 'Teehandel'; Industry = 'Handel'; City = 'Hamburg'; Contact = 'Frau Hannah Krüger'; Domain = 'speicher-tee.example.com'; Product = 'Teemischungen'; Since = 7; Until = 0; Owner = 'WErnst'; Colors = '33691E D7CCC8'; Yearly = 'Weihnachtsmailing'; Projects = @('Verpackungsdesign', 'Produktkatalog') }
        @{ Name = 'Segelschule Westwind e. V.'; Short = 'Westwind'; Industry = 'Verein'; City = 'Hamburg'; Contact = 'Herr Ole Hansen'; Domain = 'segelschule-westwind.example.org'; Product = 'Segelkurse'; Since = 6; Until = 0; Owner = 'SHarz'; Colors = '01579B FFFFFF'; Yearly = 'Saisonstart'; Projects = @('Mitgliederwerbung', 'Vereinsheft') }
        @{ Name = 'TechNova Systemhaus GmbH'; Short = 'TechNova'; Industry = 'IT'; City = 'Hamburg'; Contact = 'Herr Dennis Wolf'; Domain = 'technova.example.net'; Product = 'IT-Wartungsverträge'; Since = 6; Until = 0; Owner = 'JFrick'; Colors = '311B92 64FFDA'; Projects = @('Messeauftritt', 'Website-Relaunch', 'Recruiting-Kampagne') }
        @{ Name = 'Optik Klarsicht e. K.'; Short = 'Klarsicht'; Industry = 'Gesundheit'; City = 'Hamburg'; Contact = 'Frau Nina Schulz'; Domain = 'optik-klarsicht.example.com'; Product = 'Gleitsichtbrillen'; Since = 6; Until = 2; Owner = 'WLonska'; Colors = '006064 FFAB91'; Projects = @('Anzeigenserie', 'Neueröffnung') }
        @{ Name = 'Musikschule Taktvoll'; Short = 'Taktvoll'; Industry = 'Kultur'; City = 'Berlin'; Contact = 'Herr Paul Neumann'; Domain = 'taktvoll.example.org'; Product = 'Instrumentalunterricht'; Since = 6; Until = 0; Owner = 'LMayer'; Colors = '4A148C FFCA28'; Yearly = 'Konzertplakate'; Projects = @('Website-Relaunch') }
        @{ Name = 'Weingut Sonnenhang'; Short = 'Sonnenhang'; Industry = 'Gastronomie'; City = 'Musterhausen'; Contact = 'Frau Maria Roth'; Domain = 'weingut-sonnenhang.example.net'; Product = 'Riesling'; Since = 5; Until = 0; Owner = 'WErnst'; Colors = '880E4F F8BBD0'; Yearly = 'Weihnachtsmailing'; Projects = @('Etikettendesign', 'Hoffest') }
        @{ Name = 'Alsterblick Immobilien GmbH'; Short = 'Alsterblick'; Industry = 'Immobilien'; City = 'Hamburg'; Contact = 'Frau Julia Meyer'; Domain = 'alsterblick-immo.example.com'; Product = 'Neubauwohnungen'; Since = 5; Until = 0; Owner = 'CHerz'; Colors = '37474F B0BEC5'; Projects = @('Exposé-Serie', 'Bauschild', 'Website-Relaunch') }
        @{ Name = 'Fitnessstudio Kraftwerk'; Short = 'Kraftwerk'; Industry = 'Freizeit'; City = 'Berlin'; Contact = 'Herr Timo Schreiber'; Domain = 'kraftwerk-fitness.example.com'; Product = 'Mitgliedschaften'; Since = 5; Until = 1; Owner = 'VSpula'; Colors = '212121 FF3D00'; Yearly = 'Neujahrsaktion'; Projects = @('Social-Media-Kampagne') }
        @{ Name = 'Biohof Schulte'; Short = 'Biohof Schulte'; Industry = 'Handel'; City = 'Musterhausen'; Contact = 'Herr Jens Schulte'; Domain = 'biohof-schulte.example.org'; Product = 'Gemüsekisten'; Since = 4; Until = 0; Owner = 'KAnders'; Colors = '558B2F FFF59D'; Projects = @('Hofladen-Eröffnung', 'Abo-Kampagne') }
        @{ Name = 'Theater am Kanal e. V.'; Short = 'Theater am Kanal'; Industry = 'Kultur'; City = 'Berlin'; Contact = 'Frau Leonie Graf'; Domain = 'theater-kanal.example.org'; Product = 'Spielzeit und Abonnements'; Since = 4; Until = 0; Owner = 'EMustermann'; Colors = '000000 E53935'; Yearly = 'Spielzeitheft'; Projects = @('Plakatserie') }
        @{ Name = 'Physiotherapie Bewegt'; Short = 'Physio Bewegt'; Industry = 'Gesundheit'; City = 'Hamburg'; Contact = 'Herr Malte Jensen'; Domain = 'physio-bewegt.example.com'; Product = 'Rückenkurse'; Since = 4; Until = 0; Owner = 'RJung'; Colors = '00897B FFFFFF'; Projects = @('Praxisflyer', 'Website-Relaunch') }
        @{ Name = 'Tischlerei Hobelspan GmbH'; Short = 'Hobelspan'; Industry = 'Handwerk'; City = 'Hamburg'; Contact = 'Herr Henning Claasen'; Domain = 'hobelspan.example.net'; Product = 'Einbaumöbel nach Maß'; Since = 3; Until = 0; Owner = 'JFrick'; Colors = '6D4C41 FFCC80'; Projects = @('Recruiting-Kampagne', 'Fahrzeugbeschriftung') }
        @{ Name = 'Volkshochschule Musterstadt'; Short = 'VHS Musterstadt'; Industry = 'Bildung'; City = 'Musterstadt'; Contact = 'Frau Petra Lindner'; Domain = 'vhs-musterstadt.example.org'; Product = 'Kursprogramm'; Since = 3; Until = 0; Owner = 'VSpula'; Yearly = 'Programmheft'; Colors = 'C62828 ECEFF1'; Projects = @('Anzeigenserie') }
        @{ Name = 'Solarwerk Nord GmbH'; Short = 'Solarwerk'; Industry = 'Energie'; City = 'Hamburg'; Contact = 'Herr Fabian Ohlsen'; Domain = 'solarwerk-nord.example.com'; Product = 'Balkonkraftwerke'; Since = 3; Until = 0; Owner = 'SHarz'; Colors = 'F9A825 263238'; Projects = @('Tarifkampagne', 'Messeauftritt', 'Social-Media-Kampagne') }
        @{ Name = 'Kletterhalle Gipfelstürmer'; Short = 'Gipfelstürmer'; Industry = 'Freizeit'; City = 'Berlin'; Contact = 'Frau Jana Wilke'; Domain = 'gipfelstuermer.example.com'; Product = 'Kletterkurse'; Since = 2; Until = 0; Owner = 'LMayer'; Colors = 'FF6F00 37474F'; Projects = @('Neueröffnung', 'Social-Media-Kampagne') }
        @{ Name = 'Hafenbistro Kombüse'; Short = 'Kombüse'; Industry = 'Gastronomie'; City = 'Hamburg'; Contact = 'Herr Okan Demir'; Domain = 'kombuese.example.com'; Product = 'Fischbrötchen und Mittagstisch'; Since = 2; Until = 0; Owner = 'WLonska'; Colors = '1A237E FFEB3B'; Projects = @('Speisekarte', 'Lieferdienst-Start') }
        @{ Name = 'CloudWerk Software GmbH'; Short = 'CloudWerk'; Industry = 'IT'; City = 'Berlin'; Contact = 'Frau Sophie Brandl'; Domain = 'cloudwerk.example.net'; Product = 'Buchhaltungssoftware'; Since = 1; Until = 0; Owner = 'JDoe'; Colors = '1565C0 76FF03'; Projects = @('Website-Relaunch', 'Recruiting-Kampagne') }
        @{ Name = 'Hausverwaltung Elbblick GmbH'; Short = 'Elbblick'; Industry = 'Immobilien'; City = 'Hamburg'; Contact = 'Herr Torben Rasch'; Domain = 'elbblick-hv.example.com'; Product = 'Mietverwaltung'; Since = 1; Until = 0; Owner = 'RJung'; Colors = '455A64 80CBC4'; Projects = @('Imagebroschüre') }
    )

    # Posten: Text|Preis von|Preis bis|Einheit|Menge bis (Menge fehlt = 1)
    Suppliers     = @(
        @{ Name = 'Nordlicht Druckerei GmbH'; City = 'Hamburg'; Domain = 'nordlicht.example.com'; Items = @('Druck Flyer DIN A5, 4/4-farbig, 135 g/m², 5.000 Stück|180|420|pauschal', 'Druck Plakate DIN A1, 4/0-farbig, 100 Stück|240|560|pauschal', 'Broschüre 16 Seiten DIN A4, Klebebindung, 1.000 Stück|1450|2900|pauschal', 'Visitenkarten 85 x 55 mm, 350 g/m², 250 Stück|29|49|Stk.|6', 'Roll-up 85 x 200 cm inkl. Kassette|89|149|Stk.|3') }
        @{ Name = 'Steuerkanzlei Hanse'; City = 'Hamburg'; Domain = 'kanzlei-hanse.example.org'; Items = @('Finanzbuchhaltung laut Vereinbarung|380|620|Monat', 'Lohnabrechnung je Mitarbeiter|19|28|Stk.|14', 'Umsatzsteuer-Voranmeldung|65|120|Monat') }
        @{ Name = 'Papierhaus Mitte KG'; City = 'Berlin'; Domain = 'papierhaus-mitte.example.com'; Items = @('Kopierpapier A4, 80 g/m², 5 x 500 Blatt|19|29|Karton|6', 'Toner schwarz für Multifunktionsgerät|69|139|Stk.|3', 'Ordner breit, 10 Stück|18|32|Pack|3', 'Layoutblock A3|6|12|Stk.|8') }
        @{ Name = 'Messebau Elbufer GmbH'; City = 'Hamburg'; Domain = 'messebau-elbufer.example.com'; Items = @('Messestand 12 m², Systembau|2400|4800|pauschal', 'Grafikwand 3 x 2,5 m, bedruckt|680|1250|Stk.|2', 'Auf- und Abbau Messestand|650|1200|pauschal', 'Lagerung Standelemente|45|90|Monat') }
        @{ Name = 'Fotostudio Lichtblick'; City = 'Berlin'; Domain = 'lichtblick-foto.example.com'; Items = @('Fotoshooting Produkt, Tagessatz|950|1400|Tag|2', 'Bildbearbeitung je Motiv|25|60|Stk.|20', 'Nutzungsrechte Print und Online, 2 Jahre|300|900|pauschal') }
        @{ Name = 'IT-Service Nordost GmbH'; City = 'Berlin'; Domain = 'it-nordost.example.net'; Items = @('Wartungsvertrag Server|180|290|Monat', 'Austausch Festplatte Arbeitsplatz|140|260|Stk.', 'Lizenz Bildbearbeitung (Jahr)|290|720|Stk.|4', 'Vor-Ort-Einsatz Techniker|85|110|Std.|6') }
        @{ Name = 'Kurierdienst Blitzrad'; City = 'Berlin'; Domain = 'blitzrad.example.com'; Items = @('Kurierfahrt innerhalb Berlin|12|28|Stk.|9', 'Expresszustellung Druckerei|35|65|Stk.|3', 'Monatspauschale Botendienst|120|180|Monat') }
        @{ Name = 'Bildagentur Pixelmeer'; City = 'Hamburg'; Domain = 'pixelmeer.example.com'; Items = @('Bildlizenz Standard, Web|19|49|Stk.|8', 'Bildlizenz erweitert, Print bis 50.000|120|290|Stk.|3', 'Abo 25 Bilder|149|199|Monat') }
        @{ Name = 'Bürowelt Schmidt GmbH'; City = 'Berlin'; Domain = 'buerowelt-schmidt.example.com'; Items = @('Leasingrate Multifunktionsgerät|129|189|Monat', 'Wartungspauschale Kopierer|35|60|Monat', 'Bürostuhl ergonomisch|390|690|Stk.|2') }
        @{ Name = 'Hausverwaltung Mitte GmbH'; City = 'Berlin'; Domain = 'hv-mitte.example.com'; Items = @('Miete Büroräume|3200|3600|Monat', 'Nebenkostenvorauszahlung|540|720|Monat', 'Stellplatz Tiefgarage|90|120|Monat|2') }
    )

    Services      = @(
        @{ Text = 'Konzeption und Strategie'; Unit = 'Std.'; Min = 95; Max = 120 }
        @{ Text = 'Grafikdesign'; Unit = 'Std.'; Min = 85; Max = 110 }
        @{ Text = 'Reinzeichnung und Druckdatenerstellung'; Unit = 'Std.'; Min = 70; Max = 85 }
        @{ Text = 'Text und Lektorat'; Unit = 'Std.'; Min = 80; Max = 95 }
        @{ Text = 'Projektmanagement'; Unit = 'Std.'; Min = 75; Max = 90 }
        @{ Text = 'Fotoshooting inkl. Bildbearbeitung'; Unit = 'Tag'; Min = 950; Max = 1400 }
        @{ Text = 'Betreuung Social-Media-Kanäle'; Unit = 'Monat'; Min = 900; Max = 1800 }
        @{ Text = 'Pflege Website'; Unit = 'Std.'; Min = 85; Max = 100 }
        @{ Text = 'Druckabwicklung (Fremdleistung)'; Unit = 'pauschal'; Min = 300; Max = 4500 }
        @{ Text = 'Mediaplanung und Schaltung'; Unit = 'pauschal'; Min = 800; Max = 2500 }
        @{ Text = 'Logo-Entwicklung inkl. Nutzungsrechte'; Unit = 'pauschal'; Min = 1800; Max = 4500 }
    )

    Audiences     = @('Familien mit Kindern', 'junge Berufstätige in der Stadt', 'Stammkunden über 50', 'Studierende', 'Unternehmen aus der Region', 'Touristen und Tagesgäste', 'umweltbewusste Haushalte', 'Fachkräfte aus dem Handwerk')
    Channels      = @('Plakate im Stadtgebiet', 'Instagram', 'Newsletter', 'Anzeigen in der Lokalzeitung', 'Radiospot', 'Flyer am Point of Sale', 'Landingpage', 'Messe und Events', 'Facebook', 'Kinowerbung')
    FirstNames    = @('Anna', 'Ben', 'Clara', 'David', 'Elif', 'Felix', 'Greta', 'Hannes', 'Ida', 'Jonas', 'Katharina', 'Leon', 'Marie', 'Niklas', 'Olivia', 'Philipp', 'Rosa', 'Samuel', 'Tara', 'Yusuf', 'Emil', 'Frieda', 'Mats', 'Nele')
    LastNames     = @('Albrecht', 'Becker', 'Demir', 'Engel', 'Franke', 'Graf', 'Haas', 'Jansen', 'Keller', 'Lorenz', 'Martens', 'Nowak', 'Otto', 'Peters', 'Ritter', 'Sommer', 'Thiel', 'Vogel', 'Winter', 'Ziegler', 'Brandt', 'Kühn', 'Möller', 'Wolff')
    Streets       = @('Hauptstraße', 'Bahnhofstraße', 'Am Markt', 'Lindenallee', 'Hafenweg', 'Gartenstraße', 'Schulstraße', 'Kirchplatz', 'Mühlenweg', 'Industriestraße', 'Birkenweg', 'Am Kanal')
    Hotels        = @('Hotel am Markt', 'Pension Seeblick', 'Hotel Stadtmitte', 'Gasthof Zur Linde')
    # Kassenbons im Belegordner (aufgeklebt): Laden, Posten mit Preisspanne in Euro.
    Shops         = @(
        @{ Name = 'Bäckerei Krume & Kruste'; Items = @('Kaffee to go|2.40|3.90', 'Brötchen gemischt|0.45|0.90', 'Kuchen für das Team|14|28') }
        @{ Name = 'Papierhaus Mitte KG'; Items = @('Briefumschläge C4|4.90|8.90', 'Klebeband|1.20|3.50', 'Druckerpapier A4|5.90|9.90') }
        @{ Name = 'Parkhaus Musterplatz'; Items = @('Parken|3.50|14') }
        @{ Name = 'Tankstelle am Ring'; Items = @('Super E10|35|80', 'Scheibenwischwasser|3.90|6.90') }
        @{ Name = 'Deutsche Muster-Post'; Items = @('Briefmarken|8.50|17', 'Einschreiben|2.65|4.80') }
        @{ Name = 'Osteria Beispiel'; Items = @('Bewirtung Kundentermin|38|140') }
        @{ Name = 'Taxi-Zentrale Mitte'; Items = @('Taxifahrt|11|36') }
    )
    Banks         = @('Spreebank Berlin', 'Hanseatische Musterbank', 'Volksbank Beispielstadt', 'Sparkasse Musterhausen')
    Insurers      = @('Musterkasse Gesund', 'BKK Beispiel', 'Hansekasse', 'Gesundkasse Nordost')
    Positions     = @('Mediengestalter/in Digital und Print', 'Junior Art Director (m/w/d)', 'Werkstudent/in Social Media', 'Projektmanager/in Kommunikation', 'Auszubildende/r Mediengestalter/in', 'Texter/in (m/w/d)', 'Office-Manager/in (Teilzeit)')
    Bookings      = @('Miete Büroräume', 'Leasingrate Multifunktionsgerät', 'Telefon und Internet', 'Kfz-Versicherung', 'Kontoführungsgebühren', 'Rundfunkbeitrag', 'Strom Büro', 'Gehälter')
    BwaRows       = @('Umsatzerlöse', 'Fremdleistungen', 'Personalkosten', 'Raumkosten', 'Werbe- und Reisekosten', 'EDV-Kosten', 'Sonstige Kosten', 'Vorläufiges Ergebnis')
    DeviceTypes   = @('Arbeitsplatz', 'Notebook', 'Drucker', 'Multifunktionsgerät', 'Firewall', 'Switch', 'Access Point', 'Server')
    Software      = @('Office-Paket', 'Bildbearbeitung', 'Layoutprogramm', 'Virenschutz', 'Fernwartung', 'Schriftenpaket', 'Videoschnitt')
    Systems       = @('Webmail', 'Router Büro', 'Social-Media-Konto Agentur', 'Bildagentur Pixelmeer', 'Druckerei-Portal', 'Domain-Verwaltung', 'WLAN Gäste')
    Months        = @('Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember')
    Motifs        = @(
        @{ Name = 'Flyer DIN A5'; File = 'Flyer'; Shape = 'Portrait' }
        @{ Name = 'Plakat DIN A1'; File = 'Plakat'; Shape = 'Portrait' }
        @{ Name = 'Anzeige Lokalzeitung'; File = 'Anzeige'; Shape = 'Portrait' }
        @{ Name = 'Social-Media-Post'; File = 'Social-Post'; Shape = 'Square' }
        @{ Name = 'Banner Website'; File = 'Banner'; Shape = 'Landscape' }
        # Projekttypische Lieferungen: nur, wenn Match auf den Projektnamen passt. Pages = Seiten bzw. Motive der Serie.
        @{ Name = 'Broschüre DIN A4'; File = 'Broschuere'; Pages = 12; Layout = 'Brochure'; Match = 'brosch|katalog|bericht|heft|prospekt|speisekarte|exposé' }
        @{ Name = 'Messewand 3 x 2,5 m'; File = 'Messewand'; Match = 'messe' }
        @{ Name = 'Bauschild 3 x 2 m'; File = 'Bauschild'; Match = 'bauschild' }
        @{ Name = 'Fahrzeugbeschriftung Seitenansicht'; File = 'Fahrzeug'; Match = 'fahrzeug' }
        @{ Name = 'Stanzbogen DIN A2'; File = 'Stanzbogen'; Match = 'verpackung|etikett' }
        @{ Name = 'Plakatserie DIN A1'; File = 'Plakatserie'; Pages = 4; Layout = 'Series'; Match = 'plakatserie|kampagne|eröffnung' }
        @{ Name = 'Anzeigenserie'; File = 'Anzeigenserie'; Pages = 4; Layout = 'Series'; Match = 'anzeigenserie|recruiting|tarif' }
        @{ Name = 'Social-Media-Serie'; File = 'Social-Serie'; Pages = 12; Layout = 'Series'; Match = 'social|aktion|fest|start|jubiläum|werbung' }
        @{ Name = 'Screendesign Website'; File = 'Screendesign'; Pages = 8; Layout = 'Web'; Match = 'website|relaunch|landingpage|lieferdienst|abo' }
    )

    Labels        = @{
        Invoice = 'Rechnung'; Offer = 'Angebot'; Confirmation = 'Auftragsbestätigung'; Reminder = 'Zahlungserinnerung'; Dunning = 'Mahnung'; Delivery = 'Lieferschein'
        Date = 'Datum'; Number = 'Nummer'; CustomerNo = 'Kundennummer'; Pos = 'Pos.'; Description = 'Leistung'; Quantity = 'Menge'; Unit = 'Einheit'
        Price = 'Einzelpreis'; Amount = 'Betrag'; Net = 'Nettobetrag'; Vat = 'zzgl. 19 % USt.'; Total = 'Gesamtbetrag'; Sum = 'Summe'; Page = 'Seite {0} von {1}'
        Received = 'EINGEGANGEN'; Booked = 'GEBUCHT'; Paid = 'BEZAHLT'; Released = 'FREIGEGEBEN'; Copy = 'Kopie von '; Draft = 'Entwurf'; Variant = 'Variante'; Version = 'Stand'
        Regards = 'Mit freundlichen Grüßen'; Salutation = 'Sehr geehrte Damen und Herren'; Attendees = 'Teilnehmende'; Agenda = 'Tagesordnung'; Minutes = 'Protokoll'
        Tasks = 'Aufgaben'; Task = 'Aufgabe'; Owner = 'Verantwortlich'; Due = 'Termin'; Statement = 'Kontoauszug'; Balance = 'Kontostand'; Booking = 'Buchungstext'
        OldBalance = 'Alter Kontostand'; NewBalance = 'Neuer Kontostand'; Salary = 'Entgeltabrechnung'; Gross = 'Bruttoentgelt'; NetSalary = 'Auszahlungsbetrag'
        Tax = 'Lohnsteuer'; Social = 'Sozialversicherung (AN-Anteil)'; Travel = 'Reisekostenabrechnung'; Purpose = 'Anlass der Reise'; Mileage = 'Fahrtkosten (0,30 € je km)'
        Allowance = 'Verpflegungsmehraufwand'; Hotel = 'Übernachtung'; Receipt = 'Beleg'; Contract = 'Arbeitsvertrag'; Reference = 'Arbeitszeugnis'; Cv = 'Lebenslauf'
        Application = 'Bewerbung als {0}'; Report = 'Kampagnenbericht'; Press = 'Pressemitteilung'; Briefing = 'Briefing'; Concept = 'Konzept'; Presentation = 'Präsentation'
        Bwa = 'Betriebswirtschaftliche Auswertung'; Kpi = 'Kennzahl'; Plan = 'Plan'; Actual = 'Ist'; Month = 'Monat'; Cumulative = 'Kumuliert'; Signature = 'Unterschrift'
        Customer = 'Kunde'; Contact = 'Ansprechpartner'; Project = 'Projekt'; Schedule = 'Zeitplan'; Budget = 'Budget'; Phase = 'Phase'; Week = 'KW'; Moodboard = 'Moodboard'
        NextSteps = 'Nächste Schritte'; Position = 'Stelle'; Name = 'Name'; Period = 'Zeitraum'; Device = 'Gerät'; Hostname = 'Name im Netzwerk'; IpAddress = 'IP-Adresse'
        Location = 'Standort'; Product = 'Produkt'; Licenses = 'Anzahl'; ValidUntil = 'gültig bis'; Network = 'Netzwerkübersicht'; LicenseList = 'Lizenzübersicht'
        ReceivedGoods = 'Ware vollständig und unbeschädigt erhalten'; VersionOf = 'Version {0} vom {1}'; Employee = 'Mitarbeiter/in'; Motifs = 'Motive'; Thanks = 'Vielen Dank!'
        Questions = 'Fragen und Antworten'; Correction = 'Korrektur'; PrintRelease = 'Druckfreigabe'; Request = 'Anfrage'; Calculation = 'Kalkulation'; Hours = 'Stunden'
        Rate = 'Stundensatz'; MediaPlan = 'Mediaplan'; Timesheet = 'Zeiterfassung'; Revenue = 'Umsatz'; Vacation = 'Urlaubsplanung'; Birthdays = 'Geburtstage im Team'
        PhoneList = 'Telefonliste'; CustomerList = 'Kundenliste'; Inventory = 'Inventar'; Applicants = 'Bewerbungen'; Status = 'Status'; Comment = 'Bemerkung'
        PersonnelSheet = 'Personalbogen'; BirthDate = 'Geburtsdatum'; BirthPlace = 'Geburtsort'; Address = 'Anschrift'; TaxId = 'Steuer-ID'; TaxClass = 'Steuerklasse'
        SocialNo = 'Sozialversicherungsnummer'; IdCard = 'Personalausweis-Nr.'; Insurance = 'Krankenkasse'; Confession = 'Konfession'; Marital = 'Familienstand'; Children = 'Kinder'
        Iban = 'IBAN'; Bank = 'Bank'; Phone = 'Telefon'; Mobile = 'Mobil'; Email = 'E-Mail'; SickNote = 'Arbeitsunfähigkeitsbescheinigung'; From = 'von'; To = 'bis'
        CreditCard = 'Kreditkartenabrechnung'; CardNumber = 'Kartennummer'; Mandate = 'SEPA-Lastschriftmandat'; Raffle = 'Gewinnspiel'; Participants = 'Teilnehmende'
        Credentials = 'Zugangsdaten'; Password = 'Kennwort'; Username = 'Benutzername'; System = 'System'; Payroll = 'Lohnjournal'; Entry = 'Eintritt'; Leave = 'Austritt'
        Public = 'Öffentlich'; Internal = 'Intern'; Confidential = 'Vertraulich'; Secret = 'Streng vertraulich'; Classification = 'Klassifizierung'
        Single = 'ledig'; Married = 'verheiratet'; NoConfession = 'keine'; Catholic = 'römisch-katholisch'; Protestant = 'evangelisch'; Holder = 'Kontoinhaber/in'
        Branding = 'Branding'; Palette = 'Farbpalette'; Contactsheet = 'Kontaktbogen'; Invitation = 'Einladung'; Placeholder = 'Bildplatzhalter'; Motif = 'Motiv'
        Background = 'Hintergrund'; Goal = 'Ziel'; Audience = 'Zielgruppe'; Mandatory = 'Pflichtvorgaben'; Timing = 'Zeitplan'; Situation = 'Ausgangslage'
        Idea = 'Leitidee'; Goals = 'Ziele'; Measures = 'Maßnahmen'; Risks = 'Risiken und offene Punkte'; Feedback = 'Anmerkungen des Kunden'; Note = 'Notiz'
        PrintData = 'Druckdaten'; Cancelled = 'abgesagt'; Results = 'Ergebnis'; Learnings = 'Erkenntnisse'; Agenda2 = 'Agenda'; Welcome = 'Willkommen'
        Margin = 'Marge'; ExternalCosts = 'Fremdkosten'; Overview = 'Übersicht'; Policy = 'Richtlinie'; Announcement = 'Rundschreiben'; Template = 'Vorlage'
    }

    # Unterordner unterhalb der Freigaben aus FileServer.psd1. Travel und Applications muessen zu den Altlast-Pfaden passen (Test).
    FolderNames   = @{
        Incoming = 'Eingangsrechnungen'; Outgoing = 'Ausgangsrechnungen'; Reminders = 'Mahnungen'; Statements = 'Kontoauszüge'; Delivery = 'Lieferscheine'
        Travel = 'Reisekosten'; CreditCard = 'Kreditkarte'; Payroll = 'Lohn'; Mandates = 'Lastschriftmandate'; Offers = 'Angebote'; Orders = 'Aufträge'
        Customers = 'Kunden'; Minutes = 'Protokolle'; Press = 'Pressemitteilungen'; Reports = 'Berichte'; Presentations = 'Präsentationen'
        Files = 'Personalakten'; Payslips = 'Entgeltabrechnungen'; SickNotes = 'Krankmeldungen'; Applications = 'Bewerbungen'; References = 'Zeugnisse'
        Policies = 'Richtlinien'; Docs = 'Dokumentation'; Bwa = 'BWA'; Agreements = 'Verträge'; Templates = 'Vorlagen'; Ci = 'Corporate Design'
        Branding = 'Branding'; Announcements = 'Rundschreiben'; Events = 'Veranstaltungen'; Documents = 'Dokumente'; Private = 'Privat'; Backup = 'Sicherung'
        Former = '_Ehemalige'; Onboarding = 'Onboarding'; Kickoff = 'Jahresauftakt'; Receipts = 'Belege'; Proofs = 'Proofs'; Letters = 'Korrespondenz'
        ProjectSteps = @('01_Angebot', '02_Briefing', '03_Konzept', '04_Entwürfe', '05_Präsentation', '06_Abrechnung')
    }
}
