# 3 Mailfluss

## 3.1 Nachrichtenverfolgung ★★

**Ziel:** Den Weg einer Mail durch Exchange nachvollziehen.

**Aufgabe:** Schicke in OWA als Max eine Mail an den Verteiler `marketing-kiel`. Verfolge sie in der EMS.

```powershell
Get-MessageTrackingLog -Sender mmustermann@<k>.<zone> -Start (Get-Date).AddMinutes(-15) |
  Sort-Object Timestamp | Format-Table Timestamp, EventId, Source, Recipients, MessageSubject -AutoSize
```

**Prüfen:** Du siehst `RECEIVE`, `EXPAND` (Verteiler wird aufgelöst), `DELIVER` an fünf Empfänger. Was bedeuten `SUBMIT` und `HAREDIRECT`? Wiederhole die Verfolgung im ECP unter *Nachrichtenfluss → Zustellberichte*.

## 3.2 Mails aus dem Internet empfangen ★★

**Ziel:** MX, NSG und Empfangsconnector zusammenbringen.

**Aufgabe:**

1. Prüfe den öffentlichen MX: `Resolve-DnsName <k>.<zone> -Type MX -Server 1.1.1.1`.
2. Öffne die NSG-Regel `Allow-Exchange-SMTP` für die Quelle `Internet` (Portal oder `az network nsg rule update … --source-address-prefixes Internet`).
3. Schicke von einem privaten Postfach eine Mail an `mmustermann@<k>.<zone>`.
4. Stelle die Regel danach wieder auf deine eigene IP. Ein offener Port 25 zieht Spam an.

**Prüfen:** `Get-MessageTrackingLog -EventId RECEIVE -Start (Get-Date).AddMinutes(-30) | Where-Object Source -eq SMTP | Format-List Timestamp, ClientIp, ConnectorId, Sender, Recipients` zeigt die Mail. Welche IP steht in `ClientIp`, welcher Empfangsconnector in `ConnectorId`? Vergleiche mit `Get-ReceiveConnector | Format-Table Identity, Bindings, TransportRole`. Schicke dieselbe Mail an `alle@<k>.<zone>`: Warum kommt eine Unzustellbarkeitsnachricht zurück? (Übung 1.4)

## 3.3 Transportregel: Signatur für externe Mails ★★

**Aufgabe:** Alle Mails an externe Empfänger bekommen einen Hinweistext angehängt.

```powershell
New-TransportRule -Name 'Hinweis extern' -FromScope InOrganization -SentToScope NotInOrganization `
  -ApplyHtmlDisclaimerLocation Append -ApplyHtmlDisclaimerFallbackAction Wrap `
  -ApplyHtmlDisclaimerText '<p style="font-size:9pt">Lab-Umgebung der Ausbildung, bitte nicht antworten.</p>'
```

**Prüfen:** `Get-TransportRule 'Hinweis extern' | Format-List State, Priority, Description`. Ausgehende Mails bleiben im Lab hängen (Übung 3.5). Teste die Regel deshalb mit `-SentToScope InOrganization` an einen internen Empfänger und stelle sie danach zurück.

## 3.4 Relay für Geräte und Anwendungen ★★★

**Ziel:** Ein Scanner oder eine Anwendung soll ohne Anmeldung Mails auch an externe Adressen versenden dürfen, aber nur von einer bestimmten IP.

**Aufgabe:** Lege einen eigenen Empfangsconnector an, der nur den Client (`10.0.1.10`) anonym relayen lässt.

```powershell
New-ReceiveConnector -Name 'Relay Lab-Client' -TransportRole FrontendTransport -Custom `
  -Bindings 0.0.0.0:25 -RemoteIPRanges 10.0.1.10 -PermissionGroups AnonymousUsers
Get-ReceiveConnector 'Relay Lab-Client' |
  Add-ADPermission -User 'NT AUTHORITY\ANONYMOUS LOGON' -ExtendedRights 'Ms-Exch-SMTP-Accept-Any-Recipient'
```

Auf dem Client (PowerShell):

```powershell
Send-MailMessage -SmtpServer mail.<k>.<zone> -From scanner@<k>.<zone> -To jemand@example.com -Subject 'Relay-Test'
```

**Prüfen:** Der Client bekommt keinen Fehler „Unable to relay“. Die Mail liegt in der Warteschlange mit `DeliveryType` `Unreachable` (`Get-Queue`), weil es keinen Send Connector für externe Domains gibt. Derselbe Befehl vom Exchange-Server selbst (anderer IP) wird abgelehnt. Warum ist ein Relay-Connector mit `RemoteIPRanges 0.0.0.0-255.255.255.255` gefährlich?

## 3.5 Warteschlangen ★★

**Aufgabe:** Untersuche die Warteschlange aus Übung 3.4 und entferne die hängende Mail.

```powershell
Get-Queue | Format-Table Identity, DeliveryType, Status, MessageCount, NextHopDomain, LastError
Get-Message -Queue '<K>-EX01\<Nummer>' | Format-List Subject, FromAddress, Status, LastError
Remove-Message -Identity '<K>-EX01\<Nummer>\<Nachrichten-ID>' -WithNDR $false
```

**Prüfen:** Die `Unreachable`-Warteschlange ist leer. Erkläre die Fehlermeldung in `LastError`: Warum kennt Exchange keinen Weg zu `example.com`?

## 3.6 Send Connector über Smart Host ★★★

**Hintergrund:** Azure blockiert ausgehende Verbindungen auf Port 25 für die meisten Subscriptions. Mails an fremde Domains gehen deshalb nur über einen Smart Host mit Anmeldung (meist Port 587). Nur mit Zugangsdaten vom Ausbilder durchführen.

```powershell
New-SendConnector -Name 'Smart Host' -AddressSpaces '*' -Usage Internet `
  -SmartHosts smtp.example.com -Port 587 -RequireTLS $true `
  -SmartHostAuthMechanism BasicAuthRequireTLS -AuthenticationCredential (Get-Credential)
```

**Prüfen:** `Get-SendConnector | Format-List Name, SmartHosts, Port, RequireTLS`. Eine Mail an eine externe Adresse erscheint im Tracking mit `EventId SEND`. Ohne Smart Host: Erkläre, warum `Test-NetConnection gmail-smtp-in.l.google.com -Port 25` scheitert.

## 3.7 Anti-Spam-Agents ★★

**Aufgabe:** Installiere die Anti-Spam-Agents und sperre einen Absender.

```powershell
& $env:ExchangeScripts\Install-AntiSpamAgents.ps1
Restart-Service MSExchangeTransport
Set-SenderFilterConfig -BlockedSenders spam@example.com
```

**Prüfen:** `Get-TransportAgent` listet u. a. „Sender Filter Agent“ und „Content Filter Agent“ als aktiviert. `Get-SenderFilterConfig | Format-List Enabled, BlockedSenders`.

## 3.8 SPF und DMARC ★

**Aufgabe:** Lies die Mail-Hygiene-Einträge deiner Zone von außen.

```powershell
Resolve-DnsName <k>.<zone> -Type TXT -Server 1.1.1.1
Resolve-DnsName _dmarc.<k>.<zone> -Type TXT -Server 1.1.1.1
```

**Prüfen:** `v=spf1 mx -all` und `v=DMARC1; p=none`. Erkläre beide Einträge: Wer darf für die Domain senden, was bedeutet `-all`, was passiert bei `p=none` im Vergleich zu `p=reject`? Warum signiert Exchange on Premises nicht selbst mit DKIM?
