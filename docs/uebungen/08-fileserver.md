# 8 Fileserver

Der Fileserver `<K>-FS01` gehört der fiktiven Mustermann Medien GmbH, einer Werbeagentur mit Zentrale in Berlin und Niederlassung in Hamburg. Auf `F:\Shares` liegen rund 60 GB Dokumente aus zwölf Jahren: Kundenprojekte, Buchhaltung, Personal, Richtlinien, Vorlagen. Die Berechtigungen folgen AGDLP, ein paar Stellen sind aber absichtlich verbaut, wie auf echten Servern nach Jahren im Betrieb.

**Zugang:** RDP vom Client aus auf `<K>-FS01` als `<K>\azadmin` (Remote Desktop Manager, Arbeitsbereich „Lab-Server“). Auf dem Desktop liegt `Lab-Info.txt` mit Freigaben und Gruppen. Werkzeuge auf dem Fileserver: *Server-Manager*, *Ressourcen-Manager für Dateiserver* (`fsrm.msc`), PowerShell mit den Modulen `SmbShare`, `FileServerResourceManager` und `ActiveDirectory`. Benutzer und Gruppen verwaltest du wie gewohnt auf dem Exchange-Server.

| Freigabe | Inhalt | Wer ändern darf |
| --- | --- | --- |
| `\\<K>-FS01\Abteilungen` | Allgemein, Geschäftsleitung, Buchhaltung, Personal, Marketing (Berlin/Hamburg), Vertrieb, IT | je Ordner `DL-FS-<Bereich>-M` |
| `\\<K>-FS01\Projekte` | Kundenprojekte `<Jahr>_<Kunde>_<Projekt>` | Marketing, Vertrieb, Geschäftsleitung |
| `\\<K>-FS01\Archiv` | abgeschlossene Jahre | Geschäftsleitung, alle lesen |
| `\\<K>-FS01\Scans` | Scan-Eingang | alle (siehe 8.3) |
| `\\<K>-FS01\Home$` | Basisordner, auf dem Client `H:` | jeder seinen eigenen |

## 8.1 Freigaben, NTFS und ABE erkunden ★

**Ziel:** Verstehen, wie Freigabe- und NTFS-Rechte zusammenspielen und was die zugriffsbasierte Aufzählung (ABE) macht.

```powershell
Get-SmbShare | Format-Table Name, Path, FolderEnumerationMode
Get-SmbShareAccess -Name Abteilungen
icacls F:\Shares\Abteilungen\Buchhaltung
Get-ADGroupMember DL-FS-Buchhaltung-M
```

Melde dich am Client nacheinander als `<K>\kanders` und als `<K>\emustermann` an und öffne jeweils `\\<K>-FS01\Abteilungen`.

**Prüfen:** Die Freigaben erlauben *Authentifizierten Benutzern* „Ändern“, gesteuert wird über NTFS. Karl Anders sieht weder `Buchhaltung` noch `Personal`, Erika Mustermann sieht beide. Warum zeigt der Explorer Karl die Ordner gar nicht an, statt „Zugriff verweigert“ zu melden? Welche Rechte gelten am Ende, wenn Freigabe und NTFS unterschiedlich viel erlauben?

## 8.2 AGDLP: neue Kollegin in der Buchhaltung ★

**Aufgabe:** Lea Mayer übernimmt zusätzlich die Buchhaltung. Sie soll dort ändern dürfen, ohne dass du am Fileserver eine einzige Berechtigung anfasst.

```powershell
Add-ADGroupMember -Identity GG-Buchhaltung -Members lmayer
Get-ADGroupMember DL-FS-Buchhaltung-M
Get-ADPrincipalGroupMembership lmayer | Select-Object Name
```

Lea muss sich danach am Client ab- und wieder anmelden.

**Prüfen:** Als `<K>\lmayer` lässt sich in `\\<K>-FS01\Abteilungen\Buchhaltung` eine Datei anlegen. `DL-FS-Buchhaltung-M` enthält weiterhin nur die Gruppe `GG-Buchhaltung`, nicht Lea selbst. Warum reicht ein neues Anmelden, ein `gpupdate` dagegen nicht? Wofür sind globale und domänenlokale Gruppen jeweils zuständig?

## 8.3 Altlasten finden und beheben ★★

