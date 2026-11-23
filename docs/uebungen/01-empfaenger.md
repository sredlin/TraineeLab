# 1 Empfänger und Berechtigungen

## 1.1 Lab erkunden ★

**Ziel:** Überblick, welche Empfänger es gibt.

**Aufgabe:** Liste alle Empfänger nach Typ gruppiert auf. Öffne danach ECP → *Empfänger* und finde dieselben Objekte.

```powershell
Get-Recipient -ResultSize Unlimited | Group-Object RecipientTypeDetails | Sort-Object Name | Format-Table Count, Name
```

**Prüfen:** Mindestens 12 × `UserMailbox`, 2 × `SharedMailbox`, 2 × `RoomMailbox`, 4 × `MailUniversalDistributionGroup`, 2 × `MailContact`.

## 1.2 Neuer Mitarbeiter ★

**Ziel:** AD-Konto und Postfach in einem Schritt anlegen.

**Aufgabe:** Lege „Nina Neu“ in Hamburg an (`OU=Users,OU=Hamburg,OU=Branch,OU=LEARN-<k>`), Anmeldename `nneu@<k>.<zone>`. Setze Ort und Abteilung (Marketing) in AD.

```powershell
New-Mailbox -Name 'Nina Neu' -FirstName Nina -LastName Neu -SamAccountName NNeu `
  -UserPrincipalName nneu@<k>.<zone> -OrganizationalUnit 'OU=Users,OU=Hamburg,OU=Branch,OU=LEARN-<k>,DC=<k>,DC=intern' `
  -Password (Read-Host -AsSecureString 'Kennwort')
Set-User nneu -City Hamburg -Department Marketing
```

**Prüfen:** `Get-Mailbox nneu | Format-List PrimarySmtpAddress, Database, OrganizationalUnit` zeigt `nneu@<k>.<zone>` und `DB01`. Melde dich in OWA als Nina an.

## 1.3 Zusätzliche Adresse ★

**Ziel:** Proxy-Adressen und Adressrichtlinie verstehen.

**Aufgabe:** John Doe soll zusätzlich `john.doe@<k>.<zone>` empfangen.

```powershell
Set-Mailbox jdoe -EmailAddresses @{ Add = 'john.doe@<k>.<zone>' }
```

**Prüfen:** `(Get-Mailbox jdoe).EmailAddresses` enthält `smtp:john.doe@<k>.<zone>` (Präfix klein = sekundär) und `SMTP:JDoe@<k>.<zone>` (Präfix groß = primär). Warum gibt es zusätzlich eine Adresse `@<k>.intern`? Tipp: `Get-EmailAddressPolicy | Format-List Name, EnabledEmailAddressTemplates`.

## 1.4 Verteiler pflegen ★

**Aufgabe:** Nimm Nina in `marketing-hamburg` auf. Erlaube danach, dass auch externe Absender an den Verteiler `alle` schreiben dürfen, und überlege, warum das standardmäßig verboten ist.

```powershell
Add-DistributionGroupMember marketing-hamburg -Member nneu
Set-DistributionGroup alle -RequireSenderAuthenticationEnabled $false
```

**Prüfen:** `Get-DistributionGroupMember marketing-hamburg` listet Nina. `(Get-DistributionGroup alle).RequireSenderAuthenticationEnabled` ist `False`. Setze den Wert danach wieder auf `$true`.

## 1.5 Dynamischer Verteiler ★★

**Ziel:** Mitgliedschaft per Filter statt per Liste.

**Aufgabe:** Ein Verteiler „Alle Hamburg“ soll automatisch alle Postfächer mit Ort Hamburg enthalten.

```powershell
New-DynamicDistributionGroup -Name 'Alle Hamburg' -Alias alle-hamburg `
  -OrganizationalUnit 'OU=DistributionLists,OU=Administration,OU=LEARN-<k>,DC=<k>,DC=intern' `
  -RecipientFilter "(RecipientType -eq 'UserMailbox') -and (City -eq 'Hamburg')"
```

