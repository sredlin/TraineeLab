# Übungen zum Exchange-Lab

Die Übungen bauen auf dem fertig bereitgestellten Lab auf: Lab-Benutzer, Verteiler, freigegebene Postfächer, Räume und Kontakte sind schon da (siehe `Lab-Info.txt` auf dem Desktop des Exchange-Servers).

## So arbeitest du

- **Platzhalter:** `<k>` = dein Kürzel (klein), `<K>` = dein Kürzel (groß), `<zone>` = übergeordnete DNS-Zone. Deine Mail-Domain ist also `<k>.<zone>`, die AD-Domain `<k>.intern`.
- **EMS:** Exchange Management Shell auf `<K>-EX01`, per Rechtsklick *Als Administrator ausführen*. Viele Aufgaben gehen auch im ECP (`https://mail.<k>.<zone>/ecp`). Probiere beide Wege aus.
- **Prüfen:** Jede Übung endet mit einem Prüfbefehl und dem erwarteten Ergebnis. Stimmt es nicht, erst selbst suchen (Log, Ereignisanzeige, `Get-Help <Cmdlet> -Full`), dann fragen.
- **Vorher fertig?** Der Update-Lauf nach dem Deployment muss abgeschlossen sein (`C:\ExchangeLab\Logs\Update-LabServer.log` endet mit „Keine ausstehenden Updates“ oder „Maximale Anzahl“).
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

Kapitel 6.5 bis 6.7 brauchen den zweiten DC (`deploySecondDc = true`), Kapitel 2 den Client (`deployClient = true`).
