<#
.SYNOPSIS
    Installiert und konfiguriert Exchange Server SE auf der Lab-VM.

.DESCRIPTION
    Phase 'Orchestrate' (Standard, Azure Managed Run Command als LocalSystem):
      - wartet, bis der Domaenenbeitritt inkl. Neustart abgeschlossen ist
      - legt Secrets DPAPI-geschuetzt ab und startet Phase 'Install' als Scheduled Task
        unter dem Domain-Admin mit hoechsten Rechten (volles Admin-Token fuer Exchange-Setup)
      - wartet auf das Ergebnis, raeumt Task und Secrets auf, startet den Server verzoegert neu

    Phase 'Install' (Scheduled Task als <NETBIOS>\<AdminUser>):
      - OU-Struktur und Lab-Benutzer aus LabUsers.psd1, UPN-Suffix der oeffentlichen Domain,
        Kennwortablauf fuer Lab-Konten aus, AD-Papierkorb an
      - Pruefung DC-Build (Windows Server 2025 braucht fuer PrepareSchema mind. 26100.7171)
      - Exchange-Setup: PrepareSchema, PrepareAD, Mailbox-Rolle (DB und Logs auf F:)
      - Nachkonfiguration: Accepted Domain, Adressrichtlinie, Postfaecher, Zertifikat (IIS/SMTP),
        interne/externe URLs, Autodiscover-SCP
      - registriert den einmaligen Update-Task auf Exchange-Server und DC(s)

    Das Skript ist idempotent und enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1).
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'AdminPasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'LabUserPasswordB64', Justification = 'Run Command uebergibt Parameter nur als String; Wert ist Base64 und kommt aus protectedParameters.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Passwoerter kommen als protectedParameters bzw. DPAPI-geschuetzt und werden nur lokal verwendet.')]
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
    [string] $PublicDomainName,

    [Parameter(Mandatory)]
    [string] $CompanyOu,

    [Parameter(Mandatory)]
    [string] $DcComputerName,

    [string] $OrganizationName = 'ExchOrg',

    # Optionaler zweiter DC, bekommt ebenfalls den einmaligen Update-Task.
    [string] $SecondDcComputerName = '',

    # Nur Phase 'Orchestrate':
    [string] $AdminPasswordB64,
    [string] $LabUserPasswordB64,
    [string] $LabUsersB64,
    [string] $UpdateScriptB64,

    [ValidateSet('Orchestrate', 'Install')]
    [string] $Phase = 'Orchestrate',

    [int] $TimeoutMinutes = 140
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LabRoot = 'C:\ExchangeLab'
$LogDir = Join-Path $LabRoot 'Logs'
$ScriptDir = Join-Path $LabRoot 'Scripts'
$SecretDir = Join-Path $LabRoot 'Secrets'
$SecretFile = Join-Path $SecretDir 'install.dat'
$ResultFile = Join-Path $LabRoot 'exchange-install.result'
$DoneMarker = Join-Path $LabRoot 'exchange-install.done'
$LabUsersFile = Join-Path $ScriptDir 'LabUsers.psd1'
$UpdateScriptFile = Join-Path $ScriptDir 'Update-LabServer.ps1'
$MediaDir = Join-Path $LabRoot 'Media\ExchangeSE'
$CertDir = 'C:\Certificates'
$InstallTaskName = 'ExchangeLab-InstallExchange'
$UpdateTaskName = 'ExchangeLab-InitialUpdates'
$PfxPassword = 'poshacme'
$SelfText = $MyInvocation.MyCommand.ScriptBlock.ToString()

New-Item -Path $LogDir, $ScriptDir -ItemType Directory -Force | Out-Null
$LogFile = Join-Path $LogDir "Install-ExchangeServer-$Phase.log"

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Phase, $Message
    Add-Content -Path $LogFile -Value $line
    Write-Information -MessageData $line -InformationAction Continue
}

function ConvertFrom-Base64String {
    param([Parameter(Mandatory)][string] $Value)
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)][scriptblock] $ScriptBlock,
        [Parameter(Mandatory)][string] $Activity,
        [int] $Attempts = 3,
        [int] $DelaySeconds = 30
    )
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            return & $ScriptBlock
        }
        catch {
            Write-LabLog "$Activity - Versuch $i/$Attempts fehlgeschlagen: $($_.Exception.Message)"
            if ($i -eq $Attempts) { throw }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Content)
    # Mit BOM, damit Windows PowerShell 5.1 Umlaute korrekt liest.
    [IO.File]::WriteAllText($Path, $Content, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true))
}

