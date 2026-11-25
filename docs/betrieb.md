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

Der Fileserver hat keine Public IP. RDP geht vom Exchange-Server aus auf `<K>-FS01`.

Nach dem Start braucht Exchange einige Minuten, bis alle Dienste laufen. OWA meldet bis dahin Fehler 500 oder 503.

## Neue eigene IP-Adresse (RDP geht nicht mehr)

Die NSG lässt RDP nur von der IP zu, die beim Deployment in `allowedRdpSourcePrefix` stand. Nach einem Wechsel (Homeoffice, anderes Netz) die Regeln anpassen:

```bash
MYIP=$(curl -s https://ifconfig.me)
az network nsg rule update -g rg-exlab-<k> --nsg-name nsg-exlab-<k> -n Allow-RDP-Exchange --source-address-prefixes "$MYIP/32"
az network nsg rule update -g rg-exlab-<k> --nsg-name nsg-exlab-<k> -n Allow-RDP-Client --source-address-prefixes "$MYIP/32"
```

Die Regeln `Allow-Exchange-Web` und `Allow-Exchange-SMTP` nutzen standardmäßig dieselbe Quelle und müssen ggf. ebenfalls angepasst werden. Ein erneutes Deployment setzt alle Regeln auf die Parameterwerte zurück.

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

Die Beispieldokumente entstehen im Deployment höchstens 60 Minuten lang, den Rest erzeugt der Task `TraineeLab-SampleDocuments` im Hintergrund. Danach verkleinert sich der Fileserver selbst auf `fileServerFinalVmSize` (Standard `Standard_B2s_v2`). Das passiert erst, wenn Beispieldaten, Einrichtung und Update-Lauf fertig sind, und kostet einen Neustart.

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
