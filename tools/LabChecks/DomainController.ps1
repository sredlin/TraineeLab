# Pruefungen auf einem Domain Controller (laeuft nach Common.ps1, siehe dort). $Lab.FirstDc unterscheidet DC01/DC02.

Invoke-Check 'dc.role' {
    $role = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
    if ($role -ge 4) { 'OK', "DomainRole $role" } else { 'FAIL', "kein Domain Controller (DomainRole $role)" }
}

Invoke-Check 'dc.services' {
    $down = @('NTDS', 'DNS', 'Netlogon', 'Kdc', 'DFSR' | Where-Object { (Get-Service -Name $_).Status -ne 'Running' })
    if ($down) { 'FAIL', "Dienste nicht gestartet: $($down -join ', ')" } else { 'OK', 'NTDS, DNS, Netlogon, Kdc, DFSR' }
}

Invoke-Check 'dc.ready' {
    $sysvol = [int](Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters').SysvolReady
    $shares = @(Get-SmbShare -Name NETLOGON, SYSVOL -ErrorAction SilentlyContinue).Count
    if (-not (Test-Path -Path (Join-Path $LabRoot 'dc-ready.txt'))) { return 'FAIL', 'dc-ready.txt fehlt (Phase PostReboot nicht fertig)' }
    if ($sysvol -ne 1 -or $shares -ne 2) { return 'FAIL', "SysvolReady $sysvol, Freigaben NETLOGON/SYSVOL: $shares" }
    'OK', 'dc-ready.txt, SYSVOL, NETLOGON'
}

Invoke-Check 'dc.dns' {
    $problems = @()
    if (@((Get-DnsServerForwarder).IPAddress | ForEach-Object { "$_" }) -notcontains '168.63.129.16') { $problems += 'Forwarder 168.63.129.16 fehlt' }
    $initialSync = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters').'Repl Perform Initial Synchronizations'
    if ($initialSync -ne 0) { $problems += "Repl Perform Initial Synchronizations = $initialSync" }
    $srv = @(Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$($Lab.Domain)" -Type SRV -Server 127.0.0.1 -DnsOnly | Where-Object Type -EQ 'SRV')
    if ($srv.Count -lt $Lab.DcCount) { $problems += "SRV-Records: $($srv.Count) von $($Lab.DcCount) DCs" }
    $mail = @(Resolve-DnsName -Name "mail.$($Lab.Public)" -Type A -Server 127.0.0.1 -DnsOnly | Where-Object Type -EQ 'A')
    if (@($mail | ForEach-Object { $_.IPAddress }) -notcontains $Lab.ExchangeIp) { $problems += "Split DNS mail.$($Lab.Public) zeigt nicht auf $($Lab.ExchangeIp)" }
    $octets = $Lab.ExchangeIp.Split('.')
    $ptr = @(Resolve-DnsName -Name ('{3}.{2}.{1}.{0}.in-addr.arpa' -f $octets) -Type PTR -Server 127.0.0.1 -DnsOnly -ErrorAction SilentlyContinue | Where-Object Type -EQ 'PTR')
    if (-not $ptr) { $problems += "PTR fuer $($Lab.ExchangeIp) fehlt" }
    if ($problems) { 'FAIL', ($problems -join '; ') } else { 'OK', "Forwarder, $($srv.Count) DC-SRV, Split DNS, PTR" }
}

Invoke-Check 'dc.sites' {
    $expected = @{ de = @('Berlin', 'Hamburg'); en = @('London', 'Manchester') }[$Lab.Language]
    $sites = @(Get-ADReplicationSite -Filter * | ForEach-Object { $_.Name })
    $missing = @($expected | Where-Object { $sites -notcontains $_ })
    $own = (Get-ADDomainController -Identity $env:COMPUTERNAME).Site
    if ($missing) { return 'FAIL', "AD-Standorte fehlen: $($missing -join ', ') (vorhanden: $($sites -join ', '))" }
    if ($own -ne $expected[0]) { return 'FAIL', "DC steht im Standort $own statt $($expected[0])" }
    'OK', ($sites -join ', ')
}

if ($Lab.DcCount -gt 1) {
    Invoke-Check 'dc.replication' {
        $partners = @(Get-ADReplicationPartnerMetadata -Target $env:COMPUTERNAME -Scope Server -Partition *)
        if (-not $partners) { return 'FAIL', 'keine Replikationspartner' }
        $failed = @($partners | Where-Object { $_.LastReplicationResult -ne 0 })
        if ($failed) { return 'FAIL', ('Fehler {0} von {1}' -f $failed[0].LastReplicationResult, $failed[0].Partner) }
        'OK', ('{0} Partner-Partitionen ohne Fehler' -f $partners.Count)
    }
}

if ($Lab.FirstDc) {
    Invoke-Check 'ad.users' {
        $ou = Get-ADOrganizationalUnit -Filter "Name -eq 'LEARN-$($Lab.Trainee)'"
        $users = @(Get-ADUser -SearchBase $ou.DistinguishedName -Filter "Enabled -eq 'True'" -Properties company, facsimileTelephoneNumber, l, co)
        $incomplete = @($users | Where-Object { -not $_.company -or -not $_.facsimileTelephoneNumber -or -not $_.l -or -not $_.co })
        if ($users.Count -lt 28) { return 'FAIL', "$($users.Count) Lab-Benutzer statt 28" }
        if ($incomplete) { return 'FAIL', "$($incomplete.Count) Benutzer ohne Firma/Fax/Ort/Land, z. B. $($incomplete[0].SamAccountName)" }
        'OK', "$($users.Count) Benutzer, Firma $($users[0].company)"
    }
}

Invoke-CommonCheck -UpdateRun
