# Übungen zum Trainee Lab

Die Übungen bauen auf dem fertig bereitgestellten Lab auf: Lab-Benutzer, Verteiler, freigegebene Postfächer, Räume und Kontakte sind schon da (siehe `Lab-Info.txt` auf dem Desktop des Exchange-Servers), ebenso die Freigaben und Beispieldaten des Fileservers (`Lab-Info.txt` auf `<K>-FS01`).

## So arbeitest du

- **Platzhalter:** `<k>` = dein Kürzel (klein), `<K>` = dein Kürzel (groß), `<zone>` = übergeordnete DNS-Zone. Deine Mail-Domain ist also `<k>.<zone>`, die AD-Domain `<k>.intern`. In den Kapiteln 9 und 10 steht `<mandant>` für den Microsoft-365-Übungsmandanten.
- **EMS:** Exchange Management Shell auf `<K>-EX01`, per Rechtsklick *Als Administrator ausführen*. Viele Aufgaben gehen auch im ECP (`https://mail.<k>.<zone>/ecp`). Probiere beide Wege aus.
- **Prüfen:** Jede Übung endet mit einem Prüfbefehl und dem erwarteten Ergebnis. Stimmt es nicht, erst selbst suchen (Log, Ereignisanzeige, `Get-Help <Cmdlet> -Full`), dann fragen.
- **Vorher fertig?** Der Update-Lauf nach dem Deployment muss abgeschlossen sein (`C:\ExchangeLab\Logs\Update-LabServer.log` endet mit „Keine ausstehenden Updates“ oder „Maximale Anzahl“). Für Kapitel 8 müssen außerdem die Beispieldaten fertig sein (`C:\ExchangeLab\sample-documents.json` auf `<K>-FS01`, `State` = `fertig`).
- **Kaputt gemacht?** Gehört dazu. Hilfe in [troubleshooting.md](../troubleshooting.md), Notfall: Lab abbauen und neu deployen ([betrieb.md](../betrieb.md)).

Schwierigkeit: ★ Einstieg, ★★ Fortgeschritten, ★★★ Profi.

## Kapitel

| Kapitel | Themen | Stufe |
| --- | --- | --- |
| [1 Empfänger und Berechtigungen](01-empfaenger.md) | Postfächer, Adressen, Verteiler, dynamische Verteiler, FullAccess/SendAs, Räume, Kontingente | ★–★★ |
| [2 Client und Outlook](02-client-outlook.md) | Office-Aktivierung, Autodiscover, Automapping, Senden als, Raumbuchung, GPO | ★–★★ |
| [3 Mailfluss](03-mailfluss.md) | Nachrichtenverfolgung, eingehende Mails, Transportregeln, Relay, Warteschlangen, Anti-Spam, SPF/DMARC | ★★–★★★ |
| [4 Zertifikate und Sicherheit](04-zertifikate-sicherheit.md) | Zertifikate, NSG, RBAC, Admin-Überwachungsprotokoll | ★★ |
| [5 Datenbanken und Backup](05-datenbanken-backup.md) | zweite Datenbank, Postfachverschiebung, Transaktionslogs, Windows Server Backup, Recovery-Datenbank | ★★–★★★ |
| [6 Active Directory und DNS](06-active-directory.md) | Split DNS, AD-Papierkorb, Gruppenrichtlinien, Delegation, Replikation und FSMO mit zweitem DC | ★–★★★ |
| [7 Updates und Diagnose](07-updates-diagnose.md) | Build-Nummern, HealthChecker, Security Updates, Wartungsmodus, Managed Availability | ★★ |
| [8 Fileserver](08-fileserver.md) | Freigaben, NTFS und ABE, AGDLP, Altlasten, Laufwerke per GPO, FSRM, Schattenkopien, Deduplizierung, Archivierung, Entra-Branding | ★–★★★ |
| [9 Migration nach SharePoint Online](09-migration-sharepoint.md) | Bestandsaufnahme, Zielstruktur, Benutzerzuordnung, SharePoint Migration Tool, OneDrive, Umstellung | ★★–★★★ |
| [10 Datenklassifizierung](10-datenklassifizierung.md) | sensible Daten finden, Vertraulichkeitsbezeichnungen, automatische Bezeichnung, Fehlablagen, DLP, Aufbewahrung | ★★–★★★ |

Kapitel 6.5 bis 6.7 brauchen den zweiten DC (`deploySecondDc = true`), Kapitel 2 sowie 8.4 und 8.7 den Client (`deployClient = true`), Kapitel 8 den Fileserver (`deployFileServer = true`, Standard). Übung 8.10 und die Kapitel 9 und 10 brauchen einen Microsoft-365-Übungsmandanten mit SharePoint Online vom Ausbilder, Kapitel 10 zusätzlich Microsoft-Purview-Funktionen (z. B. Microsoft 365 E5 oder E5 Compliance). Kapitel 10 setzt Kapitel 9 voraus: Klassifiziert wird erst, wenn die Daten in SharePoint Online liegen.
