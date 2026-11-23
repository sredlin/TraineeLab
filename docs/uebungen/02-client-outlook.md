# 2 Client und Outlook

Voraussetzung: Client `<K>-CL01` (Parameter `deployClient`). RDP auf die Ausgabe `clientRdpHost`.

## 2.1 Als Anwender anmelden und Office aktivieren ★

**Aufgabe:** Melde dich per RDP als `<K>\mmustermann` am Client an. Starte Word und aktiviere Office mit **deinem Firmenkonto**.

**Prüfen:** Word → *Datei → Konto* zeigt „Lizenziertes Produkt“. Frage: Warum taucht der Lab-Client trotzdem nicht in den Geräten der Firma auf? Tipp: `reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin`.

## 2.2 Outlook-Profil per Autodiscover ★

**Ziel:** Verstehen, wie Outlook seinen Server findet.

**Aufgabe:** Starte Outlook (klassisch). Das Profil für `mmustermann@<k>.<zone>` entsteht ohne Eingabe eines Servers. Öffne danach mit Strg + Rechtsklick auf das Outlook-Symbol im Infobereich:

1. *Verbindungsstatus*: Welches Protokoll, welcher Server?
2. *E-Mail-AutoKonfiguration testen*: Nur „Autodiscover verwenden“ anhaken, Ergebnis im Register *Protokoll* lesen.

**Prüfen:** Protokoll ist „HTTP“ (MAPI über HTTP), Server `mail.<k>.<zone>`. Im Protokoll steht, dass Autodiscover per SCP aus dem Active Directory gefunden wurde.

**Zum Nachdenken:** Wie findet ein Outlook auf deinem eigenen Laptop (nicht in der Domäne) den Server? Schau dir dazu den CNAME `autodiscover` in der öffentlichen Zone an.

## 2.3 Automapping ★

**Aufgabe:** Melde dich als `<K>\emustermann` am Client an und starte Outlook.

**Prüfen:** Das Postfach „Info“ erscheint ohne Zutun in der Ordnerliste (Vollzugriff mit Automapping, siehe `Get-MailboxPermission info`). Das Postfach „Buchhaltung“ aus Übung 1.6 ([Kapitel 1](01-empfaenger.md)) erscheint **nicht**. Warum?

## 2.4 Senden als ★

**Aufgabe:** Als Erika eine Mail mit Absender `info@<k>.<zone>` an Max schicken (Feld *Von* einblenden).

**Prüfen:** Bei Max steht als Absender nur „Info“. In der EMS:

```powershell
Get-MessageTrackingLog -Start (Get-Date).AddMinutes(-15) -EventId RECEIVE | Format-Table Timestamp, Sender, Recipients, MessageSubject
```

Wiederhole das als Celina mit *Senden im Auftrag* (Übung 1.6) und vergleiche, was Max sieht.

## 2.5 Raum buchen ★

**Aufgabe:** Lade als Max zu einer Besprechung ein und füge `raum-kiel` als Raum hinzu. Buche danach als Erika denselben Zeitraum.

**Prüfen:** Max bekommt eine Zusage vom Raum, Erika eine Absage (Konflikt). Eine Buchung über 4 Stunden wird abgelehnt, wenn du Übung 1.7 ([Kapitel 1](01-empfaenger.md)) gemacht hast.

## 2.6 Gruppenrichtlinie für Outlook ★★

**Ziel:** Verstehen, warum das neue Outlook im Lab ausgeblendet ist.

**Aufgabe:** Finde heraus, welche GPOs für Max gelten und was „LAB - Outlook klassisch“ einstellt.

```powershell
gpresult /r /scope user
```

Öffne die GPO auf dem Exchange-Server in der Gruppenrichtlinienverwaltung (*Einstellungen*-Register).

**Prüfen:** „LAB - Outlook klassisch“ steht unter den angewendeten Objekten. Die Werte `HideNewOutlookToggle = 1` und `NewOutlookMigrationUserSetting = 0` liegen unter `HKCU\Software\Policies\Microsoft\office\16.0\outlook`. Begründe mit der [Microsoft-Dokumentation](https://learn.microsoft.com/microsoft-365-apps/outlook/manage/admin-controlled-migration-policy), warum das neue Outlook hier nicht funktioniert.

## 2.7 Abwesenheitsnotiz ★

**Aufgabe:** Richte als Karl in Outlook eine Abwesenheitsnotiz ein. Lies sie danach in der EMS aus und ändere den Text für externe Absender.

```powershell
Get-MailboxAutoReplyConfiguration kanders
Set-MailboxAutoReplyConfiguration kanders -ExternalMessage 'Bin im Urlaub.' -ExternalAudience All
```

**Prüfen:** Eine Mail von Max an Karl bekommt die interne Antwort.
