# Bereitstellung

Voraussetzungen, Parameter und erste Schritte nach dem Deployment. Platzhalter: `<k>` = Kürzel des Azubis (3 Buchstaben, klein), `<K>` = Kürzel groß, `<zone>` = übergeordnete DNS-Zone vom Ausbilder. Wie das Lab aufgebaut ist, steht in der [Architektur](architecture.md).

## Voraussetzungen

- **Rechte:** Owner auf der eigenen Ziel-Ressourcengruppe (für die Rollenzuweisungen der Managed Identities von Exchange-Server und Fileserver) und *DNS Zone Contributor* auf `rg-publicdns`. Eine Entra-/Global-Admin-Rolle ist **nicht** nötig. Ohne Owner: Parameter `enableLetsEncrypt = false` und `fileServerFinalVmSize` leer (der Fileserver verkleinert sich dann nicht selbst).
- **Kürzel** darf noch nicht als Subdomain in `<zone>` existieren.
- **Übergeordnete Zone:** Existiert `<zone>` in der Ressourcengruppe `parentDnsZoneResourceGroup`, bleibt sie unverändert, das Deployment ergänzt nur den NS-Eintrag `<k>`. Fehlt sie, wird sie angelegt. Die Ressourcengruppe selbst muss existieren. Eine neu angelegte Zone muss einmalig beim Registrar delegiert werden, sonst schlägt Let's Encrypt fehl.
- **Kontingent:** 8 vCPU in der Region (4 × BS-Familie für DC und Client, 4 × ESv5-Familie), mit zweitem DC 10 vCPU (6 × BS-Familie). Ohne Client 2 vCPU weniger. Der Fileserver braucht während der Erzeugung der Beispieldaten zusätzlich 4 × DSv5-Familie, danach 2 × BSv2-Familie: insgesamt also 12 vCPU, mit zweitem DC 14. Reicht das Kontingent nicht, `fileServerVmSize = Standard_B2s_v2` setzen; die Beispieldaten entstehen dann über viele Stunden im Hintergrund.
- **Windows-11-Lizenz (Client):** Windows 11 auf Azure braucht Multitenant Hosting Rights, laut Microsoft z. B. Windows Enterprise E3/E5 oder VDA pro Benutzer (Lizenzgrundlage u. a. auch M365 E3/E5/F3 und Business Premium), alternativ ein Dev/Test-Angebot der Subscription. Ohne passende Lizenz `deployClient = false` setzen.
- **Office-Lizenz (Client):** Microsoft 365 Apps aktiviert der Azubi mit seinem Firmenkonto (eine von fünf Installationen). `officeProductId` muss zur Lizenz passen: `O365ProPlusRetail` für Apps for enterprise (M365 E3/E5), `O365BusinessRetail` für Apps for business (Business Standard/Premium).
- **Remote Desktop Manager (Client):** Devolutions RDM Free ist laut Devolutions für eine Einzelperson lizenziert, auch beruflich. Der Lab-Client hat mehrere Benutzer und eine gemeinsame Verbindungsliste. Wer das nicht möchte, setzt `clientRemoteDesktopManager = false`.

## Bereitstellen

