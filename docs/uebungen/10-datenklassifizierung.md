# 10 Datenklassifizierung

Die Daten der Mustermann Medien GmbH liegen jetzt in SharePoint Online und OneDrive ([Kapitel 9](09-migration-sharepoint.md)). Mit dabei sind Personaldaten, Kontonummern und ein paar Dateien am falschen Ort. In diesem Kapitel findest du sie mit Microsoft Purview, kennzeichnest sie und sorgst dafür, dass sie nicht nach außen gelangen.

**Alle personenbezogenen Daten sind erfunden.** Steuer-IDs, Personalausweis- und Rentenversicherungsnummern haben gültige Prüfziffern, gehören aber zu niemandem. Die IBANs nutzen Bankleitzahlen, die keine Bank führt, die Kreditkarten sind Testnummern der Kartenanbieter, Rufnummern und Domains stammen aus reservierten Bereichen.

**Voraussetzungen:**

- Kapitel 9 ist abgeschlossen.
- Im Übungsmandanten Microsoft-Purview-Funktionen der E5-Klasse (Microsoft 365 E5, E5 Compliance oder E5 Information Protection and Governance). Manuelle Bezeichnungen und DLP für SharePoint gehen auch mit E3, Daten-Explorer, automatische Bezeichnung und Standardbezeichnungen für Bibliotheken nicht.
- Rollen: *Compliance-Administrator*, für 10.1 zusätzlich die Rollengruppen *Data Explorer List viewer* und *Data Explorer Content viewer*.
- Geduld: Purview klassifiziert im Hintergrund. Bis der Daten-Explorer Treffer aus SharePoint zählt, können bis zu 14 Tage vergehen. Fang mit 10.1 direkt nach der Migration an und arbeite in der Zwischenzeit an 10.2.