**Aufgabe:** Auf dem Server sind fünf Berechtigungen falsch gesetzt, dazu liegen Basisordner von Leuten, die nicht mehr da sind. Finde alles und behebe es so, dass AGDLP wieder stimmt. Vor einer Migration (Kapitel 9) muss das ohnehin erledigt sein.

Alle Ordner mit expliziten Einträgen, die keine `DL-FS-`-Gruppe und kein Systemkonto sind:

```powershell
$denied = $null
Get-ChildItem F:\Shares -Directory -Recurse -ErrorAction SilentlyContinue -ErrorVariable +denied | ForEach-Object {
    $folder = $_.FullName
    (Get-Acl -LiteralPath $folder).Access | Where-Object { -not $_.IsInherited } | ForEach-Object {
        [pscustomobject]@{ Ordner = $folder.Substring(10); Wer = $_.IdentityReference; Rechte = $_.FileSystemRights }
    }
} | Where-Object { $_.Wer -notmatch 'DL-FS-|Domain Users|Domänen-Benutzer|BUILTIN|VORDEFINIERT|NT AUTHORITY|NT-AUTORIT|CREATOR|ERSTELLER' -and $_.Ordner -notmatch '^Home\\[^\\]+$' } |
    Format-Table -AutoSize
$denied | ForEach-Object { $_.TargetObject }      # Ordner, die du nicht einmal lesen darfst
Get-SmbShareAccess -Name Scans
```

Basisordner ohne AD-Konto:

```powershell
Get-ChildItem F:\Shares\Home -Directory | Where-Object { -not (Get-ADUser -Filter "SamAccountName -eq '$($_.Name)'") }
```

Hinweise zum Beheben, je Fund:

- **Ein Benutzer direkt im ACL:** `icacls <Ordner> /remove:g <K>\<benutzer>`. Wie bekommt er die Rechte richtig, falls er sie wirklich braucht?
- **Unterbrochene Vererbung mit „Everyone“:** `icacls <Ordner> /reset /T /C /Q` setzt den Ordner und alles darunter wieder auf geerbte Rechte. Warum ist gerade dieser Ordner heikel?
- **Unbekannte SID `S-1-5-21-…`:** Gehört einem gelöschten Konto. Im AD-Papierkorb nachsehen, wem (`Get-ADObject -Filter 'isDeleted -eq $true' -IncludeDeletedObjects -Properties objectSid`). Danach entscheiden: wiederherstellen (Übung 6.2) oder die SID mit `icacls <Ordner> /remove:g *<SID>` entfernen.
- **Ordner ohne Rechte für Administratoren:** Zuerst die Besitzrechte übernehmen (`takeown /F <Ordner>`), dann `icacls <Ordner> /grant *S-1-5-32-544:(OI)(CI)F` (Administratoren), dann den Besitzer zurückgeben (`icacls <Ordner> /setowner <K>\<benutzer>`). Bevor du hineinschaust: Darfst du das? Was sagt die IT-Richtlinie unter `Abteilungen\Allgemein\Richtlinien`?
- **„Everyone“ mit Vollzugriff auf Freigabe und NTFS:** `Revoke-SmbShareAccess -Name <Freigabe> -AccountName Everyone -Force` und `icacls <Ordner> /remove:g *S-1-1-0`.
- **Basisordner ohne Konto:** Nicht einfach löschen. Wer übernimmt die Daten, wie lange müssen sie aufbewahrt werden?

**Prüfen:** Die Suche oben liefert keine Zeilen mehr, `$denied` ist leer und `Get-SmbShareAccess -Name Scans` zeigt nur noch *Administratoren* und *Authentifizierte Benutzer*. Warum sieht Karl Anders `Buchhaltung` nicht, obwohl er vorher in einem Unterordner davon ändern durfte?

## 8.4 Laufwerke per Gruppenrichtlinie ★★

Voraussetzung: Client (`deployClient = true`).

**Aufgabe:** Alle Lab-Benutzer bekommen `S:` für die Abteilungen, nur das Marketing zusätzlich `P:` für die Projekte. In der *Gruppenrichtlinienverwaltung* auf dem Exchange-Server:

1. Neues GPO `LAB - Laufwerke`, verknüpft mit `OU=LEARN-<k>`.
2. *Benutzerkonfiguration → Einstellungen → Windows-Einstellungen → Laufwerkzuordnungen → Neu*: Aktion *Aktualisieren*, Ort `\\<K>-FS01\Abteilungen`, Laufwerk `S:`, Bezeichnung „Abteilungen“.
3. Zweite Zuordnung `P:` auf `\\<K>-FS01\Projekte`. Unter *Gemeinsam → Zielgruppenadressierung* eine Sicherheitsgruppe `GG-Marketing-Berlin` und mit *ODER* `GG-Marketing-Hamburg` eintragen.

**Prüfen:** Am Client als `<K>\kanders` zeigt `net use` die Laufwerke `H:`, `S:` und `P:`, als `<K>\mmustermann` nur `H:` und `S:`. `gpresult /r /scope user` listet `LAB - Laufwerke`. Warum ist Zielgruppenadressierung hier besser als ein eigenes GPO pro Gruppe?

## 8.5 Speicherberichte mit FSRM ★★

**Aufgabe:** Finde heraus, was auf dem Server Platz frisst: große Dateien, doppelte Dateien, lange nicht genutzte Dateien, Verteilung nach Dateityp und Besitzer.

```powershell
New-FsrmStorageReport -Name 'Bestandsaufnahme' -Namespace 'F:\Shares' -Interactive `
    -ReportType LargeFiles, DuplicateFiles, LeastRecentlyAccessed, FilesByFileGroup, FilesByOwner