function Protect-Directory {
    param([Parameter(Mandatory)][string] $Path)
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    & icacls.exe $Path /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' | Out-Null
}

function Register-LabUpdateTask {
    # Wird lokal und per Invoke-Command auf dem DC ausgefuehrt, daher ohne Abhaengigkeiten.
    param(
        [Parameter(Mandatory)][string] $ScriptContent,
        [Parameter(Mandatory)][string] $TaskName,
        [bool] $StartNow = $false
    )
    $scriptFolder = 'C:\ExchangeLab\Scripts'
    New-Item -Path $scriptFolder -ItemType Directory -Force | Out-Null
    $scriptPath = Join-Path $scriptFolder 'Update-LabServer.ps1'
    Set-Content -Path $scriptPath -Value $ScriptContent -Encoding ASCII

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -TaskName $TaskName"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = 'PT5M'
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4) -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    if ($StartNow) {
        Start-ScheduledTask -TaskName $TaskName
    }
}

#region Phase Orchestrate

function Get-PendingRebootReason {
    $reasons = @()
    if (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons += 'Component Based Servicing'
    }
    if (Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons += 'Windows Update'
    }
    if (Test-Path -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain') {
        $reasons += 'Domaenenbeitritt'
    }
    return $reasons
}

function Wait-DomainJoinComplete {
    $deadline = (Get-Date).AddMinutes(30)
    while ($true) {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $joinPending = Test-Path -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain'
        $secureChannel = $false
        if ($computerSystem.PartOfDomain -and -not $joinPending) {
            try { $secureChannel = Test-ComputerSecureChannel } catch { $secureChannel = $false }
        }
        if ($secureChannel) {
            Write-LabLog "Domaenenbeitritt zu $($computerSystem.Domain) abgeschlossen, Secure Channel ok."
            return
        }
        if ((Get-Date) -gt $deadline) {
            throw 'Domaenenbeitritt nach 30 Minuten nicht abgeschlossen.'
        }
        Write-LabLog "Warte auf Domaenenbeitritt (Teil der Domain: $($computerSystem.PartOfDomain), Neustart ausstehend: $joinPending)."
        Start-Sleep -Seconds 20
    }
}

