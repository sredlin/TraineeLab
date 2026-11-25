# Protokolle, Briefe, Rundschreiben, Notizen (siehe README.md)
@{
    MinutesTopic   = @(
        @{ Title = 'Auslastung'; Text = 'Wir liegen im {Monat} {Prozent} % über Plan, {KollegeVorname} hat {Stunden} Stunden offen. Mehr geht nicht.
{Leitung} will Reinzeichnung an Freie geben. Dagegen: Die letzte Freie hat beim Beschnitt gepfuscht, zwei Nachdrucke.
Ergebnis: nur unkritische Jobs raus. {Ich} prüft bis {Termin}, was sich schieben lässt.' }
        @{ Title = 'Projektstand {KundeKurz} – {Projekt}'; Text = '{Projekt} hängt seit dem {Vortermin}, die Freigabe fehlt, {Ansprechpartner} ist im Urlaub. Budget zu {Prozent} % verbraucht.
{KollegeVorname} will schon reinzeichnen. {Ich} dagegen: Ändert der Kunde danach die Farben, machen wir alles doppelt.
Ergebnis: erst nach schriftlicher Freigabe. {Kollege} ruft Montag an, Start notfalls am {Termin2}.' }
        @{ Title = 'Urlaubsplanung'; Text = 'Drei Anträge für dieselben zwei Wochen ab {Termin}, mitten in der heißen Phase für {KundeKurz}. Geht nicht.
Vorrang für Eltern? {KollegeVorname} findet das unfair. Einigung: Eltern-Vorrang nur in den Schulferien, wer letztes Jahr zurückgesteckt hat, ist zuerst dran.
Liste in der Freigabe Abteilungen, eintragen bis {Termin2}. Danach entscheidet {Leitung}.' }
        @{ Title = 'Neue Anfrage {KundeKurz}'; Text = '{Ansprechpartner} hat am {Vortermin} angerufen: mehr Werbung für {Produkt}, über {Kanal} und {Kanal2}, Budget grob {Budget}.
{KollegeVorname}: Das Geld reicht für einen Kanal. {Ich} sieht die Chance auf einen Dauerkunden.
Ergebnis: Angebot in zwei Varianten. {Ich} schreibt bis {Termin}, {Kollege} rechnet die Stunden.' }
        @{ Title = 'Ärger mit der Druckerei'; Text = 'Plakate für {KundeKurz} zwei Tage zu spät, das Rot viel zu blass. Die Druckerei schiebt es auf unser Farbprofil. {KollegeVorname} hat geprüft: ISO Coated v2, 3 mm Beschnitt, alles korrekt.
Wechseln? {Leitung} will nichts übers Knie brechen, fünf Jahre lief es gut.
Ergebnis: Reklamation mit Fotos, Nachdruck auf deren Kosten, {Ich} bis {Termin}. Nächstes Mal Vergleichsangebot.' }
        @{ Title = 'Fileserver voll'; Text = 'Server zu 94 % voll, {KollegeVorname} konnte Dienstag nicht speichern. Brocken: Shooting-Rohdaten doppelt in H: und Projekte, „Sicherung alt“ mit 180 GB.
{Ich} will Platten kaufen, {Leitung} erst aufräumen.
Ergebnis: Basisordner aufräumen bis {Termin}, Projekte älter als zwei Jahre ins Archiv. {Kollege} fragt den IT-Dienstleister nach Preisen.' }
        @{ Title = 'Drucker im Flur'; Text = 'Papierstau in Fach 2 fast täglich. Techniker war am {Vortermin} da, hat drei Tage gehalten.
{KollegeVorname} will ein Austauschgerät fordern. {Ich} will erst die Zählerstände prüfen, vielleicht drucken wir zu viel.
Ergebnis: Fach 2 gesperrt (Zettel dran), {Ich} schreibt an den Leasinggeber, Frist {Termin}.' }
        @{ Title = 'Weihnachtsfeier'; Text = 'Gemeinsam oder getrennt? {KollegeVorname} ist für getrennt, die Rückfahrt nach Hamburg war letztes Jahr zu viel. {Leitung}: einziger Abend im Jahr, an dem alle zusammen sind.
Ergebnis: gemeinsam in Berlin, Hamburg mit Hotel. 65 € pro Kopf plus Fahrt, Wichteln bis 15 €. Umfrage zum Lokal bis {Termin} ({Kollege}).' }
        @{ Title = 'Homeoffice-Regeln'; Text = 'Beschwerde von {KundeKurz}: dienstags und freitags erreicht man niemanden. {Leitung} will feste Präsenztage, {KollegeVorname} nicht – im Büro wird ständig gequatscht.
Ergebnis: Mittwoch ist Bürotag für alle, Teamrunde 10 Uhr. Telefon aufs Notebook umleiten, nicht aufs private Handy. Ab {Termin}, {Ich} passt die Richtlinie an.' }
        @{ Title = 'Neue Kollegin'; Text = 'Am {Termin} fängt die neue Grafikerin an, Platz am Fenster. Notebook kommt erst am Vortag – knapp.
{KollegeVorname} kann das Layoutprogramm am besten erklären, hat aber keine Zeit. Einigung: erste Woche {Kollege}, danach Patenschaft {Ich}.
Benutzerkonto beantragt {Ich}, Schlüssel {Kollege}. Erster Tag: Mittagessen zusammen.' }
        @{ Title = 'Preisanpassung'; Text = 'Stundensätze seit drei Jahren gleich, Miete und Gehälter nicht. {Ich} schlägt plus 8 % ab {Termin2} vor.
{KollegeVorname} hat Bauchschmerzen bei Kita, Verein und Musikschule. {Leitung} will keine zwei Preislisten.
Ergebnis: 8 % für alle, 10 % Rabatt für Gemeinnützige bleibt. Kundenbrief {Ich} bis {Termin}, {Kollege} liest gegen.' }
        @{ Title = 'Abmahnung Bildrechte'; Text = 'Abmahnung für {KundeKurz}: Foto auf der Landingpage ohne Lizenz, 1.480 € plus Anwalt. War mal Platzhalter im Entwurf vom {Vortermin}.
{KollegeVorname} ist sicher, dass wir die Lizenz gekauft haben, die Rechnung findet keiner. {Leitung}: Nichts unterschreiben, bevor das geklärt ist.
Ergebnis: {Kollege} sucht die Lizenz, {Ich} informiert Kunde und Anwalt, Frist {Termin}. Platzhalter nur noch mit Wasserzeichen.' }
    )
    LetterCustomer = @(
        @{ Subject = 'Terminbestätigung {Projekt}'; Text = 'wie besprochen kommen wir am {Termin} um 10 Uhr zu Ihnen nach {Stadt}, um die Entwürfe für {Projekt} durchzugehen. Wir bringen drei Varianten mit.
Ideal wäre, wenn auch die Person dabei ist, die am Ende freigibt – das spart eine Korrekturschleife.' }
        @{ Subject = 'Danke für {Projekt}'; Text = 'die Kampagne „{Claim}“ ist abgeschlossen, und wir wollen uns persönlich bedanken. Nicht immer einfach – Sie erinnern sich an den Abend vor dem Drucktermin –, aber über {Kanal} kamen {Prozent} % mehr Anfragen als im Vorjahr.
Den Bericht erhalten Sie bis zum {Termin}.' }
        @{ Subject = 'Zum Jahreswechsel'; Text = 'danke für ein gutes Jahr, schnelle Rückmeldungen und die eine oder andere Diskussion, aus der ein besseres Ergebnis wurde.
Vom 24. Dezember bis 1. Januar ist unser Büro geschlossen. Erholsame Feiertage!' }
        @{ Subject = 'Anpassung unserer Stundensätze'; Text = 'drei Jahre lang sind unsere Preise gleich geblieben, Miete, Löhne und Lizenzen nicht. Zum {Termin2} erhöhen wir unsere Stundensätze um 8 %.
Angebote, die Sie bis zum {Termin} annehmen, rechnen wir noch zum alten Satz ab.' }
        @{ Subject = 'Rückfrage zu Bildrechten'; Text = 'für {Projekt} möchten Sie die Fotos vom {Vortermin} verwenden. Bei sechs Bildern fehlt uns, wer sie gemacht hat und ob Sie die Rechte für Druck und Web haben, auf zwei sind Personen erkennbar.
Bitte bestätigen Sie uns das bis zum {Termin} – eine Abmahnung wäre teurer.' }
    )
    LetterSupplier = @(
        @{ Subject = 'Reklamation Auftrag {Projekt}'; Text = 'die am {Vortermin} gelieferten Flyer für {Kunde} (Auflage {Auflage}, DIN A5) nehmen wir so nicht ab:
• Hausrot deutlich ins Orange verschoben, sichtbar anders als der Proof.
• Auf etwa einem Drittel der Bögen Schnitt bis 2 mm im Motiv, trotz 3 mm Beschnitt.
• Schmierstreifen am rechten Rand in mehreren Kartons.
Fotos liegen bei. Bitte Nachdruck auf Ihre Kosten bis {Termin}, die Verteilung beginnt am {Termin2}.' }
        @{ Subject = 'Anfrage Rahmenvertrag'; Text = 'seit fünf Jahren arbeiten wir zusammen, zuletzt rund 40 Aufträge im Jahr. Wir schlagen einen Rahmenvertrag über zwei Jahre vor: feste Staffelpreise, Lieferung frei Haus, fünf Werktage Produktionszeit. Dafür sichern wir 30.000 € netto im Jahr zu.
Passt Ihnen ein Gespräch am {Termin}?' }
        @{ Subject = 'Verschiebung Termin {Projekt}'; Text = 'den für den {Termin} reservierten Termin müssen wir leider verschieben, unser Kunde hat die Daten noch nicht freigegeben. Wäre der {Termin2} möglich?' }
        @{ Subject = 'Kündigung Leasingvertrag Multifunktionsgerät'; Text = 'hiermit kündigen wir den Leasingvertrag für das Multifunktionsgerät im Büro {Standort} fristgerecht zum {Termin2}.
Seit dem {Vortermin} waren vier Technikereinsätze nötig, das zugesagte Austauschgerät kam nie. Bitte bestätigen Sie die Kündigung und nennen Sie einen Abholtermin.' }
    )
    Reminder       = @(
        @{ Level = 1; Text = 'Ihre Zahlung zur unten aufgeführten Rechnung konnten wir bis heute nicht feststellen. Sicher nur übersehen. Bitte überweisen Sie den Betrag bis zum {Termin}. Haben Sie inzwischen gezahlt, ist dieses Schreiben gegenstandslos.' }
        @{ Level = 1; Text = 'Ihre Rechnung zu {Projekt} ist seit dem {Vortermin} fällig. Vielleicht liegt sie auf dem falschen Schreibtisch? Bitte gleichen Sie den Betrag bis zum {Termin} aus, bei Fragen zur Abrechnung rufen Sie uns gern an.' }
        @{ Level = 2; Text = 'Ihre Zahlung ist trotz unserer Erinnerung vom {Vortermin} nicht eingegangen. Wir mahnen den Betrag zuzüglich 5,00 € Mahngebühr an, fällig bis {Termin}. Danach geht die Forderung an ein Inkassobüro.' }
        @{ Level = 2; Text = 'Sie haben auf unsere Erinnerung vom {Vortermin} nicht reagiert, die Rechnung ist über 30 Tage überfällig. Bitte zahlen Sie bis {Termin}. Bis zum Zahlungseingang stellen wir weitere Arbeiten an Ihren Projekten zurück.' }
    )
    Announcement   = @(
        @{ Event = 'Founding'; Subject = 'Es ist offiziell!'; Text = 'Ihr Lieben, seit heute steht {Firma} im Handelsregister! Danke an John, der mit Max und mir zwischen Kartons in der Kastanienallee 8 sitzt, und an Dirk, der unsere Belege aus dem Schuhkarton rettet.
Erster Auftrag: Flyer für die Bäckerei Krume & Kruste. Freitag ab 17 Uhr Sekt im Büro!
Erika' }
        @{ Event = 'Hamburg'; Subject = 'Niederlassung Hamburg'; Text = 'Liebe Kolleginnen und Kollegen,
30 % unseres Umsatzes kommen inzwischen aus dem Norden, die Fahrten kosten uns einen Arbeitstag pro Woche. Zum 1. September eröffnen wir deshalb in Hamburg, Ring 1. Leitung: Celina Herz, mit ihr starten Wolfgang Ernst und Jan Petersen.
Max Mustermann' }
        @{ Event = 'Move'; Subject = 'Wir ziehen um!'; Text = 'Ihr Lieben, Ende Juni ziehen wir von der Kastanienallee in den Weg 1 – endlich ein Besprechungsraum mit Tür!
Bitte Schreibtische ausmisten, Kartons mit Namen und Raumnummer beschriften. Rechner baut der IT-Dienstleister um, Telefonnummern bleiben. Bequeme Schuhe!
Erika' }
        @{ Event = 'Rebranding'; Subject = 'Unser neuer Auftritt'; Text = 'Ihr Lieben, ab Montag sehen wir anders aus! Statt Bordeauxrot und Times: Petrol, Orange und Arial. Unter dem Signet steht statt „Werbung, die ankommt.“ künftig „Agentur für Kommunikation und Design“.
Bitte nur noch die neuen Vorlagen nutzen. Alte Visitenkarten werden Notizzettel. Danke Karl und Veronika für ein halbes Jahr Arbeit!
Erika' }
        @{ Event = 'Scanner'; Subject = 'Neuer Scanner im Flur'; Text = 'Hallo zusammen, das neue Gerät im Flur scannt jetzt auch: Vorlage einlegen, „Scan to Ordner“, Namen antippen, Start. Die PDFs landen in der Freigabe Scans, Unterordner mit eurem Namen. Bitte zeitnah in den Projektordner verschieben, Scans ist kein Archiv.
Nadine' }
        @{ Event = 'Homeoffice'; Subject = 'Regelung Homeoffice'; Text = 'Liebe Kolleginnen und Kollegen,
ab 1. April sind bis zu zwei Homeoffice-Tage pro Woche möglich, nach Absprache im Team. Kernzeit 10 bis 15 Uhr. Nur Firmen-Notebook mit VPN, keine Kundendaten auf privaten Geräten. Auswertung nach sechs Monaten.
Max Mustermann' }
        @{ Event = 'Anniversary'; Subject = '10 Jahre {Firma}!'; Text = 'Ihr Lieben, vor zehn Jahren saßen Max, John und ich zu dritt in der Kastanienallee, mit einem Drucker, der nur montags ging. Heute sind wir 14 Leute in Berlin und Hamburg. Das feiern wir am letzten Samstag im März ab 18 Uhr im Weg 1. Zusagen bitte bis 10. März an mich!
Erika' }
        @{ Event = 'FileServer'; Subject = 'Neuer Fileserver – bitte lesen'; Text = 'Liebe Kolleginnen und Kollegen,
am Wochenende ziehen unsere Daten auf den neuen Fileserver. Freitag ab 16 Uhr nichts mehr speichern. Ab Montag gilt:
• H: ist euer persönliches Laufwerk, nur für Arbeitsdateien.
• Kundenarbeit liegt in Projekte, ein Ordner je Kunde und Projekt, Teamunterlagen in Abteilungen.
• Projekte älter als zwei Jahre bis Ende November ins Archiv verschieben.
• Keine privaten Dateien, Fotos oder Musik auf dem Server.
Fragen an John oder den Support, +49 30 23125-777.
Max Mustermann' }
        @{ Event = 'CustomerLost'; Subject = '{KundeKurz}'; Text = 'Liebe Kolleginnen und Kollegen,
es gibt keinen guten Weg, das zu sagen: {Kunde} hat die Ausschreibung an eine andere Agentur vergeben. Wir lagen 15 % über dem günstigsten Angebot. Das sind rund 22 % unseres Umsatzes.
Kündigungen wird es nicht geben, aber vorerst auch keine Neueinstellungen. Sieben Jahre Arbeit stecken in diesem Kunden. Es lag nicht an euch. Donnerstag 10 Uhr reden wir in Ruhe darüber.
Max Mustermann' }
        @{ Event = 'FrameworkContract'; Subject = 'Rahmenvertrag {KundeKurz}'; Text = 'Hallo zusammen, {Kunde} hat den Rahmenvertrag über drei Jahre unterschrieben: Exposés, Bauschilder, Website, rund 1.400 Stunden im Jahr. Danke für die langen Abende vor der Präsentation!
Heißt auch: Hamburg ist ab Oktober voll. Projektleitung Wolfgang, Umsetzung Wioletta und Johann. Neue Anfragen bitte erst über mich.
Celina' }
        @{ Event = 'Christmas'; Subject = 'Weihnachtsfeier {Jahr}'; Text = 'Ihr Lieben, am zweiten Freitag im Dezember feiern wir ab 16 Uhr in Berlin. Wichteln bis 15 €, Lose ziehen wir in der Teamrunde. Vegetarisch, vegan, Allergien? Bis Ende November an mich. Und ja, John plant wieder ein Quiz!
Erika' }
        @{ Event = 'Summer'; Subject = 'Sommerfest {Jahr}'; Text = 'Hi all, FYI:
• letzter Freitag im Juni, 15 Uhr, diesmal Hamburg an der Elbe
• Grill und Getränke organisiert, Salate bringt jeder mit, Liste asap
• Berlin fährt 10:30 mit dem Zug, Plan B bei Regen tbd
Zu-/Absage bis KW 24 an mich. Kids welcome!
John' }
    )
    HomeNote       = @(
        @{ Voice = 'MMustermann'; Text = 'Liquidität {Monat}: Eingang 38.200 €, Ausgang 41.700 €. {KundeKurz} zahlt nicht. Kanzlei wegen Vorauszahlung anrufen.' }
        @{ Voice = 'EMustermann'; Text = 'Teamfrühstück Freitag: Brötchen bestellen, Lea macht die Playlist! Karte für {KollegeVorname} liegt in der Schublade!' }
        @{ Voice = 'JDoe'; Text = 'To-dos KW: Pitch {KundeKurz} finalisieren asap, Mediaplan {Kanal} tbd, 1:1 mit Lea Do 14:00' }
        @{ Voice = 'KAnders'; Text = 'Idee {KundeKurz} – nicht das Produkt zeigen, sondern den Moment danach: Krümel, leerer Teller, warmes Seitenlicht, viel Weißraum.' }
        @{ Voice = 'VSpula'; Text = 'Druckdaten {Projekt}:
1. Beschnitt ok
2. Schriften eingebettet
3. Titelbild nur 240 dpi, nachfragen
4. Freigabe fehlt' }
        @{ Voice = 'LMayer'; Text = 'Dateien richtig benennen!!! Kein final_final2.indd mehr :-) Veronika fragen, wie Verpacken geht.' }
        @{ Voice = 'CHerz'; Text = 'Call {Ansprechpartner}: Budget steht, wenn Exposés 2 Wochen früher kommen. Wolfgang baut Vorlagen. Angebot bis {Termin}.' }
        @{ Voice = 'WErnst'; Text = 'Bei {KundeKurz} auf Proof auf Papier bestehen. Früher hat man am Leuchttisch abgestimmt, heute ein Häkchen im Portal.' }
        @{ Voice = 'JFrick'; Text = '{KundeKurz}: FOGRA39, Orange 0/60/100/0, nicht aus RGB wandeln lassen. Plakat A1: 150 dpi reicht.' }
        @{ Voice = 'SHarz'; Text = 'Claim {KundeKurz}: „Nicht lang schnacken, machen.“ Wortspiel-Quote heute: 3. Celina erlaubt 2.' }
        @{ Voice = 'WLonska'; Text = 'Vor Reinzeichnung {Ansprechpartner} fragen: altes Logo hinten lassen? Neue Telefonnummer? Sind alle mit dem Teamfoto einverstanden?' }
        @{ Voice = 'RJung'; Text = 'Wolfgang fragen, ob ich die Plakatdaten selbst rausschicken darf. Sorry nochmal wegen der falschen Version. Vorlagen in H: oder Projekte??' }
        @{ Text = 'Rückruf {Ansprechpartner} wegen {Projekt}: wollte bis {Termin} sagen, ob {Kanal2} dazukommt. Mittwoch nachhaken.' }
        @{ Text = 'Zugang Druckerei-Portal läuft am {Termin} ab. Neues Passwort NICHT wieder auf den Zettel am Monitor.' }
        @{ Text = 'Stunden {Projekt}: Mo 3,5 / Di 6 / Mi 2 Korrektur / Do 4 – noch eintragen!' }
    )
    PrivateNote    = @(
        @{ Subject = 'Urlaub Sommer'; Text = 'Zingst, Ferienwohnung 98 €/Nacht, 2 Wochen ca. 1.400 €. Oder Gardasee Camping, aber die Kinder wollen Pool. Bis Ende Januar buchen!' }
        @{ Subject = 'Wohnungssuche'; Text = 'Do 18 Uhr Gartenstraße 14, 3 Zi., 1.150 € warm, 4. OG ohne Aufzug. Sa 11 Uhr Lindenallee 3, 980 € warm. Schufa mitnehmen!' }
        @{ Subject = 'Geschenke'; Text = 'Mama: Fotobuch vom Sommer. Jonas: Kletterschuhe Gr. 39. Oma: Pralinen ohne Alkohol! Max. 250 € insgesamt.' }
        @{ Subject = 'Linsensuppe (Oma)'; Text = '250 g Tellerlinsen einweichen, Zwiebel, 2 Möhren, Sellerie, 2 Kartoffeln, 1,5 l Brühe, 40 Min. Zum Schluss Essig und Würstchen.' }
        @{ Subject = 'Einkaufsliste'; Text = 'Milch, Haferflocken, Bananen, Käse für Raclette, Wein für Anke, Batterien AA, Kaffee!!! Paket von der Post holen.' }
        @{ Subject = 'Fahrrad verkaufen'; Text = 'Trekkingrad 28 Zoll, RH 52, neue Reifen. 180 € VB, nicht unter 150. Herr Sommer will Sonntag gucken kommen.' }
    )
}