Get-FsrmStorageReport -Name 'Bestandsaufnahme'
```

FSRM legt für die Berichte kurz eine Schattenkopie an. Scheitert der Bericht mit `0x8004532c`, ist der Schattenkopie-Speicher zu klein (siehe 8.7).

**Prüfen:** Unter `C:\StorageReports\Interactive` liegen die Berichte als HTML. Welche Dateitypen belegen den meisten Platz und warum (Tipp: Druckdaten, ZIP-Pakete für die Druckerei)? Wie viel Platz belegen doppelte Dateien? Woran erkennst du im Bericht, dass Kopien in Basisordnern liegen?

## 8.6 Kontingente und Dateiprüfung ★★

**Aufgabe:** Basisordner sollen höchstens 2 GB groß werden, und in `Home` dürfen keine Audio- und Videodateien landen.

```powershell
New-FsrmQuota -Path 'F:\Shares\Home\KAnders' -Size 2GB
Get-FsrmFileGroup | Select-Object Name
New-FsrmFileScreen -Path 'F:\Shares\Home' -IncludeGroup 'Audio and Video Files' -Active
```

Den Gruppennamen aus `Get-FsrmFileGroup` übernehmen, falls er auf deinem Server anders lautet.

Teste am Client als `<K>\kanders`: Kopiere große Druck-PDFs aus `\\<K>-FS01\Projekte` nach `H:` und lege eine Datei `H:\test.mp3` an.

**Prüfen:** Ab 2 GB bricht das Kopieren mit „Nicht genügend Speicherplatz“ ab, `test.mp3` lässt sich nicht speichern. `Get-FsrmQuota -Path F:\Shares\Home\KAnders` zeigt die Belegung. Wie würdest du das Kontingent für alle Basisordner auf einmal setzen, auch für künftige (Stichwort *Automatisches Kontingent*)?

## 8.7 Schattenkopien und Vorgängerversionen ★★

Voraussetzung: Client (`deployClient = true`).

**Aufgabe:** Benutzer sollen versehentlich gelöschte Dateien selbst wiederherstellen.

```powershell
vssadmin add shadowstorage /for=F: /on=F: /maxsize=20GB
vssadmin create shadow /for=F:
vssadmin list shadows /for=F:
```

Den Zeitplan (z. B. werktags 7 und 12 Uhr) richtest du im Explorer ein: Laufwerk `F:` → *Eigenschaften → Schattenkopien → Einstellungen → Zeitplan*.

Am Client als `<K>\kanders`: eine Datei in `H:` löschen, dann Rechtsklick auf den Ordner → *Eigenschaften → Vorherige Versionen*.

**Prüfen:** Die gelöschte Datei ist wieder da. Warum ersetzen Schattenkopien kein Backup?

## 8.8 Deduplizierung messen ★★★

**Aufgabe:** Wie viel Platz spart die Datendeduplizierung bei diesen Daten?

```powershell
Install-WindowsFeature FS-Data-Deduplication
Enable-DedupVolume -Volume F: -UsageType Default
Set-DedupVolume -Volume F: -MinimumFileAgeDays 0
Start-DedupJob -Volume F: -Type Optimization
Get-DedupJob                                            # Fortschritt
```

Bei 60 GB dauert der Lauf je nach VM-Größe einige Stunden. Am besten abends starten. Die VM darf dabei nicht abschalten, sonst läuft der Job beim nächsten Start weiter.

**Prüfen:** `Get-DedupStatus F: | Format-List SavedSpace, OptimizedFilesCount` und `Get-DedupVolume F: | Format-List SavingsRate`. Woher kommt die Ersparnis (Kopien, Versionen, Sicherungsordner)? Warum sparen die ZIP-Pakete trotz gleichem Inhalt wenig? Warum stellt man `MinimumFileAgeDays` im Betrieb nicht auf 0?

## 8.9 Archivierung mit robocopy ★★

**Aufgabe:** Die Projekte des ältesten Jahres in `Projekte` sollen ins Archiv, ohne dass Datum und Uhrzeit der Dateien verloren gehen.

```powershell
Get-ChildItem F:\Shares\Projekte -Directory | Group-Object { $_.Name.Substring(0, 4) } | Select-Object Name, Count
$jahr = '<ältestes Jahr>'
$ziel = "F:\Shares\Archiv\$jahr\Projekte"
New-Item -Path C:\Temp -ItemType Directory -Force | Out-Null
Get-ChildItem F:\Shares\Projekte -Directory -Filter "${jahr}_*" | ForEach-Object {
    robocopy $_.FullName (Join-Path $ziel $_.Name) /E /MOVE /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NP /L /LOG+:C:\Temp\archiv-$jahr.log
}
```

`/L` listet nur auf, ohne etwas zu verschieben. Prüfe das Log, dann denselben Befehl ohne `/L` ausführen.

**Prüfen:** In `Projekte` gibt es keine Ordner des Jahres mehr. Im Archiv haben die Dateien ihr altes Änderungsdatum (`Get-ChildItem $ziel -Recurse -File | Select-Object -First 5 FullName, LastWriteTime`). `icacls` auf eine verschobene Datei zeigt nur noch geerbte Rechte des Archivs. Was wäre mit `/COPYALL` statt `/COPY:DAT` anders gewesen, und was ist für ein Archiv richtig?

## 8.10 Entra-Branding mit den Dateien der IT ★

Voraussetzung für den zweiten Teil: Microsoft-365-Übungsmandant.

**Aufgabe:** Die IT hat in `\\<K>-FS01\Abteilungen\IT\Branding` Logos und Hintergrund für die Anmeldeseite vorbereitet, dazu `Anleitung_Entra-Branding.docx`. Prüfe zuerst, ob die Dateien die Vorgaben von Microsoft einhalten:

```powershell
Add-Type -AssemblyName System.Drawing
Get-ChildItem F:\Shares\Abteilungen\IT\Branding -File -Include *.png, *.jpg -Recurse | ForEach-Object {
    $image = [System.Drawing.Image]::FromFile($_.FullName)
    [pscustomobject]@{ Datei = $_.Name; Breite = $image.Width; Hoehe = $image.Height; KB = [math]::Round($_.Length / 1KB, 1) }
    $image.Dispose()
} | Format-Table -AutoSize
```

Vergleiche mit [Unternehmensbranding hinzufügen](https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding): Favicon 32 × 32 px bis 5 KB, Hintergrund 1920 × 1080 px bis 300 KB, Kopfzeilen- und Bannerlogo 245 × 36 px bis 10 bzw. 50 KB, quadratische Logos 240 × 240 px bis 50 KB. Danach im Übungsmandanten im *Microsoft Entra Admin Center → Entra ID → Unternehmensbranding* das Standardbranding bearbeiten und Hintergrund, Favicon, Banner- und Kopfzeilenlogo hochladen. Dafür brauchst du mindestens die Rolle *Organisationsbranding-Administrator* und eine passende Lizenz (z. B. Entra ID P1 oder Microsoft 365 Business Standard).

**Prüfen:** Alle Dateien halten Maße und Größen ein. Die Anmeldeseite des Mandanten zeigt nach dem Eingeben der Benutzer-E-Mail das Agentur-Logo. Warum liegt im Ordner auch `Archiv_alte_CI`, und warum sollte man daraus nichts hochladen?
