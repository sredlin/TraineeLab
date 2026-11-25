# Texte rund um Kundenprojekte (siehe README.md)
@{
    RequestNote = @(
        @{ Voice = 'JDoe'; Text = 'Call mit {Ansprechpartner} ({KundeKurz}), {Datum}:
- wollen {Projekt}, Start idealerweise {Termin2}
- Budget „so um die“ {Budget}, final tbd
- Kanäle: {Kanal} + {Kanal2}, Print eher nice to have
- Angebot asap, spätestens {Termin}. FYI {KollegeVorname}' }
        @{ Voice = 'MMustermann'; Text = 'Anfrage {Kunde} vom {Datum}. Projekt: {Projekt}. Budgetrahmen laut Kunde {Budget}, Aufwand geschätzt {Stunden} Stunden. Letzte Rechnung wurde erst nach Mahnung bezahlt, daher 30 Prozent Abschlag bei Auftrag. Angebot bis {Termin} zur Freigabe vorlegen.' }
        @{ Voice = 'EMustermann'; Text = 'Ihr Lieben, {Ansprechpartner} hat eben angerufen – {KundeKurz} will {Projekt} mit uns machen! Sie war von unserem Termin am {Vortermin} noch ganz angetan. Ich hätte gern {KollegeVorname} mit im Boot. Wer hat diese Woche Luft? Das Angebot muss bis {Termin} raus!' }
        @{ Voice = 'CHerz'; Text = 'Mail von {Ansprechpartner}: {Projekt}, Wunschtermin {Termin2}. Machbar, wenn wir Fotos aus dem Bestand nehmen und auf ein eigenes Shooting verzichten. Habe ich so angedeutet. Angebot schreibe ich, {KollegeVorname} schätzt bitte bis morgen den Gestaltungsaufwand.' }
        @{ Voice = 'LMayer'; Text = 'Hatte grad {Ansprechpartner} am Telefon :-) Die wollen {Projekt}, aber erst nach dem Sommer. Budget wusste sie nicht. Hab gesagt, wir melden uns bis {Termin}. Kann das jemand übernehmen, der sowas schon mal kalkuliert hat?' }
        @{ Voice = 'RJung'; Text = 'Entschuldigung, falls das schon jemand weiß: {Ansprechpartner} von {KundeKurz} hat am {Datum} wegen {Projekt} angerufen. Ich habe gesagt, dass sich jemand meldet. War das richtig? Rückruf am besten vormittags. Soll ich schon mal einen Projektordner anlegen?' }
        @{ Text = 'Telefonnotiz {Datum}: {Ansprechpartner} ({Kunde}) fragt nach {Projekt}. Vorbild sei das, was wir am {Vortermin} gezeigt haben, nur kleiner. Auflage ca. {Auflage} Stück, Liefertermin spätestens {Termin2}. Offen: Wer schreibt die Texte? Rückruf zugesagt bis {Termin}.' }
        @{ Text = 'Anfrage per Mail von {Ansprechpartner}: {Projekt} über {Kanal}. Sie fragen noch zwei andere Agenturen, Preis ist also Thema. Vorschlag: Basispaket ohne Shooting für ca. {Betrag}, Shooting als Option. Entscheidung bei {Leitung}.' }
    )
    OfferIntro = @(
        @{ Text = 'vielen Dank für das Gespräch am {Vortermin}. Wie besprochen erhalten Sie heute unser Angebot für {Projekt}. Wir haben es in zwei Teile gegliedert: Konzept und Gestaltung zum Festpreis, Druck und Schaltung nach tatsächlichem Aufwand.' }
        @{ Text = 'gern machen wir Ihnen ein Angebot für {Projekt}. Grundlage sind Ihre Mail vom {Vortermin} und unsere bisherigen Projekte für {KundeKurz}. Wo Angaben noch fehlten, haben wir Annahmen getroffen und im Angebot kenntlich gemacht.' }
        @{ Text = 'nach unserem Termin bei Ihnen in {Stadt} haben wir die Ideen sortiert und gerechnet. Ihr Budget von {Budget} reicht für alles, was Sie genannt haben, mit einer Ausnahme: Das Fotoshooting führen wir als Option auf.' }
        @{ Text = 'anbei unser überarbeitetes Angebot für {Projekt}. Es ersetzt die Fassung vom {Vortermin}: Wie besprochen haben wir die Auflage auf {Auflage} Stück erhöht und einen zweiten Korrekturlauf aufgenommen.' }
    )
    OfferClose = @(
        @{ Text = 'Das Angebot gilt bis zum {Termin}. Damit wir den Start am {Termin2} halten können, bräuchten wir Ihre Zusage spätestens eine Woche vorher.' }
        @{ Text = 'Wenn Ihnen einzelne Positionen zu hoch erscheinen, sprechen Sie uns bitte an. Meist lässt sich über Auflage oder Anzahl der Motive etwas bewegen, ohne dass das Ergebnis leidet.
Wir freuen uns auf die Zusammenarbeit.' }
        @{ Text = 'Alle Preise verstehen sich zuzüglich Umsatzsteuer. Fremdleistungen wie Druck und Bildlizenzen rechnen wir ohne Aufschlag ab und legen die Belege bei. Das Angebot ist 30 Tage gültig.' }
        @{ Text = 'Sobald Sie den Auftrag bestätigen, schicken wir Ihnen einen Terminplan und die Liste der Unterlagen, die wir von Ihnen brauchen. Am schnellsten geht es, wenn Logo, Texte und Bilder bis {Termin} bei uns sind.' }
    )
    BriefingBackground = @(
        @{ Industry = 'Retail'; Text = 'Das Geschäft lebt von Laufkundschaft. Seit dem Umbau der Straße kommen weniger Leute vorbei. Das Sortiment an {Produkt} ist gewachsen, aber kaum jemand weiß davon.' }
        @{ Industry = 'Hospitality'; Text = 'Mittags ist es voll, abends bleiben Tische leer. Die neue Saisonkarte startet im {Monat}, der Lieferdienst läuft seit einem Jahr, ist aber kaum bekannt.' }
        @{ Industry = 'Hotel'; Text = 'Im Sommer ist das Haus ausgebucht, von November bis März liegt die Auslastung bei rund {Prozent} Prozent. Die {Produkt} sollen die Nebensaison füllen.' }
        @{ Industry = 'Crafts'; Text = 'Die Auftragslage ist gut, das Problem sind die Leute: Zwei Gesellen gehen in Rente, auf die letzte Stellenanzeige kamen drei Bewerbungen. Aufträge werden schon abgelehnt.' }
        @{ Industry = 'Health'; Text = 'Mehr Patientinnen und Patienten sollen {Produkt} nutzen. Werbung ist eng geregelt: Das Heilmittelwerbegesetz verbietet Heilversprechen, auch Vorher-nachher-Vergleiche sind tabu.' }
        @{ Industry = 'Education'; Text = 'Die Anmeldezahlen für {Jahr} sind gesunken. Eltern informieren sich fast nur noch online, die Broschüre von vor fünf Jahren zeigt Räume, die es so nicht mehr gibt.' }
        @{ Industry = 'Leisure'; Text = 'Von Oktober bis März sind die Kurse voll, im Sommer bricht die Nachfrage um ein Drittel ein. Sommerkurse gibt es, nur weiß das kaum jemand.' }
        @{ Industry = 'RealEstate'; Text = 'Das Objekt ist zu einem Drittel vermarktet. Die Besichtigungen sind gut besucht, danach kommen zu wenige Reservierungen. Die Exposés sind textlastig und ohne Grundrisse im Anhang.' }
        @{ Industry = 'Energy'; Text = 'Nach den Preissprüngen der letzten Jahre sind viele Haushalte verunsichert, manche haben den Anbieter schon zweimal gewechselt. {KundeKurz} will mit Vertrauen punkten, nicht mit dem billigsten Tarif.' }
        @{ Industry = 'IT'; Text = '{KundeKurz} verkauft {Produkt} an Mittelständler, Neukunden kommen fast nur über Empfehlungen. Dazu vier offene Stellen: Fachkräfte sind schwerer zu finden als Kunden.' }
        @{ Industry = 'Club'; Text = 'Rund 300 Mitglieder, das Durchschnittsalter steigt. Ohne neue Ehrenamtliche fallen ab der nächsten Saison die Jugendkurse weg, der Vorstand sucht seit einem Jahr eine Kassenwartin.' }
        @{ Industry = 'Culture'; Text = 'Die neue Spielzeit beginnt im {Monat}. Der Vorverkauf lief letztes Jahr schleppend, Abos gehen seit drei Jahren zurück, Einzelkarten werden immer kurzfristiger gekauft.' }
        @{ Text = '{KundeKurz} ist in {Stadt} seit Jahren bekannt, wird aber mit dem alten Angebot verbunden. {Produkt} soll nach vorn, ohne Stammkunden zu verprellen.' }
        @{ Text = 'Die letzte Kampagne ({Vortermin}) brachte Reichweite, aber kaum Anfragen. Diesmal soll messbar sein, was ankommt: eigene Landingpage, eigener Code auf jedem Flyer.' }
    )
    BriefingAudience = @(
        @{ Industry = 'Retail'; Text = 'Kundschaft aus dem Viertel, die zu Fuß oder mit dem Rad vorbeikommt. Will anfassen und beraten werden, vergleicht online Preise, kauft aber gern vor Ort.' }
        @{ Industry = 'Hospitality'; Text = 'Berufstätige aus den Büros im Umkreis, die mittags eine halbe Stunde haben. Am Wochenende Familien und Paare, die Zeit mitbringen und Neues probieren.' }
        @{ Industry = 'Hotel'; Text = 'Paare zwischen 35 und 60 mit höchstens zwei Stunden Anfahrt, die kurzfristig für ein oder zwei Nächte buchen. Wichtig sind Ruhe, gutes Frühstück und kein Trubel.' }
        @{ Industry = 'Crafts'; Text = 'Zwei Gruppen: Gesellinnen und Gesellen, die wechseln würden, wenn Lohn und Klima stimmen, und Schulabgänger auf Ausbildungssuche. Bei den Jüngeren lesen die Eltern mit.' }
        @{ Industry = 'Health'; Text = 'Erwachsene ab 40, die bisher nur bei Beschwerden kommen. Sie sind skeptisch gegenüber Werbung und wollen sachliche Informationen statt Versprechen.' }
        @{ Industry = 'Education'; Text = 'Eltern, die ein Angebot für ihre Kinder suchen, und Erwachsene, die sich neben dem Beruf weiterbilden. Entscheidend sind Uhrzeit, Erreichbarkeit und Preis. Angemeldet wird online.' }
        @{ Industry = 'Leisure'; Text = 'Einsteigerinnen und Einsteiger zwischen 20 und 45, die etwas ausprobieren wollen, aber Angst haben, sich zu blamieren. Das Probetraining ist die eigentliche Hürde.' }
        @{ Industry = 'RealEstate'; Text = 'Paare und kleine Familien mit gutem Einkommen, die seit Monaten suchen. Sie kennen die Preise, lesen Exposés genau und kommen mit Fragenliste zur Besichtigung.' }
        @{ Industry = 'Energy'; Text = 'Haushalte, die beim Tarifwechsel vorsichtig sind, weil sie schon einmal reingefallen sind. Ein Ansprechpartner vor Ort ist ihnen wichtiger als ein Cent pro Kilowattstunde.' }
        @{ Industry = 'IT'; Text = 'Geschäftsführung und IT-Verantwortliche in Firmen mit 20 bis 200 Beschäftigten: wenig Zeit, viel Skepsis. Dazu Fachkräfte, die über einen Wechsel nachdenken.' }
        @{ Industry = 'Club'; Text = 'Mitglieder, die wieder mehr mitmachen sollen, und Familien aus der Nachbarschaft, die den Verein nur vom Vorbeigehen kennen.' }
        @{ Industry = 'Culture'; Text = 'Stammpublikum über 50, das Abos kauft, und Jüngere, die spontan kommen, wenn sie rechtzeitig davon erfahren. Die zweite Gruppe ist schwerer zu erreichen.' }
        @{ Text = 'Im Mittelpunkt stehen {Zielgruppe}. Daneben Bestandskunden, die {KundeKurz} kennen, aber {Produkt} noch nie ausprobiert haben.' }
        @{ Text = 'Primär {Zielgruppe} im Umkreis von 15 Kilometern um {Stadt}. Nicht im Fokus: Schnäppchenjäger, die nur für den Rabatt kommen und nicht wieder.' }
    )
    ConceptSituation = @(
        @{ Industry = 'Retail'; Text = 'Gute Lage, aber das Schaufenster wirkt beliebig. Laufkundschaft geht vorbei, weil von außen nicht zu erkennen ist, was es drinnen gibt.' }
        @{ Industry = 'Hospitality'; Text = 'Der Mittagstisch trägt den Laden. Saisonkarte und Lieferdienst kennen vor allem die Stammgäste.' }
        @{ Industry = 'Hotel'; Text = 'Sommer voll, Winter halb leer. Die Nebensaison wurde bisher nur über Rabatte beworben, das drückt die Preise.' }
        @{ Industry = 'Crafts'; Text = 'Volle Auftragsbücher, zu wenig Personal. Die Stellenanzeigen sehen aus wie die aller anderen Betriebe.' }
        @{ Industry = 'Health'; Text = 'Guter Ruf durch Empfehlungen, online kaum sichtbar. Die Werbung muss ohne Heilversprechen auskommen.' }
        @{ Industry = 'Education'; Text = 'Die Anmeldung läuft über ein PDF-Formular, an dem viele Eltern scheitern. Die Website ist auf dem Handy kaum lesbar.' }
        @{ Industry = 'Leisure'; Text = 'Starke Wintersaison, schwacher Sommer. Die Kurse sind gut, aber Neue trauen sich nicht hinein.' }
        @{ Industry = 'RealEstate'; Text = 'Viele Besichtigungen, wenig Abschlüsse. Interessierte vergleichen fünf Objekte, und unser Exposé bleibt nicht hängen.' }
        @{ Industry = 'Energy'; Text = 'Der Markt ist voller Lockangebote. {KundeKurz} ist nicht der Billigste, aber vor Ort und erreichbar.' }
        @{ Industry = 'IT'; Text = 'Fachlich stark, nach außen unsichtbar. Weder Kunden noch Bewerber wissen, was {KundeKurz} eigentlich macht.' }
        @{ Industry = 'Club'; Text = 'Ein kleiner Kern trägt seit Jahren alles und wird müde. Neue Mitglieder kommen, bleiben aber passiv.' }
        @{ Industry = 'Culture'; Text = 'Treues Publikum, das älter wird. Der Vorverkauf startet spät, viele erfahren erst nach der Premiere davon.' }
        @{ Text = 'Stand nach dem Briefing am {Vortermin}: bekannte Marke, sinkende Nachfrage nach {Produkt}, {Budget} für das ganze Jahr.' }
        @{ Text = 'Der Wettbewerb wirbt laut und über den Preis. {KundeKurz} hat dafür weder Budget noch Lust, aber die besseren Geschichten.' }
    )
    ConceptIdea = @(
        @{ Industry = 'Retail'; Text = 'Das Schaufenster wird zum Plakat: jeden Monat ein Stück aus dem Sortiment groß inszeniert, dieselbe Szene parallel auf {Kanal}.' }
        @{ Industry = 'Hospitality'; Text = 'Der Mittagstisch bekommt ein Gesicht: Wochenkarte als Plakat, montags auf {Kanal}, Bestellung beim Lieferdienst per QR-Code.' }
        @{ Industry = 'Hotel'; Text = 'Nebensaison als Vorteil: leerer Strand, warme Sauna, kein Gedränge. Statt Rabatt ein Arrangement mit Abendessen.' }
        @{ Industry = 'Crafts'; Text = 'Die eigenen Leute sind die Kampagne: echte Gesellinnen und Gesellen mit Namen, Werkzeug und einem Satz, warum sie bleiben.' }
        @{ Industry = 'Health'; Text = 'Information statt Versprechen: Was passiert bei {Produkt}, wie lange dauert es, was kostet es. Sachlich, freundlich, ohne Effekte.' }
        @{ Industry = 'Education'; Text = 'Ein ganz normaler Tag, ehrlich fotografiert. Dazu eine Anmeldung, die auf dem Handy in drei Minuten erledigt ist.' }
        @{ Industry = 'Leisure'; Text = '„Das erste Mal“ als Leitmotiv: Neue erzählen von ihrer ersten Stunde. Probetraining kostenlos, Sommerkurse draußen.' }
        @{ Industry = 'RealEstate'; Text = 'Wohnen statt Quadratmeter: Jedes Exposé beginnt mit einem Morgen in der Wohnung, Grundriss und Zahlen folgen auf Seite zwei.' }
        @{ Industry = 'Energy'; Text = 'Gesichter statt Tarifrechner: Leute aus dem Kundenservice stehen mit Namen für den Tarifwechsel. Wer anruft, landet bei ihnen.' }
        @{ Industry = 'IT'; Text = 'Die Probleme der Kunden zeigen, nicht die Technik: der Drucker am Montag, das Backup am Freitag. {KundeKurz} kümmert sich.' }
        @{ Industry = 'Club'; Text = '„Mitmachen in klein“: statt Vorstandsamt eine Stunde im Monat. Jede Aufgabe steht auf einer Karte zum Mitnehmen im Vereinsheim.' }
        @{ Industry = 'Culture'; Text = 'Hinter die Bühne schauen: Plakate zeigen Proben und Menschen, die man sonst nie sieht. Der Vorverkaufsstart wird zum eigenen Abend.' }
        @{ Text = 'Leitidee ist der Claim „{Claim}“. Alles, was wir zeigen, muss diesen Satz einlösen, sonst fliegt es raus.' }
        @{ Text = 'Weniger Kanäle, dafür richtig: {Kanal} als Hauptkanal, {Kanal2} begleitend. Alles andere streichen wir für diese Runde.' }
    )
    Claim = @(
        @{ Industry = 'Retail'; Text = 'Anfassen erlaubt.' }
        @{ Industry = 'Retail'; Text = 'Gleich um die Ecke.' }
        @{ Industry = 'Hospitality'; Text = 'Mittags bei uns.' }
        @{ Industry = 'Hospitality'; Text = 'Frisch aus der Saison.' }
        @{ Industry = 'Hotel'; Text = 'Endlich Nebensaison.' }
        @{ Industry = 'Hotel'; Text = 'Zeit hat hier Platz.' }
        @{ Industry = 'Crafts'; Text = 'Hände gesucht.' }
        @{ Industry = 'Crafts'; Text = 'Gute Arbeit bleibt.' }
        @{ Industry = 'Health'; Text = 'Gut beraten.' }
        @{ Industry = 'Health'; Text = 'In ruhigen Händen.' }
        @{ Industry = 'Education'; Text = 'Anmelden, ankommen.' }
        @{ Industry = 'Education'; Text = 'Hier lernt man gern.' }
        @{ Industry = 'Leisure'; Text = 'Einfach mal anfangen.' }
        @{ Industry = 'Leisure'; Text = 'Die Saison gehört dir.' }
        @{ Industry = 'RealEstate'; Text = 'Erst wohnen, dann rechnen.' }
        @{ Industry = 'RealEstate'; Text = 'Besichtigen lohnt sich.' }
        @{ Industry = 'Energy'; Text = 'Strom von nebenan.' }
        @{ Industry = 'Energy'; Text = 'Wechseln ohne Bauchweh.' }
        @{ Industry = 'IT'; Text = 'Läuft. Auch montags.' }
        @{ Industry = 'IT'; Text = 'IT, die man nicht bemerkt.' }
        @{ Industry = 'Club'; Text = 'Eine Stunde reicht.' }
        @{ Industry = 'Club'; Text = 'Mach mit. Bleib dabei.' }
        @{ Industry = 'Culture'; Text = 'Der Abend gehört Ihnen.' }
        @{ Industry = 'Culture'; Text = 'Neue Spielzeit, gute Plätze.' }
        @{ Text = 'Gut. Von hier.' }
        @{ Text = 'Näher dran.' }
    )
    Motif = @(
        @{ Industry = 'Retail'; Text = 'Kundin hebt ein Stück aus dem Regal, der Verkäufer zeigt lachend auf ein Detail' }
        @{ Industry = 'Retail'; Text = 'Blick von der Straße ins beleuchtete Schaufenster, früher Abend, Passanten unscharf' }
        @{ Industry = 'Hospitality'; Text = 'Tagesgericht auf dem Holztisch, im Hintergrund die volle Theke zur Mittagszeit' }
        @{ Industry = 'Hospitality'; Text = 'Fahrradkurier nimmt an der Tür eine Tüte für den Lieferdienst entgegen' }
        @{ Industry = 'Hotel'; Text = 'Paar im Bademantel mit Tee am Fenster, draußen ein grauer Wintertag' }
        @{ Industry = 'Hotel'; Text = 'Leerer Strand im Morgennebel, zwei Strandkörbe, Dünengras im Vordergrund' }
        @{ Industry = 'Crafts'; Text = 'Gesellin misst mit dem Zollstock nach, Bleistift hinterm Ohr, Werkstatt im Hintergrund' }
        @{ Industry = 'Crafts'; Text = 'Team in Arbeitskleidung beim Frühstück auf der Ladefläche des Firmenwagens' }
        @{ Industry = 'Health'; Text = 'Beratungsgespräch am Empfang, freundlich und ruhig, keine Behandlungsszene' }
        @{ Industry = 'Health'; Text = 'Heller Wartebereich mit Pflanze und Blick ins Grüne, niemand wartet' }
        @{ Industry = 'Education'; Text = 'Erwachsene im Kursraum am Abend, eine Teilnehmerin lacht über ihre eigene Notiz' }
        @{ Industry = 'Education'; Text = 'Mutter füllt am Küchentisch die Anmeldung auf dem Handy aus, Kind malt daneben' }
        @{ Industry = 'Leisure'; Text = 'Einsteigerin in ihrer ersten Stunde, der Trainer zeigt die Haltung, beide lachen' }
        @{ Industry = 'Leisure'; Text = 'Gruppe nach dem Sommerkurs draußen auf der Wiese, verschwitzt und zufrieden' }
        @{ Industry = 'RealEstate'; Text = 'Morgenlicht in der leeren Küche, eine Kaffeetasse auf der Fensterbank' }
        @{ Industry = 'RealEstate'; Text = 'Paar mit Exposé in der Hand bei der Besichtigung, sie zeigt auf das große Fenster' }
        @{ Industry = 'Energy'; Text = 'Kundenberaterin am Telefon, Namensschild lesbar, im Fenster die Stadt' }
        @{ Industry = 'Energy'; Text = 'Familie am Küchentisch mit der Jahresabrechnung, entspannt statt erschrocken' }
        @{ Industry = 'IT'; Text = 'Techniker tauscht im Serverschrank eine Festplatte, der Kunde schaut über die Schulter' }
        @{ Industry = 'IT'; Text = 'Büro am Montagmorgen, alle arbeiten, niemand steht fluchend am Drucker' }
        @{ Industry = 'Club'; Text = 'Ehrenamtliche streichen gemeinsam das Vereinsheim, Kaffeekanne auf der Leiter' }
        @{ Industry = 'Club'; Text = 'Ältere Mitglieder zeigen beim Saisonstart den Neuen die Handgriffe' }
        @{ Industry = 'Culture'; Text = 'Darstellerin in der Garderobe vor dem Spiegel, kurz vor dem Auftritt' }
        @{ Industry = 'Culture'; Text = 'Foyer nach der Vorstellung: Gläser, Gespräche, zusammengerollte Programmhefte' }
        @{ Text = '{Ansprechpartner} vor dem Eingang in {Stadt}, Ärmel hochgekrempelt' }
        @{ Text = '{Produkt} auf neutralem Grund, weich ausgeleuchtet, rechts viel Platz für Text' }
    )
    AdCopy = @(
        @{ Industry = 'Retail'; Text = 'Kommen Sie rein und nehmen Sie es in die Hand. Unser Sortiment an {Produkt} ist gewachsen, die Beratung ist so gründlich wie immer.' }
        @{ Industry = 'Hospitality'; Text = 'Neue Saisonkarte ab {Termin2}. Mittagstisch werktags ab 11:30 Uhr. Keine Zeit? Wir liefern im ganzen Viertel.' }
        @{ Industry = 'Hotel'; Text = 'Drei Nächte, zwei bezahlen: unter der Woche von November bis März. Sauna, Frühstück bis 11 Uhr und ein Strand fast für Sie allein.' }
        @{ Industry = 'Crafts'; Text = 'Wir haben mehr Aufträge als Hände. Du kannst dein Handwerk und suchst einen Betrieb, in dem man dich kennt? Ruf an oder komm vorbei.' }
        @{ Industry = 'Health'; Text = 'Wir nehmen uns Zeit für Ihre Fragen zu {Produkt}. Termine auch früh morgens und am späten Nachmittag.' }
        @{ Industry = 'Education'; Text = 'Das neue Programm ist da. Anmelden geht jetzt online, auch abends vom Sofa aus. Anmeldeschluss ist der {Termin}.' }
        @{ Industry = 'Leisure'; Text = 'Die erste Stunde ist kostenlos, Vorkenntnisse brauchst du keine. Die Sommerkurse starten am {Termin2}.' }
        @{ Industry = 'RealEstate'; Text = 'Drei Zimmer, Südbalkon, Bezug im {Quartal}. Besichtigung samstags nach Vereinbarung, das Exposé schicken wir Ihnen gern vorab.' }
        @{ Industry = 'Energy'; Text = 'Der Tarifwechsel dauert zehn Minuten, die Kündigung beim alten Anbieter übernehmen wir. Und bei Fragen sitzen wir hier in {Stadt}.' }
        @{ Industry = 'IT'; Text = 'Ihr Netzwerk läuft, Ihre Daten sind gesichert, und wenn etwas klemmt, ruft Sie jemand mit Namen zurück. {Produkt} für Firmen aus der Region.' }
        @{ Industry = 'Club'; Text = 'Wir suchen keine Vorstände, sondern Leute mit einer Stunde Zeit im Monat. Mehr beim Tag der offenen Tür am {Termin2}.' }
        @{ Industry = 'Culture'; Text = 'Die neue Spielzeit steht. Vorverkauf ab {Termin2}, Abonnements bis {Termin} noch zum alten Preis.' }
        @{ Industry = 'Retail'; Text = 'Neu im Laden: {Produkt}. Wir haben es selbst ausprobiert, bevor es ins Regal kam. Testen vor Ort, ohne Kaufzwang.' }
        @{ Industry = 'Retail'; Text = 'Samstags bis 18 Uhr geöffnet, Parkplätze direkt vor der Tür. Was Sie bis Donnerstag bestellen, liegt am Samstag bereit.' }
        @{ Industry = 'Hospitality'; Text = 'Frisch aus dem Ofen ab 7 Uhr. Vorbestellen geht bis 18 Uhr am Vortag, telefonisch oder per Mail.' }
        @{ Industry = 'Hospitality'; Text = 'Feiern Sie bei uns: Nebenraum für bis zu 30 Personen, Menü nach Absprache. Fragen Sie nach freien Terminen im {Monat}.' }
        @{ Industry = 'Hotel'; Text = 'Ankommen, Koffer abstellen, ans Wasser gehen. Die Zimmer zur Seeseite sind ab {Termin2} wieder buchbar.' }
        @{ Industry = 'Hotel'; Text = 'Tagungen bis 40 Personen mit Technik, Pausenversorgung und Zimmerkontingent. Eine Ansprechpartnerin für alles.' }
        @{ Industry = 'Crafts'; Text = 'Termin in der Werkstatt meist innerhalb einer Woche. Kostenvoranschlag vorher, Abrechnung nach Aufwand, keine Überraschungen.' }
        @{ Industry = 'Crafts'; Text = 'Ausbildung bei uns heißt: ab dem ersten Tag mit auf der Baustelle. Bewerben bis {Termin}, Praktikum jederzeit.' }
        @{ Industry = 'Health'; Text = 'Neue Patientinnen und Patienten sind willkommen. Den ersten Termin vergeben wir innerhalb von zwei Wochen, auch online.' }
        @{ Industry = 'Health'; Text = 'Barrierefreier Zugang, Aufzug im Haus, Parkplätze im Hof. Bitte bringen Sie Ihre Versichertenkarte mit.' }
        @{ Industry = 'Education'; Text = 'Kurse am Vormittag, am Abend und am Wochenende, in Gruppen mit höchstens zwölf Teilnehmenden.' }
        @{ Industry = 'Education'; Text = 'Ermäßigung für Studierende und Rentner. Viele Kurse sind als Bildungsurlaub anerkannt, fragen Sie uns.' }
        @{ Industry = 'Leisure'; Text = 'Kinder bis sechs Jahre frei, Geschwister zahlen die Hälfte. Leihausrüstung gibt es vor Ort.' }
        @{ Industry = 'Leisure'; Text = 'Geöffnet bei jedem Wetter, Halle und Außenbereich. Gutscheine an der Kasse und online.' }
        @{ Industry = 'RealEstate'; Text = 'Neubau nach aktuellem Effizienzstandard, Fertigstellung im {Quartal}. Noch vier Wohnungen frei, Grundrisse auf Anfrage.' }
        @{ Industry = 'RealEstate'; Text = 'Sie wollen verkaufen? Wir bewerten Ihre Immobilie kostenlos und sagen Ihnen ehrlich, was realistisch ist.' }
        @{ Industry = 'Energy'; Text = 'Strom aus der Region, Preisgarantie für 24 Monate. Den Abschlag passen Sie online an, jederzeit.' }
        @{ Industry = 'Energy'; Text = 'Störung? Unsere Hotline ist rund um die Uhr besetzt, und zwar mit Leuten aus {Stadt}.' }
        @{ Industry = 'IT'; Text = 'Neue Arbeitsplätze an einem Tag eingerichtet, Daten übernommen, Altgeräte fachgerecht entsorgt.' }
        @{ Industry = 'IT'; Text = 'Fernwartung innerhalb von 30 Minuten, vor Ort am selben Tag im Stadtgebiet. Monatlicher Festpreis.' }
        @{ Industry = 'Club'; Text = 'Training dienstags und donnerstags ab 18 Uhr, Probetraining jederzeit. Beitrag 8 Euro im Monat.' }
        @{ Industry = 'Club'; Text = 'Sommerfest am {Termin2}: Flohmarkt, Kuchenbuffet und Turnier für alle. Helferinnen und Helfer gesucht.' }
        @{ Industry = 'Culture'; Text = 'Sonntags Familienvorstellung um 15 Uhr. Kinder zahlen 5 Euro, Erwachsene 12 Euro.' }
        @{ Industry = 'Culture'; Text = 'Führungen hinter die Kulissen an jedem ersten Samstag im Monat. Anmeldung an der Theaterkasse.' }
        @{ Text = '{Claim} {Produkt} von {KundeKurz}, mitten in {Stadt}. Der Kaffee steht schon da.' }
        @{ Text = 'Seit Jahren in {Stadt}, und trotzdem kennen uns noch nicht alle. Ändern wir das: {Produkt}, ehrlich beraten und fair berechnet.' }
    )
    BriefingGoal = @(
        @{ Text = 'Bis Ende {Quartal} sollen {Prozent} Prozent mehr Anfragen über {Kanal} kommen als im Vorjahreszeitraum. Gemessen wird über das Kontaktformular und den Code auf dem Flyer.' }
        @{ Text = 'Nicht Reichweite, sondern Rücklauf: 50 brauchbare Anfragen bis {Termin2}. Lieber wenige, die passen, als viele Klicks.' }
        @{ Text = 'Die Leute in {Stadt} sollen wissen, dass es {Produkt} bei {KundeKurz} gibt. Schwer messbar, daher eine kurze Umfrage vor und nach der Kampagne.' }
    )
    BriefingMandatory = @(
        @{ Text = 'Logo nur in der Fassung von {Jahr}, Hausfarben laut Styleguide. Keine Stockfotos mit Models, nur echte Mitarbeitende. Impressum auf jedem Druckstück.' }
        @{ Text = 'Texte liefert der Kunde, wir lektorieren. Preise immer inklusive MwSt. Freigaben ausschließlich über {Ansprechpartner}, nicht über die Filialen.' }
        @{ Text = 'Schrift im Print mindestens 10 pt, Kontraste geprüft. Aussagen zu Preisen und Rabatten vor dem Druck schriftlich bestätigen lassen.' }
    )
    BriefingTiming = @(
        @{ Text = 'Briefing {Vortermin}, erste Entwürfe {Termin}, Druckdaten eine Woche vor Start, Kampagnenstart {Termin2}. Puffer gibt es keinen, Feiertage sind eingerechnet.' }
        @{ Text = 'KW 1–2 Konzept, KW 3 Präsentation, KW 4–5 Ausarbeitung und Korrektur, KW 6 Druck. Start {Termin2}. Verschiebt sich die Freigabe, verschiebt sich alles.' }
        @{ Text = 'Präsentation am {Termin}, danach zwei Korrekturschleifen zu je drei Werktagen. Online-Start {Termin2}, Print folgt zwei Wochen später.' }
    )
    ConceptGoals = @(
        @{ Text = '1. {Prozent} Prozent mehr Anfragen bis Ende {Quartal}
2. Dieselbe Bildsprache auf allen Kanälen
3. Kosten pro Anfrage unter denen der letzten Kampagne' }
        @{ Text = 'Gezählt wird Rücklauf über {Kanal}. Reichweite auf {Kanal2} ist willkommen, gilt aber nicht als Erfolg.' }
        @{ Text = 'Zwei Ziele, die sich beißen: mehr Neukunden und keine Rabatte. Wir priorisieren Neukunden und begrenzen Rabatte auf eine Aktion im {Monat}.' }
    )
    ConceptMeasures = @(
        @{ Text = '• Plakatserie mit drei Motiven
• {Auflage} Flyer für den Point of Sale
• Landingpage mit Anmeldeformular
• vier Wochen Anzeigen auf {Kanal}' }
        @{ Text = 'Phase 1 bis {Termin}: Shooting und Texte. Phase 2 ab {Termin2}: Schaltung auf {Kanal} und {Kanal2}, wöchentliche Auswertung mit {Ansprechpartner}.' }
        @{ Text = 'Kein Radiospot: Das Budget reicht nicht für genug Wiederholungen. Das Geld geht stattdessen in eine zweite Plakatwelle.' }
    )
    ConceptRisks = @(
        @{ Text = 'Offen: Wer macht die Fotos? Steht das Shooting nicht bis {Termin}, nehmen wir Bestandsbilder und verlieren an Glaubwürdigkeit.' }
        @{ Text = 'Das Budget von {Budget} ist knapp. Ab der dritten Korrekturschleife wird es teurer als der Festpreis, das muss der Kunde vorher wissen.' }
        @{ Text = 'Beim letzten Projekt hat die Geschäftsführung des Kunden kurz vor Druck alles umgeworfen. Diesmal schriftliche Zwischenfreigabe nach dem Konzept.' }
    )
    PrintRelease = @(
        @{ Text = 'Hiermit geben wir die Druckdaten für {Projekt} in der Fassung vom {Datum} frei. Auflage {Auflage} Stück. Inhalt und Rechtschreibung sind von uns geprüft.
{Ansprechpartner}, {Kunde}' }
        @{ Text = 'Guten Tag, anbei die finalen Druckdaten für {Projekt}: PDF/X-4, 3 mm Beschnitt, Auflage {Auflage}. Lieferung bis {Termin} direkt an {Kunde}. Bitte vorab einen Proof schicken.' }
        @{ Text = 'Freigabe mit einer Änderung: Auf Seite 3 die Telefonnummer korrigieren, dann ist alles freigegeben. Einen weiteren Proof brauchen wir nicht.' }
    )
    CustomerFeedback = @(
        @{ Text = 'Das Logo muss größer. Deutlich größer.' }
        @{ Text = 'Können wir das Blau freundlicher machen? Es wirkt so kalt. Aber nicht heller, das ist ja unsere Hausfarbe.' }
        @{ Text = 'Meinem Mann gefällt das Foto nicht, er sagt, das sind nicht wir. Gibt es noch eins aus dem Archiv?' }
        @{ Text = 'Der Text ist zu lang, das liest keiner. Bitte trotzdem noch Öffnungszeiten, Parkplätze und den Gutschein aufnehmen.' }
        @{ Text = 'Am {Vortermin} hatten wir uns auf Variante B geeinigt. Jetzt sehe ich wieder A. Bitte klären.' }
        @{ Text = 'Ich finde es gut so. Unsere Geschäftsführung hat aber noch nicht draufgeschaut, die ist bis {Termin} im Urlaub.' }
        @{ Text = 'Bitte überall nur „Kunden“ schreiben, „Kundinnen und Kunden“ ist zu lang. Auf der Website lassen wir es, wie es ist.' }
        @{ Text = 'Seite 2, dritter Absatz: Der Preis stimmt nicht, richtig ist {Betrag}. Sonst passt alles, danke!' }
        @{ Text = 'Mehr Luft bitte, das wirkt alles sehr voll. Und könnte noch das Teamfoto mit drauf?' }
        @{ Text = 'Im Proof sind die Farben viel dunkler als am Bildschirm. Ist das normal oder müssen wir uns Sorgen machen?' }
    )
    CancelNote = @(
        @{ Voice = 'MMustermann'; Text = '{Projekt} für {KundeKurz} bis auf Weiteres gestoppt. Grund: Budgetkürzung beim Kunden. Geleistet {Stunden} Stunden, Abrechnung gemäß Angebot. Unterlagen ins Archiv.' }
        @{ Voice = 'CHerz'; Text = '{KundeKurz} hat abgesagt, sie machen {Projekt} jetzt intern mit einer Werkstudentin. Schade, aber nachvollziehbar. Das Konzept stellen wir trotzdem in Rechnung.' }
        @{ Text = 'Verschoben: {Ansprechpartner} hat am {Datum} angerufen, {Projekt} kommt erst im {Quartal}. Entwürfe bleiben liegen, der Druckauftrag bei {Lieferant} ist storniert.' }
        @{ Text = 'Seit der Präsentation am {Vortermin} keine Reaktion, zwei Nachfragen unbeantwortet. Projekt ruht, Wiedervorlage am {Termin}.' }
    )
    InternalComment = @(
        @{ Voice = 'MMustermann'; Text = '{Stunden} Stunden reichen für diesen Umfang nicht. Ansatz um 20 Prozent erhöhen.' }
        @{ Voice = 'EMustermann'; Text = 'Das ist richtig gut geworden, ihr Lieben! Nur der Schluss braucht noch einen Satz mehr Wärme.' }
        @{ Voice = 'JDoe'; Text = 'FYI: Kunde will V2 bis EOD sehen. Headline tbd, bitte asap 2–3 Alternativen.' }
        @{ Voice = 'JDoe'; Text = 'Zahl vs. Reporting vom {Vortermin} checken, da stand was anderes. Fix bis Ende KW pls.' }
        @{ Voice = 'KAnders'; Text = 'Mir fehlt hier das Licht – das Bild steht, aber es atmet nicht. Was, wenn wir näher rangehen, nur Hände und Werkzeug?' }
        @{ Voice = 'VSpula'; Text = '1. Kundennamen einheitlich schreiben. 2. Datum in Zeile 4 prüfen. 3. Quelle für die Prozentzahl fehlt.' }
        @{ Voice = 'LMayer'; Text = 'Find ich super so :-) Nur die Headline ist mir zu brav.' }
        @{ Voice = 'LMayer'; Text = 'Hab das Bild getauscht, das alte war voll verpixelt. Passt das so?' }
        @{ Voice = 'CHerz'; Text = 'Absatz streichen, sagt dem Kunden nichts Neues. Preis lieber gleich hier nennen.' }
        @{ Voice = 'CHerz'; Text = 'Ist das Shooting im Budget? Wenn nein, Variante ohne und das ehrlich dazuschreiben.' }
        @{ Voice = 'WErnst'; Text = 'Wie früher bei den Prospekten: erst die Fakten, dann die Schönheit. Der Preis gehört nach oben.' }
        @{ Voice = 'JFrick'; Text = 'Bild hat 150 dpi bei 100 %, für A1 zu wenig. Original anfordern, Profil ISO Coated v2, 3 mm Beschnitt fehlt.' }
        @{ Voice = 'SHarz'; Text = 'Die Headline ist nett. Aber nett ist die kleine Schwester von langweilig.' }
        @{ Voice = 'WLonska'; Text = 'Ist hier die Adresse der Filiale gemeint oder die Zentrale? Ich habe beide gefunden und möchte nichts Falsches drucken.' }
        @{ Voice = 'RJung'; Text = 'Entschuldigung, soll das Logo links oder rechts stehen? Im Styleguide steht beides. Ich hab es erstmal links gemacht, ist das ok?' }
        @{ Text = 'Bitte mit dem Stand vom {Vortermin} abgleichen, da war der Termin noch ein anderer.' }
        @{ Text = 'Mit {Ansprechpartner} abgestimmt? Sonst lieber raus.' }
        @{ Text = 'Quelle für diese Zahl? Der Kunde wird danach fragen.' }
    )
    ReportSummary = @(
        @{ Text = 'Laufzeit {Termin} bis {Termin2}: {Prozent} Prozent mehr Anfragen als im Vorjahr. Online-Ziel erreicht, Print blieb hinter den Erwartungen.' }
        @{ Text = 'Budget eingehalten, {Betrag} von {Budget} ausgegeben. {Kanal} brachte die meisten Anfragen, {Kanal2} kaum messbare Wirkung.' }
        @{ Text = 'Viel Aufmerksamkeit, weniger Abschlüsse als geplant. Der Kunde ist trotzdem zufrieden und will im {Quartal} nachlegen.' }
    )
    ReportLearnings = @(
        @{ Text = 'Fotos echter Mitarbeitender liefen deutlich besser als Agenturbilder. Nächstes Mal Shooting fest einplanen.' }
        @{ Text = 'Zweimal ging eine Woche verloren, weil Freigaben fehlten. Künftig feste Freigabetermine im Zeitplan.' }
        @{ Text = 'Den QR-Code auf dem Plakat hat kaum jemand genutzt. Eine kurze Webadresse wirkt besser.' }
    )
    PressHeadline = @(
        @{ Text = '{Kunde} startet {Projekt}' }
        @{ Text = '{KundeKurz}: Neues Angebot ab {Termin2}' }
        @{ Text = 'Aus {Stadt}, für {Stadt}: {KundeKurz} setzt auf {Produkt}' }
    )
    PressBody = @(
        @{ Text = '{Stadt}, {Datum}. Ab dem {Termin2} ist {Kunde} mit {Projekt} auf {Kanal} und {Kanal2} zu sehen. Im Mittelpunkt steht {Produkt}. Entwickelt hat die Kampagne {Firma}.' }
        @{ Text = '{Stadt}, {Datum}. {Kunde} erweitert das Angebot rund um {Produkt}. Wer sich bis zum {Termin} meldet, lernt die Neuerungen vorab kennen.' }
        @{ Text = '{Stadt}, {Datum}. Mehr als {Auflage} Menschen kamen im letzten Jahr zu {KundeKurz}. Mit {Projekt} will das Team neue Zielgruppen erreichen.' }
    )
    PressQuote = @(
        @{ Text = '„Wir wollten nicht lauter werden, sondern deutlicher“, sagt {Ansprechpartner}. „Man soll sehen, wer hier arbeitet.“' }
        @{ Text = '„Das Briefing war kurz, die Diskussionen lang“, sagt {Ich} von {Firma}. „Am Ende hat die einfachste Idee gewonnen.“' }
        @{ Text = '„Wir sind seit Jahren in {Stadt} und wollen hier bleiben“, sagt {Ansprechpartner}.' }
    )
    NextStep = @(
        @{ Text = 'Korrekturen einarbeiten bis {Termin}' }
        @{ Text = 'Freigabe durch {Ansprechpartner} einholen' }
        @{ Text = 'Druckdaten an {Lieferant} bis {Termin2}' }
        @{ Text = 'Auswertung mit dem Kunden Ende {Monat}' }
    )
}
