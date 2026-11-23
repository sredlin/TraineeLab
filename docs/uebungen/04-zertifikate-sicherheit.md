# 4 Zertifikate und Sicherheit

## 4.1 Zertifikate ansehen ★

**Aufgabe:** Finde heraus, welches Zertifikat für IIS und SMTP aktiv ist, wer es ausgestellt hat und wie lange es gilt.

```powershell
Get-ExchangeCertificate | Format-List FriendlyName, Subject, CertificateDomains, Issuer, NotAfter, Services, Thumbprint
```

**Prüfen:** Ein Wildcard-Zertifikat `*.<k>.<zone>` von Let's Encrypt (bei Testdeployments „(STAGING)“) mit Diensten `IIS, SMTP`. Daneben gibt es das selbstsignierte Exchange-Zertifikat und das „Microsoft Exchange Server Auth Certificate“. Wofür ist Letzteres da? Öffne OWA im Browser und vergleiche die Zertifikatskette.

## 4.2 Automatische Erneuerung verstehen ★★

**Aufgabe:** Finde heraus, wann das Zertifikat erneuert wird und was der Wartungs-Task genau tut.

```powershell
Get-ScheduledTask ExchangeLab-Maintenance | Get-ScheduledTaskInfo
Get-Content C:\ExchangeLab\Logs\Invoke-LabMaintenance.log -Tail 20
$env:POSHACME_HOME = 'C:\ProgramData\Posh-ACME'; Import-Module Posh-ACME
Get-PAOrder | Format-List MainDomain, Status, CertExpires, RenewAfter
```

**Prüfen:** Du kannst erklären, warum die DNS-Challenge über die Managed Identity der VM funktioniert. Tipp: Rollenzuweisungen der DNS-Zone `<k>.<zone>` im Portal (*Zugriffssteuerung (IAM)*).

**Achtung:** Kein `Submit-Renewal -Force` ohne Absprache. Let's Encrypt erlaubt für die übergeordnete Zone nur 50 Zertifikate pro Woche, für alle Azubis zusammen.

## 4.3 Netzwerksicherheitsgruppe ★★

**Aufgabe:** Lies die NSG-Regeln und beantworte die Fragen.

```bash
az network nsg rule list -g rg-exlab-<k> --nsg-name nsg-exlab-<k> -o table
```

**Prüfen:**

- Warum hat der DC keine eingehende Regel und keine Public IP?
- Warum sind SMTP (25) und HTTPS (443) getrennte Regeln? Was wäre öffentlich erreichbar, wenn `Allow-Exchange-Web` auf `Internet` steht?
- Welche Standardregeln (Priorität 65000+) gelten zusätzlich?

## 4.4 Rollenbasierte Berechtigungen (RBAC) ★★

**Ziel:** Nicht jeder braucht Domain-Admin-Rechte.

**Aufgabe:** Celina Herz soll im ECP Empfänger verwalten dürfen, aber keine Server- oder Organisationseinstellungen ändern.

```powershell
Add-RoleGroupMember 'Recipient Management' -Member CHerz
```

**Prüfen:** `Get-RoleGroupMember 'Recipient Management'` listet Celina. Melde dich als Celina im ECP an: *Empfänger* ist da, *Server* nicht. Welche Rollen enthält die Gruppe? (`Get-RoleGroup 'Recipient Management' | Format-List Roles`)

## 4.5 Admin-Überwachungsprotokoll ★★

**Aufgabe:** Finde heraus, wer heute welche Exchange-Cmdlets ausgeführt hat.

```powershell
Search-AdminAuditLog -StartDate (Get-Date).Date | Sort-Object RunDate |
  Format-Table RunDate, Caller, CmdletName, ObjectModified -AutoSize
```

**Prüfen:** Du findest deine Änderungen aus Kapitel 1 und Celinas Änderungen aus 4.4.

## 4.6 Sicherheitsbefunde mit HealthChecker ★★

**Aufgabe:** Lass den HealthChecker laufen (siehe Kapitel 7.2) und lies den Abschnitt „Security Settings“.

**Prüfen:** Du kannst für Extended Protection, TLS-Einstellungen, AMSI und SMBv1 erklären, was der HealthChecker prüft und ob dein Server grün ist.
