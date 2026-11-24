<#
.SYNOPSIS
    Baut die Artefakte fuer die Beispieldokumente des Fileservers aus den lesbaren Quellen.

.DESCRIPTION
    - scripts/SampleCorpus.gz: gzip-JSON { "<Datei>.psd1": "<Inhalt>" } aus scripts/corpus/*.psd1.
      Gelangt als userData auf die FS-VM (Grenze 64 KB Base64, also hoechstens 48 KB gzip).
    - scripts/Start-SampleDocuments.ps1: Startskript mit dem gzip-gepackten Generator
      scripts/New-SampleDocuments.ps1. Spart rund zwei Drittel der Groesse im Run Command.

    Nach jeder Aenderung am Korpus oder am Generator ausfuehren und die Artefakte mit committen
    (wie azuredeploy.json). Die Pester-Tests pruefen, dass Artefakte und Quellen uebereinstimmen.

.EXAMPLE
    ./tools/Build-SampleArtifacts.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$scripts = Join-Path $repoRoot 'scripts'

function ConvertTo-GzipByte {
    param([Parameter(Mandatory)][byte[]] $Bytes)
    $buffer = New-Object -TypeName System.IO.MemoryStream
    $gzip = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $buffer, ([IO.Compression.CompressionLevel]::Optimal)
    $gzip.Write($Bytes, 0, $Bytes.Length)
    $gzip.Dispose()
    , $buffer.ToArray()
}

# Korpus: Dateien sortiert, Inhalt ohne BOM, Zeilenenden LF.
$corpus = [ordered]@{}
foreach ($file in Get-ChildItem -Path (Join-Path $scripts 'corpus') -Filter '*.psd1' -File | Sort-Object -Property Name) {
    $corpus[$file.Name] = [IO.File]::ReadAllText($file.FullName).Replace("`r`n", "`n")
}
$json = $corpus | ConvertTo-Json -Compress
$corpusGzip = ConvertTo-GzipByte ([Text.Encoding]::UTF8.GetBytes($json))
$corpusPath = Join-Path $scripts 'SampleCorpus.gz'
[IO.File]::WriteAllBytes($corpusPath, $corpusGzip)
$base64Length = [Convert]::ToBase64String($corpusGzip).Length
Write-Output ('SampleCorpus.gz: {0} Dateien, {1:N0} Byte gzip, {2:N0} Byte Base64 (Grenze 65.536).' -f $corpus.Count, $corpusGzip.Length, $base64Length)
if ($base64Length -gt 65536) { throw 'Der Korpus passt nicht mehr in die userData (64 KB Base64). Texte kuerzen.' }

# Generator: gepackt in ein kleines Startskript.
$generatorPath = Join-Path $scripts 'New-SampleDocuments.ps1'
$generatorBytes = [IO.File]::ReadAllBytes($generatorPath)
if ($generatorBytes | Where-Object { $_ -gt 127 }) { throw 'New-SampleDocuments.ps1 muss reines ASCII sein.' }
$payload = [Convert]::ToBase64String((ConvertTo-GzipByte $generatorBytes))
$lines = @(
    '<#'
    '.SYNOPSIS'
    '    Startet den Generator fuer die Beispieldokumente (Run Command New-SampleDocuments auf <K>-FS01).'
    ''
    '.DESCRIPTION'
    '    ERZEUGT von tools/Build-SampleArtifacts.ps1, nicht von Hand aendern. Quelle: scripts/New-SampleDocuments.ps1.'
    '    Entpackt den Generator nach C:\ExchangeLab\Scripts und startet ihn. Der Textkorpus kommt aus der userData der VM.'
    '#>'
    '[CmdletBinding()]'
    'param('
    '    [double] $TargetSizeGB = 60,'
    '    [int] $TimeBudgetMinutes = 60'
    ')'
    ''
    '$ErrorActionPreference = ''Stop'''
    '$scriptDir = ''C:\ExchangeLab\Scripts'''
    'New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null'
    ('$payload = ''{0}''' -f $payload)
    '$packed = New-Object -TypeName System.IO.MemoryStream -ArgumentList (, [Convert]::FromBase64String($payload))'
    '$gzip = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $packed, ([IO.Compression.CompressionMode]::Decompress)'
    '$plain = New-Object -TypeName System.IO.MemoryStream'
    '$gzip.CopyTo($plain)'
    '$gzip.Dispose()'
    '$generator = Join-Path $scriptDir ''New-SampleDocuments.ps1'''
    '[IO.File]::WriteAllBytes($generator, $plain.ToArray())'
    '& $generator -TargetSizeGB $TargetSizeGB -TimeBudgetMinutes $TimeBudgetMinutes'
    'if ($LASTEXITCODE -eq 0) { exit 0 }'
    'exit $LASTEXITCODE'
)
$startPath = Join-Path $scripts 'Start-SampleDocuments.ps1'
[IO.File]::WriteAllText($startPath, (($lines -join "`n") + "`n"), [Text.Encoding]::ASCII)
Write-Output ('Start-SampleDocuments.ps1: {0:N0} Byte (Generator {1:N0} Byte).' -f (Get-Item -Path $startPath).Length, $generatorBytes.Length)
