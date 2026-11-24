# Textkorpus der Beispieldokumente

Aus diesen Dateien erzeugt `scripts/New-SampleDocuments.ps1` auf dem Fileserver Word-, Excel-, PowerPoint- und PDF-Dokumente der fiktiven **Mustermann Medien GmbH**, einer Werbeagentur mit Zentrale in Berlin und Niederlassung in Hamburg. Die erzeugten Dokumente liegen nie im Repo, nur diese Quellen.

| Datei | Inhalt |
| --- | --- |
| `Company.psd1` | Drehbuch: Firma, Corporate Identity, Zeitleiste, Mitarbeitende (aktuell und ehemalig), Kunden, Lieferanten, Leistungen, Listen, Beschriftungen, Ordnernamen |
| `Texts-Projects.psd1` | Texte rund um Kundenprojekte: Anfrage, Angebot, Briefing, Konzept, Entwurf, Korrektur, Freigabe, Bericht, Pressemitteilung |
| `Texts-Office.psd1` | Protokolle, Briefe, Mahnungen, Rundschreiben zu Firmenereignissen, Notizen, Privates |
| `Texts-People.psd1` | Personal: Arbeitsvertrag, Zeugnisse, Bewerbungen, Mitarbeitergespräche, Onboarding |
| `Texts-Company.psd1` | Richtlinien und Handbücher, CI-Handbuch, Entra-Branding-Anleitung, Verträge, IT-Dokumentation, Jahresauftakt |

`tools/Build-SampleArtifacts.ps1` packt alle `*.psd1` dieses Ordners in `scripts/SampleCorpus.gz`. Dieses Paket geht als `userData` auf die VM und darf höchstens 48 KB haben, denn `userData` erlaubt 64 KB Base64. Dasselbe Skript packt den Generator in `scripts/Start-SampleDocuments.ps1`. Ein Pester-Test prüft Größe und Übereinstimmung mit den Quellen. **Nach jeder Änderung hier oder am Generator das Build-Skript ausführen.**

Besondere Listen in `Company.psd1`:

- `Suppliers[].Items` und `Shops[].Items`: Posten als `Text|Preis von|Preis bis|Einheit|Menge bis` (Einheit und Menge optional), Preise mit Punkt als Dezimaltrennzeichen.
- `Motifs`: Werbemittel. Ohne `Match` für jedes Projekt wählbar, mit `Match` (regulärer Ausdruck auf den Projektnamen) nur für passende Projekte, etwa die Messewand für einen Messeauftritt. `Pages` = Seiten oder Motive einer Serie, `Layout` = `Brochure`, `Series` oder `Web`. Das Format (`File`) braucht einen Eintrag in `$ShapeSizes` des Generators.

## Format

- PowerShell-Datendatei (`.psd1`), UTF-8 **mit BOM**, LF-Zeilenenden. Nur Literale: Zeichenketten in einfachen Anführungszeichen, Apostroph als `''` verdoppeln, `@( )` und `@{ }`.
- Jede Text-Datei ist eine Hashtable: Schlüssel = **Art** (siehe unten), Wert = Liste von **Einträgen**.
- Ein Eintrag ist eine Hashtable mit `Text` und optional:
  - `Industry`: passt nur zu Kunden dieser Branche
  - `Voice`: wird nur verwendet, wenn genau diese Person schreibt
  - `Level`, `Grade`, `Event`, `Subject`, `Title`: je nach Art, siehe Tabelle
- Einträge ohne `Industry` oder `Voice` sind allgemein verwendbar. **Jede Art braucht genügend allgemeine Einträge**, damit es für jede Kombination einen Text gibt.
- Absätze innerhalb von `Text` mit `\n` trennen, als echter Zeilenumbruch im String (Zeilenumbruch innerhalb der einfachen Anführungszeichen).

## Platzhalter

Der Generator ersetzt sie. Andere geschweifte Klammern sind verboten, ein Test prüft das.