**Prüfen:**

```powershell
Get-Recipient -RecipientPreviewFilter (Get-DynamicDistributionGroup alle-hamburg).RecipientFilter | Select-Object Name, City
```

zeigt die sechs Hamburger und Nina (aus 1.2).

## 1.6 Postfachberechtigungen ★★

**Ziel:** Unterschied zwischen Vollzugriff, Senden als und Senden im Auftrag.

**Aufgabe:**

1. Erika Mustermann bekommt Vollzugriff auf `buchhaltung`, aber **ohne** Automapping.
2. Celina Herz darf im Auftrag von `info` senden.

```powershell
Add-MailboxPermission buchhaltung -User EMustermann -AccessRights FullAccess -AutoMapping $false
Set-Mailbox info -GrantSendOnBehalfTo CHerz
```

**Prüfen:**

```powershell
Get-MailboxPermission buchhaltung | Where-Object { -not $_.IsInherited } | Format-Table User, AccessRights
Get-ADPermission (Get-Mailbox info).DistinguishedName | Where-Object ExtendedRights -like '*Send-As*' | Format-Table User
(Get-Mailbox info).GrantSendOnBehalfTo
```

Beantworte: Was sieht der Empfänger bei *Senden als* und was bei *Senden im Auftrag*?

## 1.7 Räume und Ausstattung ★★

**Aufgabe:** `raum-kiel` soll Buchungen höchstens 90 Tage im Voraus und höchstens 4 Stunden lang annehmen, Überschneidungen ablehnen. Lege zusätzlich ein Ausstattungspostfach „Beamer Kiel“ an.

```powershell
Set-CalendarProcessing raum-kiel -AutomateProcessing AutoAccept -BookingWindowInDays 90 -MaximumDurationInMinutes 240 -AllowConflicts $false
New-Mailbox -Equipment -Name 'Beamer Kiel' -Alias beamer-kiel -OrganizationalUnit 'OU=Resources,OU=Administration,OU=LEARN-<k>,DC=<k>,DC=intern'
```

**Prüfen:** `Get-CalendarProcessing raum-kiel | Format-List AutomateProcessing, BookingWindowInDays, MaximumDurationInMinutes, AllowConflicts`. Teste die Buchung in Übung 2.5 ([Kapitel 2](02-client-outlook.md)).

## 1.8 Postfach trennen und wieder verbinden ★★

**Ziel:** Unterschied zwischen `Disable-Mailbox` (AD-Konto bleibt) und `Remove-Mailbox` (AD-Konto wird gelöscht).

**Aufgabe:** Trenne das Postfach von Lea Mayer und verbinde es wieder.

```powershell
Disable-Mailbox lmayer -Confirm:$false
# getrennte Postfächer anzeigen (ggf. erst Store-Status aktualisieren)
Get-MailboxStatistics -Database DB01 | Where-Object DisconnectReason | Format-Table DisplayName, DisconnectReason, MailboxGuid
Update-StoreMailboxState -Database DB01 -Identity <MailboxGuid>   # falls Lea noch nicht erscheint
Connect-Mailbox -Identity 'Lea Mayer' -Database DB01 -User LMayer
```

**Prüfen:** `Get-Mailbox lmayer` liefert wieder ein Postfach, die alten Mails sind in OWA sichtbar.

## 1.9 Kontingente ★

**Aufgabe:** Karl Anders bekommt ein eigenes Kontingent: Warnung bei 900 MB, Senden gesperrt ab 1 GB, Senden und Empfangen gesperrt ab 1,2 GB.

```powershell
Set-Mailbox kanders -UseDatabaseQuotaDefaults $false -IssueWarningQuota 900MB -ProhibitSendQuota 1GB -ProhibitSendReceiveQuota 1.2GB
```

**Prüfen:** `Get-Mailbox kanders | Format-List *Quota*` und `Get-MailboxStatistics kanders | Format-List TotalItemSize, StorageLimitStatus`.