function Save-InstallSecret {
    Add-Type -AssemblyName System.Security
    Protect-Directory -Path $SecretDir
    $payload = @{
        AdminPassword   = ConvertFrom-Base64String $AdminPasswordB64
        LabUserPassword = ConvertFrom-Base64String $LabUserPasswordB64
    } | ConvertTo-Json -Compress
    $protected = [Security.Cryptography.ProtectedData]::Protect([Text.Encoding]::UTF8.GetBytes($payload), $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
    [IO.File]::WriteAllBytes($SecretFile, $protected)
}

function Save-OwnScript {
    param([Parameter(Mandatory)][string] $Destination)
    if ($PSCommandPath -and (Test-Path -Path $PSCommandPath)) {
        Copy-Item -Path $PSCommandPath -Destination $Destination -Force
    }
    else {
        Set-Content -Path $Destination -Value $SelfText -Encoding ASCII
    }
}

function Invoke-InstallTask {
    $scriptCopy = Join-Path $ScriptDir 'Install-ExchangeServer.ps1'
    Save-OwnScript -Destination $scriptCopy
    Write-Utf8File -Path $LabUsersFile -Content (ConvertFrom-Base64String $LabUsersB64)
    Write-Utf8File -Path $UpdateScriptFile -Content (ConvertFrom-Base64String $UpdateScriptB64)
    Save-InstallSecret
    Remove-Item -Path $ResultFile -Force -ErrorAction SilentlyContinue

    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Phase Install -DomainName {1} -NetbiosName {2} -AdminUser {3} -PublicDomainName {4} -CompanyOu {5} -DcComputerName {6} -OrganizationName {7}' -f $scriptCopy, $DomainName, $NetbiosName, $AdminUser, $PublicDomainName, $CompanyOu, $DcComputerName, $OrganizationName
    if ($SecondDcComputerName) {
        $arguments += " -SecondDcComputerName $SecondDcComputerName"
    }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 3)
    $adminPassword = ConvertFrom-Base64String $AdminPasswordB64
    Register-ScheduledTask -TaskName $InstallTaskName -Action $action -Settings $settings -User "$NetbiosName\$AdminUser" -Password $adminPassword -RunLevel Highest -Force | Out-Null
    Start-ScheduledTask -TaskName $InstallTaskName
    Write-LabLog "Installationsphase als $NetbiosName\$AdminUser gestartet (Task $InstallTaskName)."

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    Start-Sleep -Seconds 30
    while ((Get-ScheduledTask -TaskName $InstallTaskName).State -eq 'Running') {
        if ((Get-Date) -gt $deadline) {
            Stop-ScheduledTask -TaskName $InstallTaskName
            throw "Installationsphase nach $TimeoutMinutes Minuten abgebrochen."
        }
        Start-Sleep -Seconds 30
    }

    $taskInfo = Get-ScheduledTaskInfo -TaskName $InstallTaskName
    Unregister-ScheduledTask -TaskName $InstallTaskName -Confirm:$false
    Remove-Item -Path $SecretFile -Force -ErrorAction SilentlyContinue

    $result = if (Test-Path -Path $ResultFile) { (Get-Content -Path $ResultFile -Raw).Trim() } else { 'missing' }
    if ($result -ne '0') {
        $installLog = Join-Path $LogDir 'Install-ExchangeServer-Install.log'
        $tail = Get-Content -Path $installLog -Tail 40 -ErrorAction SilentlyContinue
        throw "Installationsphase fehlgeschlagen (Ergebnis $result, Task-Code $($taskInfo.LastTaskResult)).`n$($tail -join "`n")"
    }
}

function Invoke-OrchestratePhase {
    if (Test-Path -Path $DoneMarker) {
        Write-LabLog 'Exchange ist bereits installiert und konfiguriert, nichts zu tun.'
        return
    }
    foreach ($name in 'AdminPasswordB64', 'LabUserPasswordB64', 'LabUsersB64', 'UpdateScriptB64') {
        if (-not (Get-Variable -Name $name -ValueOnly)) {
            throw "Parameter $name fehlt."
        }
    }

    Wait-DomainJoinComplete
    $pending = Get-PendingRebootReason
    if ($pending) {
        Write-LabLog "WARNUNG: Neustart ausstehend ($($pending -join ', ')). Exchange-Setup prueft das selbst."
    }

    Invoke-InstallTask

    Set-Content -Path $DoneMarker -Value (Get-Date -Format o) -Encoding ASCII
    Write-LabLog 'Exchange installiert und konfiguriert. Neustart in 120 Sekunden, danach Update-Lauf.'
    & shutdown.exe /r /t 120 /c 'ExchangeLab: Neustart nach Exchange-Installation' /d p:4:2 | Out-Null
}

#endregion

#region Phase Install

function Get-InstallSecret {
    Add-Type -AssemblyName System.Security
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($SecretFile), $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
    [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
}

function Initialize-LabDirectory {
    param([Parameter(Mandatory)][securestring] $LabUserPassword)

    Import-Module ActiveDirectory
    $forest = Get-ADForest
    if ($forest.UPNSuffixes -notcontains $PublicDomainName) {
        Set-ADForest -Identity $forest -UPNSuffixes @{ Add = $PublicDomainName }
        Write-LabLog "UPN-Suffix $PublicDomainName hinzugefuegt."
    }

    $domainDn = (Get-ADDomain).DistinguishedName
    $companyDn = "OU=$CompanyOu,$domainDn"
    if (-not [adsi]::Exists("LDAP://$companyDn")) {
        New-ADOrganizationalUnit -Name $CompanyOu -Path $domainDn
        Write-LabLog "OU $companyDn angelegt."
    }

    $data = Import-PowerShellDataFile -Path $LabUsersFile
    foreach ($relativeOu in $data.OrganizationalUnits) {
        $ouDn = "$relativeOu,$companyDn"
        if ([adsi]::Exists("LDAP://$ouDn")) { continue }
        $parts = $relativeOu -split ',', 2
        $name = $parts[0] -replace '^OU=', ''
        $parentDn = if ($parts.Count -gt 1) { "$($parts[1]),$companyDn" } else { $companyDn }
        New-ADOrganizationalUnit -Name $name -Path $parentDn
        Write-LabLog "OU $ouDn angelegt."
    }

    foreach ($user in $data.Users) {
        $displayName = "$($user.GivenName) $($user.Surname)"
        $attributes = @{
            GivenName         = $user.GivenName
            Surname           = $user.Surname
            DisplayName       = $displayName
            UserPrincipalName = '{0}@{1}' -f $user.SamAccountName.ToLowerInvariant(), $PublicDomainName
            StreetAddress     = $user.StreetAddress
            City              = $user.City
            PostalCode        = $user.PostalCode
            Country           = 'DE'
            Company           = $CompanyOu
            Office            = $user.Office
            Title             = $user.Title
            OfficePhone       = $user.OfficePhone
            MobilePhone       = $user.MobilePhone
            # Lab-Kompromiss: Ohne das laeuft das Kennwort nach 42 Tagen (Default Domain Policy) ab.
            PasswordNeverExpires = $true
        }
        if ($user.Department) { $attributes.Department = $user.Department }

        $existing = Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'"
        if ($existing) {
            Set-ADUser -Identity $existing @attributes
        }
        else {
            New-ADUser -Name $displayName -SamAccountName $user.SamAccountName -Path "$($user.OrganizationalUnit),$companyDn" -AccountPassword $LabUserPassword -Enabled $true @attributes
            Write-LabLog "Benutzer $($user.SamAccountName) angelegt."
        }
    }

    Set-ADUser -Identity $AdminUser -PasswordNeverExpires $true
    Write-LabLog "Kennwortablauf fuer $AdminUser und die Lab-Benutzer deaktiviert."
    return $data.Users
}

function Enable-AdRecycleBin {
    # Nicht fatal: Der Papierkorb ist eine Komfortfunktion und darf die Exchange-Installation nicht abbrechen.
    # Laeuft als Domain-Admin des Forest-Erstellers, der zugleich Enterprise Admin ist.
    try {
        $feature = Get-ADOptionalFeature -Identity 'Recycle Bin Feature'
        if ($feature.EnabledScopes.Count -gt 0) {
            Write-LabLog 'AD-Papierkorb ist bereits aktiv.'
            return
        }
        Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target (Get-ADForest).Name -Confirm:$false
        Write-LabLog 'AD-Papierkorb aktiviert.'
    }
    catch {
        Write-LabLog "WARNUNG: AD-Papierkorb nicht aktiviert: $($_.Exception.Message)"
    }
}

function Assert-DomainControllerBuild {
    $dcFqdn = "$DcComputerName.$DomainName"
    try {
        $build = Invoke-Command -ComputerName $dcFqdn -ScriptBlock {
            $currentVersion = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
            [pscustomobject]@{ Build = [int]$currentVersion.CurrentBuildNumber; Ubr = [int]$currentVersion.UBR }
        }
    }
    catch {
        # Nur die Pruefung entfaellt; Marketplace-Images "latest" erfuellen die Bedingung.
        Write-LabLog "WARNUNG: Build des DC $dcFqdn nicht pruefbar: $($_.Exception.Message)"
        return
    }
    Write-LabLog "DC $dcFqdn hat Build $($build.Build).$($build.Ubr)."
    if ($build.Build -eq 26100 -and $build.Ubr -lt 7171) {
        throw "DC $dcFqdn braucht fuer PrepareSchema mindestens Build 26100.7171 (Update November 2025)."
    }
}

function Invoke-ExchangeSetup {
    param([Parameter(Mandatory)][string] $Step, [Parameter(Mandatory)][string[]] $Arguments)

    $setupExe = Join-Path $MediaDir 'Setup.exe'
    $allArguments = $Arguments + '/IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF'
    $outFile = Join-Path $LogDir "ExchangeSetup-$Step.out.log"
    Write-LabLog "Exchange-Setup ${Step}: $($allArguments -join ' ')"
    $process = Start-Process -FilePath $setupExe -ArgumentList $allArguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err"
    if ($process.ExitCode -ne 0) {
        $tail = Get-Content -Path 'C:\ExchangeSetupLogs\ExchangeSetup.log' -Tail 30 -ErrorAction SilentlyContinue
        throw "Exchange-Setup $Step mit Exit-Code $($process.ExitCode) beendet.`n$($tail -join "`n")"
    }
    Write-LabLog "Exchange-Setup $Step erfolgreich."
}

