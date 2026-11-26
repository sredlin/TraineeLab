# Pruefungen auf dem Exchange-Server (laeuft nach Common.ps1, siehe dort).

$updateRunning = [bool](Get-ScheduledTask -TaskName 'ExchangeLab-InitialUpdates' -ErrorAction SilentlyContinue)

Invoke-Check 'ex.installed' {
    if (Test-Path -Path (Join-Path $LabRoot 'exchange-install.done')) { 'OK', 'exchange-install.done' } else { 'FAIL', 'exchange-install.done fehlt' }
}

Invoke-Check 'ex.services' {
    $names = 'MSExchangeADTopology', 'MSExchangeIS', 'MSExchangeTransport', 'MSExchangeFrontEndTransport', 'MSExchangeServiceHost', 'MSExchangeRPC', 'W3SVC'
    $down = @($names | Where-Object { (Get-Service -Name $_ -ErrorAction SilentlyContinue).Status -ne 'Running' })
    if (-not $down) { return 'OK', "$($names.Count) Dienste laufen" }
    # Waehrend des Update-Laufs (Exchange-SU) sind Dienste zeitweise gestoppt.
    if ($updateRunning) { return 'PENDING', "Update-Lauf, Dienste gestoppt: $($down -join ', ')" }
    'FAIL', "Dienste nicht gestartet: $($down -join ', ')"
}

$snapin = $false
try {
    Add-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn
    $snapin = $true
}
catch {
    $state = if ($updateRunning) { 'PENDING' } else { 'FAIL' }
    Write-Check -Id 'ex.powershell' -State $state -Detail "Exchange-Snap-in nicht ladbar: $($_.Exception.Message)"
}

if ($snapin) {
    Invoke-Check 'ex.mailboxes' {
        $users = @(Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Where-Object { "$($_.OrganizationalUnit)" -like "*LEARN-$($Lab.Trainee)*" })
        $shared = @(Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited)
        $rooms = @(Get-Mailbox -RecipientTypeDetails RoomMailbox -ResultSize Unlimited)
        $groups = @(Get-DistributionGroup -ResultSize Unlimited)
        $contacts = @(Get-MailContact -ResultSize Unlimited)
        $detail = '{0} Benutzer, {1} freigegeben, {2} Raeume, {3} Verteiler, {4} Kontakte' -f $users.Count, $shared.Count, $rooms.Count, $groups.Count, $contacts.Count
        if ($users.Count -lt 28 -or -not $shared -or -not $rooms -or -not $groups -or -not $contacts) { return 'FAIL', $detail }
        'OK', $detail
    }

    Invoke-Check 'ex.language' {
        $expected = @{ de = 'de-DE'; en = 'en-GB' }[$Lab.Language]
        # Nur die Lab-Postfaecher in der Firmen-OU, nicht das Admin-Konto.
        $boxes = @(Get-Mailbox -RecipientTypeDetails UserMailbox, SharedMailbox, RoomMailbox -ResultSize Unlimited | Where-Object { "$($_.OrganizationalUnit)" -like "*LEARN-$($Lab.Trainee)*" })
        $wrong = @($boxes | Where-Object { "$((Get-MailboxRegionalConfiguration -Identity $_.Identity).Language)" -ne $expected })
        if ($wrong) { return 'FAIL', ('{0} von {1} Postfaechern nicht {2}, z. B. {3}' -f $wrong.Count, $boxes.Count, $expected, $wrong[0].Alias) }
        'OK', "$($boxes.Count) Postfaecher $expected"
    }

    Invoke-Check 'ex.certificate' {
        # Massgeblich ist die tatsaechliche Bindung auf 443 (Default Web Site), nicht die Services-Liste.
        $binding = (& netsh.exe http show sslcert ipport=0.0.0.0:443) -join ' '
        $bound = [regex]::Match($binding, '\b[0-9a-fA-F]{40}\b').Value
        if (-not $bound) { return 'FAIL', 'kein Zertifikat auf 0.0.0.0:443 gebunden' }
        $certificate = Get-ExchangeCertificate -Server $env:COMPUTERNAME -Thumbprint $bound
        $detail = '{0}, {1}, gueltig bis {2:yyyy-MM-dd}' -f $certificate.Subject, $certificate.Issuer, $certificate.NotAfter
        if (-not $Lab.LetsEncrypt) { return 'OK', $detail }
        $domains = @($certificate.CertificateDomains | ForEach-Object { "$_" })
        if ($certificate.IsSelfSigned -or ($domains -notcontains "*.$($Lab.Public)" -and $domains -notcontains "mail.$($Lab.Public)")) {
            return 'FAIL', "auf 443 kein Let's-Encrypt-Zertifikat: $detail"
        }
        if ("$($certificate.Services)" -notmatch 'SMTP') { return 'FAIL', "Zertifikat nicht fuer SMTP aktiviert: $detail" }
        'OK', $detail
    }

    Invoke-Check 'ex.urls' {
        $owa = Get-OwaVirtualDirectory -Server $env:COMPUTERNAME
        $expected = "https://mail.$($Lab.Public)/owa"
        if ("$($owa.ExternalUrl)" -ne $expected) { return 'FAIL', "OWA ExternalUrl $($owa.ExternalUrl)" }
        'OK', $expected
    }
}

Invoke-Check 'ex.owa' {
    # Ueber Split DNS auf die interne IP. Ein Staging-Zertifikat ist nicht vertrauenswuerdig, daher curl -k
    # (ein PowerShell-Callback fuer die Zertifikatspruefung ist im Run Command nicht verlaesslich).
    $url = "https://mail.$($Lab.Public)/owa/healthcheck.htm"
    $code = "$(& curl.exe -k -s -o NUL -w '%{http_code}' --max-time 60 $url)"
    if ($code -eq '200') { return 'OK', "healthcheck.htm 200" }
    if ($updateRunning) { return 'PENDING', "Update-Lauf: HTTP $code" }
    'FAIL', "$url liefert HTTP $code"
}

Invoke-Check 'ex.maintenance' {
    if (Get-ScheduledTask -TaskName 'ExchangeLab-Maintenance' -ErrorAction SilentlyContinue) { 'OK', 'Wartungs-Task registriert' } else { 'FAIL', 'Wartungs-Task fehlt' }
}

Invoke-CommonCheck -UpdateRun -LabInfo
