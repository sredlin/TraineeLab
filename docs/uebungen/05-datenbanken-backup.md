# 5 Datenbanken und Backup

## 5.1 Datenbank ansehen ★

```powershell
Get-MailboxDatabase -Status | Format-List Name, EdbFilePath, LogFolderPath, DatabaseSize, AvailableNewMailboxSpace, CircularLoggingEnabled, LastFullBackup
```

**Prüfen:** `DB01` liegt auf `F:` (ReFS-Datendisk), Umlaufprotokollierung ist aus, `LastFullBackup` ist leer. Warum liegen Datenbank und Logs bei Exchange in Azure auf Premium Storage?

## 5.2 Zweite Datenbank und Postfachverschiebung ★★

**Aufgabe:** Lege `DB02` an und verschiebe Karl Anders dorthin.

```powershell
New-MailboxDatabase -Name DB02 -Server <K>-EX01 -EdbFilePath F:\ExchangeDatabases\DB02\DB02.edb -LogFolderPath F:\ExchangeDatabases\DB02\Logs
Restart-Service MSExchangeIS     # nach dem Anlegen einer Datenbank nötig
Mount-Database DB02
New-MoveRequest -Identity kanders -TargetDatabase DB02
Get-MoveRequest | Get-MoveRequestStatistics | Format-Table DisplayName, StatusDetail, PercentComplete
```

**Prüfen:** `Get-Mailbox kanders | Format-List Database` zeigt `DB02`, Karl kann in OWA weiterarbeiten. Räume danach mit `Get-MoveRequest | Remove-MoveRequest` auf.

## 5.3 Transaktionslogs wachsen ★

**Aufgabe:** Miss, wie viel Platz die Logs von `DB01` belegen, und schicke dann ein paar Mails mit großen Anhängen.

```powershell
Get-ChildItem F:\ExchangeDatabases\DB01\Logs -Filter *.log | Measure-Object Length -Sum
```

**Prüfen:** Die Summe wächst und schrumpft nie von selbst. Erkläre, wann Exchange Logs löscht (Stichwort: Vollsicherung) und was passiert, wenn `F:` vollläuft.

## 5.4 Sicherung mit Windows Server Backup ★★★

**Ziel:** Eine Exchange-fähige Vollsicherung, die die Logs abschneidet.

**Aufgabe:**

1. Hänge im Portal eine neue Datendisk an `vm-<k>-ex01` (Standard SSD, 128 GB) und initialisiere sie als `G:` (Datenträgerverwaltung).
2. Installiere Windows Server Backup und sichere `F:` per VSS-Vollsicherung.

```powershell
Install-WindowsFeature Windows-Server-Backup
wbadmin start backup -backupTarget:G: -include:F: -vssFull -quiet
```

**Prüfen:** `Get-MailboxDatabase -Status | Format-List Name, LastFullBackup` zeigt die Uhrzeit der Sicherung. Die Zahl der Logdateien aus 5.3 ist deutlich kleiner.

**Kosten:** Die Disk nach Kapitel 5 wieder löschen.

## 5.5 Einzelnes Postfach aus der Sicherung wiederherstellen ★★★

**Ziel:** Gelöschte Mails über eine Recovery-Datenbank zurückholen.

**Aufgabe:**

1. Lösche als Max in OWA einige Mails endgültig (auch aus „Wiederherstellbare Elemente“).
2. Stelle die gesicherten Datenbankdateien in einen Ordner auf `G:` wieder her:

   ```powershell
   wbadmin get versions
   wbadmin start recovery -version:<Version> -itemType:File -items:F:\ExchangeDatabases\DB01 -recoveryTarget:G:\Restore -recursive -quiet
   ```

3. Bringe die Datenbank in einen konsistenten Zustand. `eseutil /mh` zeigt den Zustand. Bei „Dirty Shutdown“ die Logs einspielen (Logpräfix `E00`):

   ```powershell
   cd G:\Restore\DB01
   eseutil /mh .\DB01.edb | Select-String State
   eseutil /r E00 /l .\Logs /s .\Logs /d .
   ```

4. Recovery-Datenbank anlegen, einhängen und Max' Inhalte in einen eigenen Ordner zurückspielen:

   ```powershell
   New-MailboxDatabase -Recovery -Name RDB01 -Server <K>-EX01 -EdbFilePath G:\Restore\DB01\DB01.edb -LogFolderPath G:\Restore\DB01\Logs
   Restart-Service MSExchangeIS
   Mount-Database RDB01
   New-MailboxRestoreRequest -SourceDatabase RDB01 -SourceStoreMailbox 'Max Mustermann' -TargetMailbox mmustermann -TargetRootFolder 'Wiederhergestellt' -AllowLegacyDNMismatch
   ```

**Prüfen:** `Get-MailboxRestoreRequest | Get-MailboxRestoreRequestStatistics` steht auf `Completed`, in Max' Postfach gibt es den Ordner „Wiederhergestellt“. Danach aufräumen: Restore-Request entfernen, `Dismount-Database RDB01`, `Remove-MailboxDatabase RDB01`, Dateien löschen. Anleitung: [Recovery-Datenbanken](https://learn.microsoft.com/exchange/high-availability/disaster-recovery/recovery-databases).

## 5.6 Umlaufprotokollierung ★★

**Aufgabe:** Schalte für `DB02` die Umlaufprotokollierung ein.

```powershell
Set-MailboxDatabase DB02 -CircularLoggingEnabled $true
Dismount-Database DB02 -Confirm:$false; Mount-Database DB02
```

**Prüfen:** `Get-MailboxDatabase DB02 | Format-List CircularLoggingEnabled`. Erkläre den Nachteil: Welche Wiederherstellung ist danach nicht mehr möglich?