function Install-Exchange {
    if (Get-Service -Name MSExchangeIS -ErrorAction SilentlyContinue) {
        Write-LabLog 'Exchange ist bereits installiert.'
        return
    }
    Assert-DomainControllerBuild
    Invoke-ExchangeSetup -Step 'PrepareSchema' -Arguments '/PrepareSchema'
    Invoke-ExchangeSetup -Step 'PrepareAD' -Arguments '/PrepareAD', "/OrganizationName:$OrganizationName"
    Invoke-ExchangeSetup -Step 'Install' -Arguments '/Mode:Install', '/Roles:Mailbox', '/MdbName:DB01', '/DbFilePath:F:\ExchangeDatabases\DB01\DB01.edb', '/LogFolderPath:F:\ExchangeDatabases\DB01\Logs'
}

function Connect-ExchangeSession {
    # Neues Kerberos-Ticket, damit die beim PrepareAD vergebene Gruppe "Organization Management" wirkt.
    & klist.exe purge | Out-Null
    $uri = ('http://{0}.{1}/PowerShell/' -f $env:COMPUTERNAME, $DomainName).ToLowerInvariant()
    $session = Invoke-WithRetry -Activity 'Exchange-PowerShell-Verbindung' -Attempts 20 -DelaySeconds 30 -ScriptBlock {
        New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $uri -Authentication Kerberos
    }
    Import-PSSession -Session $session -DisableNameChecking -AllowClobber | Out-Null
    Write-LabLog "Exchange-PowerShell verbunden ($uri)."
}