Die Menüpunkte im [Purview-Portal](https://purview.microsoft.com) stehen unten so, wie Microsoft sie dokumentiert. Je nach Sprache der Oberfläche heißen sie leicht anders.

## 10.1 Sensible Daten finden ★★

**Ziel:** Sehen, welche vertraulichen Informationen Purview in den migrierten Daten erkennt und wo sie liegen.

Im Purview-Portal: *Solutions → Information Protection → Explorers → Data explorer*. Filtere nach diesen vertraulichen Informationstypen (Sensitive information types):

- *Germany tax identification number* (Steuer-ID)
- *Germany identity card number* (Personalausweis)
- *International banking account number (IBAN)*
- *Credit card number*

**Prüfen:** Treffer gibt es in den Personalakten, den Lohnjournalen und Entgeltabrechnungen sowie in Gehaltslisten an Orten, an denen du sie nicht erwartest. Zwei Dinge fehlen, und beides ist lehrreich:

- **Kreditkartenabrechnungen:** Purview erkennt die reservierten Testnummern der Kartenanbieter absichtlich nicht ([Definition](https://learn.microsoft.com/purview/sit-defn-credit-card-number)).
- **Gescannte Dokumente** wie Arbeitsverträge, Krankmeldungen und der Belegordner: Ein Scan ist ein Bild, ohne Texterkennung findet Purview darin nichts. Lies [Texterkennung (OCR) in Purview](https://learn.microsoft.com/purview/ocr-learn-about): Was kostet sie, und gilt sie auch für Dateien, die schon hochgeladen sind?

## 10.2 Vertraulichkeitsbezeichnungen ★★

**Aufgabe:** Die Agentur hat eine Klassifizierungsrichtlinie, die neueste Fassung lag auf dem Fileserver in `Abteilungen\Allgemein\Richtlinien` und jetzt dort, wohin du in 9.2 `Allgemein` migriert hast. Setze sie mit Vertraulichkeitsbezeichnungen um.

1. Die Bezeichnungen in SharePoint und OneDrive aktivieren, als SharePoint-Administrator:

   ```powershell
   Connect-SPOService -Url https://<mandant>-admin.sharepoint.com
   Set-SPOTenant -EnableAIPIntegration $true
   Set-SPOTenant -EnableSensitivityLabelforPDF $true
   ```

2. *Information Protection → Sensitivity labels*: Bezeichnungen *Öffentlich*, *Intern*, *Vertraulich* und *Streng vertraulich* nach der Richtlinie anlegen, z. B. mit Kopf- oder Fußzeilenvermerk. Ohne Verschlüsselung anfangen.
3. Die Bezeichnungen mit einer Bezeichnungsrichtlinie für deine Testbenutzer veröffentlichen.

**Prüfen:** Nach einiger Zeit kann `emustermann` in Word im Web einer Datei die Bezeichnung *Vertraulich* geben, und die Bibliothek zeigt sie in der Spalte *Vertraulichkeit*. Viele alte Dokumente tragen schon einen Vermerk wie „Vertraulich“ in der Kopfzeile oder eine Dateieigenschaft *Klassifizierung*. Was ist der Unterschied zu einer Vertraulichkeitsbezeichnung? Warum ist die Bezeichnung zuverlässiger als ein Wort in der Kopfzeile?

Details: [Vertraulichkeitsbezeichnungen für Office-Dateien in SharePoint und OneDrive](https://learn.microsoft.com/purview/sensitivity-labels-sharepoint-onedrive-files).

## 10.3 Automatische Bezeichnung ★★★

**Aufgabe:** Dokumente mit Steuer-ID oder Personalausweisnummer sollen automatisch *Streng vertraulich* werden, Dokumente mit IBAN *Vertraulich*.

*Information Protection → Policies → Auto-labeling policies → Create policy*: Speicherorte *SharePoint sites* und *OneDrive accounts*, Regeln mit den vertraulichen Informationstypen aus 10.1, Bezeichnung aus 10.2. Die Richtlinie zuerst im **Simulationsmodus** laufen lassen.

**Prüfen:** Die Simulation listet die Dateien, die eine Bezeichnung bekämen. Stimmt die Liste mit 10.1 überein? Erst danach die Richtlinie einschalten. Nach dem Einschalten tragen die Dateien die Bezeichnung (das kann wieder dauern). Warum bekommen die gescannten PDFs keine Bezeichnung? Was passiert mit einer Datei, die gerade jemand bearbeitet?

Details: [Vertraulichkeitsbezeichnungen automatisch anwenden](https://learn.microsoft.com/purview/apply-sensitivity-label-automatically).

## 10.4 Fehlablagen bewerten und beheben ★★

**Aufgabe:** Im Bestand liegen Dateien, die so nicht sein dürfen. Finde sie, bewerte sie anhand der Datenschutzrichtlinie der Agentur und behebe die Fehler.

- Gehaltslisten außerhalb der Personalabteilung: im Marketing und in einem OneDrive
- Teilnehmerlisten von Gewinnspielen in Projektordnern
- eine Excel-Datei mit alten Zugangsdaten in der IT
- Bewerbungen, die älter als sechs Monate sind

Gehaltslisten findest du über den Daten-Explorer aus 10.1. Teilnehmerlisten und Zugangsdaten enthalten weder Steuer-ID noch IBAN; dafür hilft die Suche nach Dateinamen über *eDiscovery* (Rolle *eDiscovery-Manager*) oder in den jeweiligen Websites.

**Prüfen:** Für jeden Fund ist entschieden und umgesetzt: verschieben (wohin, wer hat dort Zugriff?), löschen (darf man das, wer entscheidet?) oder behalten mit Bezeichnung. Bei den Zugangsdaten: Was muss außer dem Löschen noch passieren? Am Ende liefert der Daten-Explorer Gehaltsdaten nur noch in der Website *Personal* bzw. *Buchhaltung*.

## 10.5 DLP-Richtlinie ★★★

**Aufgabe:** Dokumente mit Steuer-ID oder IBAN dürfen nicht nach außen geteilt werden.

*Data loss prevention → Policies → Create policy* mit benutzerdefinierter Richtlinie:

1. Speicherorte *SharePoint sites* und *OneDrive accounts*.
2. Bedingungen: *Content is shared from Microsoft 365 → with people outside my organization* und *Content contains* die vertraulichen Informationstypen aus 10.1.
3. Aktion: *Restrict access or encrypt the content in Microsoft 365 locations → Block only people outside your organization*, Benachrichtigungen und Richtlinientipps für Benutzer einschalten.
4. Zuerst im Simulationsmodus mit *Show policy tips while in simulation mode* laufen lassen.

**Prüfen:** Teilt `emustermann` eine Entgeltabrechnung mit einer externen Adresse, erscheint ein Richtlinientipp. Nach dem Einschalten ist das Teilen nach außen blockiert, intern geht es weiter. Was ändert sich, wenn die Bedingung statt auf Informationstypen auf die Bezeichnung *Streng vertraulich* aus 10.2 prüft?

Details: [DLP-Richtlinie gegen externes Teilen in SharePoint und OneDrive](https://learn.microsoft.com/purview/dlp-create-policy-spo-odb-external).

## 10.6 Aufbewahrung für Bewerbungen ★★

**Aufgabe:** Laut Datenschutzrichtlinie werden Unterlagen abgelehnter Bewerber nach sechs Monaten gelöscht. Setze das mit einer Aufbewahrungsbezeichnung um.

1. *Data Lifecycle Management* bzw. *Records Management → Retention labels*: Bezeichnung „Bewerbung“, sechs Monate ab Erstellung aufbewahren, danach automatisch löschen.
2. Die Bezeichnung mit einer Richtlinie für die Website *Personal* veröffentlichen.
3. In der Bibliothek mit den Bewerbungen *Einstellungen → Bezeichnung auf Elemente in dieser Liste oder Bibliothek anwenden*, die Bezeichnung wählen und *Apply to existing items* aktivieren.

**Prüfen:** Die Dateien in der Bibliothek tragen die Bezeichnung „Bewerbung“. SPMT hat das ursprüngliche Erstellungsdatum übernommen: Was bedeutet das für die Bewerbungen, die schon älter als sechs Monate sind? Warum ist eine Aufbewahrungsbezeichnung etwas anderes als eine Vertraulichkeitsbezeichnung?

Details: [Aufbewahrungsbezeichnungen erstellen und anwenden](https://learn.microsoft.com/purview/create-apply-retention-labels).
