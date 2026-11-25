# Troubleshooting

Platzhalter wie in [betrieb.md](betrieb.md). „EMS“ = Exchange Management Shell auf `<K>-EX01`, als Administrator gestartet.

## Deployment ist fehlgeschlagen

1. Im Portal unter Ressourcengruppe → *Bereitstellungen* den fehlgeschlagenen Schritt suchen. Meist ist es ein Run Command (`Install-DomainController`, `Initialize-ExchangeServer`, `Wait-DomainController`, `Install-ExchangeServer`, `Initialize-LabClient`, `Complete-LabClient`, auf dem Fileserver `Initialize-FileServer`, `New-SampleDocuments`, `Complete-FileServer`).
2. Die Fehlermeldung enthält das Ende des passenden Logs. Das vollständige Log liegt auf der VM unter `C:\ExchangeLab\Logs`.
3. Ursache beheben (z. B. Kontingent, Rechte, Zone), dann den **fehlgeschlagenen Run Command löschen** und **mit denselben Parametern erneut deployen**. Ohne das Löschen führt Azure einen fehlgeschlagenen Run Command mit unveränderten Eigenschaften nicht noch einmal aus, das Deployment meldet nur den alten Fehler. Die Skripte sind idempotent, bereits erledigte Schritte werden übersprungen.

   ```bash
   az vm run-command list -g rg-exlab-<k> --vm-name vm-<k>-dc02 --query "[].{name:name, state:provisioningState}" -o table
   az vm run-command delete -g rg-exlab-<k> --vm-name vm-<k>-dc02 --name Install-DomainController --yes
   ```

Typische Ursachen:

| Meldung / Symptom | Ursache | Lösung |
| --- | --- | --- |
| `QuotaExceeded` | zu wenig vCPU in der Region | Kontingent erhöhen lassen oder `deployClient`/`deploySecondDc` aus. Betrifft es die DSv5-Familie: `fileServerVmSize = Standard_B2s_v2` |
| `AuthorizationFailed` bei der Rollenzuweisung | kein Owner auf der Ressourcengruppe | Rechte vom Ausbilder holen oder `enableLetsEncrypt = false` und `fileServerFinalVmSize` leer lassen |
| `New-SampleDocuments` meldet einen Fehler | Datendisk fehlt oder Textkorpus aus der userData nicht lesbar | `New-SampleDocuments.log` auf dem Fileserver lesen. Ein reines Zeitproblem ist kein Fehler: Nach 60 Minuten endet der Run Command erfolgreich und der Task setzt fort |
| `Wait-DomainController` läuft in Timeout | DC nicht fertig geworden | `Install-DomainController-*.log` auf dem DC lesen, bei vorgemerktem Neustart auch `Install-DomainController-Promote.log` |
| „Role change is in progress or this computer needs to be restarted“ | Windows-Wartung nach dem ersten Start hat einen Neustart vorgemerkt | Das Skript stuft dann automatisch nach einem Neustart herauf. Steht der Fehler trotzdem im Log: DC im Gast neu starten, Run Command löschen, erneut deployen |
| `letsencrypt-failed.txt` in `C:\ExchangeLab` | Zertifikat nicht ausgestellt, Exchange nutzt selbstsigniertes Zertifikat | Delegation der Subdomain prüfen, siehe unten |

## OWA meldet Zertifikatsfehler

- **Testdeployment mit `letsEncryptStaging = true`:** Die Staging-CA ist absichtlich nicht vertrauenswürdig. Das ist kein Fehler.
- **`C:\ExchangeLab\letsencrypt-failed.txt` existiert:** Die DNS-Challenge hat nicht funktioniert. Prüfen, ob die Subdomain von außen auflösbar ist:

  ```powershell
  Resolve-DnsName -Name <k>.<zone> -Type NS -Server 1.1.1.1
  ```

