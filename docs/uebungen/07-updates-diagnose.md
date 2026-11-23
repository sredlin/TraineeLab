# 7 Updates und Diagnose

## 7.1 Build-Nummer bestimmen ★

```powershell
Get-Command Exsetup.exe | ForEach-Object { $_.FileVersionInfo } | Format-Table ProductVersion, FileName
Get-ExchangeServer | Format-List Name, Edition, AdminDisplayVersion
```

**Prüfen:** Ordne die `ProductVersion` in der Tabelle [Exchange Server build numbers](https://learn.microsoft.com/exchange/new-features/build-numbers-and-release-dates) einem Security Update (SU) zu. Warum zeigt `AdminDisplayVersion` das SU nicht an?

## 7.2 HealthChecker ★★

**Aufgabe:** Lass den HealthChecker laufen und erzeuge den HTML-Bericht.

```powershell
cd C:\ExchangeLab\Tools
.\HealthChecker.ps1
.\HealthChecker.ps1 -BuildHtmlServersReport
```

**Prüfen:** Im Ordner liegt eine HTML-Datei mit dem Bericht. Suche dir einen gelben oder roten Befund aus, recherchiere ihn über den Link im Bericht und behebe ihn oder begründe, warum er im Lab bleiben darf (z. B. RAM unter der Empfehlung).

## 7.3 Update-Lauf nachvollziehen ★

**Aufgabe:** Finde heraus, welche Updates nach dem Deployment installiert wurden.

```powershell
Get-Content C:\ExchangeLab\Logs\Update-LabServer.log
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10
```

**Prüfen:** Du findest das Exchange-SU im Log („Gefunden: Security Update for Exchange Server …“). Warum laufen danach keine automatischen Updates mehr auf den Servern, auf dem Client aber schon? (Patch-Modus der VMs im Portal unter *Updates*)

## 7.4 Security Update von Hand installieren ★★

**Aufgabe:** Wenn Microsoft ein neues SU veröffentlicht: Lies den zugehörigen Blogartikel im [Exchange Team Blog](https://techcommunity.microsoft.com/category/exchange/blog/exchange), lade das SU aus dem Microsoft Update Catalog und installiere es.

- Das SU **aus einer Eingabeaufforderung mit Administratorrechten** starten. Ein Doppelklick ohne Erhöhung führt zu halb installierten Updates und deaktivierten Diensten.
- Vorher HealthChecker und `Test-ServiceHealth` laufen lassen, danach erneut.

**Prüfen:** Die Build-Nummer aus 7.1 hat sich erhöht, `Test-ServiceHealth` ist ohne fehlende Dienste.

## 7.5 Wartungsmodus ★★

**Aufgabe:** Versetze den Server in den Wartungsmodus und hole ihn wieder heraus.

```powershell
Set-ServerComponentState <K>-EX01 -Component HubTransport -State Draining -Requester Maintenance
Set-ServerComponentState <K>-EX01 -Component ServerWideOffline -State Inactive -Requester Maintenance
Get-ServerComponentState <K>-EX01 | Format-Table Component, State
# ... Wartung ...
Set-ServerComponentState <K>-EX01 -Component ServerWideOffline -State Active -Requester Maintenance
Set-ServerComponentState <K>-EX01 -Component HubTransport -State Active -Requester Maintenance
```

**Prüfen:** Während der Wartung liefert OWA einen Fehler, danach sind wieder alle Komponenten `Active`. Warum ist der Wartungsmodus bei nur einem Exchange-Server trotzdem sinnvoll? Was würde er bei einer DAG zusätzlich bewirken?

## 7.6 Managed Availability und Dienste ★★

```powershell
Test-ServiceHealth
Get-HealthReport <K>-EX01 | Where-Object AlertValue -ne Healthy | Format-Table HealthSet, AlertValue
Test-MapiConnectivity -Server <K>-EX01
```

**Prüfen:** Alle Rollen melden `RequiredServicesRunning : True`, `Test-MapiConnectivity` meldet `Success`. Recherchiere einen Health Set, der nicht `Healthy` ist.

## 7.7 Logs und Speicherplatz ★

**Aufgabe:** Finde heraus, wie viel Platz IIS- und Exchange-Diagnoselogs auf `C:` belegen und wie der Wartungs-Task aufräumt.

```powershell
Get-ChildItem C:\inetpub\logs\LogFiles -Recurse -File | Measure-Object Length -Sum
Get-ChildItem "$env:ExchangeInstallPath\Logging" -Recurse -File | Measure-Object Length -Sum
Get-Content C:\ExchangeLab\Logs\Invoke-LabMaintenance.log -Tail 10
```

**Prüfen:** Du kannst erklären, welche Logs der Task nach 14 Tagen löscht und warum die Nachrichtenverfolgungs-Logs (`TransportRoles\Logs\MessageTracking`) bewusst nicht dazugehören.