1. **Deploy to Azure** klicken, Ressourcengruppe wählen (z. B. `rg-exlab-<k>`).
2. Parameter ausfüllen:

   | Parameter | Pflicht | Bedeutung |
   | --- | --- | --- |
   | `trainee` | ja | Kürzel, 3 Buchstaben |
   | `labLanguage` | nein | Sprache der Lab-Daten: `de` (Standard, Mustermann Medien GmbH, Berlin und Hamburg) oder `en` (Contoso Ltd, London und Manchester). Bestimmt Benutzer, Gruppen, Freigaben, Beispieldokumente, Gebietsschema der VMs und Postfachsprache |
   | `adminPassword` | ja | Passwort für `azadmin` (lokal, Domain-Admin, DSRM) |
   | `labUserPassword` | ja | Passwort der 28 Lab-Benutzer, bewusst ein anderes als `adminPassword` |
   | `allowedRdpSourcePrefix` | ja | eigene öffentliche IP, z. B. `203.0.113.10/32` |
   | `parentDnsZoneName` | ja | übergeordnete DNS-Zone `<zone>`, Name vom Ausbilder |
   | `parentDnsZoneResourceGroup` | nein | Ressourcengruppe der übergeordneten Zone, Standard `rg-publicdns` |
   | `exchangePublishedSourcePrefix` | nein | Quelle für 443/80, leer = wie RDP |
   | `smtpSourcePrefix` | nein | Quelle für 25, leer = wie 443/80. Für eingehende Mails erst nach dem Update-Lauf auf `Internet` stellen |
   | `autoShutdownTime` | nein | tägliches Herunterfahren von Exchange-VM, Client, Fileserver und zweitem DC (`HHmm`), Standard `1900`, leer = aus |
   | `deploySecondDc` | nein | zweiten Domain Controller `<K>-DC02` bereitstellen, Standard `false` |
   | `deployClient` | nein | Windows-11-Client `<K>-CL01` bereitstellen, Standard `true` |
   | `officeProductId` | nein | `O365ProPlusRetail` (Standard, Apps for enterprise) oder `O365BusinessRetail` (Apps for business) |
   | `clientImageSku` / `clientVmSize` | nein | Windows-11-Image (Standard `win11-25h2-ent`) und VM-Größe des Clients |
   | `clientRemoteDesktopManager` | nein | Remote Desktop Manager mit Verbindungen zu allen Lab-Servern auf dem Client, Standard `true`. Achtung: Jeder Benutzer am Client kann dann das Passwort von `azadmin` auslesen |
   | `deployFileServer` | nein | Fileserver `<K>-FS01` bereitstellen, Standard `true` |
   | `fileServerDataPercent` | nein | Umfang der Beispieldokumente in Prozent der Datendisk (256 GB), Standard `90` (rund 230 GB), `0` = keine |
   | `fileServerVmSize` / `fileServerFinalVmSize` | nein | Größe während der Erzeugung (Standard `Standard_D4s_v5`) und Dauergröße danach (Standard `Standard_B2s_v2`, leer = bleibt). Bei einem erneuten Deployment `fileServerVmSize = Standard_B2s_v2` übergeben, sonst wird der Fileserver kurz wieder vergrößert |
   | `enableLetsEncrypt` / `letsEncryptStaging` | nein | Zertifikat an/aus, Test-CA für Testdeployments |
   | `wingetPackages` | nein | zusätzliche Tools per winget, Standard `Microsoft.VisualStudioCode` |

3. Das Deployment dauert **ca. 1–1,5 Stunden**, mit zweitem DC etwas länger: Exchange beginnt erst, wenn DC02 vollständig bereit ist (SYSVOL, DNS, Replikation in beide Richtungen). Im Test waren es rund 65 Minuten, davon allein 31 Minuten Exchange-Setup. Danach startet der Exchange-Server neu und installiert im Hintergrund alle Updates, inklusive Exchange-Sicherheitsupdate über Microsoft Update. Die DCs starten ihren Update-Lauf erst ganz am Ende des Deployments, wenn Exchange, Client und Fileserver fertig sind; so trifft kein DC-Neustart eine VM, die gerade beitritt. Rechne mit weiteren 30–60 Minuten. Die Beispieldaten des Fileservers entstehen höchstens 60 Minuten lang im Deployment, der Rest im Hintergrund: Mit `Standard_D4s_v5` waren 60 GB im Test nach gut 30 Minuten fertig, für rund 230 GB sind etwa zwei Stunden zu erwarten. Danach verkleinert sich der Fileserver selbst auf `Standard_B2s_v2` und startet dafür einmal neu.

   **Startzeit:** Mit der Standard-Abschaltzeit 19:00 das Deployment bis etwa **17:30** starten. Die Abschaltung unterbricht kein Deployment-Modul, aber laufende Hintergrundarbeiten (Updates, Beispieldaten). Diese setzen nach dem nächsten Start fort, fertig ist das Lab dann erst am nächsten Tag.

