# Pruefungen auf dem Windows-11-Client (laeuft nach Common.ps1, siehe dort).

Invoke-Check 'cl.domain' {
    $system = Get-CimInstance -ClassName Win32_ComputerSystem
    if (-not $system.PartOfDomain) { return 'FAIL', 'nicht in der Domain' }
    if (-not (Test-ComputerSecureChannel)) { return 'FAIL', "Secure Channel zu $($system.Domain) gestoert" }
    'OK', $system.Domain
}

Invoke-Check 'cl.language' {
    # Deutsch mit Sprachpaket, Englisch bleibt bei der Oberflaeche des Images (en-US) mit Formaten en-GB.
    $expected = @{ de = 'de-DE'; en = 'en-US' }[$Lab.Language]
    $ui = @(Get-SystemPreferredUILanguage)[0]
    if ($ui -ne $expected) { return 'FAIL', "Anzeigesprache $ui statt $expected" }
    'OK', "Anzeigesprache $ui"
}

Invoke-Check 'cl.office' {
    $failed = Join-Path $LabRoot 'office-failed.txt'
    if (Test-Path -Path $failed) { return 'FAIL', "Office-Installation: $(Get-Content -Path $failed -Raw)" }
    if (-not (Test-Path -Path (Join-Path $env:ProgramFiles 'Microsoft Office\root\Office16\OUTLOOK.EXE'))) { return 'FAIL', 'Outlook fehlt' }
    $culture = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue).ClientCulture
    'OK', "Outlook installiert ($culture)"
}

if ($Lab.RemoteDesktopManager) {
    Invoke-Check 'cl.rdm' {
        $failed = Join-Path $LabRoot 'rdm-failed.txt'
        if (Test-Path -Path $failed) { return 'FAIL', "Remote Desktop Manager: $(Get-Content -Path $failed -Raw)" }
        $exe = Get-ChildItem -Path (Join-Path $env:ProgramFiles 'Devolutions') -Filter 'RemoteDesktopManager.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $exe) { return 'FAIL', 'RemoteDesktopManager.exe fehlt' }
        'OK', "Version $($exe.VersionInfo.ProductVersion)"
    }
}

if ($Lab.WingetPackages) {
    Invoke-Check 'cl.winget' {
        $failed = Join-Path $LabRoot 'winget-failed.txt'
        if (Test-Path -Path $failed) { return 'FAIL', "winget: $(Get-Content -Path $failed -Raw)" }
        $resultFile = Join-Path $LabRoot 'winget-result.txt'
        if (-not (Test-Path -Path $resultFile)) { return 'FAIL', 'winget-result.txt fehlt' }
        $ok = @(Get-Content -Path $resultFile | Where-Object { $_ -like '*|Ok' } | ForEach-Object { $_.Split('|')[0] })
        $missing = @($Lab.WingetPackages.Split(',') | Where-Object { $ok -notcontains $_ })
        if ($missing) { return 'FAIL', "nicht installiert: $($missing -join ', ')" }
        if (-not (Get-ScheduledTask -TaskName 'TraineeLab-WinGetUpdate' -ErrorAction SilentlyContinue)) { return 'FAIL', 'Task TraineeLab-WinGetUpdate fehlt' }
        'OK', "$($ok -join ', '), Task TraineeLab-WinGetUpdate"
    }
}

Invoke-Check 'cl.rdp' {
    $members = @(Get-LocalGroupMember -SID 'S-1-5-32-555' | ForEach-Object { $_.SID.Value })
    if (-not ($members | Where-Object { $_ -like 'S-1-5-21-*-513' })) { return 'FAIL', 'Domaenen-Benutzer fehlen in Remotedesktopbenutzer' }
    'OK', 'Domaenen-Benutzer in Remotedesktopbenutzer'
}

Invoke-CommonCheck -LabInfo