- **Zertifikat abgelaufen:** `C:\ExchangeLab\Logs\Invoke-LabMaintenance.log` lesen. Wartung von Hand anstoßen: `Start-ScheduledTask -TaskName ExchangeLab-Maintenance`. Hilft das nicht, die manuelle Erneuerung aus dem [readme](../readme.md#zertifikat) nutzen.

## Exchange-Dienste laufen nach dem Start nicht

Kurz nach dem Start sind einige Dienste noch nicht bereit. Nach 10 Minuten in der EMS:

```powershell
Test-ServiceHealth
Get-Service MSExchange* | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' } | Start-Service
```

Bleiben Dienste aus, ist oft der DC nicht erreichbar: `nltest /dsgetdc:<k>.intern` auf dem Exchange-Server.

## SYSVOL und NETLOGON fehlen auf dem DC

Symptom: `net share` auf dem DC zeigt weder `SYSVOL` noch `NETLOGON`, Gruppenrichtlinien werden nicht angewendet. Ursache ist fast immer, dass der DC im Portal gestoppt (deallokiert) wurde. Danach ist SYSVOL nicht-autoritativ und findet keinen Partner, von dem es synchronisieren kann.

**Nur ein DC:** SYSVOL auf diesem DC autoritativ setzen (entspricht dem „D4“ aus der Microsoft-Anleitung). Auf `<K>-DC01`, PowerShell als Administrator:

```powershell
Install-WindowsFeature RSAT-DFS-Mgmt-Con          # liefert dfsrdiag
Set-Service DFSR -StartupType Manual; Stop-Service DFSR

$dn = "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,$((Get-ADDomainController).ComputerObjectDN)"
Set-ADObject -Identity $dn -Replace @{ 'msDFSR-Enabled' = $false; 'msDFSR-options' = 1 }

Start-Service DFSR                                 # Ereignis 4114 im Log "DFS Replication"
Set-ADObject -Identity $dn -Replace @{ 'msDFSR-Enabled' = $true }
dfsrdiag pollad                                    # Ereignis 4602: SYSVOL initialisiert
Set-Service DFSR -StartupType Automatic
net share                                          # SYSVOL und NETLOGON sind wieder da
```

**Zwei DCs, beide waren deallokiert:** `<K>-DC01` (PDC-Emulator) autoritativ, `<K>-DC02` nicht-autoritativ setzen. Die vollständige Reihenfolge steht bei Microsoft: [Force authoritative and non-authoritative synchronization for DFSR-replicated SYSVOL](https://learn.microsoft.com/troubleshoot/windows-server/group-policy/force-authoritative-non-authoritative-synchronization).

## Mails bleiben in der Warteschlange

```powershell
Get-Queue
Get-Message -Queue "<K>-EX01\<Queue-Identität>" | Format-List FromAddress, Recipients, LastError
```

- **Externe Empfänger** (Warteschlange mit `DeliveryType` `Unreachable`): Es gibt keinen Send Connector, außerdem blockiert Azure ausgehend Port 25. Das ist so gewollt. Siehe Übung 3.6 in [Kapitel 3](uebungen/03-mailfluss.md).
- **Interne Empfänger:** `Test-ServiceHealth` und `Get-ServerComponentState <K>-EX01` prüfen. Steht `HubTransport` auf `Inactive`, mit `Set-ServerComponentState <K>-EX01 -Component HubTransport -State Active -Requester Maintenance` aktivieren.

## Outlook auf dem Client verbindet nicht

1. Ist der Benutzer mit Domänenkonto angemeldet (`<K>\mmustermann`), nicht als lokaler Admin?
2. Löst der Client richtig auf? `Resolve-DnsName mail.<k>.<zone>` muss `10.0.1.5` liefern (Split DNS).
3. Autodiscover testen: Strg + Rechtsklick auf das Outlook-Symbol im Infobereich → *E-Mail-AutoKonfiguration testen*.
4. Wurde versehentlich das **neue** Outlook gestartet? Es unterstützt kein Exchange on Premises. Das klassische Outlook über *Start → Outlook (classic)* öffnen.

## Office meldet „Nicht lizenziertes Produkt“

- Mit dem **Firmenkonto** angemeldet, nicht mit dem Lab-Konto? Das Lab-Konto hat keine Microsoft-365-Lizenz.
- Lizenzstatus anzeigen (PowerShell als Administrator):

  ```powershell
  cd "C:\Program Files\Microsoft Office\Office16"
  .\vnextdiag.ps1 -action list
  ```

- Passt die Produkt-ID nicht zur Lizenz (Apps for business vs. Apps for enterprise): Microsoft 365 Apps unter *Einstellungen → Apps* deinstallieren, in `C:\ExchangeLab\Install\OfficeDeploymentTool\LabConfiguration.xml` die `Product ID` ändern und als Administrator neu installieren:

  ```powershell
  cd C:\ExchangeLab\Install\OfficeDeploymentTool
  .\setup.exe /configure LabConfiguration.xml
  ```

## Client-Oberfläche ist Englisch

Das Sprachpaket wird beim Aufbau installiert und greift nach dem Neustart. Steht in `Initialize-LabClient-Prepare.log` eine Warnung zum Sprachpaket, als Administrator nachholen:

```powershell
Install-Language de-DE -CopyToSettings
Set-SystemPreferredUILanguage de-DE
Restart-Computer
```

## Beispieldaten fehlen oder wachsen nicht mehr

Stand auf `<K>-FS01` (PowerShell als Administrator):

```powershell
Get-Content C:\ExchangeLab\sample-documents.json
Get-Content C:\ExchangeLab\Logs\New-SampleDocuments.log -Tail 20
Get-ScheduledTask -TaskName TraineeLab-SampleDocuments | Get-ScheduledTaskInfo
```

- **`State` = `wird im Hintergrund fortgesetzt`, Log steht still:** Die VM wurde zur Abschaltzeit heruntergefahren. Der Task startet beim nächsten Start von selbst, sofort geht es mit `Start-ScheduledTask -TaskName TraineeLab-SampleDocuments`. Der Generator überspringt vorhandene Dateien und räumt halbfertige auf.
- **`WARNUNG`-Zeilen im Log:** Einzelne Dateien oder Einheiten sind fehlgeschlagen. Das stört die übrigen Daten nicht. Bei vielen gleichen Warnungen das Log an den Ausbilder geben.
- **Kein Statusfile:** Der Run Command `New-SampleDocuments` ist nicht gelaufen (`fileServerDataSizeGB = 0` oder Fehler im Deployment).

## Fileserver bleibt groß

Der Fileserver verkleinert sich erst, wenn Beispieldaten, Einrichtung und Update-Lauf fertig sind und er mindestens 30 Minuten läuft. Den Grund fürs Warten nennt das Log:

```powershell
Get-Content C:\ExchangeLab\Logs\Resize-FileServer.log -Tail 10
```

Steht dort, dass die Größe im aktuellen Cluster nicht verfügbar ist, von Hand verkleinern (Cloud Shell):

```bash
az vm deallocate -g rg-exlab-<k> -n vm-<k>-fs01
az vm resize -g rg-exlab-<k> -n vm-<k>-fs01 --size Standard_B2s_v2
az vm start -g rg-exlab-<k> -n vm-<k>-fs01
```

## Zugriff verweigert auf `Home\JFrick\Privat`

Das ist gewollt: Der Ordner ist eine der Altlasten aus [Kapitel 8](uebungen/08-fileserver.md). Nur Johann Frick und SYSTEM haben Rechte, Domain-Admins nicht. Wie man damit umgeht, ohne die Rechte zu zerstören, ist Übung 8.3.

## Kennwort eines Lab-Benutzers vergessen

Auf dem Exchange-Server als `<K>\azadmin` in *Active Directory-Benutzer und -Computer* das Kennwort zurücksetzen, oder:

```powershell
Set-ADAccountPassword -Identity mmustermann -Reset -NewPassword (Read-Host -AsSecureString 'Neues Kennwort')
```