function Initialize-ExchangeConfiguration {
    param([Parameter(Mandatory)][object[]] $Users)

    $server = $env:COMPUTERNAME
    $mailHost = "mail.$PublicDomainName"
    $baseUrl = "https://$mailHost"

    # Accepted Domain und Adressrichtlinie
    if (-not (Get-AcceptedDomain | Where-Object { "$($_.DomainName)" -eq $PublicDomainName })) {
        New-AcceptedDomain -Name $PublicDomainName -DomainName $PublicDomainName -DomainType Authoritative | Out-Null
    }
    Set-AcceptedDomain -Identity $PublicDomainName -MakeDefault $true
    $policy = Get-EmailAddressPolicy | Where-Object { "$($_.Priority)" -eq 'Lowest' } | Select-Object -First 1
    Set-EmailAddressPolicy -Identity $policy.Name -EnabledEmailAddressTemplates "SMTP:%m@$PublicDomainName", "smtp:%m@$DomainName"
    Update-EmailAddressPolicy -Identity $policy.Name
    Write-LabLog "Accepted Domain $PublicDomainName ist Standard, Adressrichtlinie '$($policy.Name)' angewendet."

    # Postfaecher
    $database = (Get-MailboxDatabase -Server $server | Select-Object -First 1).Name
    foreach ($user in $Users) {
        $upn = '{0}@{1}' -f $user.SamAccountName.ToLowerInvariant(), $PublicDomainName
        $recipient = Get-User -Identity $upn
        if ("$($recipient.RecipientType)" -ne 'UserMailbox') {
            Invoke-WithRetry -Activity "Enable-Mailbox $upn" -Attempts 5 -DelaySeconds 30 -ScriptBlock {
                Enable-Mailbox -Identity $upn -Database $database | Out-Null
            }
            Write-LabLog "Postfach fuer $upn angelegt."
        }
    }

    # Zertifikat
    $pfxFile = Join-Path $CertDir 'fullchain.pfx'
    if (Test-Path -Path $pfxFile) {
        $certificate = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $pfxFile, $PfxPassword
        $thumbprint = $certificate.Thumbprint
        if (-not (Get-ExchangeCertificate -Server $server | Where-Object { $_.Thumbprint -eq $thumbprint })) {
            Import-ExchangeCertificate -Server $server -FileData ([IO.File]::ReadAllBytes($pfxFile)) -Password (ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force) -PrivateKeyExportable $true | Out-Null
        }
        Enable-ExchangeCertificate -Server $server -Thumbprint $thumbprint -Services 'IIS,SMTP' -Force -Confirm:$false
        Write-LabLog "Zertifikat $($certificate.Subject) ($thumbprint, gueltig bis $($certificate.NotAfter)) fuer IIS und SMTP aktiviert."
    }
    else {
        Write-LabLog "WARNUNG: $pfxFile fehlt, Exchange nutzt weiter das selbstsignierte Zertifikat."
    }

    # Interne und externe URLs
    Set-OwaVirtualDirectory -Identity "$server\owa (Default Web Site)" -InternalUrl "$baseUrl/owa" -ExternalUrl "$baseUrl/owa"
    Set-EcpVirtualDirectory -Identity "$server\ecp (Default Web Site)" -InternalUrl "$baseUrl/ecp" -ExternalUrl "$baseUrl/ecp"
    Set-WebServicesVirtualDirectory -Identity "$server\EWS (Default Web Site)" -InternalUrl "$baseUrl/EWS/Exchange.asmx" -ExternalUrl "$baseUrl/EWS/Exchange.asmx"
    Set-OabVirtualDirectory -Identity "$server\OAB (Default Web Site)" -InternalUrl "$baseUrl/OAB" -ExternalUrl "$baseUrl/OAB"
    Set-ActiveSyncVirtualDirectory -Identity "$server\Microsoft-Server-ActiveSync (Default Web Site)" -InternalUrl "$baseUrl/Microsoft-Server-ActiveSync" -ExternalUrl "$baseUrl/Microsoft-Server-ActiveSync"
    Set-MapiVirtualDirectory -Identity "$server\mapi (Default Web Site)" -InternalUrl "$baseUrl/mapi" -ExternalUrl "$baseUrl/mapi"
    # Mit ExternalHostname verlangt Exchange eine externe Authentifizierungsmethode; vorhandene beibehalten.
    $outlookAnywhere = Get-OutlookAnywhere -Identity "$server\Rpc (Default Web Site)"
    $externalAuth = "$($outlookAnywhere.ExternalClientAuthenticationMethod)"
    if (-not $externalAuth) { $externalAuth = 'Ntlm' }
    Set-OutlookAnywhere -Identity "$server\Rpc (Default Web Site)" -InternalHostname $mailHost -ExternalHostname $mailHost -InternalClientsRequireSsl $true -ExternalClientsRequireSsl $true -ExternalClientAuthenticationMethod $externalAuth
    Set-ClientAccessService -Identity $server -AutoDiscoverServiceInternalUri "https://autodiscover.$PublicDomainName/Autodiscover/Autodiscover.xml"
    Write-LabLog "Interne und externe URLs auf $baseUrl gesetzt, Autodiscover-SCP konfiguriert."
}

