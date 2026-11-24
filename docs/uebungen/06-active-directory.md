# 6 Active Directory und DNS

Werkzeuge auf dem Exchange-Server: *Active Directory-Benutzer und -Computer*, *Active Directory-Verwaltungscenter*, *DNS*, *Gruppenrichtlinienverwaltung*. Für den DC selbst: RDP vom Exchange-Server auf `<K>-DC01`.

## 6.1 Split DNS ★

**Ziel:** Verstehen, warum intern und extern dieselben Namen auf unterschiedliche IPs zeigen.

```powershell
Resolve-DnsName mail.<k>.<zone>                  # intern über den DC
Resolve-DnsName mail.<k>.<zone> -Server 1.1.1.1  # öffentlich
Resolve-DnsName 10.0.1.5                         # Reverse-Lookup
```

**Prüfen:** Intern `10.0.1.5`, öffentlich die Public IP des Exchange-Servers, der Reverse-Lookup liefert den FQDN des Exchange-Servers in `<k>.intern`. Finde in der DNS-Konsole die Zonen `<k>.intern`, `<k>.<zone>` und `1.0.10.in-addr.arpa`. Was würde passieren, wenn die interne Zone `<k>.<zone>` fehlt?

## 6.2 AD-Papierkorb ★

**Aufgabe:** Lege einen Testbenutzer an, lösche ihn und stelle ihn wieder her.

```powershell
New-ADUser -Name 'Test Papierkorb' -Path 'OU=Users,OU=Berlin,OU=Branch,OU=LEARN-<k>,DC=<k>,DC=intern'
Remove-ADUser 'CN=Test Papierkorb,OU=Users,OU=Berlin,OU=Branch,OU=LEARN-<k>,DC=<k>,DC=intern' -Confirm:$false
Get-ADObject -Filter 'isDeleted -eq $true -and Name -like "Test Papierkorb*"' -IncludeDeletedObjects | Restore-ADObject
```

**Prüfen:** Der Benutzer ist wieder in seiner OU, mit derselben SID wie vorher (`Get-ADUser 'Test Papierkorb' | Select-Object SID`). Zeige die gelöschten Objekte auch grafisch im Verwaltungscenter (Container „Deleted Objects“).

## 6.3 Gruppenrichtlinie für den Client ★★

**Aufgabe:** Beim Anmelden am Client soll ein Hinweistext erscheinen.

```powershell
New-GPO -Name 'LAB - Anmeldehinweis' |
  New-GPLink -Target 'OU=Computers,OU=Berlin,OU=Branch,OU=LEARN-<k>,DC=<k>,DC=intern'
$key = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System'
Set-GPRegistryValue -Name 'LAB - Anmeldehinweis' -Key $key -ValueName LegalNoticeCaption -Type String -Value 'Ausbildungs-Lab'
Set-GPRegistryValue -Name 'LAB - Anmeldehinweis' -Key $key -ValueName LegalNoticeText -Type String -Value 'Nur fuer Schulungszwecke.'
```

Auf dem Client: `gpupdate /force`, dann abmelden und neu anmelden.

**Prüfen:** Vor der Anmeldung erscheint der Hinweis. `gpresult /r /scope computer` listet die GPO. Warum wirkt sie nur, weil der Client in `OU=Computers,OU=Berlin` liegt?

## 6.4 Delegation ★★

**Aufgabe:** Celina Herz soll Kennwörter der Hamburger Benutzer zurücksetzen dürfen, sonst nichts. Nutze in *Active Directory-Benutzer und -Computer* auf `OU=Users,OU=Hamburg,OU=Branch` den Assistenten *Objektverwaltung zuweisen*.

**Prüfen:** Starte auf dem Exchange-Server eine PowerShell als Celina (`runas /user:<K>\cherz powershell`). Dort klappt `Set-ADAccountPassword -Identity rjung -Reset -NewPassword (Read-Host -AsSecureString)`, für `mmustermann` (Berlin) gibt es „Zugriff verweigert“.

## 6.5 Replikation mit zwei DCs ★★

Voraussetzung: `deploySecondDc = true`.

**Aufgabe:** Lege auf `<K>-DC02` einen Benutzer an und prüfe, ob er auf `<K>-DC01` ankommt.

```powershell
New-ADUser -Name 'Test Replikation' -Server <K>-DC02 -Path 'OU=Users,OU=Berlin,OU=Branch,OU=LEARN-<k>,DC=<k>,DC=intern'
Get-ADUser -Filter 'Name -eq "Test Replikation"' -Server <K>-DC01
repadmin /replsummary
repadmin /showrepl <K>-DC01
```

**Prüfen:** Der Benutzer ist nach wenigen Sekunden auf beiden DCs sichtbar, `repadmin /replsummary` meldet 0 Fehler.

## 6.6 FSMO-Rollen ★★★

Voraussetzung: `deploySecondDc = true`.

**Aufgabe:** Finde die Rolleninhaber, verschiebe PDC-Emulator, RID- und Infrastrukturmaster auf `<K>-DC02` und danach zurück.

```powershell
netdom query fsmo
Move-ADDirectoryServerOperationMasterRole -Identity <K>-DC02 -OperationMasterRole PDCEmulator, RIDMaster, InfrastructureMaster
netdom query fsmo
Move-ADDirectoryServerOperationMasterRole -Identity <K>-DC01 -OperationMasterRole PDCEmulator, RIDMaster, InfrastructureMaster
```

**Prüfen:** Am Ende liegen alle Rollen wieder auf `<K>-DC01`. Warum sollte der PDC-Emulator auf dem DC liegen, der immer läuft? Was ist der Unterschied zwischen Übertragen und Übernehmen (`-Force`)?

## 6.7 DC-Ausfall ★★★

Voraussetzung: `deploySecondDc = true`. Nicht kurz vor der automatischen Abschaltzeit durchführen.

**Aufgabe:** Fahre `<K>-DC01` **im Gast** herunter (`Stop-Computer` auf dem DC, nicht im Portal). Prüfe, ob Exchange weiterarbeitet.

```powershell
Get-ExchangeServer <K>-EX01 -Status | Format-List CurrentDomainControllers, CurrentGlobalCatalogs
```

Melde dich in OWA an, schicke eine Mail. Starte `<K>-DC01` danach im Portal wieder.

**Prüfen:** Exchange nutzt nach kurzer Zeit `<K>-DC02`, OWA funktioniert. Warum ist ein Herunterfahren im Gast unproblematisch, ein Deallokieren im Portal dagegen nicht? (Stichwort VM-Generation-ID, siehe [readme](../../readme.md#kosten-und-abschalten).)
