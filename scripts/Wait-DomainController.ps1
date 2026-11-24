<#
.SYNOPSIS
    Wartet auf der Exchange-VM, bis der Domain Controller vollstaendig bereit ist.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) vor dem Domaenenbeitritt.
    Erneuert die DHCP-Lease (neuer DNS-Server aus dem VNet) und prueft in einer Schleife:
      - DNS-Server der VM ist der DC
      - SRV-Record _ldap._tcp.dc._msdcs.<Domain> ist aufloesbar
      - Split-DNS-Record mail.<PublicDomainName> zeigt auf die Exchange-IP (PostReboot-Phase des DC fertig)
      - LDAP-Bind mit dem Domain-Admin funktioniert

    Das Skript enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'AdminPasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Run Command kann keine PSCredential uebergeben.')]
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $DomainName,

    [Parameter(Mandatory)]
    [string] $NetbiosName,

    [Parameter(Mandatory)]
    [string] $AdminUser,

    [Parameter(Mandatory)]
    [string] $AdminPasswordB64,

    [Parameter(Mandatory)]
    [string] $DcIp,

    [Parameter(Mandatory)]
    [string] $PublicDomainName,

    [Parameter(Mandatory)]
    [string] $ExchangeIp,

    [int] $TimeoutMinutes = 45
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LogDir = 'C:\ExchangeLab\Logs'
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir 'Wait-DomainController.log'

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function Test-DomainControllerReady {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'DirectoryEntry erwartet das Passwort als String.')]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Password)

    $dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses).ServerAddresses
    if ($dnsServers -notcontains $DcIp) {
        return "DNS-Server der VM ($($dnsServers -join ', ')) enthaelt den DC $DcIp noch nicht."
    }

    $srv = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -DnsOnly -ErrorAction SilentlyContinue
    if (-not ($srv | Where-Object Type -EQ 'SRV')) {
        return "SRV-Record fuer $DomainName noch nicht aufloesbar."
    }

    $mail = Resolve-DnsName -Name "mail.$PublicDomainName" -Type A -Server $DcIp -DnsOnly -ErrorAction SilentlyContinue
    if (($mail | Where-Object Type -EQ 'A').IPAddress -notcontains $ExchangeIp) {
        return "Split-DNS-Record mail.$PublicDomainName zeigt noch nicht auf $ExchangeIp."
    }

    # UPN statt NETBIOS\Benutzer: von einem Rechner ausserhalb der Domain scheitert der Bind
    # mit NetBIOS-Praefix gegen den Domain-FQDN (im Testdeployment nachgewiesen).
    $entry = New-Object -TypeName System.DirectoryServices.DirectoryEntry -ArgumentList "LDAP://$DomainName/RootDSE", "$AdminUser@$DomainName", $Password
    try {
        $entry.RefreshCache()
        $namingContext = $entry.Properties['defaultNamingContext'].Value
        if (-not $namingContext) {
            return 'LDAP-Bind liefert keinen Naming Context.'
        }
    }
    catch {
        return "LDAP-Bind als $AdminUser@$DomainName fehlgeschlagen: $($_.Exception.Message)"
    }
    finally {
        # psbase umgeht den DirectoryEntry-Adapter: Sonst sucht PowerShell "Dispose" als AD-Attribut,
        # bindet dafuer erneut und ueberdeckt bei einem Fehler die eigentliche Meldung.
        try { $entry.psbase.Dispose() } catch { Write-Verbose -Message "Dispose: $($_.Exception.Message)" }
    }

    return $null
}

try {
    $password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($AdminPasswordB64))

    Write-LabLog 'Erneuere DHCP-Lease (DNS-Server aus dem VNet).'
    & ipconfig.exe /renew | Out-Null

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ($true) {
        Clear-DnsClientCache
        try {
            $reason = Test-DomainControllerReady -Password $password
        }
        catch {
            $reason = $_.Exception.Message
        }

        if (-not $reason) {
            break
        }
        if ((Get-Date) -gt $deadline) {
            throw "Domain Controller nach $TimeoutMinutes Minuten nicht bereit: $reason"
        }
        Write-LabLog "Warte: $reason"
        Start-Sleep -Seconds 20
    }

    Write-LabLog "Domain Controller fuer $DomainName ist bereit."
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    exit 1
}