function Register-InitialUpdate {
    $content = Get-Content -Path $UpdateScriptFile -Raw
    Register-LabUpdateTask -ScriptContent $content -TaskName $UpdateTaskName
    Write-LabLog 'Update-Task auf dem Exchange-Server registriert (laeuft nach dem Neustart).'

    foreach ($dcName in @($DcComputerName, $SecondDcComputerName) | Where-Object { $_ }) {
        $dcFqdn = "$dcName.$DomainName"
        try {
            Invoke-Command -ComputerName $dcFqdn -ScriptBlock ${function:Register-LabUpdateTask} -ArgumentList $content, $UpdateTaskName, $true
            Write-LabLog "Update-Task auf $dcFqdn registriert und gestartet."
        }
        catch {
            Write-LabLog "WARNUNG: Update-Task auf $dcFqdn nicht registriert: $($_.Exception.Message)"
        }
    }
}

function Invoke-InstallPhase {
    $secret = Get-InstallSecret
    $users = Initialize-LabDirectory -LabUserPassword (ConvertTo-SecureString -String $secret.LabUserPassword -AsPlainText -Force)
    Enable-AdRecycleBin
    Install-Exchange
    Connect-ExchangeSession
    Initialize-ExchangeConfiguration -Users $users
    Register-InitialUpdate
}

#endregion

try {
    Write-LabLog "Start (Domain $DomainName, oeffentliche Domain $PublicDomainName)."
    switch ($Phase) {
        'Orchestrate' { Invoke-OrchestratePhase }
        'Install' {
            Invoke-InstallPhase
            Set-Content -Path $ResultFile -Value '0' -Encoding ASCII
        }
    }
    Write-LabLog 'Ende ohne Fehler.'
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    Write-LabLog $_.ScriptStackTrace
    if ($Phase -eq 'Install') {
        Set-Content -Path $ResultFile -Value '1' -Encoding ASCII
    }
    exit 1
}
