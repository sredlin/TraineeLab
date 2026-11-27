# Pruefungen auf dem Fileserver (laeuft nach Common.ps1, siehe dort).

Invoke-Check 'fs.complete' {
    if (Test-Path -Path (Join-Path $LabRoot 'fs-complete.done')) { 'OK', 'fs-complete.done' } else { 'FAIL', 'fs-complete.done fehlt (Phase Complete nicht fertig)' }
}

Invoke-Check 'fs.shares' {
    # Ohne administrative Freigaben wie F$.
    $shares = @(Get-SmbShare | Where-Object { $_.Path -like 'F:\*' -and -not $_.Name.EndsWith('$') })
    $withoutAbe = @($shares | Where-Object { "$($_.FolderEnumerationMode)" -ne 'AccessBased' })
    if ($shares.Count -lt 3) { return 'FAIL', "nur $($shares.Count) Freigaben auf F:" }
    if ($withoutAbe) { return 'FAIL', "ohne zugriffsbasierte Aufzaehlung: $(@($withoutAbe | ForEach-Object Name) -join ', ')" }
    'OK', (@($shares | ForEach-Object Name) -join ', ')
}

Invoke-Check 'fs.legacy' {
    $markers = @(Get-ChildItem -Path $LabRoot -Filter 'fs-*.done' | ForEach-Object Name)
    if (-not ($markers | Where-Object { $_ -like 'fs-orphan-*' }) -or $markers -notcontains 'fs-owneronly.done') {
        return 'FAIL', "Altlasten unvollstaendig (Marker: $($markers -join ', '))"
    }
    'OK', ($markers -join ', ')
}

Invoke-Check 'fs.samples' {
    if ($Lab.FileServerPercent -le 0) { return 'OK', 'keine Beispieldaten angefordert' }
    $statusFile = Join-Path $LabRoot 'sample-documents.json'
    if (-not (Test-Path -Path $statusFile)) { return 'PENDING', 'Generator noch nicht gestartet' }
    $status = Get-Content -Path $statusFile -Raw | ConvertFrom-Json
    $detail = '{0}: {1} von {2} GB, {3} Dateien (Stand {4})' -f $status.State, $status.WrittenGB, $status.TargetGB, $status.Files, $status.Updated
    if ($status.State -ne 'fertig') { return 'PENDING', $detail }
    $volume = Get-Volume -DriveLetter F
    $used = ($volume.Size - $volume.SizeRemaining) / $volume.Size * 100
    if ($used -lt $Lab.FileServerPercent - 10) { return 'FAIL', ('{0}; F: nur zu {1:N0} % belegt' -f $detail, $used) }
    'OK', ('{0}; F: {1:N0} % belegt' -f $detail, $used)
}

Invoke-CommonCheck -UpdateRun -LabInfo
