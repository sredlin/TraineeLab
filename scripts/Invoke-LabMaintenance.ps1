<#
.SYNOPSIS
    Taegliche Wartung des Exchange-Servers im Lab: Log-Bereinigung und Zertifikatserneuerung.

.DESCRIPTION
    Wird nach der Exchange-Installation als Scheduled Task (SYSTEM) registriert. Laeuft taeglich um 12:00;
    ist die VM dann aus (Auto-Shutdown), holt StartWhenAvailable den Lauf nach dem naechsten Start nach.

      - Log-Bereinigung: loescht *.log, *.blg und *.etl aelter als RetentionDays in den IIS-Logs,
        im Exchange-Ordner Logging und in den Diagnose-Traces der Suche. Message-Tracking-Logs liegen
        unter TransportRoles und bleiben unberuehrt (eigene Aufbewahrung, Uebungsthema).
      - Zertifikat: erneuert das Let's-Encrypt-Zertifikat per Posh-ACME, sobald es faellig ist, kopiert
        die Dateien nach C:\Certificates und bindet es an IIS und SMTP. Die Exchange-Cmdlets kommen aus
        dem lokalen Snap-in, weil SYSTEM keine Remote-PowerShell-Sitzung mit RBAC-Rechten bekommt.

    Das Skript enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Fest vorgegebenes PFX-Passwort von Posh-ACME, die Datei liegt nur fuer Administratoren lesbar in C:\Certificates.')]
[CmdletBinding()]
param(
    [int] $RetentionDays = 14
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$CertDir = 'C:\Certificates'
$PoshAcmeHome = 'C:\ProgramData\Posh-ACME'
$PfxPassword = 'poshacme'

New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir 'Invoke-LabMaintenance.log'

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function Clear-OldLogFile {
    $paths = @('C:\inetpub\logs\LogFiles')
    $exchangePath = [Environment]::GetEnvironmentVariable('ExchangeInstallPath', 'Machine')
    if ($exchangePath) {
        $paths += Join-Path $exchangePath 'Logging'
        $paths += Join-Path $exchangePath 'Bin\Search\Ceres\Diagnostics\ETLTraces'
        $paths += Join-Path $exchangePath 'Bin\Search\Ceres\Diagnostics\Logs'
    }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    foreach ($path in $paths | Where-Object { Test-Path -Path $_ }) {
        $files = @(Get-ChildItem -Path $path -Recurse -File -Include '*.log', '*.blg', '*.etl' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff })
        $bytes = ($files | Measure-Object -Property Length -Sum).Sum
        # Dateien, die gerade geschrieben werden, bleiben einfach stehen.
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-LabLog ('{0}: {1} Dateien aelter als {2} Tage geloescht ({3:N0} MB).' -f $path, $files.Count, $RetentionDays, ($bytes / 1MB))
    }
}

function Invoke-CertificateRenewal {
    if (-not (Test-Path -Path $PoshAcmeHome) -or -not (Get-Module -ListAvailable -Name Posh-ACME)) {
        Write-LabLog "Kein Posh-ACME eingerichtet, Let's Encrypt wird nicht genutzt."
        return
    }

    $env:POSHACME_HOME = $PoshAcmeHome
    Import-Module -Name Posh-ACME
    $order = Get-PAOrder
    if (-not $order) {
        Write-LabLog 'Kein ACME-Auftrag vorhanden, nichts zu erneuern.'
        return
    }

    # Ohne Faelligkeit liefert Submit-Renewal nichts zurueck und warnt nur.
    $certificate = Submit-Renewal -WarningAction SilentlyContinue
    if (-not $certificate) {
        Write-LabLog "Zertifikat $($order.MainDomain) noch nicht faellig (Erneuerung ab $($order.RenewAfter))."
        return
    }

    foreach ($file in @($certificate.CertFile, $certificate.KeyFile, $certificate.ChainFile, $certificate.FullChainFile, $certificate.PfxFile, $certificate.PfxFullChain)) {
        if ($file -and (Test-Path -Path $file)) {
            Copy-Item -Path $file -Destination $CertDir -Force
        }
    }
    Write-LabLog "Zertifikat $($order.MainDomain) erneuert (gueltig bis $($certificate.NotAfter)), Dateien nach $CertDir kopiert."

    Add-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn
    $pfxFile = Join-Path $CertDir 'fullchain.pfx'
    $x509 = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $pfxFile, $PfxPassword
    if (-not (Get-ExchangeCertificate | Where-Object { $_.Thumbprint -eq $x509.Thumbprint })) {
        Import-ExchangeCertificate -FileData ([IO.File]::ReadAllBytes($pfxFile)) -Password (ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force) -PrivateKeyExportable $true | Out-Null
    }
    Enable-ExchangeCertificate -Thumbprint $x509.Thumbprint -Services 'IIS,SMTP' -Force -Confirm:$false
    Write-LabLog "Neues Zertifikat $($x509.Thumbprint) fuer IIS und SMTP aktiviert."
}

$failed = $false
foreach ($step in 'Clear-OldLogFile', 'Invoke-CertificateRenewal') {
    try {
        & $step
    }
    catch {
        $failed = $true
        Write-LabLog "FEHLER in ${step}: $($_.Exception.Message)"
    }
}

if ($failed) {
    exit 1
}
Write-LabLog 'Wartung ohne Fehler beendet.'
exit 0
