# 9 Migration nach SharePoint Online

Die Mustermann Medien GmbH zieht vom Fileserver nach Microsoft 365: Abteilungs- und Projektdaten nach SharePoint Online, die Basisordner nach OneDrive. Du planst die Migration, probst sie an einem Ordner und führst sie danach durch. Erst wenn die Daten in SharePoint liegen, kommt in [Kapitel 10](10-datenklassifizierung.md) die Klassifizierung.

**Voraussetzungen:**

- Microsoft-365-Übungsmandant `<mandant>` vom Ausbilder, ein Konto mit der Rolle *SharePoint-Administrator* sowie Testbenutzer mit SharePoint-Lizenz (z. B. `kanders@<mandant>.onmicrosoft.com`).
- Übung 8.3 ist erledigt: Altlasten nimmt man nicht mit in die Cloud.
- Werkzeug: [SharePoint Migration Tool](https://learn.microsoft.com/sharepointmigration/introducing-the-sharepoint-migration-tool) (SPMT) auf `<K>-FS01`. Der Fileserver erreicht das Internet ausgehend. Alternativ geht alles auch mit dem [Migration Manager](https://learn.microsoft.com/sharepointmigration/mm-setup-clients) im SharePoint Admin Center (*Migration → Dateifreigaben*), der einen Agenten auf dem Fileserver nutzt.

Die Lab-Benutzer gibt es nur im lokalen AD `<k>.intern`, es gibt keinen Abgleich mit dem Mandanten. Das ist ein typischer Fall bei kleinen Firmen und spielt in 9.3 eine Rolle.

## 9.1 Bestandsaufnahme ★★

**Ziel:** Wissen, was migriert wird, wie viel es ist und was in SharePoint Probleme machen würde.

```powershell
New-Item -Path C:\Temp -ItemType Directory -Force | Out-Null
Get-ChildItem F:\Shares -Directory | ForEach-Object {
    $files = Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue
    [pscustomobject]@{ Freigabe = $_.Name; Dateien = $files.Count; GB = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1GB, 1) }
} | Format-Table -AutoSize

# Kandidaten für Probleme: lange Pfade, gesperrte Namen, Zeichen, die nicht überall gehen
Get-ChildItem F:\Shares -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName.Length -gt 300 -or $_.Name -match '^~\$|_vti_|^desktop\.ini$|[#%]|^\s|\s$' -or $_.BaseName -in 'CON', 'PRN', 'AUX', 'NUL'
} | Select-Object FullName | Export-Csv C:\Temp\probleme.csv -NoTypeInformation -Encoding UTF8

icacls F:\Shares\Abteilungen /save C:\Temp\acl-abteilungen.txt /T /C /Q     # Rechte vorher sichern
```

Die Grenzen von SharePoint und OneDrive stehen unter [Einschränkungen in OneDrive und SharePoint](https://support.microsoft.com/office/restrictions-and-limitations-in-onedrive-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa): höchstens 400 Zeichen für den ganzen Pfad in SharePoint (URL der Website und Bibliothek zählen mit, daher die Grenze 300 lokal), Dateien bis 250 GB, keine Namen wie `desktop.ini`, `~$…` oder `_vti_`.

**Prüfen:** Du hast eine Tabelle mit Dateianzahl und Größe je Freigabe und eine Liste möglicher Problemdateien. Entscheide und begründe: Was passiert mit `Archiv` (abgeschlossene Jahre) und mit `Scans` (Eingangskorb)? Müssen alle zwölf Jahre in die Cloud?

Für Kapitel 10 reichen mindestens die Abteilungen, die Basisordner und die Projekte der letzten zwei Jahre. Unordnung wie Gehaltslisten am falschen Ort nimmst du bewusst mit, Kapitel 10 findet sie.

## 9.2 Zielstruktur planen und anlegen ★★

**Aufgabe:** Lege fest, welche Freigabe wohin kommt, und lege die Websites an. Ein Vorschlag als Ausgangspunkt:

| Quelle | Ziel |
| --- | --- |
| `Abteilungen\Allgemein` | Kommunikationswebsite *Intranet* |
| `Abteilungen\Geschaeftsleitung`, `\Buchhaltung`, `\Personal`, `\Vertrieb`, `\IT` | je eine Teamwebsite (mit Microsoft-365-Gruppe) |
| `Abteilungen\Marketing\Berlin`, `\Hamburg` | Teamwebsite *Marketing*, je ein Ordner oder eine Bibliothek |
| `Projekte` | Teamwebsite *Projekte* |
| `Home$\<benutzer>` | OneDrive des Benutzers |

Websites legst du im *SharePoint Admin Center → Websites → Aktive Websites → Erstellen* an. Mitglieder und Besitzer leiten sich aus den globalen Gruppen ab (`Get-ADGroupMember GG-Buchhaltung`). Mit PnP PowerShell geht es auch per Skript: `New-PnPSite -Type TeamSite -Title 'Buchhaltung' -Alias 'buchhaltung'`.

**Prüfen:** Alle Websites sind angelegt, in jeder Teamwebsite stehen die richtigen Mitglieder. Warum ist eine Website pro Abteilung meist besser als eine große Website mit Ordnern und unterbrochener Vererbung?

## 9.3 Rechte und Benutzerzuordnung ★★

**Aufgabe:** Entscheide, wie die Rechte nach SharePoint kommen. Zwei Wege:

1. **Rechte übernehmen:** SPMT überträgt NTFS-Rechte (Lesen → Lesen, Schreiben → Mitwirken, Vollzugriff → Vollzugriff), wenn es zu jedem lokalen Konto ein Cloud-Konto kennt. Ohne Abgleich brauchst du eine [Benutzerzuordnungsdatei](https://learn.microsoft.com/sharepointmigration/create-a-user-mapping-file-for-data-content-migration): CSV ohne Kopfzeile, Quelle, Ziel, Gruppe ja/nein.

   ```text
   <K>\kanders,kanders@<mandant>.onmicrosoft.com,FALSE
   <K>\emustermann,emustermann@<mandant>.onmicrosoft.com,FALSE
   ```

   In den [SPMT-Einstellungen](https://learn.microsoft.com/sharepointmigration/spmt-settings) dann *Preserve file share permissions* ein- und *Automatic user mapping* ausschalten und die Datei angeben.
2. **Rechte neu vergeben:** Rechte nicht übernehmen, der Zugriff ergibt sich nur aus Besitzern und Mitgliedern der Websites aus 9.2.

**Prüfen:** Deine Entscheidung mit Begründung. Lies dazu [Berechtigungen bei der Migration](https://learn.microsoft.com/sharepointmigration/understanding-permissions-when-migrating): Was passiert mit „Verweigern“-Einträgen, mit Freigabeberechtigungen und mit den domänenlokalen Gruppen `DL-FS-*`? Warum sind übernommene Ordnerrechte in SharePoint später schwer zu pflegen?

## 9.4 Pilotmigration mit SPMT ★★

**Aufgabe:** Migriere zuerst nur `Abteilungen\Marketing\Berlin` in die Website *Marketing*.

1. SPMT auf `<K>-FS01` installieren und mit dem SharePoint-Administrator des Mandanten anmelden.
2. In den *Settings* einstellen: *Migrate file version history*, *Replace invalid filename characters*, Rechte wie in 9.3 entschieden. SPMT braucht für seinen Arbeitsordner (Standard `%appdata%\Microsoft\MigrationTool`) viel freien Platz; reicht `C:` nicht, den Arbeitsordner auf `F:` legen.
3. Neue Migration vom Typ Dateifreigabe, Quelle `F:\Shares\Abteilungen\Marketing\Berlin`, Ziel `https://<mandant>.sharepoint.com/sites/Marketing`, Bibliothek *Dokumente*, Unterordner `Berlin`.
4. Zuerst mit *Only perform scanning* laufen lassen, Bericht lesen, dann richtig migrieren.

**Prüfen:**

- Unter *View reports* zeigt `SummaryReport.csv` so viele migrierte Dateien wie `(Get-ChildItem F:\Shares\Abteilungen\Marketing\Berlin -Recurse -File).Count`, `ItemFailureReport.csv` ist leer oder jeder Fehler ist erklärt (siehe [SPMT-Berichte](https://learn.microsoft.com/sharepointmigration/using-the-sharepoint-migration-tool-reports)).
- In der Bibliothek tragen Stichproben dasselbe *Geändert am* wie auf dem Fileserver. Wer steht unter *Geändert von*, und warum?

## 9.5 Hauptmigration und Basisordner nach OneDrive ★★★

**Aufgabe:** Migriere die übrigen Bereiche aus 9.2 in einem Lauf und die Basisordner in die OneDrives.

Für mehrere Quellen nimmt SPMT eine [CSV-Datei](https://learn.microsoft.com/sharepointmigration/how-to-format-your-csv-file-for-data-content-migration) mit sechs Spalten: Quelle, zwei leere Spalten, Ziel-Website, Bibliothek (`Documents` für *Dokumente*), Unterordner.

```text
F:\Shares\Abteilungen\Buchhaltung,,,https://<mandant>.sharepoint.com/sites/Buchhaltung,Documents,
F:\Shares\Abteilungen\Personal,,,https://<mandant>.sharepoint.com/sites/Personal,Documents,
F:\Shares\Home\EMustermann,,,https://<mandant>-my.sharepoint.com/personal/emustermann_<mandant>_onmicrosoft_com,Documents,
```

OneDrives entstehen erst bei der ersten Anmeldung. Für die Migration legst du sie vorher an (SharePoint Online Management Shell):

```powershell
Connect-SPOService -Url https://<mandant>-admin.sharepoint.com
Request-SPOPersonalSite -UserEmails 'emustermann@<mandant>.onmicrosoft.com', 'kanders@<mandant>.onmicrosoft.com'
```

Das Anlegen läuft im Hintergrund und kann dauern. Das Konto, das den Befehl ausführt, braucht selbst eine SharePoint-Lizenz.

**Prüfen:** Alle Aufgaben in SPMT stehen auf *Abgeschlossen*, die Fehlerberichte sind leer oder erklärt, Erika findet ihre Dateien in ihrem OneDrive. Was hast du mit `Home\JFrick\Privat` gemacht, und warum? Was mit den Basisordnern ehemaliger Mitarbeitender?

## 9.6 Umstellung ★★

**Aufgabe:** Ab heute arbeiten alle in SharePoint. Dazu:

1. Die Freigaben auf dem Fileserver auf „Lesen“ stellen, je Freigabe:

   ```powershell
   Revoke-SmbShareAccess -Name Abteilungen -AccountName 'Authenticated Users' -Force
   Grant-SmbShareAccess -Name Abteilungen -AccountName 'Authenticated Users' -AccessRight Read -Force
   ```

2. Die Migration in SPMT noch einmal starten (Delta-Lauf): Es werden nur neue und geänderte Dateien übertragen. Was in der Quelle gelöscht wurde, bleibt im Ziel.
3. Die Laufwerkszuordnungen aus 8.4 entfernen und den Benutzern sagen, wo ihre Daten jetzt liegen (Infomail mit Links zu den Websites).

**Prüfen:** Als `<K>\kanders` lässt sich auf `\\<K>-FS01\Abteilungen` nichts mehr speichern. Eine Datei, die du kurz vor dem Delta-Lauf als Administrator geändert hast, ist in SharePoint mit dem neuen Stand angekommen. Warum stellt man die Quelle vor dem letzten Lauf auf „Lesen“, statt sie gleich abzuschalten?