| Platzhalter | Bedeutung | Beispiel |
| --- | --- | --- |
| `{Firma}` | eigene Firma | Mustermann Medien GmbH |
| `{Standort}` | Standort der schreibenden Person | Berlin |
| `{Kunde}` / `{KundeKurz}` | Kundenname lang/kurz | Bäckerei Krume & Kruste KG / Krume und Kruste |
| `{Anrede}` | Briefanrede an den Kundenkontakt, ohne Komma | Sehr geehrte Frau Böhm |
| `{Ansprechpartner}` | Kontakt beim Kunden | Frau Annika Böhm |
| `{Branche}`, `{Produkt}`, `{Stadt}` | Branche, Hauptprodukt, Ort des Kunden | Gastronomie, Brot aus Natursauerteig, Berlin |
| `{Projekt}` | Projektname | Weihnachtsmailing |
| `{Zielgruppe}`, `{Kanal}`, `{Kanal2}` | aus den Listen in Company.psd1 | Familien mit Kindern, Instagram, Plakate |
| `{Claim}` | Kampagnen-Claim | Gut. Von hier. |
| `{Datum}` | Datum des Dokuments | 14.03.2023 |
| `{Termin}`, `{Termin2}` | spätere Termine (Abgabe, Start) | 28.03.2023 |
| `{Vortermin}` | früherer Termin (Briefing, letztes Treffen) | 02.03.2023 |
| `{Monat}`, `{Jahr}`, `{Quartal}` | Zeitraum | März, 2023, Q1 |
| `{Betrag}`, `{Budget}` | Geldbetrag mit Euro, deutsch formatiert | 12.450,00 € |
| `{Stunden}`, `{Auflage}`, `{Prozent}` | Zahlen | 36, 5.000, 18 |
| `{Ich}`, `{IchVorname}` | schreibende Person | Erika Mustermann, Erika |
| `{Kollege}`, `{KollegeVorname}` | eine andere Person aus dem Team | Karl Anders, Karl |
| `{Leitung}` | Leitung des Standorts | Celina Herz |
| `{Mitarbeiter}` | betroffene Person (Personal) | Lea Mayer |
| `{Stelle}` | Stellenbezeichnung | Mediengestalter/in Digital und Print |
| `{Bewerber}` | Name eines Bewerbers | Greta Lorenz |
| `{Eintritt}`, `{Austritt}` | Daten im Arbeitsverhältnis | 01.04.2019 |
| `{Lieferant}` | Lieferant | Nordlicht Druckerei GmbH |
| `{Motiv}` | Bildmotiv-Beschreibung | Familie lädt Lastenrad vor dem Laden |

## Branchen (`Industry`)

`Handel`, `Gastronomie`, `Hotellerie`, `Handwerk`, `Gesundheit`, `Bildung`, `Freizeit`, `Immobilien`, `Energie`, `IT`, `Verein`, `Kultur`

## Stimmen (`Voice`) der Mitarbeitenden

| Voice | Person | Schreibstil |
| --- | --- | --- |
| `MMustermann` | Max Mustermann, Geschäftsführer | förmlich, knapp, Zahlen zuerst, keine Ausrufezeichen |
| `EMustermann` | Erika Mustermann, Geschäftsführerin Marketing | herzlich, motivierend, gern Ausrufezeichen, „ihr“ im Team |
| `JDoe` | John Doe, Leiter Marketing Berlin | Stichpunkte, Abkürzungen (KW, tbd, asap, FYI), Anglizismen |
| `KAnders` | Karl Anders, Grafiker Berlin | kreativ, ausschweifend, Bildsprache, Gedankenstriche |
| `VSpula` | Veronika Spula, Grafikerin Berlin | präzise, strukturiert, nummeriert |
| `LMayer` | Lea Mayer, Junior-Grafikerin Berlin | locker, jung, „:-)“, kurze Sätze |
| `CHerz` | Celina Herz, Leitung Hamburg | pragmatisch, direkt, lösungsorientiert |
| `WErnst` | Wolfgang Ernst, Senior-Grafiker Hamburg | erfahren, etwas altmodisch, „wie früher bei …“ |
| `JFrick` | Johann Frick, Grafiker Hamburg | knapp, technisch (Farbprofile, Beschnitt, dpi) |
| `SHarz` | Sascha Harz, Grafiker Hamburg | humorvoll, Wortspiele |
| `WLonska` | Wioletta Lonska, Grafikerin Hamburg | sorgfältig, freundlich, fragt nach |
| `RJung` | Robert Jung, Junior Hamburg | unsicher, viele Rückfragen, entschuldigt sich |

## Arten

`Texts-Projects.psd1`

| Art | Felder | Inhalt |
| --- | --- | --- |
| `RequestNote` | Text, Voice? | interne Notiz zu einer neuen Kundenanfrage (Telefonat, Mail) |
| `OfferIntro`, `OfferClose` | Text | Einleitung und Schluss eines Angebotsschreibens (nach `{Anrede},`) |
| `BriefingBackground`, `BriefingAudience` | Text, Industry | Hintergrund und Zielgruppe im Briefing |
| `BriefingGoal`, `BriefingMandatory`, `BriefingTiming` | Text | Ziel, Pflichtvorgaben, Zeitplan im Briefing |
| `ConceptSituation`, `ConceptIdea` | Text, Industry | Ausgangslage, Leitidee im Konzept |
| `ConceptGoals`, `ConceptMeasures`, `ConceptRisks` | Text | Ziele, Maßnahmen, Risiken und offene Punkte |
| `Claim` | Text, Industry | kurzer Kampagnen-Claim |
| `AdCopy` | Text, Industry | Anzeigen- oder Flyertext, 1 bis 3 Sätze |
| `Motif` | Text, Industry | Beschreibung eines Bildmotivs für Bildplatzhalter |
| `CustomerFeedback` | Text | Korrekturwunsch des Kunden |
| `InternalComment` | Text, Voice? | Kommentar einer Kollegin oder eines Kollegen im Word-Dokument |
| `PrintRelease` | Text | Druckfreigabe des Kunden oder Bestätigung an die Druckerei |
| `ReportSummary`, `ReportLearnings` | Text | Ergebnis und Lehren im Kampagnenbericht |
| `PressHeadline`, `PressBody`, `PressQuote` | Text | Pressemitteilung |
| `NextStep` | Text | Stichpunkt „Nächste Schritte“ auf einer Folie |
| `CancelNote` | Text, Voice? | Notiz: Projekt abgesagt oder verschoben |

