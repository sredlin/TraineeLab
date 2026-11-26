# Richtlinien, Handbücher, Verträge, IT-Dokumentation (siehe README.md)
@{
    Policy = @(
        @{ Title = 'IT-Richtlinie'; Folder = 'IT'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Geltungsbereich'; Text = 'Diese Richtlinie gilt für alle, die bei {Firma} ein Konto haben: Festangestellte, Auszubildende, Praktikantinnen und Praktikanten, Freie. Eine eigene IT-Abteilung haben wir nicht. Technisch betreut uns die IT-Service Nordost GmbH, Entscheidungen trifft die Geschäftsführung.' }
                @{ Title = '2 Kennwörter'; Text = 'Ein Kennwort hat mindestens 12 Zeichen. Gut ist ein Satz, den nur Sie kennen, etwa vier Wörter und eine Zahl. Namen von Kindern, Haustieren und Fußballvereinen sind schlecht.
Kennwörter stehen auf keinem Zettel, weder am Monitor noch unter der Tastatur, und in keiner Datei „Passwörter.xlsx“ auf H:. Auch die Urlaubsvertretung bekommt Ihr Kennwort nicht, dafür gibt es Gruppenrechte und Stellvertretungen im Postfach.
Niemand von uns oder von der IT-Service Nordost fragt je nach Ihrem Kennwort. Wer den Platz verlässt, sperrt den Bildschirm mit Windows-Taste + L.' }
                @{ Title = '3 Ablage auf dem Fileserver'; Text = 'Geschäftliches liegt auf dem Fileserver, nicht auf dem Desktop. Nur der Server wird gesichert.
• H: ist Ihr Basisordner (Freigabe Home$), nur für Sie: Entwürfe und Notizen, die noch niemand braucht.
• Abteilungen: ein Ordner je Bereich. Allgemein lesen alle, dort liegen Richtlinien und Vorlagen.
• Projekte: ein Ordner je Auftrag nach dem Muster Jahr_Kunde_Projekt, darin 01_Angebot bis 06_Abrechnung.
• Archiv: abgeschlossene Jahre, nur lesen. Ins Archiv verschiebt die Geschäftsleitung.
• Scans: Eingang des Multifunktionsgeräts. Hier sieht jede und jeder alles, also Scans noch am selben Tag abholen und richtig ablegen.
Private Fotos, Musik und Filme gehören nicht auf den Server. Kundendaten kommen nie auf USB-Sticks; Druckdaten gehen über das Upload-Portal der Druckerei.' }
                @{ Title = '4 E-Mail'; Text = 'Anhänge, mit denen Sie nicht gerechnet haben, öffnen Sie nicht, auch keine „Rechnung“ und keine „Bewerbung“. Dateien über 20 MB verschicken Sie als Downloadlink. Dienstliche Mails werden nicht an private Postfächer weitergeleitet.
Meldet ein Lieferant per Mail eine neue Bankverbindung, rufen Sie ihn unter der Nummer aus unseren Unterlagen an, nicht unter der aus der Mail.' }
                @{ Title = '5 Datensicherung und Vorgängerversionen'; Text = 'Der Fileserver wird jede Nacht gesichert und legt werktags um 7 und um 12 Uhr Vorgängerversionen an. Eine überschriebene Datei holen Sie selbst zurück: Rechtsklick, Eigenschaften, Vorgängerversionen. Wählen Sie „Kopieren“, dann landet der alte Stand neben dem aktuellen und nichts geht verloren.
Ältere Stände holt die IT-Service Nordost aus der Sicherung. Was auf dem Desktop liegt, ist nirgends gesichert.' }
                @{ Title = '6 Verhalten bei Verdacht'; Text = 'Link angeklickt, Anhang verhält sich seltsam, Dateien heißen plötzlich anders, Notebook weg: Rufen Sie sofort die IT-Service Nordost (+49 30 23125-777) und die Geschäftsführung an. Bei Verdacht auf Schadsoftware Netzwerkkabel ziehen und WLAN ausschalten, das Gerät aber nicht herunterfahren.
Ärger bekommt niemand, der hereingefallen ist und es gleich meldet. Ärger macht nur, was verschwiegen wird.' }
            ) }
        @{ Title = 'Datenschutzrichtlinie'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Grundsatz'; Text = 'Wir arbeiten täglich mit Daten anderer Menschen: Adresslisten für Mailings, Gewinnspielteilnehmer, Bewerbungen, Gehälter. Wir erheben nur, was der Auftrag braucht, behalten es nur so lange wie nötig und zeigen es nur denen, die damit arbeiten. Einen Datenschutzbeauftragten brauchen wir bei unserer Größe nicht; Ansprechpartnerin ist Erika Mustermann.' }
                @{ Title = '2 Bewerbungen'; Text = 'Bewerbungen sehen nur Personal und Geschäftsleitung. Sie liegen in Abteilungen\Personal\Bewerbungen, nicht im Postfach und nicht auf H:. Wer im Team mitentscheiden soll, sieht die Mappe im Gespräch, bekommt sie aber nicht weitergeleitet.
Sechs Monate nach einer Absage löschen wir Unterlagen und Mails, außer jemand hat schriftlich in unseren Bewerberpool eingewilligt.' }
                @{ Title = '3 Gewinnspiele für Kunden'; Text = 'Teilnehmerdaten dienen nur der Ziehung und der Benachrichtigung. Nach der Ziehung löschen wir die Liste, die Adressen der Gewinner nach dem Versand der Preise. Die Liste liegt nur im Projektordner, nie als Kopie auf H: oder im Postfach. Drei Versionen von „Teilnehmer_final.xlsx“ sind drei Löschungen, die jemand vergisst.' }
                @{ Title = '4 Personalakten'; Text = 'Personalakten, Entgeltabrechnungen, Krankmeldungen und Abmahnungen sehen nur Personal und Geschäftsleitung. Sie werden nie über die Freigabe Scans gescannt, denn dort lesen alle mit. Krankmeldungen sind Gesundheitsdaten; nach der Diagnose fragen wir nicht. Die Standortleitung erfährt, wer wie lange fehlt, sonst nichts.' }
                @{ Title = '5 Aufbewahrungsfristen'; Text = 'Wir heben auf, was das Gesetz verlangt, und nicht länger:
• 10 Jahre: Buchungsbelege, Rechnungen, Kontoauszüge, Jahresabschlüsse
• 6 Jahre: Geschäftsbriefe und geschäftliche E-Mails, Angebote, aus denen ein Auftrag wurde
Die Frist beginnt mit dem Ende des Kalenderjahres. Jeden Januar räumt die Geschäftsleitung das Archiv auf.' }
                @{ Title = '6 Auftragsverarbeitung'; Text = 'Wer für uns personenbezogene Daten verarbeitet, braucht vorher einen Vertrag zur Auftragsverarbeitung, vor allem die Nordlicht Druckerei (Adressen für Mailings) und die IT-Service Nordost. Adressen gehen nur über das Upload-Portal der Druckerei, nie als Excel-Anhang. Nach dem Versand bestätigt die Druckerei die Löschung; die Bestätigung kommt in den Projektordner unter 06_Abrechnung.' }
                @{ Title = '7 Datenpannen'; Text = 'Mail an den falschen Verteiler, Notebook im Zug vergessen: Sagen Sie es sofort der Geschäftsführung. Für die Meldung an die Aufsichtsbehörde bleiben 72 Stunden, ab dem Moment, in dem wir davon wissen.' }
            ) }
        @{ Title = 'Klassifizierungsrichtlinie'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Warum vier Stufen'; Text = 'Ein Flyer, der in der Bäckerei ausliegt, darf jeder sehen, eine Gehaltsliste nicht einmal das halbe Team. Damit niemand raten muss, bekommt jedes Dokument eine von vier Stufen. Die Stufe legt fest, wer das Dokument erstellt. Im Zweifel gilt die höhere.' }
                @{ Title = '2 Öffentlich'; Text = 'Was veröffentlicht ist oder werden darf: Pressemitteilungen nach Freigabe, Stellenanzeigen, unsere Website, Kampagnenmotive nach dem Start. Achtung: Ein fertiges Motiv ist erst ab dem Starttermin öffentlich, vorher ist es vertraulich.' }
                @{ Title = '3 Intern'; Text = 'Für unser Team bestimmt, aber ohne Schaden, wenn es versehentlich nach draußen geht: Richtlinien, Vorlagen, Protokolle der Teamrunde, Telefonliste, Urlaubsplan. Intern ist die Standardstufe; was keine Kennzeichnung trägt, gilt als intern.' }
                @{ Title = '4 Vertraulich'; Text = 'Was uns oder einem Kunden schadet, wenn es die Falschen lesen: Angebote und Kalkulationen, Briefings, unveröffentlichte Entwürfe, Verträge, Kundenlisten, BWA, das Notfallhandbuch IT. Nur für die Projektbeteiligten und den Kunden selbst; nach außen nur verschlüsselt oder als Link mit Ablaufdatum. Ausdrucke bleiben nicht im Drucker liegen.' }
                @{ Title = '5 Streng vertraulich'; Text = 'Daten über einzelne Menschen, die ihnen ernsthaft schaden können: Personalakten, Gehälter und Entgeltabrechnungen, Krankmeldungen und alle anderen Gesundheitsdaten, Abmahnungen, Bewerbungen, Bankverbindungen, Zugangsdaten. Solche Dokumente liegen nur in Abteilungen\Personal oder Abteilungen\Geschäftsleitung, gehen nicht per Mail hinaus, nicht über die Freigabe Scans und nicht auf H:. Ausdrucke kommen in den abschließbaren Schrank der Geschäftsführung.' }
                @{ Title = '6 Kennzeichnung'; Text = 'Die Stufe steht rechts in der Kopfzeile und noch einmal in der Fußzeile, etwa „Klassifizierung: Vertraulich“. In Excel gehört sie in die Kopfzeile jedes Blatts, in PowerPoint auf den Folienmaster. Mit den Vertraulichkeitsbezeichnungen in Office wählen Sie die Stufe über die Schaltfläche „Vertraulichkeit“, Kopf- und Fußzeile setzt das Programm dann selbst.
Der Dateiname ersetzt keine Kennzeichnung. „Gehaelter_GEHEIM.xlsx“ ist kein Schutz, sondern ein Wegweiser.' }
            ) }
        @{ Title = 'Homeoffice-Richtlinie'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Umfang und Absprache'; Text = 'Wer mag, arbeitet bis zu zwei Tage pro Woche von zu Hause, Auszubildende einen. Die Tage stimmen Sie mit der Standortleitung ab und tragen sie bis Freitag für die Folgewoche in den Teamkalender ein. Montags um 9:30 Uhr ist Teamrunde, da sind alle im Büro; Hamburg wird per Video zugeschaltet.' }
                @{ Title = '2 Erreichbarkeit'; Text = 'Zwischen 10 und 15 Uhr sind Sie erreichbar wie im Büro: Telefon umgeleitet, Kalender aktuell. Kundentermine vor Ort und Abgaben gehen vor. Wer am Abgabetag die Druckdaten verantwortet, sitzt im Büro. Arbeitszeit, Pausen und Feierabend gelten zu Hause genauso.' }
                @{ Title = '3 Geräte und Verbindung'; Text = 'Gearbeitet wird nur auf dem Firmen-Notebook, nicht am privaten PC. Auf den Fileserver kommen Sie über VPN; ohne VPN kein Laufwerk H:. Monitor, Tastatur und Headset stellen wir auf Wunsch, Internet und Strom tragen Sie selbst. Das Notebook nutzt nur Sie, nicht die Familie und nicht für Hausaufgaben.' }
                @{ Title = '4 Vertraulichkeit zu Hause'; Text = 'Kundentelefonate führen Sie so, dass niemand mithört, also nicht auf dem Balkon. Ausdrucke mit Kundendaten kommen wieder mit ins Büro und dort in den Aktenvernichter, nicht ins Altpapier. Streng vertrauliche Unterlagen verlassen das Büro gar nicht.' }
                @{ Title = '5 Störungen'; Text = 'Fallen zu Hause Internet oder Strom aus, kommen Sie ins Büro oder bauen nach Absprache Überstunden ab. Einen Unfall während der Arbeit melden Sie wie im Büro sofort der Geschäftsführung.' }
            ) }
        @{ Title = 'Reisekostenrichtlinie'; Folder = 'General'; Classification = 'Internal'; Sections = @(
                @{ Title = '1 Genehmigung'; Text = 'Dienstreisen genehmigt vorab die Geschäftsführung, in Hamburg die Standortleitung. Eine kurze Mail mit Anlass, Datum und Verkehrsmittel genügt. Zwischen Berlin und Hamburg fahren wir Bahn, 2. Klasse mit Sitzplatzreservierung. Das Auto nur, wenn Material mitmuss (Messe, Fotoshooting) oder der Termin anders nicht erreichbar ist.' }
                @{ Title = '2 Fahrtkosten'; Text = 'Für den privaten Pkw erstatten wir 0,30 € je gefahrenem Kilometer, laut Routenplaner und ohne Umwege. Parkgebühren und Nahverkehr gegen Beleg. Taxi nur, wenn es nicht anders geht, etwa mit zwei Roll-ups und einem Messekoffer.' }
                @{ Title = '3 Verpflegung und Übernachtung'; Text = 'Wir zahlen die steuerlichen Pauschalen: 14 € bei mehr als 8 Stunden Abwesenheit und für An- und Abreisetag, 28 € für volle 24 Stunden. Ist das Frühstück im Hotelpreis enthalten, ziehen wir 5,60 € ab, für ein Essen, zu dem ein Kunde einlädt, 11,20 €.
Hotels bis 120 € pro Nacht buchen Sie selbst, teurere nach Rücksprache. Die Rechnung lautet auf {Firma} mit Anschrift Berlin, sonst gibt es keine Vorsteuer.' }
                @{ Title = '4 Belege und Abrechnung'; Text = 'Abgerechnet wird mit dem Formular aus Abteilungen\Allgemein\Vorlagen bis zum 10. des Folgemonats. Belege scannen Sie am Multifunktionsgerät in die Freigabe Scans, Dateiname Reisekosten_Name_Datum. Von dort übernimmt die Buchhaltung sie in ihren Ordner. Eigene Rechte auf Abteilungen\Buchhaltung braucht dafür niemand, auch nicht ausnahmsweise.
Die Originale kommen im Umschlag mit Name und Monat ins Fach Buchhaltung am Empfang Berlin; Hamburg schickt sie gesammelt zum Monatsende. Thermopapier verblasst, deshalb erst scannen, dann abgeben. Erstattet wird mit der nächsten Gehaltsabrechnung.' }
            ) }
        @{ Title = 'Notfallhandbuch IT'; Folder = 'IT'; Classification = 'Confidential'; Sections = @(
                @{ Title = '1 Wofür dieses Handbuch da ist'; Text = 'Es beschreibt die ersten Stunden nach einem IT-Ausfall, auch wenn niemand vom Fach im Haus ist. Ausgedruckt liegt es im roten Ordner im Technikraum Berlin, bei der Standortleitung Hamburg und bei der Geschäftsführung zu Hause. Ein Notfallhandbuch, das nur auf dem ausgefallenen Server liegt, hilft niemandem. Nummern und Namen prüft die Geschäftsführung jeden Januar.' }
                @{ Title = '2 Ansprechpartner'; Text = '• IT-Service Nordost GmbH: +49 30 23125-777, Mo–Fr 8–18 Uhr; außerhalb dieser Zeit Notdienst unter derselben Nummer, kostenpflichtig
• Geschäftsführung: Max Mustermann, +49 30 23125-100, Vertretung Erika Mustermann, +49 30 23125-500
• Standort Hamburg: Celina Herz, +49 40 66969-100
Notdiensteinsätze beauftragt nur die Geschäftsführung.' }
                @{ Title = '3 Ausfall Fileserver'; Text = '1. Betrifft es nur einen Platz? Kommen die Nachbarn auf H: und Projekte, liegt es am Arbeitsplatz, nicht am Server.
2. Betrifft es alle: Im Technikraum nachsehen, ob der Server läuft und die USV piept. Nicht aus- und wieder einschalten, schon gar nicht während der nächtlichen Sicherung.
3. IT-Service Nordost anrufen: seit wann, wer betroffen, was zuletzt geändert wurde.
4. Bis zur Lösung arbeiten alle in einem Ordner Notbetrieb auf dem Desktop und kopieren die Dateien danach selbst zurück.
5. Stehen Abgaben an, ruft die Projektleitung den Kunden noch am selben Tag an.' }
                @{ Title = '4 Verdacht auf Ransomware'; Text = 'Anzeichen: Dateien lassen sich nicht öffnen oder tragen eine fremde Endung, in Ordnern liegen neue Textdateien mit Zahlungsaufforderung.
1. Netzwerkkabel ziehen, WLAN aus. Das Gerät NICHT ausschalten: Im Arbeitsspeicher stecken Spuren für die Aufklärung.
2. Bildschirm mit dem Handy fotografieren, Uhrzeit notieren.
3. IT-Service Nordost und Geschäftsführung anrufen, nicht mailen.
4. Nichts mehr öffnen, keine USB-Sticks anstecken, nichts ausprobieren.
5. Kein Kontakt zu den Erpressern, keine Zahlung. Über Anzeige und Meldung an die Datenschutzbehörde (72 Stunden) entscheidet die Geschäftsführung.' }
                @{ Title = '5 Wiederanlauf'; Text = 'Den Wiederanlauf steuert die IT-Service Nordost mit der Geschäftsführung:
1. Ursache beseitigt, betroffene Geräte neu installiert.
2. Erst die Domänencontroller, dann Fileserver, dann Mailserver.
3. Rücksicherung aus der letzten sauberen Sicherung: zuerst Projekte, dann Abteilungen, zuletzt Home$.
4. Alle Kennwörter neu, auch die der Dienstkonten.
5. Jede Abteilung prüft Stichproben, bevor normal weitergearbeitet wird.
Danach schreibt die Geschäftsführung auf, was passiert ist, was geholfen hat und was wir ändern.' }
            ) }
    )

    CiHandbook = @(
        @{ Title = '1 Markenkern'; Text = 'Als Max und Erika Mustermann die Agentur gründeten, war unser Zeichen eine dunkelrote Wortmarke in einer Serifenschrift. Sie passte zu zwei Leuten, die Broschüren für den Mittelstand machten. Mit Hamburg, Social Media und Bildschirmen überall wurde sie zum Problem: Als Profilbild unleserlich, im Fax ein grauer Balken, und neben Kundenlogos sah das Rot aus wie Korrekturfarbe.
Das neue Zeichen ist ein „M“ aus zwei Flächen. Petrol steht für das Verlässliche: Termine, Reinzeichnung, Handwerk. Orange für die Idee, mit der keiner gerechnet hat. Erst beide zusammen ergeben das M, so wie Berlin und Hamburg, Konzept und Umsetzung. Daneben steht die Wortmarke „Mustermann Medien“.' }
        @{ Title = '2 Logo und Schutzraum'; Text = 'Das Logo gibt es in drei Fassungen: horizontal (Standard für Briefbogen, Dokumente, Website), gestapelt (quadratische Formate, Roll-ups) und die Bildmarke allein (Favicon, Profilbild).
Mindestgröße der horizontalen Fassung: 20 mm Breite im Druck, 120 px am Bildschirm. Darunter nehmen Sie die Bildmarke allein.
Rund um das Logo bleibt ein Schutzraum frei, so breit wie das M hoch ist. Dort hinein ragt nichts: kein Text, keine Bildkante, keine Falz. Alle Dateien liegen im Ordner Branding, als PDF für den Druck und als PNG und SVG für den Bildschirm.' }
        @{ Title = '3 Farben'; Text = 'Petrol ist die Hauptfarbe, Orange setzt Akzente. Faustregel: Höchstens ein Zehntel einer Seite ist orange.
• Petrol: HEX #005461, RGB 0/84/97, CMYK 100/30/20/50
• Orange: HEX #E87722, RGB 232/119/34, CMYK 0/60/95/0
• Hellgrau: HEX #F2F2F2, RGB 242/242/242, für Flächen und Tabellenzeilen
• Anthrazit: HEX #333333, RGB 51/51/51, für Fließtext statt reinem Schwarz
Orange ist für Fließtext auf Weiß zu hell, dafür nehmen Sie Petrol oder Anthrazit. Auf ungestrichenem Papier vorher einen Andruck anfordern, Petrol kippt dort leicht ins Graue.' }
        @{ Title = '4 Typografie'; Text = 'Für Dokumente nehmen wir Arial, für Präsentationen und Bildschirm Segoe UI. Beide sind auf jedem Rechner vorhanden, Kunden sehen unsere Dateien also so, wie wir sie gebaut haben.
• Fließtext Arial 10 pt, Anthrazit, Zeilenabstand 1,3
• Überschrift 1 Arial 16 pt fett, Petrol; Überschrift 2 Arial 12 pt fett, Anthrazit
• Fußzeile und Kleingedrucktes Arial 7,5 pt
Linksbündiger Flattersatz, nie Blocksatz. Für Kundenprojekte gelten deren Schriften, dieses Handbuch regelt nur unseren eigenen Auftritt.' }
        @{ Title = '5 Briefbogen und Dokumente'; Text = 'Briefe folgen DIN 5008, Form B. Das Logo steht oben rechts, 45 mm breit. Die Fußzeile hat drei Spalten: Anschrift Berlin, Anschrift Hamburg, Bank und Handelsregister.
Nehmen Sie immer die Vorlagen aus Abteilungen\Allgemein\Vorlagen. Kopieren Sie nie einen alten Brief, um ihn zu überschreiben: Viele ältere Dateien tragen noch das rote Logo, und das merkt man erst, wenn der Kunde anruft.
Rechts in der Kopfzeile steht die Klassifizierung, Dateinamen beginnen mit dem Datum (JJJJ-MM-TT_Kunde_Thema).' }
        @{ Title = '6 Präsentationen'; Text = 'Die Vorlage ist 16:9. Die Titelfolie ist vollflächig Petrol mit dem Logo in Weiß, Inhaltsfolien sind weiß mit kleiner Bildmarke unten rechts.
• Segoe UI, nicht kleiner als 20 pt
• höchstens sechs Stichpunkte; was mehr braucht, gehört ins Handout
• Kundenlogo nur auf Titel- und Schlussfolie
• Fotos randabfallend, ohne Rahmen und Schatten
Die Schlussfolie nennt eine Ansprechperson mit Durchwahl. Nur „Vielen Dank“ ist zu wenig.' }
        @{ Title = '7 Social Media und E-Mail'; Text = 'Das Profilbild ist die Bildmarke, weiß auf Petrol. In der runden Ansicht muss das M ganz im Kreis liegen, also vor dem Hochladen prüfen.
Unsere Bilder zeigen echte Menschen bei echter Arbeit: das Team am Layouttisch, einen Andruck im Gegenlicht, Hände am Lastenrad eines Kunden. Keine Stockfotos mit Handschlag vor Glasfassade.
Die E-Mail-Signatur ist Text plus Logo in 120 px Breite: Name, Funktion, Durchwahl, Standort. Keine Sprüche, keine Banner.' }
        @{ Title = '8 Dos und Don''ts'; Text = 'Bitte so:
• Logo immer aus dem Ordner Branding nehmen, nie aus einer alten Datei kopieren
• auf Fotos nur auf ruhigen Flächen, sonst auf eine Petrol-Fläche stellen
• einfarbig nur ganz in Anthrazit oder ganz in Weiß
Bitte nicht:
• verzerren, drehen, anschneiden, mit Schatten, Kontur oder Verlauf versehen
• die Farben der beiden Flächen tauschen
• auf unruhige Fotos oder Muster setzen
• die alte rote Wortmarke verwenden, auch nicht „nur intern“. Alte Visitenkarten und Stempel werden entsorgt, nicht aufgebraucht.
Fragen zur CI beantwortet Veronika Spula.' }
    )

    BrandingGuide = @(
        @{ Title = '1 Ziel'; Text = 'Wer sich bei Microsoft 365 anmeldet, sah bisher die Standardseite von Microsoft, und genau die bauen Phishing-Mails nach. Mit unserem Logo, unseren Farben und einem eigenen Hinweis sieht die echte Anmeldeseite unverwechselbar nach {Firma} aus. Fehlt das Logo, sollen alle stutzen und nichts eingeben.
Branding ersetzt keine Mehrfaktor-Anmeldung, denn auch unser Logo lässt sich kopieren. Es macht plumpe Fälschungen aber auffällig.' }
        @{ Title = '2 Voraussetzungen'; Text = '• Ein Konto mit der Rolle „Organizational Branding Administrator“. Globaler Administrator ginge auch, ist für diese Aufgabe aber zu mächtig. Die Rolle wird für die Einrichtung zugewiesen und danach wieder entfernt.
• Eine Lizenz mit Unternehmensbranding, etwa Entra ID P1 oder Microsoft 365 Business Standard.
• Die Dateien aus dem Ordner Branding. Sie sind nach dem CI-Handbuch exportiert; bitte nichts selbst zuschneiden oder neu speichern.' }
        @{ Title = '3 Welche Datei wohin gehört'; Text = '• Favicon (Basics): favicon_32x32.png, 32 x 32 px, höchstens 5 KB
• Hintergrundbild (Basics): hintergrund_1920x1080.jpg, 1920 x 1080 px, höchstens 300 KB
• Seitenhintergrundfarbe (Basics): #005461, sichtbar, solange das Bild lädt
• Kopfzeilenlogo (Header): logo_kopfzeile_245x36.png, 245 x 36 px, höchstens 10 KB
• Bannerlogo (Sign-in form): logo_banner_245x36.png, 245 x 36 px, höchstens 50 KB
• Quadratlogo hell und dunkel (Sign-in form): logo_quadrat_hell.png und logo_quadrat_dunkel.png, je 240 x 240 px, höchstens 50 KB
• Edge for Business: edge_logo.svg (breiter als hoch) und edge_taskleiste.svg (quadratisch), je höchstens 150 KB
Im Unterordner mit den alten Logos liegen noch die rote Wortmarke und das alte Favicon. Die werden nicht hochgeladen. Faustregel: Was dunkelrot ist oder Serifen hat, ist alt.' }
        @{ Title = '4 Schritt für Schritt'; Text = '1. Im Entra Admin Center mit dem Branding-Konto anmelden.
2. Entra ID > Custom Branding öffnen, bei Default sign-in auf Bearbeiten klicken.
3. Basics: Favicon, Hintergrundbild und Hintergrundfarbe.
4. Layout: Vorlage mit Teilbildschirm-Hintergrund, damit das Anmeldefeld das Foto nicht verdeckt; Kopfzeile einblenden.
5. Header: Kopfzeilenlogo.
6. Footer: Link „Privacy & Cookies“ auf unsere Datenschutzseite umstellen.
7. Sign-in form: Bannerlogo, beide Quadratlogos, Benutzernamenhinweis, Anmeldeseitentext.
8. Review + create, alles prüfen, Create.
Edge richten wir im Microsoft 365 Admin Center über den Edge-Verwaltungsdienst ein (Konfigurationsprofil, Organization branding).' }
        @{ Title = '5 Texte der Anmeldeseite'; Text = 'Die Texte stehen fertig im Dokument „Texte Anmeldeseite“, abgestimmt mit der Geschäftsführung. Bitte wörtlich übernehmen.
• Benutzernamenhinweis: höchstens 64 Zeichen, „Ihre Firmen-E-Mail-Adresse“
• Anmeldeseitentext: der lange Hinweis, höchstens 1024 Zeichen
• Kurzhinweis (150 Zeichen) und Support (300 Zeichen): für die neuen Hinweisfelder, sobald unser Mandant sie anbietet
• Fußzeile: Linktext und Adresse für Datenschutz und Nutzungsbedingungen
Die Anmeldeseite ist öffentlich: keine Durchwahlen, keine Servernamen, keine Namen von Mitarbeitenden.' }
        @{ Title = '6 Prüfen'; Text = 'Änderungen brauchen etwas Zeit, rechnen Sie mit bis zu einer Stunde.
1. Ein privates Browserfenster öffnen, damit nichts aus dem Zwischenspeicher kommt, und die Anmeldeseite von Microsoft 365 aufrufen.
2. Ein Testkonto ohne Adminrechte eingeben. Sobald der Name erkannt ist, erscheinen Hintergrund, Bannerlogo und Hinweis.
3. Favicon im Tab prüfen, dann am Handy und im dunklen Modus.
Stimmt alles: Rolle wieder entfernen und ein Bildschirmfoto in den Ordner Branding legen.' }
    )

    SignInText = @(
        @{ Title = 'Kurzhinweis'; Text = 'Nur für Beschäftigte von Mustermann Medien. Fehlt oben unser Logo, geben Sie nichts ein und rufen Sie die IT-Hotline an.' }
        @{ Title = 'Langer Hinweis'; Text = 'Über diese Seite melden Sie sich an Ihrem Arbeitskonto von Mustermann Medien an. Prüfen Sie vor der Eingabe Ihres Kennworts zwei Dinge: Sehen Sie unser Logo, das M in Petrol und Orange? Und haben Sie die Anmeldung selbst gestartet?
Wir fragen nie per E-Mail, Chat oder Telefon nach Ihrem Kennwort oder einem Bestätigungscode. Kommt auf Ihr Handy eine Anmeldeanfrage, die Sie nicht ausgelöst haben, lehnen Sie sie ab und melden Sie sich bei der IT-Hotline.
An fremden Rechnern wählen Sie bitte nicht „Angemeldet bleiben“ und melden sich nach der Arbeit ab.
Notebook oder Handy verloren? Sofort melden, auch am Wochenende: +49 30 23125-777.' }
        @{ Title = 'Support'; Text = 'Probleme bei der Anmeldung? IT-Hotline Mo–Fr 8–18 Uhr: +49 30 23125-777 oder support@mustermann-medien.example.com. Bitte nennen Sie Namen, Standort und die Fehlermeldung, ein Foto vom Bildschirm hilft.' }
        @{ Title = 'Fußzeile'; Text = 'Datenschutz: https://www.mustermann-medien.example.com/datenschutz
Nutzungsbedingungen: https://www.mustermann-medien.example.com/it-nutzung
© {Firma}, Berlin und Hamburg' }
    )

    Agreement = @(
        @{ Title = 'Mietvertrag Büroräume Berlin'; Party = 'Hausverwaltung Mitte GmbH'; Sections = @(
                @{ Title = '§ 1 Mietgegenstand'; Text = 'Vermietet werden die Büroräume im 3. Obergeschoss des Hauses Weg 1, 10117 Berlin, rund 240 m²: sechs Büros, ein Besprechungsraum, Teeküche, zwei WC und ein Technikraum ohne Fenster, dazu ein Kellerabteil von 8 m². Der Zustand bei Übergabe ergibt sich aus dem Übergabeprotokoll.' }
                @{ Title = '§ 2 Mietzeit'; Text = 'Das Mietverhältnis beginnt am {Termin} und ist für fünf Jahre fest geschlossen. Die Mieterin kann es einmal um fünf Jahre verlängern, wenn sie dies sechs Monate vor Ablauf schriftlich erklärt.' }
                @{ Title = '§ 3 Miete und Nebenkosten'; Text = 'Die Nettokaltmiete beträgt {Betrag} monatlich, zuzüglich einer Betriebskostenvorauszahlung von 4,20 € je m² und der gesetzlichen Umsatzsteuer. Die Miete ist bis zum dritten Werktag eines Monats fällig. Die Betriebskosten werden jährlich abgerechnet.' }
                @{ Title = '§ 4 Mietsicherheit'; Text = 'Die Mieterin stellt eine unbefristete Bankbürgschaft über drei Nettokaltmieten. Sie wird nach Rückgabe der Räume und Abrechnung aller Ansprüche zurückgegeben.' }
                @{ Title = '§ 5 Nutzung und Einbauten'; Text = 'Die Räume dienen als Büro einer Werbeagentur; Kundenbesuche und Veranstaltungen bis 22 Uhr sind erlaubt. Die Mieterin darf Netzwerkkabel verlegen und im Technikraum eine Kühlung einbauen. Die Kabel bleiben bei Auszug ohne Entschädigung in den Räumen. Ein Firmenschild bis 60 x 40 cm am Hauseingang ist nach Abstimmung erlaubt.' }
                @{ Title = '§ 6 Rückgabe und Schlussbestimmungen'; Text = 'Bei Vertragsende werden die Räume besenrein mit allen Schlüsseln und Transpondern zurückgegeben. Änderungen dieses Vertrags bedürfen der Schriftform.' }
            ) }
        @{ Title = 'Leasingvertrag Multifunktionsgerät'; Party = 'Bürowelt Schmidt GmbH'; Sections = @(
                @{ Title = '§ 1 Leasinggegenstand'; Text = 'Farb-Multifunktionsgerät DIN A3 zum Drucken, Kopieren, Scannen und Faxen, 45 Seiten pro Minute, mit Finisher, eingerichtet für Scan-to-Folder und Scan-to-Mail. Aufstellungsort ist das Büro Berlin, Seriennummer laut Lieferschein.' }
                @{ Title = '§ 2 Laufzeit'; Text = 'Der Vertrag beginnt mit der Übergabe am {Datum} und läuft 60 Monate. Eine ordentliche Kündigung vorher ist ausgeschlossen.' }
                @{ Title = '§ 3 Rate und Seitenpreise'; Text = 'Die Leasingrate beträgt {Betrag} monatlich zzgl. USt. Enthalten sind 3.000 Seiten schwarzweiß und 1.000 Seiten farbig im Monat. Mehrseiten kosten 0,9 Cent bzw. 6,5 Cent und werden vierteljährlich abgerechnet; die Zählerstände sendet das Gerät selbst.' }
                @{ Title = '§ 4 Service'; Text = 'Toner, Verschleißteile, Wartung und Reparatur sind enthalten, Papier nicht. Toner kommt automatisch bei 15 % Füllstand. Bei Störungen ist ein Techniker binnen acht Arbeitsstunden vor Ort.' }
                @{ Title = '§ 5 Netzwerk und Datenträger'; Text = 'Netzwerk und Scanziele richtet der IT-Dienstleister der Leasingnehmerin ein; die Leasinggeberin erhält keinen Zugang zum internen Netz. Das Gerät speichert Aufträge auf einer internen Festplatte. Bei Austausch oder Rückgabe wird sie gelöscht und ein Löschprotokoll übergeben. Ohne Protokoll verlässt keine Festplatte das Haus.' }
            ) }
        @{ Title = 'IT-Wartungsvertrag'; Party = 'IT-Service Nordost GmbH'; Sections = @(
                @{ Title = '§ 1 Gegenstand'; Text = 'Die Auftragnehmerin betreut die IT von {Firma} in Berlin und Hamburg: zwei Domänencontroller, Fileserver, Mailserver, 16 Arbeitsplätze und Notebooks, Firewall, Switches, WLAN und die VPN-Verbindung zwischen den Standorten. Die Geräteliste ist Anlage 1.' }
                @{ Title = '§ 2 Leistungen'; Text = 'Überwachung der Server und der Datensicherung an jedem Werktag; monatliche Sicherheitsupdates im Wartungsfenster (zweiter Mittwoch ab 19 Uhr); Hotline +49 30 23125-777, Mo–Fr 8–18 Uhr; vierteljährlich ein Wiederherstellungstest mit Protokoll; Pflege der Netzwerkdokumentation. Fernzugriff auf einen Arbeitsplatz nur, wenn die Person davor ihn bestätigt.' }
                @{ Title = '§ 3 Reaktionszeiten'; Text = 'Priorität 1 (Server oder Internet eines Standorts ausgefallen): Rückruf in 30 Minuten, Arbeitsbeginn in zwei Stunden. Priorität 2 (einzelner Arbeitsplatz): vier Stunden. Priorität 3 (Anfragen, Änderungen): nächster Werktag.' }
                @{ Title = '§ 4 Vergütung'; Text = 'Die Pauschale beträgt {Betrag} monatlich zzgl. USt. Weitere Arbeiten werden mit 95 € je Stunde berechnet, außerhalb der Servicezeit mit 50 % Zuschlag und nur auf Anweisung der Geschäftsführung.' }
                @{ Title = '§ 5 Auftragsverarbeitung'; Text = 'Die Auftragnehmerin hat Zugriff auf personenbezogene Daten, auch auf Personal- und Kundendaten. Sie verarbeitet sie nach Art. 28 DSGVO nur auf Weisung der Auftraggeberin, setzt Unterauftragnehmer nur mit schriftlicher Zustimmung ein und meldet Datenschutzverletzungen innerhalb von 24 Stunden. Nach Vertragsende gibt sie alle Daten zurück oder löscht sie nachweislich. Die technischen und organisatorischen Maßnahmen sind Anlage 2.' }
                @{ Title = '§ 6 Zugänge und Laufzeit'; Text = 'Jeder Techniker arbeitet mit einem persönlichen Administratorkonto, nie mit einem gemeinsamen. Scheidet er aus, wird sein Konto am selben Tag gesperrt. Der Vertrag beginnt am {Datum}, läuft zwölf Monate und verlängert sich um jeweils zwölf Monate, wenn er nicht drei Monate vor Ablauf gekündigt wird.' }
            ) }
        @{ Title = 'Rahmenvertrag Agenturleistungen'; Party = '{Kunde}'; Sections = @(
                @{ Title = '§ 1 Gegenstand'; Text = 'Dieser Vertrag regelt alle Leistungen, die {Kunde} (Auftraggeber) bei {Firma} (Agentur) abruft: Konzeption, Gestaltung, Text, Reinzeichnung, Social Media und Projektmanagement. Jeder Einzelauftrag beginnt mit einem Angebot und einer Bestätigung in Textform; eine E-Mail genügt.' }
                @{ Title = '§ 2 Stundensätze'; Text = 'Netto je Stunde: Konzeption 110 €, Grafikdesign 95 €, Text 88 €, Projektmanagement 82 €, Reinzeichnung 78 €. Abgerechnet wird in Viertelstunden. Die Sätze gelten zwölf Monate fest; Anpassungen danach kündigt die Agentur drei Monate vorher an, höchstens 5 % im Jahr.' }
                @{ Title = '§ 3 Freigaben'; Text = 'Zwei Korrekturschleifen sind im Angebot enthalten, weitere werden nach Aufwand berechnet. Freigaben erteilt {Ansprechpartner} oder eine benannte Vertretung in Textform. Mit der Druckfreigabe übernimmt der Auftraggeber die Verantwortung für Inhalt und Rechtschreibung.' }
                @{ Title = '§ 4 Nutzungsrechte'; Text = 'Mit vollständiger Bezahlung erhält der Auftraggeber an den freigegebenen Arbeiten die ausschließlichen Nutzungsrechte für die im Einzelauftrag genannten Medien, zeitlich und räumlich unbegrenzt. Nicht gewählte Entwürfe bleiben bei der Agentur. Fotos und Schriften Dritter gelten nur im erworbenen Umfang, etwa zwei Jahre Print und Online. Veröffentlichte Arbeiten darf die Agentur mit Zustimmung als Referenz zeigen.' }
                @{ Title = '§ 5 Fremdkosten und Abrechnung'; Text = 'Druck, Fotografie und Mediaschaltungen beauftragt die Agentur im Namen des Auftraggebers oder, nach Absprache, im eigenen Namen mit 10 % Aufschlag. Abgerechnet wird monatlich mit Stundennachweis, zahlbar in 14 Tagen. Das geplante Jahresvolumen von {Budget} ist keine Abnahmepflicht.' }
                @{ Title = '§ 6 Vertraulichkeit und Laufzeit'; Text = 'Kampagnen vor dem Start, Preise und Kundendaten bleiben vertraulich. Verarbeitet die Agentur Adressen im Auftrag, etwa für ein Mailing, wird vorher ein Vertrag zur Auftragsverarbeitung geschlossen. Der Vertrag gilt ab {Datum} für zwölf Monate und verlängert sich um je ein Jahr, wenn ihn keine Seite drei Monate vor Ablauf kündigt.' }
            ) }
    )

    ItDoc = @(
        @{ Title = 'Projektplan Fileserver-Umzug'; Text = 'Ausgangslage: Die alte NAS aus der Gründungszeit ist zu 94 % voll, kennt nur „alle dürfen alles“ und ist aus Hamburg über VPN quälend langsam.
Ziel: ein Windows-Fileserver mit den Freigaben Abteilungen, Projekte, Archiv, Scans und Home$, Rechte nur über Gruppen, Vorgängerversionen, nächtliche Sicherung.
1. Aufräumen bis {Vortermin}: Jedes Team löscht Dubletten. Ansprechpartner sind Veronika Spula (Berlin) und Johann Frick (Hamburg).
2. Aufbau bis {Datum}: Server und Gruppen durch die IT-Service Nordost; die Geschäftsleitung gibt das Rechtekonzept frei.
3. Umzug am {Termin}: Freitag ab 16 Uhr ist die NAS schreibgeschützt, kopiert wird übers Wochenende, Montag 8 Uhr geht es los.
4. Nacharbeit bis {Termin2}: Die NAS bleibt vier Wochen lesbar, dann wird sie abgeschaltet.
Risiken: Pfade über 260 Zeichen („final_neu_wirklich_final“), Bildverknüpfungen in Layouts zeigen auf alte Pfade, Abgaben in der Umzugswoche. Darum vorab eine Pfadliste, Verknüpfungen im Test prüfen und kein Umzug in einer Messewoche.' }
        @{ Title = 'Konzept Datensicherung'; Text = 'Gesichert werden alle Freigaben des Fileservers sowie der Systemzustand der Domänencontroller und des Mailservers. Nicht gesichert: Desktop, lokale Dokumente, USB-Sticks.
Montag bis Donnerstag um 22 Uhr inkrementell, freitags vollständig. Wir behalten 14 Tages-, 8 Wochen- und 12 Monatssicherungen. Die Wochensicherung geht zusätzlich verschlüsselt nach Hamburg, damit ein Wasserschaden in Berlin nicht Server und Sicherung zugleich trifft.
Vorgängerversionen entstehen werktags um 7 und 12 Uhr. Damit holen sich alle versehentlich überschriebene Dateien selbst zurück; eine Sicherung ersetzen sie nicht.
Wiederherstellungstest: Einmal im Quartal stellt die IT-Service Nordost einen zufällig gewählten Projektordner in einen Testpfad zurück und vergleicht ihn mit dem Original. Dauer und Ergebnis kommen ins Protokoll, die Geschäftsführung zeichnet ab. Eine Sicherung, die nie zurückgespielt wurde, ist nur eine Hoffnung.' }
        @{ Title = 'Netzwerkdokumentation – Einleitung'; Text = 'Diese Dokumentation beschreibt das Netzwerk von {Firma} in Berlin und Hamburg. Sie ist für die IT-Service Nordost und für alle, die im Notfall verstehen müssen, was wo steht. Kennwörter stehen hier nicht, sie liegen im Kennwortsafe.
Berlin ist der Hauptstandort mit dem Technikraum. Die Server stehen im Netz 10.0.1.0/24: Domänencontroller 10.0.1.4 und 10.0.1.6, Mailserver 10.0.1.5, Fileserver 10.0.1.7. Arbeitsplätze und Drucker bekommen ihre Adressen per DHCP. Hamburg ist über eine dauerhafte VPN-Verbindung angebunden und hat keine eigenen Server.
Die folgenden Kapitel listen Geräte, Adressen und Lizenzen. Wer etwas ändert, trägt es am selben Tag ein. Stand: {Datum}.' }
        @{ Title = 'Übergabeprotokoll Notebook'; Text = 'Übergabe an: {Mitarbeiter}, {Stelle}, Eintritt {Eintritt}
Übergeben von: {Ich}, {Standort}, am {Datum}
Gerät: Notebook 14 Zoll mit Netzteil, Headset und Tasche. Inventarnummer MM-NB-____, Seriennummer ____________
Zustand: neu / gebraucht, Auffälligkeiten: ____________
Gemeinsam geprüft: Anmeldung mit eigenem Konto, Kennwort selbst gesetzt, Laufwerk H: verbunden, E-Mail, Drucker, VPN, Festplattenverschlüsselung aktiv.
Ich habe die IT-Richtlinie erhalten. Ich nutze das Gerät nur dienstlich und gebe es nicht weiter. Verlust oder Diebstahl melde ich sofort unter +49 30 23125-777. Am letzten Arbeitstag gebe ich das Gerät mit Zubehör zurück.
Unterschrift übergebende Person: ____________   Unterschrift {Mitarbeiter}: ____________' }
    )

    KickoffSlide = @(
        @{ Title = 'Jahresauftakt'; Text = '{Firma}, Berlin und Hamburg
{Datum}, Besprechungsraum Berlin, Hamburg per Video
Max und Erika Mustermann
Danach Frühstück für alle, in Hamburg geht es auf die Firma' }
        @{ Title = 'Rückblick'; Text = 'Das war {Jahr}:
52 Projekte abgeschlossen, 11 davon für Neukunden
Größter Auftrag: {Projekt} für {Kunde}
Eigene Website neu, erstes Recruiting-Video in eigener Sache
Weniger schön: Ein langjähriger Kunde hat im Herbst gekündigt' }
        @{ Title = 'Zahlen'; Text = 'Umsatz +{Prozent} % zum Vorjahr
Auslastung im Schnitt 81 %, im November über 100 %
Anteil Hamburg am Umsatz: 34 %
Offene Forderungen zum Jahresende: {Betrag}
Weniger Krankheitstage, danke fürs Auskurieren statt Durchziehen' }
        @{ Title = 'Drei Ziele, nicht zehn'; Text = '1. Jeder Stammkunde bekommt ein Jahresgespräch, nicht erst, wenn es brennt
2. Ab der dritten Korrekturschleife wird abgerechnet, ohne schlechtes Gewissen
3. Freitags nach 16 Uhr keine Abgaben mehr, Ausnahmen nur mit Ansage' }
        @{ Title = 'Neue Kunden und Projekte'; Text = '{Kunde}: {Projekt}, Start {Termin}
Ausschreibung eines Energieversorgers: Präsentation am {Termin2}
Rahmenvertrag mit einem Hamburger Kunden verlängert
Mehr Anfragen aus der Branche {Branche}, dort bauen wir Referenzen auf' }
        @{ Title = 'Team'; Text = 'Neu an Bord: {Mitarbeiter} als {Stelle}
Wir bilden wieder aus: ab August Kaufleute für Büromanagement
Weiterbildung: 1.000 € pro Kopf, Vorschläge an die Standortleitung
Teamtag im Juni in Hamburg, Regenjacken mitbringen' }
        @{ Title = 'Termine'; Text = 'Urlaubsplanung bis 31. Januar in den Teamkalender
Mitarbeitergespräche bis Ende März
Schulung Klassifizierung im Februar, eine Stunde je Standort
Sommerfest am letzten Freitag vor den Berliner Sommerferien
Fragen? Jetzt, oder später bei Max und Erika' }
    )
}
