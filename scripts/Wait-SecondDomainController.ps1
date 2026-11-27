<#
.SYNOPSIS
    Wartet auf dem ersten DC, bis der zweite DC vollstaendig bereit ist (Schranke im Deployment).

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) auf DC01, nachdem DC02 heraufgestuft wurde. Erst danach wird
    DC02 als DNS-Server ins VNet eingetragen und die Exchange-Installation beginnt. Geprueft wird:
      - DC02 ist Domain Controller und hat seine Einrichtung abgeschlossen (dc-ready.txt, SYSVOL bereit)
      - Freigaben NETLOGON und SYSVOL auf DC02
      - DC02 kennt das Admin-Konto (Erstreplikation)
      - DNS auf DC02 loest den DC-SRV-Record und den Split-DNS-Record mail.<oeffentliche Domain> auf
      - Replikation in beide Richtungen ohne Fehler

    Nach TimeoutMinutes endet der Run Command mit Fehler und gibt die letzten Logzeilen von DC02 aus.
    Das Skript enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'AdminPasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Passwort kommt als protectedParameter und wird nur lokal verwendet.')]
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $DomainName,

    [Parameter(Mandatory)]
    [string] $NetbiosName,

    [Parameter(Mandatory)]
    [string] $AdminUser,

    [Parameter(Mandatory)]
    [string] $SecondDcComputerName,

    [Parameter(Mandatory)]
    [string] $SecondDcIp,

    [Parameter(Mandatory)]
    [string] $PublicDomainName,

    [Parameter(Mandatory)]
    [string] $ExchangeIp,

    [Parameter(Mandatory)]
    [string] $AdminPasswordB64,

    [int] $TimeoutMinutes = 75
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LogDir = 'C:\ExchangeLab\Logs'
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir 'Wait-SecondDomainController.log'
$FirstDc = "$env:COMPUTERNAME.$DomainName"
$SecondDc = "$SecondDcComputerName.$DomainName"

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function Get-ReplicationProblem {
    # Liefert $null, wenn der Ziel-DC vom Partner eingehend fehlerfrei repliziert hat, sonst den Grund.
    param([Parameter(Mandatory)][string] $Target, [Parameter(Mandatory)][string] $PartnerName, [Parameter(Mandatory)][pscredential] $Credential)
    $partners = @(Get-ADReplicationPartnerMetadata -Target $Target -Scope Server -Credential $Credential |
        Where-Object { $_.Partner -like "*,CN=$PartnerName,*" })
    if (-not $partners) { return "$Target hat noch keine eingehende Verbindung von $PartnerName" }
    foreach ($partner in $partners) {
        if ($partner.LastReplicationResult -ne 0) {
            return "$Target repliziert von $PartnerName mit Fehler $($partner.LastReplicationResult) ($($partner.Partition))"
        }
        if (-not $partner.LastReplicationSuccess) {
            return "$Target hat von $PartnerName noch nicht erfolgreich repliziert ($($partner.Partition))"
        }
    }
    $null
}

function Get-SecondDcProblem {
    param([Parameter(Mandatory)][pscredential] $Credential)

    $state = Invoke-Command -ComputerName $SecondDc -Credential $Credential -ScriptBlock {
        $netlogon = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -ErrorAction SilentlyContinue
        [pscustomobject]@{
            DomainRole  = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
            Ready       = Test-Path -Path 'C:\ExchangeLab\dc-ready.txt'
            SysvolReady = [int]$netlogon.SysvolReady
            Shares      = @(Get-SmbShare -Name NETLOGON, SYSVOL -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        }
    }
    if ($state.DomainRole -lt 4) { return "$SecondDc ist noch kein Domain Controller (DomainRole $($state.DomainRole))" }
    if (-not $state.Ready) { return "$SecondDc hat seine Einrichtung noch nicht abgeschlossen (dc-ready.txt fehlt)" }
    if ($state.SysvolReady -ne 1) { return "SYSVOL auf $SecondDc ist noch nicht bereit" }
    if (@($state.Shares).Count -lt 2) { return "Freigaben NETLOGON/SYSVOL auf $SecondDc fehlen (vorhanden: $(@($state.Shares) -join ', '))" }

    Get-ADUser -Identity $AdminUser -Server $SecondDc -Credential $Credential | Out-Null

    $srv = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -Server $SecondDcIp -DnsOnly -ErrorAction SilentlyContinue
    if (-not ($srv | Where-Object Type -EQ 'SRV')) { return "DNS auf $SecondDcIp loest den SRV-Record von $DomainName noch nicht auf" }
    $mail = Resolve-DnsName -Name "mail.$PublicDomainName" -Type A -Server $SecondDcIp -DnsOnly -ErrorAction SilentlyContinue
    if (($mail | Where-Object Type -EQ 'A').IPAddress -notcontains $ExchangeIp) { return "DNS auf $SecondDcIp kennt mail.$PublicDomainName noch nicht" }

    foreach ($pair in @(@($FirstDc, $SecondDcComputerName), @($SecondDc, $env:COMPUTERNAME))) {
        $problem = Get-ReplicationProblem -Target $pair[0] -PartnerName $pair[1] -Credential $Credential
        if ($problem) {
            # Die KCC legt neue Verbindungen sonst erst nach bis zu 15 Minuten an.
            & repadmin.exe /kcc $pair[0] | Out-Null
            return $problem
        }
    }
    $null
}

function Write-SecondDcLogTail {
    param([Parameter(Mandatory)][pscredential] $Credential)
    try {
        $tail = Invoke-Command -ComputerName $SecondDc -Credential $Credential -ScriptBlock {
            Get-ChildItem -Path 'C:\ExchangeLab\Logs' -Filter 'Install-DomainController-*.log' -ErrorAction SilentlyContinue |
                ForEach-Object { "--- $($_.Name)"; Get-Content -Path $_.FullName -Tail 15 }
        }
        foreach ($line in $tail) { Write-LabLog "  $line" }
    }
    catch {
        Write-LabLog "Logs von $SecondDc nicht lesbar: $($_.Exception.Message)"
    }
}

try {
    $password = ConvertTo-SecureString -String ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($AdminPasswordB64))) -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$NetbiosName\$AdminUser", $password
    Import-Module -Name ActiveDirectory

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ($true) {
        try {
            $reason = Get-SecondDcProblem -Credential $credential
        }
        catch {
            $reason = $_.Exception.Message
        }
        if (-not $reason) { break }
        if ((Get-Date) -gt $deadline) {
            Write-LabLog "FEHLER: $SecondDc nach $TimeoutMinutes Minuten nicht bereit: $reason"
            Write-SecondDcLogTail -Credential $credential
            exit 1
        }
        Write-LabLog "Warte: $reason"
        Start-Sleep -Seconds 30
    }

    Write-LabLog "$SecondDc ist bereit: DC, SYSVOL, DNS und Replikation in beide Richtungen ok."
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    exit 1
}