`Texts-Office.psd1`

| Art | Felder | Inhalt |
| --- | --- | --- |
| `MinutesTopic` | Title, Text | Tagesordnungspunkt mit Diskussion und Ergebnis, mehrere Absätze |
| `LetterCustomer` | Subject, Text | Brief an Kunden (Terminbestätigung, Dank, Jahreswechsel, Preisanpassung …) |
| `LetterSupplier` | Subject, Text | Brief an Lieferanten (Reklamation Druck, Rahmenvertrag, Kündigung …) |
| `Reminder` | Level (1 oder 2), Text | Zahlungserinnerung, Mahnung |
| `Announcement` | Event, Subject, Text | Rundschreiben zu einem Firmenereignis, Event siehe unten |
| `HomeNote` | Text, Voice? | Arbeitsnotiz im eigenen Basisordner |
| `PrivateNote` | Subject, Text | Privates, das eigentlich nicht auf den Server gehört |

Firmenereignisse (`Event`): `Founding`, `Hamburg`, `Move`, `Rebranding`, `Scanner`, `Homeoffice`, `Anniversary`, `FileServer`, `CustomerLost`, `FrameworkContract`, `Christmas`, `Summer`

`Texts-People.psd1`

| Art | Felder | Inhalt |
| --- | --- | --- |
| `ContractParagraph` | Title, Text | Paragraph des Arbeitsvertrags (§ 1 …), vollständig in Reihenfolge |
| `Reference` | Grade (1 bis 3), Text | Arbeitszeugnis, vollständiger Fließtext je Notenstufe |
| `CoverOpening`, `CoverExperience`, `CoverMotivation`, `CoverClosing` | Text | Bausteine eines Bewerbungsanschreibens |
| `CvStation` | Text | Station im Lebenslauf |
| `ApplicationReply` | Subject, Text | Einladung oder Absage an Bewerbende |
| `ReviewNote` | Text | Notiz zum Mitarbeitergespräch (vertraulich) |
| `Warning` | Text | Abmahnung (streng vertraulich) |
| `OnboardingSlide` | Title, Text | Folie „Willkommen bei {Firma}“, Stichpunkte mit `\n` getrennt |

`Texts-Company.psd1`

| Art | Felder | Inhalt |
| --- | --- | --- |
| `Policy` | Title, Folder, Classification, Sections | ganze Richtlinie; Sections = Liste aus `@{ Title; Text }` |
| `CiHandbook` | Title, Text | Kapitel des Corporate-Design-Handbuchs |
| `BrandingGuide` | Title, Text | Kapitel der Anleitung Entra-Branding |
| `SignInText` | Title, Text | Texte für die Anmeldeseite (Kurzhinweis, langer Hinweis, Support, Fußzeile) |
| `Agreement` | Title, Party, Sections | Vertrag mit Paragraphen (Miete, Leasing, Wartung, Rahmenvertrag) |
| `ItDoc` | Title, Text | IT-Dokumentation (Fileserver-Umzug, Datensicherung, Netzwerk) |
| `KickoffSlide` | Title, Text | Folie Jahresauftakt der Geschäftsleitung |

## Schreibregeln

- **Konkret statt allgemein:** echte Zahlen, Termine, Orte, Namen über Platzhalter, Entscheidungen, auch Uneinigkeit, offene Punkte, Verweise auf frühere Termine.
- **Keine Floskeln:** nicht „in der heutigen schnelllebigen Welt“, „ganzheitlich“, „Synergien heben“, „spannende Reise“. Keine Aufzählungen nur des Aufzählens wegen.
- Länge passt zur Art: Notizen sind kurz, Richtlinien und Konzepte ausführlich.
- Stimmen erkennbar machen. In Notizen und Protokollen sind vereinzelte Tippfehler und Umgangssprache erlaubt.
- **Nur fiktive Daten:**
  - Domains nur `*.example.com`, `*.example.org` oder `*.example.net`.
  - Telefon nur `+49 30 23125-…` (Berlin) oder `+49 40 66969-…` (Hamburg). Der Generator nutzt für Privatpersonen zusätzlich die übrigen Rufnummern der Bundesnetzagentur für Medienproduktionen (Köln, München, Frankfurt, Mobil).
  - Keine echten Firmen, Marken oder Personen.
- Keine Emojis: Die PDF-Ausgabe kennt nur WinAnsi. Erlaubt sind Umlaute, ß, €, –, „“ und •.
- **Keine typografischen Apostrophe ‚ ‘ ’.** PowerShell wertet sie wie `'` und beendet damit den String. Stattdessen ein gerades `'` verdoppeln: `''`.