4. **Prüfen:** `./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-<k> -Wait` prüft Deployment, DNS-Delegation, alle VMs und die Hintergrundarbeiten und wartet, bis diese fertig sind. Exit-Code 0 heißt: Lab vollständig und fehlerfrei. Details in [Betrieb](operations.md#lab-prüfen).

Welcher Schritt wann auf welcher VM läuft und wohin er protokolliert, steht in der [Architektur](architecture.md#ablauf-und-logs).

## Nach dem Deployment

- **Einstieg über den Client:** RDP auf `clientRdpHost`, z. B. als `<K>\mmustermann` (englisch `<K>\fbloggs`). Von dort geht es per **Remote Desktop Manager** (Desktop oder Startmenü, Arbeitsbereich „Lab-Server“) ohne Passworteingabe als `<K>\azadmin` auf `<K>-DC01`, `<K>-EX01`, `<K>-FS01` und, falls bereitgestellt, `<K>-DC02`. Den Arbeitsbereich bindet Active Setup bei der ersten Anmeldung jedes Benutzers ein. **Sicherheitshinweis:** RDM verschlüsselt die gespeicherten Passwörter mit einem eingebauten Schlüssel, deshalb kann jeder Benutzer des Clients das Passwort von `azadmin` auslesen. Am Client ist die Trennung von `labUserPassword` und `adminPassword` damit aufgehoben. Das ist eine bewusste Entscheidung für den Lab-Komfort; abschalten mit `clientRemoteDesktopManager = false`.
- **RDP direkt:** Der Exchange-Server ist auch direkt per Public IP erreichbar (Ausgabe `rdpHost`, als `<K>\azadmin`). DNS-Konsole, GPMC und AD-Verwaltung sind dort installiert.
- **Client:** Beim ersten Start von Word oder Outlook mit dem eigenen Firmenkonto anmelden, damit sich Office aktiviert. Die Registrierung des Lab-Clients im Entra ID der Firma ist per Richtlinie (`BlockAADWorkplaceJoin`) blockiert. Outlook (klassisch) legt das Profil per Autodiscover selbst an. Meldet Office eine fehlende Lizenz, passt `officeProductId` nicht zur Lizenz.
- **Lab-Info:** Auf dem Desktop des Exchange-Servers liegen `Lab-Info.txt` (Domain, URLs, alle Benutzer und Beispielempfänger, Zertifikat, Logs) und Verknüpfungen zu OWA, ECP und den Logs.
- **Fileserver:** RDP vom Client aus auf `<K>-FS01` (keine Public IP). Dort zeigt `Lab-Info.txt` Freigaben, Gruppen und den Stand der Beispieldaten. Auf dem Client sind die Freigaben unter `\\<K>-FS01\Abteilungen`, `\Projekte`, `\Archiv` und `\Scans` (englisch `\Departments`, `\Projects`, `\Archive`, `\Scans`) erreichbar, der Basisordner als `H:`. Ob die Beispieldaten fertig sind, steht in `C:\ExchangeLab\sample-documents.json` (`State` = `fertig`), siehe auch [Betrieb](operations.md#fileserver-beispieldaten-und-vm-größe).
- **OWA/ECP:** `https://mail.<k>.<zone>/owa` bzw. `/ecp`, z. B. als `mmustermann@<k>.<zone>` bzw. `fbloggs@<k>.<zone>`.
- **Diagnose:** In `C:\ExchangeLab\Tools` liegen `HealthChecker.ps1`, `SetupAssist.ps1` und `SetupLogReviewer.ps1` aus [CSS-Exchange](https://github.com/microsoft/CSS-Exchange) (festes Release, SHA256-geprüft). Aufruf in der Exchange Management Shell als Administrator.
- **Eingehende Mails aus dem Internet:** erst wenn `Update-LabServer.log` fertig ist, die NSG-Regel `Allow-Exchange-SMTP` auf Quelle `Internet` stellen.
- **OWA/Outlook von überall:** `Allow-Exchange-Web` nur kurzzeitig auf `Internet` stellen. Damit ist auch ECP mit der Anmeldung des Domain-Admins öffentlich erreichbar.
- **Kennwörter** von `azadmin` und den Lab-Benutzern laufen nicht ab (Lab-Kompromiss, sonst nach 42 Tagen).
- **Gelöschte AD-Objekte** lassen sich über den AD-Papierkorb wiederherstellen (Active Directory-Verwaltungscenter).
- **Ausgehende Mails** an fremde Domains gehen aus Azure nur supportet über einen Smart Host (Send Connector mit Relay). Das ist bewusst nicht vorkonfiguriert.

## Lab abbauen

Beim Löschen eines Labs immer auch die Delegation in `<zone>` entfernen, sonst bleibt ein verwaister NS-Eintrag stehen (Gefahr einer Subdomain-Übernahme). Befehle in [Betrieb](operations.md#lab-abbauen).
