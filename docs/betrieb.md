# Betrieb des Labs

Platzhalter: `<k>` = dein Kürzel (klein), `<K>` = dein Kürzel (groß), `<zone>` = übergeordnete DNS-Zone vom Ausbilder. Die Befehle laufen in der [Azure Cloud Shell](https://shell.azure.com) (Bash) oder lokal mit Azure CLI.

## Ausgaben des Deployments anzeigen

```bash
az deployment group list -g rg-exlab-<k> --query "[?properties.outputs.owaUrl].properties.outputs" -o json
```

Wichtig sind `rdpHost` (Exchange-Server), `clientRdpHost` (Windows-11-Client) und `owaUrl`.

## Starten und Stoppen

Die Exchange-VM, der optionale zweite DC, der Client und der Fileserver fahren täglich zur Abschaltzeit (`autoShutdownTime`, Standard 19:00) herunter. **Der erste DC (`vm-<k>-dc01`) läuft immer durch und wird nie im Portal gestoppt.** Warum, steht im [readme](../readme.md#kosten-und-abschalten).

Morgens starten:

```bash
az vm start -g rg-exlab-<k> -n vm-<k>-dc02   # nur mit zweitem DC
az vm start -g rg-exlab-<k> -n vm-<k>-ex01
az vm start -g rg-exlab-<k> -n vm-<k>-cl01   # nur mit Client
az vm start -g rg-exlab-<k> -n vm-<k>-fs01   # nur mit Fileserver
```

Vorzeitig abschalten (spart Geld, z. B. vor einem langen Wochenende):

```bash
az vm deallocate -g rg-exlab-<k> -n vm-<k>-cl01
az vm deallocate -g rg-exlab-<k> -n vm-<k>-fs01
az vm deallocate -g rg-exlab-<k> -n vm-<k>-ex01
az vm deallocate -g rg-exlab-<k> -n vm-<k>-dc02
```

Der Fileserver hat keine Public IP. RDP geht vom Client aus auf `<K>-FS01` (Remote Desktop Manager, siehe unten).

Nach dem Start braucht Exchange einige Minuten, bis alle Dienste laufen. OWA meldet bis dahin Fehler 500 oder 503.

## Neue eigene IP-Adresse (RDP geht nicht mehr)

Die NSG lässt RDP nur von der IP zu, die beim Deployment in `allowedRdpSourcePrefix` stand. Nach einem Wechsel (Homeoffice, anderes Netz) die Regeln anpassen:

```bash
MYIP=$(curl -s https://ifconfig.me)
az network nsg rule update -g rg-exlab-<k> --nsg-name nsg-exlab-<k> -n Allow-RDP-Exchange --source-address-prefixes "$MYIP/32"
az network nsg rule update -g rg-exlab-<k> --nsg-name nsg-exlab-<k> -n Allow-RDP-Client --source-address-prefixes "$MYIP/32"
```

Die Regeln `Allow-Exchange-Web` und `Allow-Exchange-SMTP` nutzen standardmäßig dieselbe Quelle und müssen ggf. ebenfalls angepasst werden. Ein erneutes Deployment setzt alle Regeln auf die Parameterwerte zurück.

## Server vom Client aus erreichen (Remote Desktop Manager)

Auf `<K>-CL01` ist Devolutions Remote Desktop Manager Free installiert (Parameter `clientRemoteDesktopManager`, Standard `true`). Desktop oder Startmenü → *Remote Desktop Manager*. Im Arbeitsbereich **Lab-Server** stehen `<K>-DC01`, `<K>-EX01`, `<K>-FS01` und, falls bereitgestellt, `<K>-DC02`. Ein Doppelklick verbindet als `<K>\azadmin`, ohne Passworteingabe.

So ist es aufgebaut:

- Die Verbindungen liegen in einer gemeinsamen Datei `C:\ProgramData\TraineeLab\RemoteDesktopManager\Lab-Server.xml`. Sie entsteht in der Phase *Complete* des Deployments neu.
- Bei der ersten Anmeldung jedes Benutzers bindet Active Setup (`TraineeLab-RemoteDesktopManager`) die Datei als Standard-Arbeitsbereich ein. Log: `%LOCALAPPDATA%\TraineeLab\Register-LabWorkspace.log`.
- Alle Benutzer dürfen die Datei ändern, weil RDM sie beim Laden neu schreibt. Änderungen an Verbindungen sehen deshalb alle Benutzer des Clients.

> **Sicherheitshinweis:** RDM verschlüsselt gespeicherte Passwörter mit einem Schlüssel, der in jeder Installation gleich ist. Jeder Benutzer des Clients kann deshalb das Passwort von `azadmin` auslesen. Am Client gilt die Trennung von `labUserPassword` und `adminPassword` also nicht. Das ist eine bewusste Entscheidung für den Lab-Komfort. Wer das nicht will, deployt mit `clientRemoteDesktopManager = false`.

**Admin-Passwort geändert:** In RDM die Verbindungen markieren → *Bearbeiten* → *Anmeldeinformationen* und das neue Passwort eintragen. Da die Datei gemeinsam genutzt wird, gilt das für alle Benutzer.

**RDM-Version aktualisieren (Repository):** In `scripts/Initialize-LabClient.ps1` stehen die Pins `$RdmInstaller` (URL und SHA256 aus [productinfo.json](https://devolutions.net/productinfo.json), Abschnitt `RDMWindows.Current`, x64-MSI), `$RdmModule` (Version aus der PowerShell Gallery) und `$DotNetDesktopRuntime`. Die Updatesuche in RDM ist per Richtlinie aus, weil Lab-Benutzer keine Adminrechte haben. Auf einem laufenden Client installiert ein Administrator ein neues MSI von Hand.

## Lab prüfen

Ein Werkzeug prüft das ganze Lab von außen (Azure CLI, angemeldet mit Run-Command-Rechten auf der Ressourcengruppe):

```powershell
./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-<k>
./tools/Test-LabDeployment.ps1 -ResourceGroup rg-exlab-<k> -Wait   # wartet auf Updates, Beispieldaten, Verkleinerung
```

Es liest Sprache und Optionen aus dem letzten Lab-Deployment und prüft:

| Bereich | Prüfungen |
| --- | --- |
| Azure | alle Deployments und Run Commands erfolgreich, DNS-Delegation in der Parent-Zone, Fileserver auf Dauergröße |
| DCs | DC-Rolle und Dienste, `dc-ready.txt`, SYSVOL/NETLOGON, Forwarder, SRV-Records aller DCs, Split DNS, PTR, AD-Standorte, Replikation, Lab-Benutzer mit Firma/Fax/Ort |
| Exchange | Installation, Dienste, Postfächer und Beispielempfänger, Postfachsprache, Zertifikat auf 443 (Let's Encrypt, für SMTP aktiviert), OWA-URLs und `healthcheck.htm`, Wartungs-Task |
| Fileserver | Phase Complete, Freigaben mit zugriffsbasierter Aufzählung, Altlasten, Beispieldaten fertig und Datenlaufwerk gefüllt |
| Client | Domäne und Secure Channel, Anzeigesprache, Microsoft 365 Apps, Remote Desktop Manager, RDP für Domänen-Benutzer |
| alle VMs | keine `WARNUNG:`/`FEHLER:` in `C:\ExchangeLab\Logs`, Gebietsschema, Update-Lauf fertig, `Lab-Info.txt` ohne offene Platzhalter |

Jede Prüfung ist `OK`, `FAIL` oder `PENDING` (Hintergrundarbeit läuft noch). Exit-Code 0 = alles OK, 1 = Fehler, 2 = noch nicht fertig. Die Prüfskripte je Rolle liegen in `tools/LabChecks`. Ist eine VM gestoppt (Abschaltzeit), meldet das Werkzeug `PENDING`, bis sie wieder läuft.

## Status prüfen

Stand eines Run Commands (z. B. Exchange-Installation):

```bash
az vm run-command show -g rg-exlab-<k> --vm-name vm-<k>-ex01 --name Install-ExchangeServer --instance-view \
  --query "instanceView.{Status:executionState, ExitCode:exitCode}"
```

Ende eines Logs lesen, ohne RDP:

```bash
az vm run-command invoke -g rg-exlab-<k> -n vm-<k>-ex01 --command-id RunPowerShellScript \
  --scripts "Get-Content C:\ExchangeLab\Logs\Update-LabServer.log -Tail 20"
```

Alle Logs liegen auf jeder VM unter `C:\ExchangeLab\Logs`. Welcher Schritt wo protokolliert wird, steht im [readme](../readme.md#ablauf-und-logs). Die Run Commands des Fileservers heißen `Initialize-FileServer`, `New-SampleDocuments`, `Wait-DomainController` und `Complete-FileServer`:

```bash
az vm run-command list -g rg-exlab-<k> --vm-name vm-<k>-fs01 --query "[].{name:name, state:provisioningState}" -o table
```

## Fileserver: Beispieldaten und VM-Größe

Die Beispieldokumente füllen die Datendisk `F:` bis `fileServerDataPercent` (Standard 90 %, rund 230 GB), in der Sprache aus `labLanguage`. Davon ist rund ein Drittel Kopien wie auf echten Servern (Basisordner, „Kopie von“, alte Versionen, Quartalssicherungen im Archiv). Für mehr als rund 60 GB eigene Dokumente legt der Generator entsprechend mehr Projekte je Kunde und Jahr an. Er hört auf, wenn weniger als 8 % der Disk frei sind.

Die Dokumente entstehen im Deployment höchstens 60 Minuten lang, den Rest erzeugt der Task `TraineeLab-SampleDocuments` im Hintergrund (mit `Standard_D4s_v5` insgesamt zwei bis drei Stunden; ist das Burst-Guthaben der Standard-SSD aufgebraucht, begrenzen deren IOPS das Tempo). Danach verkleinert sich der Fileserver selbst auf `fileServerFinalVmSize` (Standard `Standard_B2s_v2`). Bietet der Hardware-Cluster der VM diese Größe nicht an (eine Größenänderung ohne Deallokieren geht nur innerhalb des Clusters), nimmt er die 2-vCPU-Größe seiner Familie, mit den Standardwerten `Standard_D2s_v5`. Das passiert erst, wenn Beispieldaten, Einrichtung und Update-Lauf fertig sind, und kostet einen Neustart.

Bei 90 % Belegung bleibt wenig Platz für Schattenkopien und eigene Versuche auf `F:`. Wer mehr Luft braucht, setzt `fileServerDataPercent` niedriger, z. B. 60.

Stand der Beispieldaten und der Verkleinerung:

```bash
az vm run-command invoke -g rg-exlab-<k> -n vm-<k>-fs01 --command-id RunPowerShellScript \
  --scripts "Get-Content C:\ExchangeLab\sample-documents.json; Get-Content C:\ExchangeLab\Logs\Resize-FileServer.log -Tail 5"
az vm show -g rg-exlab-<k> -n vm-<k>-fs01 --query hardwareProfile.vmSize -o tsv
```

`State` ist `laeuft`, `wird im Hintergrund fortgesetzt` oder `fertig`. Unterbricht die Abschaltzeit die Erzeugung, setzt der Task nach dem nächsten Start fort. Von Hand anstoßen (auf `<K>-FS01`, PowerShell als Administrator):

```powershell
Start-ScheduledTask -TaskName TraineeLab-SampleDocuments
Get-Content C:\ExchangeLab\Logs\New-SampleDocuments.log -Tail 10 -Wait
```

**Erneut deployen:** Mit den Standardwerten setzt das Template den Fileserver wieder auf `Standard_D4s_v5`, er startet neu und verkleinert sich später erneut. Das vermeidest du mit dem Parameter `fileServerVmSize = Standard_B2s_v2`.

## Kosten im Blick behalten

- Größter Posten ist die Exchange-VM (`Standard_E4s_v5`), danach die Premium-Disks. Disks kosten auch, wenn die VM deallokiert ist, das gilt auch für die 256-GB-Datendisk des Fileservers.
- Der Fileserver läuft nur bis zur automatischen Verkleinerung als `Standard_D4s_v5`. Bleibt er größer, steht der Grund in `Resize-FileServer.log` (siehe [Troubleshooting](troubleshooting.md#fileserver-bleibt-groß)).
- Budget mit E-Mail-Warnung: im Portal Ressourcengruppe → *Kostenverwaltung* → *Budgets* → *Hinzufügen*, z. B. Warnung bei 80 % des Monatsbetrags.
- Zusätzliche Disks aus Übungen (Backup) nach Gebrauch wieder löschen.

## Lab abbauen

**Immer beide Schritte ausführen.** Bleibt der NS-Eintrag in der übergeordneten Zone stehen, zeigt er auf Nameserver, die jemand anderes übernehmen könnte (Subdomain-Übernahme).

```bash
az group delete -n rg-exlab-<k> --yes
az network dns record-set ns delete -g rg-publicdns -z <zone> -n <k> --yes
```
