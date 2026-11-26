<#
.SYNOPSIS
    Erzeugt lebendige Beispieldokumente (Word, Excel, PowerPoint, PDF) fuer den Fileserver des Labs.

.DESCRIPTION
    Laeuft als Azure Managed Run Command (LocalSystem) auf <K>-FS01, vor dem Domaenenbeitritt.
    Inhalt: zwoelf Jahre Geschichte der fiktiven Agentur (Mustermann Medien GmbH bzw. Contoso Ltd) nach dem Drehbuch in
    scripts/data/<Sprache>/corpus (Kundenprojekte mit vollstaendigem Lebenszyklus, Buchhaltung, Personalakten mit
    fiktiven Personendaten, Bewerbungen, Protokolle, Richtlinien, Firmenereignisse, Corporate Design,
    Entra-Branding). Der Korpus kommt gzip-gepackt als userData der VM (IMDS); die Dokumente liegen nie im Repo.

    Formate ohne Fremdbibliotheken:
      - DOCX/XLSX/PPTX und Vorlagen (dotx/xltx/potx): OOXML per System.IO.Compression
      - PDF digital: PDF 1.4 mit Standardschriften (WinAnsi)
      - PDF-Scan: Seite per GDI+ gerendert (Papier, Lochung, Stempel, Unterschrift), JPEG-Seiten
      - Entwuerfe, Druckdaten, Moodboards, Praesentations-Exporte als Bildseiten

    Ablauf: Worker-Prozesse (je vCPU) bauen deterministische Einheiten (Projekt, Monat, Person, Jahr ...),
    bis 75 % des Ziels erreicht sind. Danach Kopien wie auf echten Servern (Basisordner, "Kopie von",
    Versionen, Quartalssicherungen) bis zum Ziel, zum Schluss die Ordnerzeitstempel. Vorhandene Dateien
    werden uebersprungen, der Lauf ist wiederaufnehmbar. Nach TimeBudgetMinutes setzt ein Startup-Task
    fort, damit das Deployment nicht an Langsamkeit scheitert.

    Das Skript enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1). Lokaler Test:
      .\New-SampleDocuments.ps1 -TargetPath C:\Temp\Daten -TargetSizeMB 200 -LabRoot C:\Temp\Lab `
          -CorpusPath .\data\de\corpus -LabUsersPath .\data\de\LabUsers.psd1 -ReferenceDate 2026-11-24 -WorkerCount 1
#>
[CmdletBinding()]
param(
    # Wurzel der Freigaben, leer = Root aus FileServer.psd1.
    [string] $TargetPath = '',

    [double] $TargetSizeGB = 60,

    # Anteil an der Groesse des Volumes von TargetPath in Prozent, ueberschreibt TargetSizeGB (Deployment: 90).
    [ValidateRange(0, 95)]
    [int] $TargetPercent = 0,

    # Ueberschreibt TargetPercent und TargetSizeGB (Tests).
    [int] $TargetSizeMB = 0,

    [string] $LabRoot = 'C:\ExchangeLab',

    # Leer = userData der VM (IMDS), entpackt nach <LabRoot>\Scripts\corpus. Sonst Ordner mit den Korpus-psd1.
    [string] $CorpusPath = '',

    # Leer = <LabRoot>\Scripts\LabUsers.psd1 (legt Initialize-FileServer.ps1 ab).
    [string] $LabUsersPath = '',

    # Stichtag yyyy-MM-dd. Leer = gespeicherter Stichtag des ersten Laufs oder heute.
    [string] $ReferenceDate = '',

    [int] $Seed = 4711,

    # Danach setzt ein Startup-Task im Hintergrund fort. 0 = ohne Begrenzung.
    [int] $TimeBudgetMinutes = 120,

    # 0 = Anzahl der Prozessoren, 1 = alles im eigenen Prozess (Tests).
    [int] $WorkerCount = 0,

    # Intern: Nummer des Worker-Prozesses.
    [int] $Worker = -1,

    # Keine Rastergrafik (System.Drawing fehlt, z. B. CI unter Linux): Scans und Layouts als einfache PDFs.
    [switch] $NoRaster,

    # Intern: Fortsetzung durch den Startup-Task.
    [switch] $Continue
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$IsWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$UseRaster = $IsWindowsHost -and -not $NoRaster
$LogDir = Join-Path $LabRoot 'Logs'
$ScriptDir = Join-Path $LabRoot 'Scripts'
$ProgressDir = Join-Path $LabRoot 'sample-progress'
$StatusFile = Join-Path $LabRoot 'sample-documents.json'
$PlanFile = Join-Path $LabRoot 'sample-plan.json'
$TaskName = 'TraineeLab-SampleDocuments'
$TempSuffix = '.tmp-sample'
$DuplicateShare = 0.33
# Kapazitaet der einfachen Einheitenliste in GB (vorsichtig unter dem Messwert) und freier Mindestanteil des Volumes.
$UnitCapacityGB = 60
$MinFreeShare = 0.08
$ArchiveYears = 6
$MaxYears = 12
$SelfText = $MyInvocation.MyCommand.ScriptBlock.ToString()

$Inv = [Globalization.CultureInfo]::InvariantCulture
$MidDot = [string][char]0x00B7
$Bullet = [string][char]0x2022

# Helvetica-Breiten (AFM, 1/1000 em) fuer die Zeichen 32 bis 126. Arial ist metrisch kompatibel.
$HelveticaWidths = @(278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556,
    556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, 1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667,
    556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, 333, 556, 556, 500,
    556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334,
    260, 334, 584)
$WinAnsiSpecial = @{ 0x20AC = 0x80; 0x201A = 0x82; 0x201E = 0x84; 0x2026 = 0x85; 0x2018 = 0x91; 0x2019 = 0x92; 0x201C = 0x93; 0x201D = 0x94; 0x2022 = 0x95; 0x2013 = 0x96; 0x2014 = 0x97 }
$WidthSpecial = @{ 0x80 = 556; 0x84 = 333; 0x85 = 1000; 0x91 = 222; 0x92 = 222; 0x93 = 333; 0x94 = 333; 0x95 = 350; 0x96 = 556; 0x97 = 1000; 0xA7 = 556; 0xB0 = 400; 0xB2 = 333; 0xB3 = 333; 0xB7 = 278; 0xC4 = 667; 0xD6 = 778; 0xDC = 722; 0xDF = 611; 0xE4 = 556; 0xF6 = 556; 0xFC = 556; 0xD7 = 584 }

New-Item -Path $LogDir, $ScriptDir, $ProgressDir -ItemType Directory -Force | Out-Null
$LogFile = if ($Worker -ge 0) { Join-Path $LogDir ('New-SampleDocuments-W{0}.log' -f $Worker) } else { Join-Path $LogDir 'New-SampleDocuments.log' }

#region Grundfunktionen

function Write-LabLog {
    param([Parameter(Mandatory)][string] $Message)
    $tag = if ($Worker -ge 0) { "W$Worker" } else { 'Main' }
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $tag, $Message
    Add-Content -Path $LogFile -Value $line
    # Worker schreiben nur ins eigene Log, sonst landet ihre Ausgabe in der Run-Command-Ausgabe.
    if ($Worker -lt 0) { Write-Information -MessageData $line -InformationAction Continue }
}

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Content)
    [IO.File]::WriteAllText($Path, $Content, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true))
}

function Join-SamplePath {
    param([Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][string] $Relative)
    [IO.Path]::Combine($Root, $Relative.Replace('\', [string][IO.Path]::DirectorySeparatorChar))
}

function ConvertTo-SafeName {
    param([Parameter(Mandatory)][string] $Name)
    (($Name -replace '[\\/:*?"<>|]', '-') -replace '\s+', ' ').Trim().TrimEnd('.')
}

function Get-ShortName {
    # Erstes Wort eines Firmennamens fuer Dateinamen, z. B. "Nordlicht".
    param([Parameter(Mandatory)][string] $Name)
    ConvertTo-SafeName (($Name -split ' ')[0])
}

function Get-Rng {
    param([long] $Index, [int] $Salt = 0)
    $value = ([long]$Seed * 1000003 + $Index * 7919 + [long]$Salt * 104729) % 2147483647
    New-Object -TypeName System.Random -ArgumentList ([int][Math]::Abs($value))
}

function Get-RandomEntry {
    param([Parameter(Mandatory)] $Rng, [Parameter(Mandatory)] $List)
    $List[$Rng.Next(0, $List.Count)]
}

function Get-RandomSubset {
    # Zufaellige, eindeutige Auswahl in Originalreihenfolge.
    param([Parameter(Mandatory)] $Rng, [Parameter(Mandatory)] $List, [int] $Count)
    if (-not $List -or $List.Count -eq 0 -or $Count -le 0) { return }
    $indexes = @(0..($List.Count - 1) | Sort-Object { $Rng.Next() } | Select-Object -First ([Math]::Min($Count, $List.Count)) | Sort-Object)
    foreach ($i in $indexes) { $List[$i] }
}

function Format-Money {
    # Betrag nach Locale.Money ({0} = Betrag im Format N2 der Culture).
    param([double] $Value)
    $Locale.Money -f $Value.ToString('N2', $Culture)
}

function Format-Number {
    param([double] $Value, [int] $Decimals = 0)
    $Value.ToString("N$Decimals", $Culture)
}

function Format-LocalDate {
    param([datetime] $Date)
    $Date.ToString($Locale.Date, $Culture)
}

function Format-PdfNumber {
    # PDF verlangt den Punkt als Dezimaltrenner, unabhaengig von der Kultur des Servers.
    param([double] $Value)
    $Value.ToString('0.###', $Inv)
}

function Expand-SampleText {
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text, [hashtable] $Context)
    foreach ($key in $Context.Keys) {
        $Text = $Text.Replace('{' + $key + '}', [string]$Context[$key])
    }
    $Text
}

function Get-DocumentDate {
    # Juengere Jahre kommen haeufiger vor; immer mindestens einen Tag vor dem Stichtag, werktags.
    param([Parameter(Mandatory)] $Rng, [int] $MinYears = 0, [int] $MaxYears = $script:MaxYears)
    $weights = @()
    $sum = 0.0
    for ($k = $MinYears; $k -le $MaxYears; $k++) {
        $w = 1.0 / (1.0 + 0.35 * $k)
        $weights += $w
        $sum += $w
    }
    $pick = $Rng.NextDouble() * $sum
    $years = $MaxYears
    for ($k = 0; $k -lt $weights.Count; $k++) {
        $pick -= $weights[$k]
        if ($pick -le 0) { $years = $MinYears + $k; break }
    }
    $date = $script:Reference.AddDays( - ($years * 365 + $Rng.Next(1, 366)))
    if ($date.DayOfWeek -eq [DayOfWeek]::Saturday) { $date = $date.AddDays(-1) }
    if ($date.DayOfWeek -eq [DayOfWeek]::Sunday) { $date = $date.AddDays(-2) }
    $date.AddMinutes(450 + $Rng.Next(0, 600))
}

function Get-AreaPath {
    # Abgeschlossene Jahre (aelter als ArchiveYears) liegen im Archiv, alles andere in der Abteilung.
    param([datetime] $Date, [string] $Current, [string] $ArchiveSub)
    if (($script:Reference.Year - $Date.Year) -gt $ArchiveYears) {
        return '{0}\{1}\{2}' -f $Paths.Archive, $Date.Year, $ArchiveSub
    }
    $Current
}

function Get-WinAnsiCode {
    param([char] $Character)
    $code = [int]$Character
    if ($code -lt 128 -or ($code -ge 0xA0 -and $code -le 0xFF)) { return $code }
    if ($WinAnsiSpecial.ContainsKey($code)) { return $WinAnsiSpecial[$code] }
    63
}

# Tabellen je UTF-16-Zeichen: WinAnsi-Code und Helvetica-Breite (1/1000 em). Spart einen Funktionsaufruf je Zeichen.
$WinAnsiOf = New-Object -TypeName 'int[]' -ArgumentList 65536
$CharUnits = New-Object -TypeName 'int[]' -ArgumentList 65536
for ($i = 0; $i -lt 65536; $i++) {
    $code = if ($i -lt 128 -or ($i -ge 0xA0 -and $i -le 0xFF)) { $i } elseif ($WinAnsiSpecial.ContainsKey($i)) { $WinAnsiSpecial[$i] } else { 63 }
    $WinAnsiOf[$i] = $code
    $CharUnits[$i] = if ($code -ge 32 -and $code -le 126) { $HelveticaWidths[$code - 32] } elseif ($WidthSpecial.ContainsKey($code)) { $WidthSpecial[$code] } else { 556 }
}
$TextUnitCache = New-Object -TypeName 'System.Collections.Generic.Dictionary[string,int]'

function Get-TextUnit {
    # Breite eines Textes in 1/1000 em; Woerter werden zwischengespeichert (Gross-/Kleinschreibung zaehlt).
    param([string] $Text)
    $units = 0
    if ($script:TextUnitCache.TryGetValue($Text, [ref] $units)) { return $units }
    foreach ($character in $Text.ToCharArray()) { $units += $script:CharUnits[[int]$character] }
    if ($script:TextUnitCache.Count -lt 250000) { $script:TextUnitCache[$Text] = $units }
    $units
}

function Measure-TextWidth {
    param([string] $Text, [double] $Size, [bool] $Bold)
    $factor = if ($Bold) { 1.06 } else { 1.0 }
    (Get-TextUnit $Text) * $Size / 1000.0 * $factor
}

function Split-TextLine {
    # Zeilenumbruch nach Helvetica-Breiten, Woerter bleiben ganz.
    param([AllowEmptyString()][string] $Text, [double] $Size, [bool] $Bold, [double] $MaxWidth)
    $result = [System.Collections.Generic.List[string]]::new()
    $space = Measure-TextWidth ' ' $Size $Bold
    foreach ($paragraph in ($Text -split "`n")) {
        $line = ''
        $lineWidth = 0.0
        foreach ($word in ($paragraph -split ' ')) {
            if (-not $word) { continue }
            $wordWidth = Measure-TextWidth $word $Size $Bold
            if (-not $line) {
                $line = $word
                $lineWidth = $wordWidth
            }
            elseif ($lineWidth + $space + $wordWidth -le $MaxWidth) {
                $line = "$line $word"
                $lineWidth += $space + $wordWidth
            }
            else {
                $result.Add($line)
                $line = $word
                $lineWidth = $wordWidth
            }
        }
        $result.Add($line)
    }
    , $result.ToArray()
}

#endregion
#region OOXML gemeinsam (DOCX, XLSX, PPTX)

# Wird einmal beim Start geladen (Windows PowerShell 5.1 braucht das Assembly ausdruecklich).
Add-Type -AssemblyName System.IO.Compression

function ConvertTo-XmlText {
    # Escaping fuer XML-Textknoten und Attributwerte; entfernt Steuerzeichen, die XML verbietet.
    param([AllowNull()][AllowEmptyString()][string] $Text)
    if (-not $Text) { return '' }
    $clean = $Text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
    [Security.SecurityElement]::Escape($clean)
}

function Format-OoxmlDate {
    # W3CDTF fuer docProps/core.xml; Zeit wird als UTC ausgegeben, damit die Ausgabe deterministisch ist.
    param([datetime] $Date)
    $Date.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
}

function Add-ZipEntry {
    # Schreibt einen Teil ins Paket; Strings als UTF-8 ohne BOM. Datum = Aenderungsdatum des Dokuments.
    param(
        [Parameter(Mandatory)] $Zip,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)] $Content,
        [datetime] $Date = [datetime]'2020-01-01'
    )
    $bytes = if ($Content -is [byte[]]) { $Content } else { (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false).GetBytes([string]$Content) }
    $level = if ($Name -match '\.(png|jpe?g)$') { [IO.Compression.CompressionLevel]::NoCompression } else { [IO.Compression.CompressionLevel]::Optimal }
    $entry = $Zip.CreateEntry($Name, $level)
    if ($Date.Year -lt 1980) { $Date = [datetime]'1980-01-01' }
    $entry.LastWriteTime = New-Object -TypeName System.DateTimeOffset -ArgumentList $Date
    $stream = $entry.Open()
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

function Open-ZipPackage {
    # Liefert @{ Stream; Zip }; Aufrufer schliesst mit Close-ZipPackage.
    param([Parameter(Mandatory)][string] $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $zip = New-Object -TypeName System.IO.Compression.ZipArchive -ArgumentList $stream, ([IO.Compression.ZipArchiveMode]::Create), $false
    @{ Stream = $stream; Zip = $zip }
}

function Close-ZipPackage {
    param([Parameter(Mandatory)] $Package)
    $Package.Zip.Dispose()
    $Package.Stream.Dispose()
}

function Get-OoxmlCoreXml {
    # docProps/core.xml: Titel, Autor, zuletzt geaendert von, Revision, Erstellt/Geaendert.
    param([Parameter(Mandatory)] $Model)
    $lastBy = if ($Model.LastModifiedBy) { $Model.LastModifiedBy } else { $Model.Author }
    $revision = if ($Model.Revision) { [int]$Model.Revision } else { 1 }
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
    ('<dc:title>{0}</dc:title><dc:creator>{1}</dc:creator><cp:lastModifiedBy>{2}</cp:lastModifiedBy><cp:revision>{3}</cp:revision>' -f (ConvertTo-XmlText $Model.Title), (ConvertTo-XmlText $Model.Author), (ConvertTo-XmlText $lastBy), $revision) +
    ('<dcterms:created xsi:type="dcterms:W3CDTF">{0}</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">{1}</dcterms:modified>' -f (Format-OoxmlDate $Model.Created), (Format-OoxmlDate $Model.Modified)) +
    '</cp:coreProperties>'
}

function Get-OoxmlAppXml {
    # docProps/app.xml; Application je nach Format ('Microsoft Office Word' / 'Microsoft Excel' / 'Microsoft Office PowerPoint').
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)][string] $Application)
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' +
    ('<Application>{0}</Application><Company>{1}</Company></Properties>' -f (ConvertTo-XmlText $Application), (ConvertTo-XmlText $Model.Company))
}

function Get-OoxmlCustomXml {
    # docProps/custom.xml mit der Eigenschaft Labels.Classification (altes, manuelles Schema); $null wenn keine.
    param([Parameter(Mandatory)] $Model)
    if (-not $Model.Classification) { return $null }
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/custom-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' +
    ('<property fmtid="{{D5CDD505-2E9C-101B-9397-08002B2CF9AE}}" pid="2" name="{1}"><vt:lpwstr>{0}</vt:lpwstr></property></Properties>' -f (ConvertTo-XmlText $Model.Classification), (ConvertTo-XmlText $L.Classification))
}

function Get-OoxmlPackageRelationship {
    # _rels/.rels: Hauptteil plus core/app und optional custom.
    param([Parameter(Mandatory)][string] $MainPart, [bool] $HasCustom = $false)
    $custom = if ($HasCustom) { '<Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties" Target="docProps/custom.xml"/>' } else { '' }
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    ('<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="{0}"/>' -f $MainPart) +
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>' +
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>' +
    $custom + '</Relationships>'
}

function Get-HexColor {
    # @(r,g,b) -> 'RRGGBB'
    param([Parameter(Mandatory)][int[]] $Rgb)
    '{0:X2}{1:X2}{2:X2}' -f $Rgb[0], $Rgb[1], $Rgb[2]
}

#endregion
#region DOCX (WordprocessingML)

# Schreiber fuer .docx und .dotx nach SPEC-office-writers.md, Abschnitt DOCX.
# Setzt die Helfer aus 00-ooxml-common.ps1 voraus. Alle Teile entstehen als Strings; die Reihenfolge
# der Elemente folgt dem Schema (ECMA-376, transitional), damit Word ohne Reparatur oeffnet.
#
# Paket:
#   [Content_Types].xml, _rels/.rels, docProps/core.xml, docProps/app.xml, docProps/custom.xml (Klassifizierung)
#   word/document.xml, word/_rels/document.xml.rels, word/styles.xml, word/settings.xml, word/fontTable.xml
#   word/header1.xml (+ _rels mit Logo), word/footer1.xml, word/numbering.xml (Aufzaehlung),
#   word/comments.xml (Kommentare), word/media/imageN.png|jpeg
#
# Beziehungen im Hauptteil: rId1 styles, rId2 settings, rId3 fontTable, rId4 header1, rId5 footer1,
# rId6 numbering, rId7 comments, ab rId10 Bilder. Satzspiegel A4 wie Geschaeftsbrief (DIN 5008):
# oben 4,5 cm, unten 3 cm, links 2,5 cm, rechts 2 cm; Textbreite 9354 Twips (16,5 cm).

function Get-DocxColor {
    # Farbe aus der CI als 'RRGGBB'; Ersatzwert, wenn der Eintrag fehlt.
    param($Ci, [Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][string] $Default)
    if ($Ci -and $Ci[$Name]) { return (Get-HexColor -Rgb $Ci[$Name]) }
    $Default
}

function Get-DocxContext {
    # Arbeitszustand fuer ein Dokument: Farben, Schriften, Satzspiegel, Zaehler, Beziehungen, Medien, Kommentare.
    param([Parameter(Mandatory)] $Model)
    $ci = if ($Model.Ci) { $Model.Ci } else { @{} }
    $font = if ($ci.Font) { [string]$ci.Font } else { 'Calibri' }
    $titleFont = if ($ci.TitleFont) { [string]$ci.TitleFont } else { $font }
    @{
        Ci           = $ci
        Primary      = (Get-DocxColor -Ci $ci -Name 'Primary' -Default '1F4E79')
        Accent       = (Get-DocxColor -Ci $ci -Name 'Accent' -Default 'C55A11')
        Light        = (Get-DocxColor -Ci $ci -Name 'Light' -Default 'E7E6E6')
        Dark         = (Get-DocxColor -Ci $ci -Name 'Dark' -Default '262626')
        Font         = $font
        TitleFont    = $titleFont
        Width        = 9354
        Height       = 12585
        DocumentRels = [System.Collections.Generic.List[object]]::new()
        HeaderRels   = [System.Collections.Generic.List[object]]::new()
        Media        = [System.Collections.Generic.List[object]]::new()
        Comments     = [System.Collections.Generic.List[object]]::new()
        NextRelId    = 10
        NextDocPr    = 1
        UsesBullets  = $false
    }
}

function Add-DocxMediaPart {
    # Legt Bildbytes als media/imageN.<ext> ab und liefert das Ziel relativ zu word/. Format nach Signatur, sonst nach Angabe.
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][byte[]] $Bytes, [string] $Format = 'png')
    $ext = 'png'
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xD8) { $ext = 'jpeg' }
    elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0x89 -and $Bytes[1] -eq 0x50) { $ext = 'png' }
    elseif ($Format -match '^jpe?g$') { $ext = 'jpeg' }
    $target = 'media/image{0}.{1}' -f ($Context.Media.Count + 1), $ext
    $Context.Media.Add(@{ Target = $target; Bytes = $Bytes; Extension = $ext })
    $target
}

function Add-DocxRelationship {
    # Neue Beziehung des Hauptteils (fortlaufend ab rId10); liefert die Id.
    param([Parameter(Mandatory)] $Context, [Parameter(Mandatory)][string] $Type, [Parameter(Mandatory)][string] $Target)
    $id = 'rId{0}' -f $Context.NextRelId
    $Context.NextRelId = $Context.NextRelId + 1
    $Context.DocumentRels.Add(@{ Id = $id; Type = $Type; Target = $Target })
    $id
}

function Get-DocxRelationshipXml {
    # .rels-Teil aus einer Liste @{ Id; Type (Kurzname); Target }.
    param([Parameter(Mandatory)][AllowEmptyCollection()] $Relationship)
    $sb = [System.Text.StringBuilder]::new(1024)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    foreach ($rel in $Relationship) {
        [void]$sb.Append(('<Relationship Id="{0}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/{1}" Target="{2}"/>' -f $rel.Id, $rel.Type, $rel.Target))
    }
    [void]$sb.Append('</Relationships>')
    $sb.ToString()
}

function Get-DocxRunXml {
    # Text als ein Run; Zeilenumbrueche werden <w:br/>, Tabulatoren <w:tab/>. Leerer Text ergibt ''.
    param([AllowNull()][AllowEmptyString()][string] $Text, [string] $RunProperty = '')
    if (-not $Text) { return '' }
    $rPr = if ($RunProperty) { '<w:rPr>' + $RunProperty + '</w:rPr>' } else { '' }
    if ($Text.IndexOfAny([char[]](9, 10, 13)) -lt 0) {
        return ('<w:r>' + $rPr + '<w:t xml:space="preserve">' + (ConvertTo-XmlText $Text) + '</w:t></w:r>')
    }
    $sb = [System.Text.StringBuilder]::new(256)
    [void]$sb.Append('<w:r>').Append($rPr)
    $lines = $Text -split '\r\n|\r|\n'
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -gt 0) { [void]$sb.Append('<w:br/>') }
        $parts = $lines[$i].Split([char]9)
        for ($j = 0; $j -lt $parts.Count; $j++) {
            if ($j -gt 0) { [void]$sb.Append('<w:tab/>') }
            if ($parts[$j].Length -gt 0) {
                [void]$sb.Append('<w:t xml:space="preserve">').Append((ConvertTo-XmlText $parts[$j])).Append('</w:t>')
            }
        }
    }
    [void]$sb.Append('</w:r>')
    $sb.ToString()
}

function Get-DocxParagraphXml {
    # Absatz: Property = inneres pPr in Schema-Reihenfolge, Text als Run, Content = weitere Runs,
    # Prefix/Suffix = Kommentarmarken am Anfang bzw. Ende.
    param(
        [string] $Property = '',
        [AllowNull()][AllowEmptyString()][string] $Text = '',
        [string] $RunProperty = '',
        [string] $Content = '',
        [string] $Prefix = '',
        [string] $Suffix = ''
    )
    $pPr = if ($Property) { '<w:pPr>' + $Property + '</w:pPr>' } else { '' }
    '<w:p>' + $pPr + $Prefix + (Get-DocxRunXml -Text $Text -RunProperty $RunProperty) + $Content + $Suffix + '</w:p>'
}

function Get-DocxDrawingXml {
    # Run mit Inline-Grafik (DrawingML, Groesse in EMU); docPr-Id fortlaufend ueber das ganze Dokument.
    param(
        [Parameter(Mandatory)] $Context,
        [Parameter(Mandatory)][string] $RelId,
        [Parameter(Mandatory)][long] $Cx,
        [Parameter(Mandatory)][long] $Cy,
        [string] $Description = ''
    )
    $id = $Context.NextDocPr
    $Context.NextDocPr = $id + 1
    $descr = if ($Description) { ' descr="' + (ConvertTo-XmlText $Description) + '"' } else { '' }
    $picture = ConvertTo-XmlText $Office.Picture
    ('<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{0}" cy="{1}"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="{2}" name="{4} {2}"{3}/>' -f $Cx, $Cy, $id, $descr, $picture) +
    '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>' +
    '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">' +
    ('<pic:nvPicPr><pic:cNvPr id="{0}" name="{2} {0}"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="{1}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>' -f $id, $RelId, $picture) +
    ('<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{0}" cy="{1}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>' -f $Cx, $Cy)
}

function Get-DocxTableXml {
    # Tabelle ueber die volle Textbreite. Kopfzeile fett auf Ci.Light und wiederholt, BoldLast = letzte Zeile fett
    # mit Linie darueber, Plain = ohne Rahmen. Kommentarmarken in der ersten bzw. letzten Zelle.
    param([Parameter(Mandatory)] $Block, [Parameter(Mandatory)] $Context, [string] $Prefix = '', [string] $Suffix = '')
    $rows = [System.Collections.Generic.List[object]]::new()
    if ($Block.Header) { $rows.Add(@{ Cells = @($Block.Header); Kind = 'Header' }) }
    if ($Block.Rows) {
        foreach ($row in $Block.Rows) {
            if ($null -eq $row) { continue }
            $cells = @($row)
            # Haeufiger PowerShell-Fehler: @(, $a, $b) verpackt die erste Zeile doppelt; dann die innere Liste nehmen.
            if ($cells.Count -eq 1 -and $cells[0] -is [System.Collections.IList]) { $cells = @($cells[0]) }
            $rows.Add(@{ Cells = $cells; Kind = 'Body' })
        }
    }
    if ($Block.BoldLast -and $rows.Count -gt 0 -and $rows[$rows.Count - 1].Kind -eq 'Body') { $rows[$rows.Count - 1].Kind = 'Last' }
    $cols = 0
    foreach ($row in $rows) { if ($row.Cells.Count -gt $cols) { $cols = $row.Cells.Count } }
    if ($cols -eq 0) { return (Get-DocxParagraphXml -Prefix $Prefix -Suffix $Suffix) }

    # Spaltenbreiten aus den Bruchteilen (normiert), Rest in die letzte Spalte; sonst gleich breit.
    $fractions = @($Block.Widths)
    $useFractions = ($null -ne $Block.Widths) -and ($fractions.Count -eq $cols)
    $sum = 0.0
    if ($useFractions) {
        foreach ($f in $fractions) {
            if ([double]$f -le 0) { $useFractions = $false }
            $sum += [double]$f
        }
    }
    $widths = New-Object -TypeName 'int[]' -ArgumentList $cols
    $used = 0
    for ($i = 0; $i -lt $cols - 1; $i++) {
        $share = if ($useFractions) { [double]$fractions[$i] / $sum } else { 1.0 / $cols }
        $widths[$i] = [int][Math]::Floor($Context.Width * $share)
        $used += $widths[$i]
    }
    $widths[$cols - 1] = $Context.Width - $used

    # Ausrichtung je Spalte aus Align (L/R, zusaetzlich C).
    $align = [string]$Block.Align
    $jc = New-Object -TypeName 'string[]' -ArgumentList $cols
    for ($i = 0; $i -lt $cols; $i++) {
        $letter = if ($i -lt $align.Length) { $align.Substring($i, 1).ToUpperInvariant() } else { 'L' }
        $jc[$i] = if ($letter -eq 'R') { '<w:jc w:val="right"/>' } elseif ($letter -eq 'C') { '<w:jc w:val="center"/>' } else { '' }
    }

    $sb = [System.Text.StringBuilder]::new(4096)
    [void]$sb.Append('<w:tbl><w:tblPr>')
    if (-not $Block.Plain) { [void]$sb.Append('<w:tblStyle w:val="TableGrid"/>') }
    [void]$sb.Append(('<w:tblW w:w="{0}" w:type="dxa"/><w:tblLayout w:type="fixed"/><w:tblLook w:val="04A0"/></w:tblPr><w:tblGrid>' -f $Context.Width))
    foreach ($w in $widths) { [void]$sb.Append(('<w:gridCol w:w="{0}"/>' -f $w)) }
    [void]$sb.Append('</w:tblGrid>')
    $shading = '<w:shd w:val="clear" w:color="auto" w:fill="{0}"/>' -f $Context.Light
    $topLine = '<w:tcBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="{0}"/></w:tcBorders>' -f $Context.Dark
    for ($r = 0; $r -lt $rows.Count; $r++) {
        $row = $rows[$r]
        $kind = $row.Kind
        [void]$sb.Append('<w:tr>')
        if ($kind -eq 'Header') { [void]$sb.Append('<w:trPr><w:tblHeader/></w:trPr>') }
        $runProperty = if ($kind -eq 'Body') { '' } else { '<w:b/><w:bCs/>' }
        for ($colIdx = 0; $colIdx -lt $cols; $colIdx++) {
            $text = if ($colIdx -lt $row.Cells.Count) { [string]$row.Cells[$colIdx] } else { '' }
            [void]$sb.Append(('<w:tc><w:tcPr><w:tcW w:w="{0}" w:type="dxa"/>' -f $widths[$colIdx]))
            if ($kind -eq 'Last') { [void]$sb.Append($topLine) }
            if ($kind -eq 'Header') { [void]$sb.Append($shading) }
            [void]$sb.Append('</w:tcPr>')
            $pre = if ($r -eq 0 -and $colIdx -eq 0) { $Prefix } else { '' }
            $suf = if ($r -eq $rows.Count - 1 -and $colIdx -eq $cols - 1) { $Suffix } else { '' }
            [void]$sb.Append((Get-DocxParagraphXml -Property ('<w:spacing w:before="40" w:after="40" w:line="240" w:lineRule="auto"/>' + $jc[$colIdx]) -Text $text -RunProperty $runProperty -Prefix $pre -Suffix $suf))
            [void]$sb.Append('</w:tc>')
        }
        [void]$sb.Append('</w:tr>')
    }
    [void]$sb.Append('</w:tbl>')
    $sb.ToString()
}

function Get-DocxImageXml {
    # Bild zentriert in eigenem Absatz, Breite WidthCm (sonst 96 dpi), begrenzt auf den Satzspiegel; Caption kursiv darunter.
    param([Parameter(Mandatory)] $Block, [Parameter(Mandatory)] $Context, [string] $Prefix = '', [string] $Suffix = '')
    $caption = [string]$Block.Caption
    if (-not $Block.Bytes) {
        return (Get-DocxParagraphXml -Property '<w:pStyle w:val="Caption"/><w:jc w:val="center"/>' -Text $caption -Prefix $Prefix -Suffix $Suffix)
    }
    $target = Add-DocxMediaPart -Context $Context -Bytes $Block.Bytes -Format ([string]$Block.Format)
    $relId = Add-DocxRelationship -Context $Context -Type 'image' -Target $target
    $wPx = [double]$Block.WidthPx
    $hPx = [double]$Block.HeightPx
    if ($wPx -le 0 -or $hPx -le 0) { $wPx = 4.0; $hPx = 3.0 }
    $widthCm = [double]$Block.WidthCm
    if ($widthCm -le 0) { $widthCm = $wPx / 96.0 * 2.54 }
    $cx = [long][Math]::Round($widthCm * 360000)
    $maxCx = [long]$Context.Width * 635
    if ($cx -gt $maxCx) { $cx = $maxCx }
    $cy = [long][Math]::Round($cx * $hPx / $wPx)
    $maxCy = [long]$Context.Height * 635 - 1440000
    if ($cy -gt $maxCy) {
        $cx = [long][Math]::Round($cx * $maxCy / $cy)
        $cy = $maxCy
    }
    $drawing = Get-DocxDrawingXml -Context $Context -RelId $relId -Cx $cx -Cy $cy -Description $caption
    if (-not $caption) {
        return (Get-DocxParagraphXml -Property '<w:spacing w:before="120" w:after="120"/><w:jc w:val="center"/>' -Content $drawing -Prefix $Prefix -Suffix $Suffix)
    }
    (Get-DocxParagraphXml -Property '<w:keepNext/><w:spacing w:before="120" w:after="60"/><w:jc w:val="center"/>' -Content $drawing -Prefix $Prefix) +
    (Get-DocxParagraphXml -Property '<w:pStyle w:val="Caption"/><w:jc w:val="center"/>' -Text $caption -Suffix $Suffix)
}

function Get-DocxInfoXml {
    # Informationsblock rechts: Bezeichnung ab 7 cm vor dem rechten Rand, Wert rechtsbuendig am Rand.
    # Geordnete Hashtable in ihrer Reihenfolge; einfache Hashtable sortiert (deterministisch).
    param([Parameter(Mandatory)] $Block, [Parameter(Mandatory)] $Context, [string] $Prefix = '', [string] $Suffix = '')
    $entries = [System.Collections.Generic.List[object]]::new()
    $rows = $Block.Rows
    if ($rows -is [hashtable]) {
        $keys = New-Object -TypeName 'string[]' -ArgumentList $rows.Count
        $k = 0
        foreach ($key in $rows.Keys) { $keys[$k] = [string]$key; $k++ }
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        foreach ($key in $keys) { $entries.Add(@($key, [string]$rows[$key])) }
    }
    elseif ($rows -is [System.Collections.IDictionary]) {
        foreach ($entry in $rows.GetEnumerator()) { $entries.Add(@([string]$entry.Key, [string]$entry.Value)) }
    }
    if ($entries.Count -eq 0) { return (Get-DocxParagraphXml -Prefix $Prefix -Suffix $Suffix) }
    $labelProperty = '<w:color w:val="{0}"/><w:sz w:val="18"/><w:szCs w:val="18"/>' -f $Context.Primary
    $indent = $Context.Width - 3969
    $sb = [System.Text.StringBuilder]::new(1024)
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $label = $entries[$i][0]
        if ($label -and -not $label.EndsWith(':')) { $label += ':' }
        $after = if ($i -eq $entries.Count - 1) { 360 } else { 0 }
        $property = '<w:tabs><w:tab w:val="right" w:pos="{0}"/></w:tabs><w:spacing w:after="{1}" w:line="240" w:lineRule="auto"/><w:ind w:left="{2}"/>' -f $Context.Width, $after, $indent
        $content = (Get-DocxRunXml -Text $label -RunProperty $labelProperty) + '<w:r><w:tab/></w:r>' + (Get-DocxRunXml -Text $entries[$i][1])
        $pre = if ($i -eq 0) { $Prefix } else { '' }
        $suf = if ($i -eq $entries.Count - 1) { $Suffix } else { '' }
        [void]$sb.Append((Get-DocxParagraphXml -Property $property -Content $content -Prefix $pre -Suffix $suf))
    }
    $sb.ToString()
}

function Get-DocxBlockXml {
    # Ein Block des Modells als WordprocessingML; Prefix/Suffix tragen Kommentarmarken in den ersten bzw. letzten Absatz.
    param([AllowNull()] $Block, [Parameter(Mandatory)] $Context, [string] $Prefix = '', [string] $Suffix = '')
    if ($null -eq $Block) {
        if ($Prefix -or $Suffix) { return (Get-DocxParagraphXml -Prefix $Prefix -Suffix $Suffix) }
        return ''
    }
    switch ([string]$Block.T) {
        'Title' { return (Get-DocxParagraphXml -Property '<w:pStyle w:val="Title"/>' -Text $Block.Text -Prefix $Prefix -Suffix $Suffix) }
        'Heading' { return (Get-DocxParagraphXml -Property '<w:pStyle w:val="Heading1"/>' -Text $Block.Text -Prefix $Prefix -Suffix $Suffix) }
        'Para' { return (Get-DocxParagraphXml -Text $Block.Text -Prefix $Prefix -Suffix $Suffix) }
        'Table' { return (Get-DocxTableXml -Block $Block -Context $Context -Prefix $Prefix -Suffix $Suffix) }
        'Image' { return (Get-DocxImageXml -Block $Block -Context $Context -Prefix $Prefix -Suffix $Suffix) }
        'Info' { return (Get-DocxInfoXml -Block $Block -Context $Context -Prefix $Prefix -Suffix $Suffix) }
        'Space' { return (Get-DocxParagraphXml -Prefix $Prefix -Suffix $Suffix) }
        'Break' { return (Get-DocxParagraphXml -Content '<w:r><w:br w:type="page"/></w:r>' -Prefix $Prefix -Suffix $Suffix) }
        'Address' {
            # Ein Absatz mit Zeilenumbruechen: kein Abstand zwischen den Zeilen, Abstand danach.
            $lines = [System.Collections.Generic.List[string]]::new()
            foreach ($line in @($Block.Lines)) { if ($null -ne $line) { $lines.Add([string]$line) } }
            return (Get-DocxParagraphXml -Property '<w:spacing w:after="480" w:line="240" w:lineRule="auto"/>' -Text ($lines -join "`n") -Prefix $Prefix -Suffix $Suffix)
        }
        'Bullets' {
            $items = [System.Collections.Generic.List[string]]::new()
            foreach ($item in @($Block.Items)) { if ($null -ne $item) { $items.Add([string]$item) } }
            if ($items.Count -eq 0) { return (Get-DocxParagraphXml -Prefix $Prefix -Suffix $Suffix) }
            $Context.UsesBullets = $true
            $sb = [System.Text.StringBuilder]::new(1024)
            for ($i = 0; $i -lt $items.Count; $i++) {
                $pre = if ($i -eq 0) { $Prefix } else { '' }
                $suf = if ($i -eq $items.Count - 1) { $Suffix } else { '' }
                [void]$sb.Append((Get-DocxParagraphXml -Property '<w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>' -Text $items[$i] -Prefix $pre -Suffix $suf))
            }
            return $sb.ToString()
        }
        'Sign' {
            # Leerraum fuer die Unterschrift, darunter Name und Rolle.
            $roleProperty = '<w:color w:val="{0}"/><w:sz w:val="19"/><w:szCs w:val="19"/>' -f $Context.Dark
            return ((Get-DocxParagraphXml -Property '<w:keepNext/><w:keepLines/><w:spacing w:before="1020" w:after="0"/>' -Text ([string]$Block.Name) -Prefix $Prefix) +
                (Get-DocxParagraphXml -Property '<w:spacing w:after="240"/>' -Text ([string]$Block.Role) -RunProperty $roleProperty -Suffix $Suffix))
        }
    }
    # Unbekannter Typ: Text oder Zeilen als normaler Absatz, sonst nur die Marken.
    $fallback = if ($Block.Text) { [string]$Block.Text } elseif ($Block.Lines) { @($Block.Lines) -join "`n" } else { '' }
    if ($fallback -or $Prefix -or $Suffix) { return (Get-DocxParagraphXml -Text $fallback -Prefix $Prefix -Suffix $Suffix) }
    ''
}

function Get-DocxDocumentXml {
    # word/document.xml: Bloecke, Kommentarmarken, Abschnitt mit A4, Raendern, Kopf- und Fusszeile.
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)] $Context, [string] $HeaderId = 'rId4', [string] $FooterId = 'rId5')
    $blocks = if ($Model.Blocks) { @($Model.Blocks) } else { @() }
    $count = $blocks.Count
    $starts = New-Object -TypeName 'string[]' -ArgumentList $count
    $ends = New-Object -TypeName 'string[]' -ArgumentList $count
    if ($count -gt 0 -and $Model.Comments) {
        foreach ($comment in $Model.Comments) {
            if ($null -eq $comment) { continue }
            $index = if ($null -ne $comment.Block) { [int]$comment.Block } else { 0 }
            if ($index -lt 0) { $index = 0 }
            if ($index -ge $count) { $index = $count - 1 }
            $id = $Context.Comments.Count
            $Context.Comments.Add($comment)
            $starts[$index] += '<w:commentRangeStart w:id="{0}"/>' -f $id
            $ends[$index] += '<w:commentRangeEnd w:id="{0}"/><w:r><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:commentReference w:id="{0}"/></w:r>' -f $id
        }
    }
    $sb = [System.Text.StringBuilder]::new(16384)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<w:document xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>')
    $empty = $true
    for ($i = 0; $i -lt $count; $i++) {
        $xml = Get-DocxBlockXml -Block $blocks[$i] -Context $Context -Prefix $starts[$i] -Suffix $ends[$i]
        if (-not $xml) { continue }
        [void]$sb.Append($xml)
        $empty = $false
        # Nach einer Tabelle ein schmaler Leerabsatz: trennt Folgetabellen und schliesst das Dokument nie mit einer Tabelle.
        if ($xml.StartsWith('<w:tbl>')) { [void]$sb.Append('<w:p><w:pPr><w:spacing w:after="0"/></w:pPr></w:p>') }
    }
    if ($empty) { [void]$sb.Append('<w:p/>') }
    [void]$sb.Append(('<w:sectPr><w:headerReference w:type="default" r:id="{0}"/><w:footerReference w:type="default" r:id="{1}"/>' -f $HeaderId, $FooterId))
    [void]$sb.Append('<w:pgSz w:w="11906" w:h="16838" w:code="9"/><w:pgMar w:top="2552" w:right="1134" w:bottom="1701" w:left="1418" w:header="709" w:footer="567" w:gutter="0"/>')
    [void]$sb.Append('<w:cols w:space="708"/><w:docGrid w:linePitch="360"/></w:sectPr></w:body></w:document>')
    $sb.ToString()
}

function Get-DocxHeaderXml {
    # word/header1.xml: links HeaderLines und Marking (fett, Ci.Primary), rechts das Logo (Hoehe 1,2 cm), darunter Linie in Ci.Primary.
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)] $Context)
    $ci = $Context.Ci
    $rightWidth = 3402
    $leftWidth = $Context.Width - $rightWidth
    $lineProperty = '<w:color w:val="{0}"/>' -f $Context.Dark
    $left = [System.Text.StringBuilder]::new(1024)
    foreach ($line in @($ci.HeaderLines)) {
        if ($line) { [void]$left.Append((Get-DocxParagraphXml -Property '<w:pStyle w:val="Header"/>' -Text ([string]$line) -RunProperty $lineProperty)) }
    }
    if ($Model.Marking) {
        $markProperty = '<w:b/><w:bCs/><w:color w:val="{0}"/><w:sz w:val="18"/><w:szCs w:val="18"/>' -f $Context.Primary
        [void]$left.Append((Get-DocxParagraphXml -Property '<w:pStyle w:val="Header"/><w:spacing w:before="60"/>' -Text ([string]$Model.Marking) -RunProperty $markProperty))
    }
    if ($left.Length -eq 0) { [void]$left.Append('<w:p><w:pPr><w:pStyle w:val="Header"/></w:pPr></w:p>') }
    $logo = ''
    if ($ci.LogoPng) {
        $target = Add-DocxMediaPart -Context $Context -Bytes $ci.LogoPng -Format 'png'
        $Context.HeaderRels.Add(@{ Id = 'rId1'; Type = 'image'; Target = $target })
        $wPx = [double]$ci.LogoWidthPx
        $hPx = [double]$ci.LogoHeightPx
        if ($wPx -le 0 -or $hPx -le 0) { $wPx = 3.0; $hPx = 1.0 }
        $cy = [long]432000
        $cx = [long][Math]::Round($cy * $wPx / $hPx)
        $maxCx = [long]$rightWidth * 635
        if ($cx -gt $maxCx) {
            $cy = [long][Math]::Round($cy * $maxCx / $cx)
            $cx = $maxCx
        }
        $logo = Get-DocxDrawingXml -Context $Context -RelId 'rId1' -Cx $cx -Cy $cy -Description 'Logo'
    }
    $sb = [System.Text.StringBuilder]::new(4096)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<w:hdr xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">')
    [void]$sb.Append(('<w:tbl><w:tblPr><w:tblW w:w="{0}" w:type="dxa"/><w:tblLayout w:type="fixed"/><w:tblCellMar><w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar></w:tblPr>' -f $Context.Width))
    [void]$sb.Append(('<w:tblGrid><w:gridCol w:w="{0}"/><w:gridCol w:w="{1}"/></w:tblGrid><w:tr>' -f $leftWidth, $rightWidth))
    [void]$sb.Append(('<w:tc><w:tcPr><w:tcW w:w="{0}" w:type="dxa"/><w:vAlign w:val="bottom"/></w:tcPr>' -f $leftWidth)).Append($left.ToString()).Append('</w:tc>')
    [void]$sb.Append(('<w:tc><w:tcPr><w:tcW w:w="{0}" w:type="dxa"/><w:vAlign w:val="bottom"/></w:tcPr>' -f $rightWidth))
    [void]$sb.Append((Get-DocxParagraphXml -Property '<w:pStyle w:val="Header"/><w:jc w:val="right"/>' -Content $logo)).Append('</w:tc></w:tr></w:tbl>')
    [void]$sb.Append(('<w:p><w:pPr><w:pStyle w:val="Header"/><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="{0}"/></w:pBdr><w:spacing w:before="60"/><w:rPr><w:sz w:val="4"/><w:szCs w:val="4"/></w:rPr></w:pPr></w:p>' -f $Context.Primary))
    [void]$sb.Append('</w:hdr>')
    $sb.ToString()
}

function Get-DocxFooterXml {
    # word/footer1.xml: Marking (fett, Ci.Primary), FooterLines klein und mittig, Seitenzahl; Linie in Ci.Primary darueber.
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)] $Context)
    $small = '<w:color w:val="595959"/><w:sz w:val="14"/><w:szCs w:val="14"/>'
    $paragraphs = [System.Collections.Generic.List[object]]::new()
    if ($Model.Marking) {
        $markProperty = '<w:b/><w:bCs/><w:color w:val="{0}"/><w:sz w:val="16"/><w:szCs w:val="16"/>' -f $Context.Primary
        $paragraphs.Add(@((Get-DocxRunXml -Text ([string]$Model.Marking) -RunProperty $markProperty)))
    }
    foreach ($line in @($Context.Ci.FooterLines)) {
        if ($line) { $paragraphs.Add(@((Get-DocxRunXml -Text ([string]$line) -RunProperty $small))) }
    }
    # Seitenzahl nach Labels.Page ("Seite {0} von {1}"): Text vor, zwischen und nach den Feldern.
    $pageText = $L.Page -split '\{[01]\}'
    $page = (Get-DocxRunXml -Text $pageText[0] -RunProperty $small) +
        ('<w:fldSimple w:instr=" PAGE "><w:r><w:rPr>{0}</w:rPr><w:t>1</w:t></w:r></w:fldSimple>' -f $small) +
        (Get-DocxRunXml -Text $pageText[1] -RunProperty $small) +
        ('<w:fldSimple w:instr=" NUMPAGES "><w:r><w:rPr>{0}</w:rPr><w:t>1</w:t></w:r></w:fldSimple>' -f $small) +
        (Get-DocxRunXml -Text $pageText[2] -RunProperty $small)
    $paragraphs.Add(@($page))
    $sb = [System.Text.StringBuilder]::new(2048)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<w:ftr xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">')
    for ($i = 0; $i -lt $paragraphs.Count; $i++) {
        $border = if ($i -eq 0) { '<w:pBdr><w:top w:val="single" w:sz="4" w:space="4" w:color="{0}"/></w:pBdr>' -f $Context.Primary } else { '' }
        [void]$sb.Append((Get-DocxParagraphXml -Property ('<w:pStyle w:val="Footer"/>' + $border + '<w:jc w:val="center"/>') -Content $paragraphs[$i][0]))
    }
    [void]$sb.Append('</w:ftr>')
    $sb.ToString()
}

function Get-DocxStyleXml {
    # word/styles.xml: Standard (Ci.Font, 10,5 pt, Locale.Culture), Title, Heading1, Listenabsatz, Beschriftung,
    # Kopf-/Fusszeile, Kommentar und Tabellenstile (TableNormal ohne Rahmen, TableGrid mit Rahmen).
    param([Parameter(Mandatory)] $Context)
    $font = ConvertTo-XmlText $Context.Font
    $titleFont = ConvertTo-XmlText $Context.TitleFont
    $bodyFonts = '<w:rFonts w:ascii="{0}" w:hAnsi="{0}" w:eastAsia="{0}" w:cs="{0}"/>' -f $font
    $titleFonts = '<w:rFonts w:ascii="{0}" w:hAnsi="{0}" w:eastAsia="{0}" w:cs="{0}"/>' -f $titleFont
    $sb = [System.Text.StringBuilder]::new(8192)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">')
    [void]$sb.Append('<w:docDefaults><w:rPrDefault><w:rPr>').Append($bodyFonts)
    [void]$sb.Append(('<w:sz w:val="21"/><w:szCs w:val="21"/><w:lang w:val="{0}" w:eastAsia="en-US" w:bidi="ar-SA"/></w:rPr></w:rPrDefault>' -f $Locale.Culture))
    [void]$sb.Append('<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>')
    [void]$sb.Append('<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:rPr>').Append($bodyFonts)
    [void]$sb.Append(('<w:color w:val="{0}"/><w:sz w:val="21"/><w:szCs w:val="21"/><w:lang w:val="{1}"/></w:rPr></w:style>' -f $Context.Dark, $Locale.Culture))
    [void]$sb.Append('<w:style w:type="character" w:default="1" w:styleId="DefaultParagraphFont"><w:name w:val="Default Paragraph Font"/><w:uiPriority w:val="1"/><w:semiHidden/><w:unhideWhenUsed/></w:style>')
    [void]$sb.Append('<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/>')
    [void]$sb.Append('<w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>')
    [void]$sb.Append('<w:style w:type="numbering" w:default="1" w:styleId="NoList"><w:name w:val="No List"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/></w:style>')
    [void]$sb.Append('<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:uiPriority w:val="10"/><w:qFormat/>')
    [void]$sb.Append(('<w:pPr><w:keepNext/><w:pBdr><w:bottom w:val="single" w:sz="8" w:space="4" w:color="{0}"/></w:pBdr><w:spacing w:before="120" w:after="240" w:line="240" w:lineRule="auto"/></w:pPr>' -f $Context.Accent))
    [void]$sb.Append('<w:rPr>').Append($titleFonts).Append(('<w:color w:val="{0}"/><w:kern w:val="28"/><w:sz w:val="44"/><w:szCs w:val="44"/></w:rPr></w:style>' -f $Context.Primary))
    [void]$sb.Append('<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:uiPriority w:val="9"/><w:qFormat/>')
    [void]$sb.Append('<w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="360" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr>')
    [void]$sb.Append('<w:rPr>').Append($titleFonts).Append(('<w:b/><w:bCs/><w:color w:val="{0}"/><w:sz w:val="30"/><w:szCs w:val="30"/></w:rPr></w:style>' -f $Context.Primary))
    [void]$sb.Append('<w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:uiPriority w:val="34"/><w:qFormat/>')
    [void]$sb.Append('<w:pPr><w:spacing w:after="60"/><w:ind w:left="720"/></w:pPr></w:style>')
    [void]$sb.Append('<w:style w:type="paragraph" w:styleId="Caption"><w:name w:val="caption"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:uiPriority w:val="35"/><w:unhideWhenUsed/><w:qFormat/>')
    [void]$sb.Append('<w:pPr><w:spacing w:after="200" w:line="240" w:lineRule="auto"/></w:pPr><w:rPr><w:i/><w:iCs/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>')
    foreach ($name in @('Header', 'Footer')) {
        [void]$sb.Append(('<w:style w:type="paragraph" w:styleId="{0}"><w:name w:val="{1}"/><w:basedOn w:val="Normal"/><w:uiPriority w:val="99"/><w:unhideWhenUsed/>' -f $name, $name.ToLowerInvariant()))
        [void]$sb.Append('<w:pPr><w:tabs><w:tab w:val="center" w:pos="4677"/><w:tab w:val="right" w:pos="9354"/></w:tabs><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr><w:rPr><w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr></w:style>')
    }
    [void]$sb.Append('<w:style w:type="character" w:styleId="CommentReference"><w:name w:val="annotation reference"/><w:basedOn w:val="DefaultParagraphFont"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/><w:rPr><w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr></w:style>')
    [void]$sb.Append('<w:style w:type="paragraph" w:styleId="CommentText"><w:name w:val="annotation text"/><w:basedOn w:val="Normal"/><w:uiPriority w:val="99"/><w:unhideWhenUsed/><w:pPr><w:spacing w:line="240" w:lineRule="auto"/></w:pPr><w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr></w:style>')
    [void]$sb.Append('<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:basedOn w:val="TableNormal"/><w:uiPriority w:val="39"/><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr><w:tblPr><w:tblBorders>')
    foreach ($edge in @('top', 'left', 'bottom', 'right', 'insideH', 'insideV')) {
        [void]$sb.Append(('<w:{0} w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/>' -f $edge))
    }
    [void]$sb.Append('</w:tblBorders></w:tblPr></w:style>')
    [void]$sb.Append('</w:styles>')
    $sb.ToString()
}

function Get-DocxNumberingXml {
    # word/numbering.xml: eine Aufzaehlung (numId 1) mit drei Ebenen, Aufzaehlungszeichen in Ci.Accent.
    param([Parameter(Mandatory)] $Context)
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>' +
    ('<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#61623;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr><w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/><w:color w:val="{0}"/></w:rPr></w:lvl>' -f $Context.Accent) +
    ('<w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="o"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New" w:cs="Courier New" w:hint="default"/><w:color w:val="{0}"/></w:rPr></w:lvl>' -f $Context.Accent) +
    ('<w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#61607;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="2160" w:hanging="360"/></w:pPr><w:rPr><w:rFonts w:ascii="Wingdings" w:hAnsi="Wingdings" w:hint="default"/><w:color w:val="{0}"/></w:rPr></w:lvl>' -f $Context.Accent) +
    '</w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>'
}

function Get-DocxSettingXml {
    # word/settings.xml: Word-2013-Kompatibilitaet, Sprache, Dezimal- und Listentrennzeichen aus Locale.
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:zoom w:percent="100"/><w:defaultTabStop w:val="708"/><w:hyphenationZone w:val="425"/><w:characterSpacingControl w:val="doNotCompress"/>' +
    '<w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/><w:compatSetting w:name="overrideTableStyleFontSizeAndJustification" w:uri="http://schemas.microsoft.com/office/word" w:val="1"/>' +
    '<w:compatSetting w:name="enableOpenTypeFeatures" w:uri="http://schemas.microsoft.com/office/word" w:val="1"/><w:compatSetting w:name="doNotFlipMirrorIndents" w:uri="http://schemas.microsoft.com/office/word" w:val="1"/></w:compat>' +
    ('<w:themeFontLang w:val="{0}"/><w:decimalSymbol w:val="{1}"/><w:listSeparator w:val="{2}"/></w:settings>' -f $Locale.Culture, $Culture.NumberFormat.NumberDecimalSeparator, $Locale.ListSeparator)
}

function Get-DocxFontTableXml {
    # word/fontTable.xml mit den CI-Schriften und, bei Aufzaehlungen, den Symbolschriften.
    param([Parameter(Mandatory)] $Context)
    $sb = [System.Text.StringBuilder]::new(512)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">')
    [void]$sb.Append(('<w:font w:name="{0}"/>' -f (ConvertTo-XmlText $Context.Font)))
    if ($Context.TitleFont -ne $Context.Font) { [void]$sb.Append(('<w:font w:name="{0}"/>' -f (ConvertTo-XmlText $Context.TitleFont))) }
    if ($Context.UsesBullets) {
        [void]$sb.Append('<w:font w:name="Symbol"><w:charset w:val="02"/><w:family w:val="roman"/><w:pitch w:val="variable"/></w:font>')
        [void]$sb.Append('<w:font w:name="Courier New"><w:family w:val="modern"/><w:pitch w:val="fixed"/></w:font>')
        [void]$sb.Append('<w:font w:name="Wingdings"><w:charset w:val="02"/><w:family w:val="auto"/><w:pitch w:val="variable"/></w:font>')
    }
    [void]$sb.Append('</w:fonts>')
    $sb.ToString()
}

function Get-DocxCommentXml {
    # word/comments.xml in der Reihenfolge der Verankerung (Id = Position). Mehrzeiliger Text wird zu Absaetzen.
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)] $Context)
    $sb = [System.Text.StringBuilder]::new(2048)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">')
    for ($i = 0; $i -lt $Context.Comments.Count; $i++) {
        $comment = $Context.Comments[$i]
        $author = if ($comment.Author) { [string]$comment.Author } else { [string]$Model.Author }
        $initials = [string]$comment.Initials
        if (-not $initials) {
            foreach ($part in ($author -split '\s+')) { if ($part) { $initials += $part.Substring(0, 1) } }
        }
        $date = if ($comment.Date) { [datetime]$comment.Date } else { [datetime]$Model.Modified }
        [void]$sb.Append(('<w:comment w:id="{0}" w:author="{1}" w:date="{2}" w:initials="{3}">' -f $i, (ConvertTo-XmlText $author), (Format-OoxmlDate $date), (ConvertTo-XmlText $initials)))
        $lines = ([string]$comment.Text) -split '\r\n|\r|\n'
        for ($j = 0; $j -lt $lines.Count; $j++) {
            $mark = if ($j -eq 0) { '<w:r><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:annotationRef/></w:r>' } else { '' }
            [void]$sb.Append('<w:p><w:pPr><w:pStyle w:val="CommentText"/></w:pPr>').Append($mark).Append((Get-DocxRunXml -Text $lines[$j])).Append('</w:p>')
        }
        [void]$sb.Append('</w:comment>')
    }
    [void]$sb.Append('</w:comments>')
    $sb.ToString()
}

function Get-DocxContentTypeXml {
    # [Content_Types].xml: Defaults fuer rels, xml und die verwendeten Bildformate, Overrides fuer alle Teile.
    param([Parameter(Mandatory)] $Context, [bool] $Template = $false, [bool] $HasCustom = $false)
    $hasPng = $false
    $hasJpeg = $false
    foreach ($media in $Context.Media) {
        if ($media.Extension -eq 'png') { $hasPng = $true } else { $hasJpeg = $true }
    }
    $main = if ($Template) { 'template.main+xml' } else { 'document.main+xml' }
    $wml = 'application/vnd.openxmlformats-officedocument.wordprocessingml.'
    $sb = [System.Text.StringBuilder]::new(2048)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
    [void]$sb.Append('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>')
    if ($hasPng) { [void]$sb.Append('<Default Extension="png" ContentType="image/png"/>') }
    if ($hasJpeg) { [void]$sb.Append('<Default Extension="jpeg" ContentType="image/jpeg"/>') }
    [void]$sb.Append(('<Override PartName="/word/document.xml" ContentType="{0}{1}"/>' -f $wml, $main))
    [void]$sb.Append(('<Override PartName="/word/styles.xml" ContentType="{0}styles+xml"/>' -f $wml))
    [void]$sb.Append(('<Override PartName="/word/settings.xml" ContentType="{0}settings+xml"/>' -f $wml))
    [void]$sb.Append(('<Override PartName="/word/fontTable.xml" ContentType="{0}fontTable+xml"/>' -f $wml))
    [void]$sb.Append(('<Override PartName="/word/header1.xml" ContentType="{0}header+xml"/>' -f $wml))
    [void]$sb.Append(('<Override PartName="/word/footer1.xml" ContentType="{0}footer+xml"/>' -f $wml))
    if ($Context.UsesBullets) { [void]$sb.Append(('<Override PartName="/word/numbering.xml" ContentType="{0}numbering+xml"/>' -f $wml)) }
    if ($Context.Comments.Count -gt 0) { [void]$sb.Append(('<Override PartName="/word/comments.xml" ContentType="{0}comments+xml"/>' -f $wml)) }
    [void]$sb.Append('<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>')
    [void]$sb.Append('<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>')
    if ($HasCustom) { [void]$sb.Append('<Override PartName="/docProps/custom.xml" ContentType="application/vnd.openxmlformats-officedocument.custom-properties+xml"/>') }
    [void]$sb.Append('</Types>')
    $sb.ToString()
}

function Write-DocxFile {
    # Schreibt das Modell als Word-Dokument (.docx) bzw. als Vorlage (.dotx, Model.Template = $true).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][System.Collections.IDictionary] $Model
    )
    $context = Get-DocxContext -Model $Model
    # Reihenfolge: Kopfzeile zuerst, damit das Logo image1 und docPr 1 erhaelt.
    $headerXml = Get-DocxHeaderXml -Model $Model -Context $context
    $footerXml = Get-DocxFooterXml -Model $Model -Context $context
    $documentXml = Get-DocxDocumentXml -Model $Model -Context $context -HeaderId 'rId4' -FooterId 'rId5'
    $customXml = Get-OoxmlCustomXml -Model $Model
    $hasCustom = [bool]$customXml
    $hasComments = $context.Comments.Count -gt 0

    $rels = [System.Collections.Generic.List[object]]::new()
    $rels.Add(@{ Id = 'rId1'; Type = 'styles'; Target = 'styles.xml' })
    $rels.Add(@{ Id = 'rId2'; Type = 'settings'; Target = 'settings.xml' })
    $rels.Add(@{ Id = 'rId3'; Type = 'fontTable'; Target = 'fontTable.xml' })
    $rels.Add(@{ Id = 'rId4'; Type = 'header'; Target = 'header1.xml' })
    $rels.Add(@{ Id = 'rId5'; Type = 'footer'; Target = 'footer1.xml' })
    if ($context.UsesBullets) { $rels.Add(@{ Id = 'rId6'; Type = 'numbering'; Target = 'numbering.xml' }) }
    if ($hasComments) { $rels.Add(@{ Id = 'rId7'; Type = 'comments'; Target = 'comments.xml' }) }
    foreach ($rel in $context.DocumentRels) { $rels.Add($rel) }

    $stamp = if ($Model.Modified) { [datetime]$Model.Modified } else { [datetime]'2020-01-01' }
    $fullPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
    $package = Open-ZipPackage -Path $fullPath
    try {
        $zip = $package.Zip
        Add-ZipEntry -Zip $zip -Name '[Content_Types].xml' -Content (Get-DocxContentTypeXml -Context $context -Template ([bool]$Model.Template) -HasCustom $hasCustom) -Date $stamp
        Add-ZipEntry -Zip $zip -Name '_rels/.rels' -Content (Get-OoxmlPackageRelationship -MainPart 'word/document.xml' -HasCustom $hasCustom) -Date $stamp
        Add-ZipEntry -Zip $zip -Name 'docProps/core.xml' -Content (Get-OoxmlCoreXml -Model $Model) -Date $stamp
        Add-ZipEntry -Zip $zip -Name 'docProps/app.xml' -Content (Get-OoxmlAppXml -Model $Model -Application 'Microsoft Office Word') -Date $stamp
        if ($hasCustom) { Add-ZipEntry -Zip $zip -Name 'docProps/custom.xml' -Content $customXml -Date $stamp }
        Add-ZipEntry -Zip $zip -Name 'word/document.xml' -Content $documentXml -Date $stamp
        Add-ZipEntry -Zip $zip -Name 'word/_rels/document.xml.rels' -Content (Get-DocxRelationshipXml -Relationship $rels) -Date $stamp
        Add-ZipEntry -Zip $zip -Name 'word/styles.xml' -Content (Get-DocxStyleXml -Context $context) -Date $stamp
        Add-ZipEntry -Zip $zip -Name 'word/settings.xml' -Content (Get-DocxSettingXml) -Date $stamp
        Add-ZipEntry -Zip $zip -Name 'word/fontTable.xml' -Content (Get-DocxFontTableXml -Context $context) -Date $stamp
        if ($context.UsesBullets) { Add-ZipEntry -Zip $zip -Name 'word/numbering.xml' -Content (Get-DocxNumberingXml -Context $context) -Date $stamp }
        if ($hasComments) { Add-ZipEntry -Zip $zip -Name 'word/comments.xml' -Content (Get-DocxCommentXml -Model $Model -Context $context) -Date $stamp }
        Add-ZipEntry -Zip $zip -Name 'word/header1.xml' -Content $headerXml -Date $stamp
        if ($context.HeaderRels.Count -gt 0) { Add-ZipEntry -Zip $zip -Name 'word/_rels/header1.xml.rels' -Content (Get-DocxRelationshipXml -Relationship $context.HeaderRels) -Date $stamp }
        Add-ZipEntry -Zip $zip -Name 'word/footer1.xml' -Content $footerXml -Date $stamp
        foreach ($media in $context.Media) { Add-ZipEntry -Zip $zip -Name ('word/' + $media.Target) -Content $media.Bytes -Date $stamp }
    }
    finally {
        Close-ZipPackage -Package $package
    }
}

#endregion
#region XLSX (SpreadsheetML)

# Schreibt Arbeitsmappen (.xlsx) und Vorlagen (.xltx) direkt als OOXML-Paket.
# Benoetigt die gemeinsamen Helfer aus 00-ooxml-common.ps1.
# Stilraster in styles.xml: cellXfs-Index = ((Zeilenstil * 7) + Zahlenformat) * 2 + Fett
#   Zeilenstil:   0 normal, 1 Header, 2 Total, 3 Title
#   Zahlenformat: 0 Standard, 1 Text, 2 Integer, 3 Number, 4 Money, 5 Percent, 6 Date

function Get-XlsxColumnName {
    # Spaltennummer (1-basiert) -> Buchstaben: 1 = A, 26 = Z, 27 = AA, 16384 = XFD.
    param([Parameter(Mandatory)][int] $Index)
    if ($Index -lt 1 -or $Index -gt 16384) { throw "Spaltennummer ausserhalb 1..16384: $Index" }
    $name = ''
    $n = $Index
    while ($n -gt 0) {
        $m = ($n - 1) % 26
        $name = [string][char](65 + $m) + $name
        $n = [int][Math]::Floor(($n - 1) / 26)
    }
    $name
}

function Get-XlsxCellReference {
    # Zeile und Spalte (1-basiert) -> Zellbezug wie A1 oder AA12; mit -Absolute wie $AA$12.
    param(
        [Parameter(Mandatory)][int] $Row,
        [Parameter(Mandatory)][int] $Column,
        [switch] $Absolute
    )
    if ($Row -lt 1 -or $Row -gt 1048576) { throw "Zeilennummer ausserhalb 1..1048576: $Row" }
    $col = Get-XlsxColumnName -Index $Column
    if ($Absolute) { '$' + $col + '$' + $Row } else { $col + $Row }
}

function ConvertTo-XlsxDateSerial {
    # Datum -> Excel-Seriennummer (Datumssystem 1900, mit Tagesbruchteil); $null vor dem 01.01.1900.
    # Excel kennt den 29.02.1900, daher liegen Daten vor dem 01.03.1900 einen Tag tiefer.
    param([Parameter(Mandatory)][datetime] $Date)
    if ($Date.Year -lt 1900) { return $null }
    # 599264352000000000 = Ticks von 1899-12-30, 599317056000000000 = Ticks von 1900-03-01
    $days = [double]($Date.Ticks - 599264352000000000) / 864000000000
    if ($Date.Ticks -lt 599317056000000000) { $days = $days - 1 }
    $days
}

function Get-XlsxSheetName {
    # Gueltiger, eindeutiger Blattname: max. 31 Zeichen, ohne []:*?/\, nicht mit ' am Rand, nicht "History".
    param(
        [AllowNull()][AllowEmptyString()][string] $Name,
        [int] $Index = 1,
        [Parameter(Mandatory)][hashtable] $Used
    )
    $n = ''
    if ($Name) { $n = ($Name -replace '[\[\]:\*\?/\\]', '-') -replace '[\x00-\x1F]', '' }
    $n = $n.Trim().Trim([char]39).Trim()
    if ($n.Length -gt 31) { $n = $n.Substring(0, 31).TrimEnd().TrimEnd([char]39) }
    if (-not $n) { $n = $Office.Sheet + $Index }
    if ($n -eq 'History') { $n = 'History-1' }
    $base = $n
    $k = 2
    while ($Used.ContainsKey($n.ToUpperInvariant())) {
        $suffix = ' (' + $k + ')'
        $keep = [Math]::Min($base.Length, 31 - $suffix.Length)
        $n = $base.Substring(0, $keep).TrimEnd() + $suffix
        $k++
    }
    $Used[$n.ToUpperInvariant()] = $true
    $n
}

function Get-XlsxCiSetting {
    # Corporate-Identity-Werte mit Standardwerten; Farben als RRGGBB.
    param([Parameter(Mandatory)] $Model)
    $ci = $Model.Ci
    $font = 'Calibri'
    $titleFont = ''
    $primary = '1F4E79'
    $dark = '000000'
    if ($null -ne $ci) {
        if ($ci.Font) { $font = [string]$ci.Font }
        if ($ci.TitleFont) { $titleFont = [string]$ci.TitleFont }
        if ($ci.Primary) { $primary = Get-HexColor -Rgb $ci.Primary }
        if ($ci.Dark) { $dark = Get-HexColor -Rgb $ci.Dark }
    }
    if (-not $titleFont) { $titleFont = $font }
    # Excel erlaubt Schriftnamen bis 31 Zeichen
    if ($font.Length -gt 31) { $font = $font.Substring(0, 31) }
    if ($titleFont.Length -gt 31) { $titleFont = $titleFont.Substring(0, 31) }
    @{ Font = $font; TitleFont = $titleFont; Primary = $primary; Dark = $dark }
}

function Get-XlsxColumnCount {
    # Anzahl der Spalten eines Blatts: Maximum aus Spaltendefinitionen und Zellen je Zeile.
    param([Parameter(Mandatory)] $Sheet)
    $count = 0
    if ($null -ne $Sheet.Columns) { $count = @($Sheet.Columns).Count }
    if ($null -ne $Sheet.Rows) {
        foreach ($row in @($Sheet.Rows)) {
            if ($null -eq $row -or $null -eq $row.Cells) { continue }
            $n = @($row.Cells).Count
            if ($n -gt $count) { $count = $n }
        }
    }
    if ($count -gt 16384) { throw "Zu viele Spalten: $count" }
    $count
}

function Get-XlsxColumnWidth {
    # Spaltenbreiten in Zeichen je Spalte; ohne Angabe die Excel-Standardbreite 8,43.
    param([Parameter(Mandatory)] $Sheet, [int] $ColumnCount)
    $widths = New-Object 'double[]' $ColumnCount
    $defs = @()
    if ($null -ne $Sheet.Columns) { $defs = @($Sheet.Columns) }
    for ($i = 0; $i -lt $ColumnCount; $i++) {
        $w = 8.43
        if ($i -lt $defs.Count -and $null -ne $defs[$i] -and $null -ne $defs[$i].Width) {
            $w = [double]$defs[$i].Width
            if ($w -lt 0) { $w = 0 }
            if ($w -gt 255) { $w = 255 }
        }
        $widths[$i] = $w
    }
    , $widths
}

function Get-XlsxFilterRange {
    # AutoFilter-Bereich: erste Header-Zeile bis zur letzten Datenzeile vor Total-, Leer- oder Titelzeile.
    # Liefert @{ FirstRow; LastRow; LastColumn } oder $null.
    param([Parameter(Mandatory)] $Sheet, [int] $ColumnCount)
    if (-not $Sheet.AutoFilter -or $ColumnCount -lt 1) { return $null }
    $rows = @()
    if ($null -ne $Sheet.Rows) { $rows = @($Sheet.Rows) }
    $header = 0
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($null -ne $rows[$i] -and [string]$rows[$i].Style -eq 'Header') { $header = $i + 1; break }
    }
    if ($header -eq 0) {
        $header = 1
        if ([int]$Sheet.Freeze -gt 0) { $header = [int]$Sheet.Freeze }
    }
    $last = $header
    for ($i = $header; $i -lt $rows.Count; $i++) {
        $row = $rows[$i]
        if ($null -eq $row -or $null -eq $row.Cells -or @($row.Cells).Count -eq 0) { break }
        $style = [string]$row.Style
        if ($style -eq 'Total' -or $style -eq 'Title' -or $style -eq 'Header') { break }
        $last = $i + 1
    }
    $cols = $ColumnCount
    if ($header -le $rows.Count -and $null -ne $rows[$header - 1] -and $null -ne $rows[$header - 1].Cells) {
        $n = @($rows[$header - 1].Cells).Count
        if ($n -gt 0) { $cols = $n }
    }
    @{ FirstRow = $header; LastRow = $last; LastColumn = (Get-XlsxColumnName -Index $cols) }
}

function Get-XlsxStyleXml {
    # styles.xml mit festem Raster aus 4 Zeilenstilen x 7 Zahlenformaten x fett/normal (56 cellXfs).
    param([Parameter(Mandatory)] $Ci)
    $font = ConvertTo-XmlText $Ci.Font
    $titleFont = ConvertTo-XmlText $Ci.TitleFont
    $sb = New-Object System.Text.StringBuilder 8192
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    [void]$sb.Append('<numFmts count="2"><numFmt numFmtId="164" formatCode="').Append((ConvertTo-XmlText $Locale.XlsxDate)).Append('"/>')
    [void]$sb.Append('<numFmt numFmtId="165" formatCode="').Append((ConvertTo-XmlText $Locale.XlsxMoney)).Append('"/></numFmts>')
    [void]$sb.Append('<fonts count="4">')
    [void]$sb.Append('<font><sz val="10"/><color rgb="FF').Append($Ci.Dark).Append('"/><name val="').Append($font).Append('"/><family val="2"/></font>')
    [void]$sb.Append('<font><b/><sz val="10"/><color rgb="FF').Append($Ci.Dark).Append('"/><name val="').Append($font).Append('"/><family val="2"/></font>')
    [void]$sb.Append('<font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="').Append($font).Append('"/><family val="2"/></font>')
    [void]$sb.Append('<font><b/><sz val="16"/><color rgb="FF').Append($Ci.Primary).Append('"/><name val="').Append($titleFont).Append('"/><family val="2"/></font>')
    [void]$sb.Append('</fonts>')
    [void]$sb.Append('<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>')
    [void]$sb.Append('<fill><patternFill patternType="solid"><fgColor rgb="FF').Append($Ci.Primary).Append('"/><bgColor indexed="64"/></patternFill></fill></fills>')
    [void]$sb.Append('<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>')
    [void]$sb.Append('<border><left/><right/><top style="thin"><color rgb="FF').Append($Ci.Dark).Append('"/></top><bottom/><diagonal/></border></borders>')
    [void]$sb.Append('<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>')
    [void]$sb.Append('<cellXfs count="56">')
    $numFmt = @(0, 49, 3, 4, 165, 10, 164)
    for ($s = 0; $s -lt 4; $s++) {
        for ($f = 0; $f -lt 7; $f++) {
            for ($b = 0; $b -lt 2; $b++) {
                $fontId = $b
                if ($s -eq 1) { $fontId = 2 } elseif ($s -eq 2) { $fontId = 1 } elseif ($s -eq 3) { $fontId = 3 }
                $fillId = 0
                if ($s -eq 1) { $fillId = 2 }
                $borderId = 0
                if ($s -eq 2) { $borderId = 1 }
                [void]$sb.Append('<xf numFmtId="').Append($numFmt[$f]).Append('" fontId="').Append($fontId)
                [void]$sb.Append('" fillId="').Append($fillId).Append('" borderId="').Append($borderId).Append('" xfId="0"')
                if ($numFmt[$f] -ne 0) { [void]$sb.Append(' applyNumberFormat="1"') }
                if ($fontId -ne 0) { [void]$sb.Append(' applyFont="1"') }
                if ($fillId -ne 0) { [void]$sb.Append(' applyFill="1"') }
                if ($borderId -ne 0) { [void]$sb.Append(' applyBorder="1"') }
                if ($s -eq 3) { [void]$sb.Append(' applyAlignment="1"><alignment vertical="center"/></xf>') } else { [void]$sb.Append('/>') }
            }
        }
    }
    [void]$sb.Append('</cellXfs>')
    [void]$sb.Append('<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>')
    [void]$sb.Append('<dxfs count="0"/><tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>')
    [void]$sb.Append('</styleSheet>')
    $sb.ToString()
}

function Get-XlsxHeaderFooterXml {
    # Druckkopf und -fuss: Firma links oben, Marking fett in Primaerfarbe rechts oben und links unten,
    # Seitenzahl mittig, Blattname rechts unten. Ein & im Text wird zu &&.
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)] $Ci)
    $mark = ''
    if ($Model.Marking) {
        $text = [string]$Model.Marking
        if ($text.Length -gt 80) { $text = $text.Substring(0, 80) }
        $mark = '&B&K' + $Ci.Primary + $text.Replace('&', '&&') + '&B'
    }
    $company = ''
    if ($Model.Company) {
        $company = [string]$Model.Company
        if ($company.Length -gt 80) { $company = $company.Substring(0, 80) }
        $company = $company.Replace('&', '&&')
    }
    $sb = New-Object System.Text.StringBuilder 512
    [void]$sb.Append('<headerFooter>')
    if ($company -or $mark) {
        [void]$sb.Append('<oddHeader>').Append((ConvertTo-XmlText ('&L' + $company + '&R' + $mark))).Append('</oddHeader>')
    }
    $pageText = $L.Page -split '\{[01]\}'
    [void]$sb.Append('<oddFooter>').Append((ConvertTo-XmlText ('&L' + $mark + '&C' + $pageText[0] + '&P' + $pageText[1] + '&N' + $pageText[2] + '&R&A'))).Append('</oddFooter>')
    [void]$sb.Append('</headerFooter>')
    $sb.ToString()
}

function Get-XlsxSheetDataXml {
    # Inhalt von <sheetData>. Zellen ohne Funktionsaufruf je Zelle (Tempo), Strings als inlineStr.
    # Liefert @{ Xml; LastRow }.
    param(
        [Parameter(Mandatory)] $Sheet,
        [string[]] $ColumnName,
        [bool] $HasLogo
    )
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $special = ('<>&"' + [char]39 + (-join [char[]](0..31))).ToCharArray()
    $fmtIndex = @{ Text = 1; Integer = 2; Number = 3; Money = 4; Percent = 5; Date = 6 }
    $styleIndex = @{ Header = 1; Total = 2; Title = 3 }
    $columnCount = $ColumnName.Count - 1
    $rows = @()
    if ($null -ne $Sheet.Rows) { $rows = @($Sheet.Rows) }
    if ($rows.Count -gt 1048576) { throw "Zu viele Zeilen: $($rows.Count)" }
    $sb = New-Object System.Text.StringBuilder 65536
    $lastRow = 0
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $row = $rows[$i]
        if ($null -eq $row) { continue }
        $rs = 0
        if ($row.Style -and $styleIndex.ContainsKey([string]$row.Style)) { $rs = $styleIndex[[string]$row.Style] }
        $cells = @()
        if ($null -ne $row.Cells) { $cells = @($row.Cells) }
        $count = $cells.Count
        # Header- und Total-Zeilen ueber die ganze Breite, damit Fuellung und Linie durchgehen
        if (($rs -eq 1 -or $rs -eq 2) -and $count -lt $columnCount) { $count = $columnCount }
        if ($count -eq 0 -and $rs -ne 3) { continue }
        $rText = [string]($i + 1)
        [void]$sb.Append('<row r="').Append($rText).Append('"')
        if ($rs -eq 3) {
            if ($HasLogo -and $i -eq 0) { [void]$sb.Append(' ht="38" customHeight="1"') } else { [void]$sb.Append(' ht="24" customHeight="1"') }
        }
        [void]$sb.Append('>')
        for ($colIdx = 0; $colIdx -lt $count; $colIdx++) {
            $cell = $null
            if ($colIdx -lt $cells.Count) { $cell = $cells[$colIdx] }
            $v = $null; $f = $null; $fmt = $null; $bold = $false
            if ($cell -is [System.Collections.IDictionary]) { $v = $cell.V; $f = $cell.F; $fmt = $cell.Fmt; $bold = [bool]$cell.Bold }
            elseif ($null -ne $cell) { $v = $cell }
            # Art: 0 leer, 1 Text, 2 Zahl, 3 Wahrheitswert, 4 Datum
            $kind = 0; $text = $null
            if ($null -ne $v) {
                if ($v -is [string]) { $kind = 1; $text = $v }
                elseif ($v -is [datetime]) { $kind = 4 }
                elseif ($v -is [bool]) { $kind = 3; $text = '0'; if ($v) { $text = '1' } }
                elseif ($v -is [double] -or $v -is [single]) {
                    $d = [double]$v
                    if (-not ([double]::IsNaN($d) -or [double]::IsInfinity($d))) { $kind = 2; $text = $d.ToString('R', $inv) }
                }
                elseif ($v -is [int] -or $v -is [long] -or $v -is [decimal] -or $v -is [int16] -or $v -is [byte] -or
                    $v -is [uint16] -or $v -is [uint32] -or $v -is [uint64] -or $v -is [sbyte]) { $kind = 2; $text = $v.ToString($inv) }
                else { $kind = 1; $text = [string]$v }
            }
            $fi = 0
            if ($fmt) { if ($fmtIndex.ContainsKey([string]$fmt)) { $fi = $fmtIndex[[string]$fmt] } }
            elseif ($kind -eq 4) { $fi = 6 }
            if ($kind -eq 4) {
                $serial = $null
                if ($fi -ne 1) { $serial = ConvertTo-XlsxDateSerial -Date $v }
                if ($null -eq $serial) { $kind = 1; $text = $v.ToString($Locale.Date, $inv) }
                else { $kind = 2; $text = ([double]$serial).ToString('R', $inv) }
            }
            # Format Text erzwingt String (z. B. Personalnummer 000123), ausser bei Formeln
            if ($fi -eq 1 -and $kind -eq 2 -and -not $f) { $kind = 1 }
            $xf = (($rs * 7) + $fi) * 2
            if ($bold) { $xf++ }
            $ref = $ColumnName[$colIdx + 1] + $rText
            if ($f) {
                $ft = [string]$f
                if ($ft.StartsWith('=')) { $ft = $ft.Substring(1) }
                [void]$sb.Append('<c r="').Append($ref).Append('"')
                if ($xf -ne 0) { [void]$sb.Append(' s="').Append($xf).Append('"') }
                if ($kind -eq 1) { [void]$sb.Append(' t="str"') } elseif ($kind -eq 3) { [void]$sb.Append(' t="b"') }
                [void]$sb.Append('><f>').Append((ConvertTo-XmlText $ft)).Append('</f>')
                if ($kind -eq 1) { [void]$sb.Append('<v>').Append((ConvertTo-XmlText $text)).Append('</v>') }
                elseif ($kind -ne 0) { [void]$sb.Append('<v>').Append($text).Append('</v>') }
                [void]$sb.Append('</c>')
            }
            elseif ($kind -eq 0) {
                if ($xf -ne 0) { [void]$sb.Append('<c r="').Append($ref).Append('" s="').Append($xf).Append('"/>') }
            }
            elseif ($kind -eq 1) {
                if ($text.Length -gt 32767) { $text = $text.Substring(0, 32767) }
                if ($text.IndexOfAny($special) -ge 0) { $text = ConvertTo-XmlText $text }
                [void]$sb.Append('<c r="').Append($ref).Append('"')
                if ($xf -ne 0) { [void]$sb.Append(' s="').Append($xf).Append('"') }
                [void]$sb.Append(' t="inlineStr"><is><t xml:space="preserve">').Append($text).Append('</t></is></c>')
            }
            else {
                [void]$sb.Append('<c r="').Append($ref).Append('"')
                if ($xf -ne 0) { [void]$sb.Append(' s="').Append($xf).Append('"') }
                if ($kind -eq 3) { [void]$sb.Append(' t="b"') }
                [void]$sb.Append('><v>').Append($text).Append('</v></c>')
            }
        }
        [void]$sb.Append('</row>')
        $lastRow = $i + 1
    }
    @{ Xml = $sb.ToString(); LastRow = $lastRow }
}

function Get-XlsxSheetXml {
    # Ein Arbeitsblatt (xl/worksheets/sheetN.xml) in Schema-Reihenfolge:
    # sheetPr, dimension, sheetViews, cols, sheetData, autoFilter, pageMargins, pageSetup, headerFooter, drawing.
    param(
        [Parameter(Mandatory)] $Sheet,
        [Parameter(Mandatory)] $Model,
        [Parameter(Mandatory)] $Ci,
        [int] $ColumnCount,
        [double[]] $ColumnWidth,
        [bool] $Selected,
        $Filter,
        [bool] $HasLogo
    )
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $names = New-Object 'string[]' ($ColumnCount + 1)
    for ($colIdx = 1; $colIdx -le $ColumnCount; $colIdx++) { $names[$colIdx] = Get-XlsxColumnName -Index $colIdx }
    $data = Get-XlsxSheetDataXml -Sheet $Sheet -ColumnName $names -HasLogo $HasLogo
    $dimension = 'A1'
    if ($data.LastRow -gt 0 -and $ColumnCount -gt 0) { $dimension = 'A1:' + $names[$ColumnCount] + $data.LastRow }
    $sb = New-Object System.Text.StringBuilder ($data.Xml.Length + 4096)
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
    [void]$sb.Append('<sheetPr><tabColor rgb="FF').Append($Ci.Primary).Append('"/><pageSetUpPr fitToPage="1"/></sheetPr>')
    [void]$sb.Append('<dimension ref="').Append($dimension).Append('"/>')
    [void]$sb.Append('<sheetViews><sheetView')
    if ($Selected) { [void]$sb.Append(' tabSelected="1"') }
    [void]$sb.Append(' workbookViewId="0">')
    $freeze = [int]$Sheet.Freeze
    if ($freeze -gt 0 -and $freeze -lt 1048576) {
        $top = 'A' + ($freeze + 1)
        [void]$sb.Append('<pane ySplit="').Append($freeze).Append('" topLeftCell="').Append($top).Append('" activePane="bottomLeft" state="frozen"/>')
        [void]$sb.Append('<selection pane="bottomLeft" activeCell="').Append($top).Append('" sqref="').Append($top).Append('"/>')
    }
    [void]$sb.Append('</sheetView></sheetViews>')
    if ($null -ne $Sheet.Columns) {
        $defs = @($Sheet.Columns)
        $cols = New-Object System.Text.StringBuilder
        for ($i = 0; $i -lt $defs.Count -and $i -lt $ColumnCount; $i++) {
            if ($null -eq $defs[$i] -or $null -eq $defs[$i].Width) { continue }
            [void]$cols.Append('<col min="').Append($i + 1).Append('" max="').Append($i + 1).Append('" width="')
            [void]$cols.Append($ColumnWidth[$i].ToString('R', $inv)).Append('" customWidth="1"/>')
        }
        if ($cols.Length -gt 0) { [void]$sb.Append('<cols>').Append($cols.ToString()).Append('</cols>') }
    }
    if ($data.Xml.Length -gt 0) { [void]$sb.Append('<sheetData>').Append($data.Xml).Append('</sheetData>') } else { [void]$sb.Append('<sheetData/>') }
    if ($null -ne $Filter) {
        [void]$sb.Append('<autoFilter ref="A').Append($Filter.FirstRow).Append(':').Append($Filter.LastColumn).Append($Filter.LastRow).Append('"/>')
    }
    [void]$sb.Append('<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>')
    $total = 0.0
    foreach ($w in $ColumnWidth) { $total += $w }
    $orientation = 'portrait'
    if ($total -gt 100) { $orientation = 'landscape' }
    [void]$sb.Append('<pageSetup paperSize="9" orientation="').Append($orientation).Append('" fitToWidth="1" fitToHeight="0"/>')
    [void]$sb.Append((Get-XlsxHeaderFooterXml -Model $Model -Ci $Ci))
    if ($HasLogo) { [void]$sb.Append('<drawing r:id="rId1"/>') }
    [void]$sb.Append('</worksheet>')
    $sb.ToString()
}

function Get-XlsxDrawingXml {
    # Zeichnung mit dem Logo oben rechts: Hoehe 1,1 cm, rechte Kante an der letzten Spalte.
    param(
        [double[]] $ColumnWidth,
        [int] $LogoWidthPx,
        [int] $LogoHeightPx,
        [string] $Description
    )
    if ($LogoWidthPx -lt 1 -or $LogoHeightPx -lt 1) { $LogoWidthPx = 3; $LogoHeightPx = 1 }
    $cy = 396000
    $cx = [long][Math]::Round($cy * $LogoWidthPx / $LogoHeightPx)
    # Spaltenbreite in Pixel bei 7 px Zifferbreite; Standardspalte 64 px
    $pixel = New-Object 'double[]' $ColumnWidth.Count
    $sum = 0.0
    for ($i = 0; $i -lt $ColumnWidth.Count; $i++) {
        $px = 64.0
        if ($ColumnWidth[$i] -ne 8.43) { $px = [Math]::Truncate(((256 * $ColumnWidth[$i] + 18) / 256) * 7) }
        $pixel[$i] = $px
        $sum += $px
    }
    $start = $sum - ($cx / 9525) - 6
    if ($start -lt 0) { $start = 0 }
    $col = 0
    $acc = 0.0
    while ($col -lt $pixel.Count - 1 -and ($acc + $pixel[$col]) -le $start) { $acc += $pixel[$col]; $col++ }
    $colOff = [long][Math]::Round(($start - $acc) * 9525)
    $sb = New-Object System.Text.StringBuilder 1024
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
    [void]$sb.Append('<xdr:oneCellAnchor><xdr:from><xdr:col>').Append($col).Append('</xdr:col><xdr:colOff>').Append($colOff)
    [void]$sb.Append('</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>38100</xdr:rowOff></xdr:from>')
    [void]$sb.Append('<xdr:ext cx="').Append($cx).Append('" cy="').Append($cy).Append('"/>')
    [void]$sb.Append('<xdr:pic><xdr:nvPicPr><xdr:cNvPr id="2" name="Logo" descr="').Append((ConvertTo-XmlText $Description)).Append('"/>')
    [void]$sb.Append('<xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>')
    [void]$sb.Append('<xdr:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>')
    [void]$sb.Append('<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="').Append($cx).Append('" cy="').Append($cy).Append('"/></a:xfrm>')
    [void]$sb.Append('<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:oneCellAnchor></xdr:wsDr>')
    $sb.ToString()
}

function Get-XlsxWorkbookXml {
    # xl/workbook.xml mit Blattliste, Namen fuer AutoFilter und Drucktitel sowie fullCalcOnLoad.
    # SheetInfo: Liste von @{ Name; Filter; Freeze }.
    param([Parameter(Mandatory)][object[]] $SheetInfo)
    $sb = New-Object System.Text.StringBuilder 2048
    $names = New-Object System.Text.StringBuilder
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
    [void]$sb.Append('<bookViews><workbookView xWindow="240" yWindow="120" windowWidth="28800" windowHeight="15000" activeTab="0"/></bookViews>')
    [void]$sb.Append('<sheets>')
    for ($i = 0; $i -lt $SheetInfo.Count; $i++) {
        $info = $SheetInfo[$i]
        [void]$sb.Append('<sheet name="').Append((ConvertTo-XmlText $info.Name)).Append('" sheetId="').Append($i + 1)
        [void]$sb.Append('" r:id="rId').Append($i + 1).Append('"/>')
        $quoted = "'" + $info.Name.Replace("'", "''") + "'!"
        if ($null -ne $info.Filter) {
            $range = $quoted + '$A$' + $info.Filter.FirstRow + ':$' + $info.Filter.LastColumn + '$' + $info.Filter.LastRow
            [void]$names.Append('<definedName name="_xlnm._FilterDatabase" localSheetId="').Append($i).Append('" hidden="1">')
            [void]$names.Append((ConvertTo-XmlText $range)).Append('</definedName>')
        }
        if ($info.Freeze -gt 0 -and $info.Freeze -lt 1048576) {
            $range = $quoted + '$1:$' + $info.Freeze
            [void]$names.Append('<definedName name="_xlnm.Print_Titles" localSheetId="').Append($i).Append('">')
            [void]$names.Append((ConvertTo-XmlText $range)).Append('</definedName>')
        }
    }
    [void]$sb.Append('</sheets>')
    if ($names.Length -gt 0) { [void]$sb.Append('<definedNames>').Append($names.ToString()).Append('</definedNames>') }
    [void]$sb.Append('<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>')
    $sb.ToString()
}

function Get-XlsxRelationshipXml {
    # .rels-Teil; Target und Type als parallele Listen, Ids fortlaufend ab rId1.
    param([Parameter(Mandatory)][string[]] $Type, [Parameter(Mandatory)][string[]] $Target)
    $sb = New-Object System.Text.StringBuilder 1024
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    for ($i = 0; $i -lt $Type.Count; $i++) {
        [void]$sb.Append('<Relationship Id="rId').Append($i + 1).Append('" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/')
        [void]$sb.Append($Type[$i]).Append('" Target="').Append($Target[$i]).Append('"/>')
    }
    [void]$sb.Append('</Relationships>')
    $sb.ToString()
}

function Get-XlsxContentTypeXml {
    # [Content_Types].xml; Vorlage (.xltx) mit template.main+xml statt sheet.main+xml.
    param([int] $SheetCount, [int] $DrawingCount, [bool] $Template, [bool] $HasCustom)
    $main = 'sheet.main+xml'
    if ($Template) { $main = 'template.main+xml' }
    $ns = 'application/vnd.openxmlformats-officedocument.'
    $sb = New-Object System.Text.StringBuilder 2048
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
    [void]$sb.Append('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
    [void]$sb.Append('<Default Extension="xml" ContentType="application/xml"/>')
    if ($DrawingCount -gt 0) { [void]$sb.Append('<Default Extension="png" ContentType="image/png"/>') }
    [void]$sb.Append('<Override PartName="/xl/workbook.xml" ContentType="').Append($ns).Append('spreadsheetml.').Append($main).Append('"/>')
    for ($i = 1; $i -le $SheetCount; $i++) {
        [void]$sb.Append('<Override PartName="/xl/worksheets/sheet').Append($i).Append('.xml" ContentType="').Append($ns).Append('spreadsheetml.worksheet+xml"/>')
    }
    for ($i = 1; $i -le $DrawingCount; $i++) {
        [void]$sb.Append('<Override PartName="/xl/drawings/drawing').Append($i).Append('.xml" ContentType="').Append($ns).Append('drawing+xml"/>')
    }
    [void]$sb.Append('<Override PartName="/xl/styles.xml" ContentType="').Append($ns).Append('spreadsheetml.styles+xml"/>')
    [void]$sb.Append('<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>')
    [void]$sb.Append('<Override PartName="/docProps/app.xml" ContentType="').Append($ns).Append('extended-properties+xml"/>')
    if ($HasCustom) { [void]$sb.Append('<Override PartName="/docProps/custom.xml" ContentType="').Append($ns).Append('custom-properties+xml"/>') }
    [void]$sb.Append('</Types>')
    $sb.ToString()
}

function Write-XlsxFile {
    # Schreibt eine Arbeitsmappe nach Path (.xlsx, mit Model.Template = $true als Vorlage .xltx).
    # Logo (Ci.LogoPng) erscheint oben rechts auf jedem Blatt, dessen erste Zeile den Stil Title hat.
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][System.Collections.IDictionary] $Model
    )
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $ci = Get-XlsxCiSetting -Model $Model
    $sheets = New-Object System.Collections.ArrayList
    if ($null -ne $Model.Sheets) {
        foreach ($s in @($Model.Sheets)) { if ($null -ne $s) { [void]$sheets.Add($s) } }
    }
    if ($sheets.Count -eq 0) { [void]$sheets.Add(@{ Name = ($Office.Sheet + '1'); Rows = @() }) }
    $logo = $null
    $logoW = 0
    $logoH = 0
    if ($null -ne $Model.Ci -and $null -ne $Model.Ci.LogoPng) {
        $logo = [byte[]]$Model.Ci.LogoPng
        $logoW = [int]$Model.Ci.LogoWidthPx
        $logoH = [int]$Model.Ci.LogoHeightPx
    }
    $used = @{}
    $infos = New-Object System.Collections.ArrayList
    $drawingCount = 0
    for ($i = 0; $i -lt $sheets.Count; $i++) {
        $sheet = $sheets[$i]
        $count = Get-XlsxColumnCount -Sheet $sheet
        $drawing = 0
        if ($null -ne $logo -and $null -ne $sheet.Rows) {
            $first = @($sheet.Rows)[0]
            if ($null -ne $first -and [string]$first.Style -eq 'Title') { $drawingCount++; $drawing = $drawingCount }
        }
        [void]$infos.Add(@{
                Name        = (Get-XlsxSheetName -Name ([string]$sheet.Name) -Index ($i + 1) -Used $used)
                Sheet       = $sheet
                ColumnCount = $count
                Width       = (Get-XlsxColumnWidth -Sheet $sheet -ColumnCount $count)
                Filter      = (Get-XlsxFilterRange -Sheet $sheet -ColumnCount $count)
                Freeze      = [int]$sheet.Freeze
                Drawing     = $drawing
            })
    }
    $hasCustom = [bool]$Model.Classification
    $date = [datetime]'2020-01-01'
    if ($Model.Modified -is [datetime]) { $date = $Model.Modified }
    $relType = New-Object System.Collections.ArrayList
    $relTarget = New-Object System.Collections.ArrayList
    for ($i = 1; $i -le $infos.Count; $i++) { [void]$relType.Add('worksheet'); [void]$relTarget.Add('worksheets/sheet' + $i + '.xml') }
    [void]$relType.Add('styles')
    [void]$relTarget.Add('styles.xml')
    $package = Open-ZipPackage -Path $full
    $ok = $false
    try {
        $zip = $package.Zip
        Add-ZipEntry -Zip $zip -Name '[Content_Types].xml' -Date $date -Content (Get-XlsxContentTypeXml -SheetCount $infos.Count -DrawingCount $drawingCount -Template ([bool]$Model.Template) -HasCustom $hasCustom)
        Add-ZipEntry -Zip $zip -Name '_rels/.rels' -Date $date -Content (Get-OoxmlPackageRelationship -MainPart 'xl/workbook.xml' -HasCustom $hasCustom)
        Add-ZipEntry -Zip $zip -Name 'docProps/core.xml' -Date $date -Content (Get-OoxmlCoreXml -Model $Model)
        Add-ZipEntry -Zip $zip -Name 'docProps/app.xml' -Date $date -Content (Get-OoxmlAppXml -Model $Model -Application 'Microsoft Excel')
        if ($hasCustom) { Add-ZipEntry -Zip $zip -Name 'docProps/custom.xml' -Date $date -Content (Get-OoxmlCustomXml -Model $Model) }
        Add-ZipEntry -Zip $zip -Name 'xl/workbook.xml' -Date $date -Content (Get-XlsxWorkbookXml -SheetInfo $infos.ToArray())
        Add-ZipEntry -Zip $zip -Name 'xl/_rels/workbook.xml.rels' -Date $date -Content (Get-XlsxRelationshipXml -Type $relType.ToArray() -Target $relTarget.ToArray())
        Add-ZipEntry -Zip $zip -Name 'xl/styles.xml' -Date $date -Content (Get-XlsxStyleXml -Ci $ci)
        for ($i = 0; $i -lt $infos.Count; $i++) {
            $info = $infos[$i]
            $n = $i + 1
            $xml = Get-XlsxSheetXml -Sheet $info.Sheet -Model $Model -Ci $ci -ColumnCount $info.ColumnCount -ColumnWidth $info.Width -Selected ($i -eq 0) -Filter $info.Filter -HasLogo ($info.Drawing -gt 0)
            Add-ZipEntry -Zip $zip -Name ('xl/worksheets/sheet' + $n + '.xml') -Date $date -Content $xml
            if ($info.Drawing -gt 0) {
                $d = $info.Drawing
                Add-ZipEntry -Zip $zip -Name ('xl/worksheets/_rels/sheet' + $n + '.xml.rels') -Date $date -Content (Get-XlsxRelationshipXml -Type 'drawing' -Target ('../drawings/drawing' + $d + '.xml'))
                Add-ZipEntry -Zip $zip -Name ('xl/drawings/drawing' + $d + '.xml') -Date $date -Content (Get-XlsxDrawingXml -ColumnWidth $info.Width -LogoWidthPx $logoW -LogoHeightPx $logoH -Description ('Logo ' + [string]$Model.Company))
                Add-ZipEntry -Zip $zip -Name ('xl/drawings/_rels/drawing' + $d + '.xml.rels') -Date $date -Content (Get-XlsxRelationshipXml -Type 'image' -Target '../media/image1.png')
            }
        }
        if ($drawingCount -gt 0) { Add-ZipEntry -Zip $zip -Name 'xl/media/image1.png' -Date $date -Content $logo }
        $ok = $true
    }
    finally {
        Close-ZipPackage -Package $package
        if (-not $ok) { Remove-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue }
    }
}

#endregion
#region PPTX (PresentationML)

# Schreiber fuer .pptx und .potx. Setzt 00-ooxml-common.ps1 voraus.
# Masse in EMU (1 cm = 360000 EMU), Schriftgroessen in 1/100 pt, Farben als RRGGBB.

function Get-PptxNamespace {
    # Namensraum-Deklarationen fuer die Wurzelelemente der PresentationML-Teile.
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
}

function Get-PptxXfrmXml {
    # Position und Groesse einer Form.
    param([long] $X, [long] $Y, [long] $Cx, [long] $Cy)
    '<a:xfrm><a:off x="{0}" y="{1}"/><a:ext cx="{2}" cy="{3}"/></a:xfrm>' -f $X, $Y, $Cx, $Cy
}

function Get-PptxTreeStartXml {
    # Pflichtkopf eines spTree (nvGrpSpPr, grpSpPr); die Formen folgen danach.
    '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
}

function Get-PptxRelationshipXml {
    # .rels-Teil aus einer Liste von @(Id, Typ, Ziel); Typ = letzter Teil der Beziehungs-URI.
    param($Relation)
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    foreach ($rel in $Relation) {
        [void]$sb.Append(('<Relationship Id="{0}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/{1}" Target="{2}"/>' -f $rel[0], $rel[1], $rel[2]))
    }
    [void]$sb.Append('</Relationships>')
    $sb.ToString()
}

function Get-PptxTintColor {
    # Hellt eine Farbe @(r,g,b) zu Weiss hin auf (Anteil 0..1) und liefert RRGGBB.
    param([int[]] $Rgb, [double] $Share)
    $mix = foreach ($part in $Rgb[0..2]) { [int][Math]::Round($part + (255 - $part) * $Share) }
    Get-HexColor -Rgb $mix
}

function Get-PptxColorSet {
    # Farben und Schriften aus Ci, mit neutralen Vorgaben fuer fehlende Werte.
    param($Ci)
    if (-not $Ci) { $Ci = @{} }
    $primary = if ($Ci.Primary) { [int[]]$Ci.Primary } else { [int[]](31, 78, 121) }
    $accent = if ($Ci.Accent) { [int[]]$Ci.Accent } else { [int[]](237, 125, 49) }
    $light = if ($Ci.Light) { [int[]]$Ci.Light } else { [int[]](242, 242, 242) }
    $dark = if ($Ci.Dark) { [int[]]$Ci.Dark } else { [int[]](38, 38, 38) }
    $font = if ($Ci.Font) { [string]$Ci.Font } else { 'Calibri' }
    $titleFont = if ($Ci.TitleFont) { [string]$Ci.TitleFont } else { $font }
    @{
        Primary     = Get-HexColor -Rgb $primary
        Accent      = Get-HexColor -Rgb $accent
        Light       = Get-HexColor -Rgb $light
        Dark        = Get-HexColor -Rgb $dark
        PrimaryTint = Get-PptxTintColor -Rgb $primary -Share 0.4
        AccentTint  = Get-PptxTintColor -Rgb $accent -Share 0.4
        DarkTint    = Get-PptxTintColor -Rgb $dark -Share 0.5
        Font        = $font
        TitleFont   = $titleFont
    }
}

function Get-PptxImageSize {
    # Pixelmasse aus dem Modell, sonst aus dem PNG- bzw. JPEG-Kopf; Rueckgabe @(Breite, Hoehe).
    param([byte[]] $Bytes, $WidthPx, $HeightPx)
    if ([int]$WidthPx -gt 0 -and [int]$HeightPx -gt 0) { return @([int]$WidthPx, [int]$HeightPx) }
    $b = $Bytes
    if ($b.Length -gt 24 -and $b[0] -eq 0x89 -and $b[1] -eq 0x50) {
        $pw = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
        $ph = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
        if ($pw -gt 0 -and $ph -gt 0) { return @($pw, $ph) }
    }
    if ($b.Length -gt 4 -and $b[0] -eq 0xFF -and $b[1] -eq 0xD8) {
        $i = 2
        while ($i + 8 -lt $b.Length) {
            if ($b[$i] -ne 0xFF) { $i++; continue }
            $marker = [int]$b[$i + 1]
            if ($marker -eq 0xFF) { $i++; continue }
            if ($marker -eq 0x01 -or ($marker -ge 0xD0 -and $marker -le 0xD9)) { $i += 2; continue }
            if ($marker -ge 0xC0 -and $marker -le 0xCF -and $marker -ne 0xC4 -and $marker -ne 0xC8 -and $marker -ne 0xCC) {
                return @(([int]$b[$i + 7] * 256 + [int]$b[$i + 8]), ([int]$b[$i + 5] * 256 + [int]$b[$i + 6]))
            }
            $i += 2 + [int]$b[$i + 2] * 256 + [int]$b[$i + 3]
        }
    }
    @(4, 3)
}

function Get-PptxImageExtension {
    # Dateiendung in ppt/media; der Content-Type ist image/<Endung>.
    param([string] $Format)
    if ($Format -match '^jpe?g$') { return 'jpeg' }
    if ($Format -eq 'gif') { return 'gif' }
    'png'
}

function Get-PptxGeometry {
    # Foliengroesse (16:9 oder 4:3) und Lage der wiederkehrenden Elemente.
    param([bool] $Wide, $Ci)
    $w = [long]9144000
    if ($Wide) { $w = [long]12192000 }
    $h = [long]6858000
    $m = [long]540000
    $logoH = [long]468000
    $logoW = [long]0
    if ($Ci -and $Ci.LogoPng) {
        $size = Get-PptxImageSize -Bytes $Ci.LogoPng -WidthPx $Ci.LogoWidthPx -HeightPx $Ci.LogoHeightPx
        $logoW = [long][Math]::Round($logoH * [double]$size[0] / [double]$size[1])
    }
    $titleCx = $w - 2 * $m
    if ($logoW -gt 0) { $titleCx = $titleCx - $logoW - 180000 }
    $bodyY = [long]1584000
    $bodyCx = $w - 2 * $m
    $gap = [long]360000
    $halfCx = [long][Math]::Floor(($bodyCx - $gap) / 2)
    @{
        W = $w; H = $h; M = $m; Bar = [long]108000
        LogoW = $logoW; LogoH = $logoH; LogoX = $w - $m - $logoW; LogoY = [long]288000
        TitleY = [long]252000; TitleCx = $titleCx; TitleCy = [long]1008000; LineY = [long]1332000
        BodyY = $bodyY; BodyCx = $bodyCx; BodyCy = $h - $bodyY - 900000
        HalfCx = $halfCx; ImgX = $m + $halfCx + $gap
        FootY = $h - 576000; FootCy = [long]324000; BandCy = [long]4536000; FullBar = [long]1620000
    }
}

function Get-PptxImageFit {
    # Passt ein Bild in einen Rahmen ein: ohne Cover ganz sichtbar und zentriert, mit Cover
    # rahmenfuellend mit Zuschnitt (srcRect in 1/1000 Prozent). Seitenverhaeltnis bleibt erhalten.
    # Top = oben buendig statt vertikal zentriert.
    param([double] $ImgW, [double] $ImgH, [long] $X, [long] $Y, [long] $Cx, [long] $Cy, [bool] $Cover = $false, [bool] $Top = $false)
    $fit = @{ X = $X; Y = $Y; Cx = $Cx; Cy = $Cy; SrcRect = '' }
    if ($ImgW -le 0 -or $ImgH -le 0 -or $Cx -le 0 -or $Cy -le 0) { return $fit }
    $imgRatio = $ImgW / $ImgH
    $boxRatio = [double]$Cx / [double]$Cy
    if ($Cover) {
        if ($imgRatio -gt $boxRatio) {
            $fit.SrcRect = '<a:srcRect l="{0}" r="{0}"/>' -f [int][Math]::Floor((1 - $boxRatio / $imgRatio) * 50000)
        } elseif ($imgRatio -lt $boxRatio) {
            $fit.SrcRect = '<a:srcRect t="{0}" b="{0}"/>' -f [int][Math]::Floor((1 - $imgRatio / $boxRatio) * 50000)
        }
        return $fit
    }
    if ($imgRatio -gt $boxRatio) {
        $fitCy = [long][Math]::Floor($Cx / $imgRatio)
        if (-not $Top) { $fit.Y = $Y + [long][Math]::Floor(($Cy - $fitCy) / 2) }
        $fit.Cy = $fitCy
    } else {
        $fitCx = [long][Math]::Floor($Cy * $imgRatio)
        $fit.X = $X + [long][Math]::Floor(($Cx - $fitCx) / 2)
        $fit.Cx = $fitCx
    }
    $fit
}

function Get-PptxRunXml {
    # Textlauf; Size in 1/100 pt (0 = geerbt), Color als RRGGBB (leer = geerbt).
    param([string] $Text, [int] $Size = 0, [bool] $Bold = $false, [string] $Color = '')
    $attr = 'lang="' + $Locale.Culture + '"'
    if ($Size -gt 0) { $attr = $attr + ' sz="' + $Size + '"' }
    if ($Bold) { $attr = $attr + ' b="1"' }
    $rpr = '<a:rPr ' + $attr + ' dirty="0"/>'
    if ($Color) { $rpr = '<a:rPr ' + $attr + ' dirty="0"><a:solidFill><a:srgbClr val="' + $Color + '"/></a:solidFill></a:rPr>' }
    '<a:r>' + $rpr + '<a:t>' + (ConvertTo-XmlText $Text) + '</a:t></a:r>'
}

function Get-PptxParagraphXml {
    # Absatz; Zeilenumbrueche im Text werden zu a:br. Level 0..4, NoBullet ohne Aufzaehlungszeichen.
    param([string] $Text, [string] $Align = '', [bool] $NoBullet = $false, [int] $Level = 0,
        [int] $Size = 0, [bool] $Bold = $false, [string] $Color = '')
    $attr = ''
    if ($NoBullet) { $attr = ' marL="0" indent="0"' }
    if ($Level -gt 0) { $attr = $attr + ' lvl="' + $Level + '"' }
    if ($Align) { $attr = $attr + ' algn="' + $Align + '"' }
    $ppr = ''
    if ($NoBullet) { $ppr = '<a:pPr' + $attr + '><a:buNone/></a:pPr>' } elseif ($attr) { $ppr = '<a:pPr' + $attr + '/>' }
    $lang = 'lang="' + $Locale.Culture + '"'
    $end = '<a:endParaRPr ' + $lang + ' dirty="0"/>'
    if ($Size -gt 0) { $end = '<a:endParaRPr ' + $lang + ' sz="' + $Size + '" dirty="0"/>' }
    if (-not $Text) { return '<a:p>' + $ppr + $end + '</a:p>' }
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('<a:p>').Append($ppr)
    $first = $true
    foreach ($line in ($Text -split "`r?`n")) {
        if (-not $first) { [void]$sb.Append('<a:br><a:rPr ' + $lang + ' dirty="0"/></a:br>') }
        $first = $false
        if ($line) { [void]$sb.Append((Get-PptxRunXml -Text $line -Size $Size -Bold $Bold -Color $Color)) }
    }
    [void]$sb.Append($end).Append('</a:p>')
    $sb.ToString()
}

function Get-PptxBodyParagraphXml {
    # Absaetze aus Fliesstext (je Zeile ein Absatz ohne Aufzaehlung) und Aufzaehlungspunkten.
    param([string] $Text, $Bullets, [string] $Align = '', [bool] $BulletsAsText = $false)
    $sb = [Text.StringBuilder]::new()
    if ($Text) {
        foreach ($line in ($Text -split "`r?`n")) { [void]$sb.Append((Get-PptxParagraphXml -Text $line -NoBullet $true -Align $Align)) }
    }
    foreach ($item in @($Bullets)) {
        if ($null -eq $item -or [string]$item -eq '') { continue }
        [void]$sb.Append((Get-PptxParagraphXml -Text ([string]$item) -NoBullet $BulletsAsText -Align $Align))
    }
    $sb.ToString()
}

function Get-PptxLstStyleXml {
    # Abweichender Stil der ersten Ebene eines Platzhalters (Groesse, Farbe, Ausrichtung).
    param([int] $Size, [string] $Color = '', [string] $Align = 'l', [bool] $NoBullet = $false)
    $ppr = '<a:lvl1pPr algn="' + $Align + '">'
    if ($NoBullet) { $ppr = '<a:lvl1pPr marL="0" indent="0" algn="' + $Align + '"><a:buNone/>' }
    $fill = ''
    if ($Color) { $fill = '<a:solidFill><a:srgbClr val="' + $Color + '"/></a:solidFill>' }
    '<a:lstStyle>' + $ppr + '<a:defRPr sz="' + $Size + '">' + $fill + '</a:defRPr></a:lvl1pPr></a:lstStyle>'
}

function Get-PptxPlaceholderXml {
    # Platzhalter (p:sp mit p:ph). SpPr leer = Lage vom Layout bzw. Master geerbt.
    param([int] $Id, [string] $Name, [string] $PhType = '', [int] $PhIdx = -1, [string] $SpPr = '',
        [string] $BodyPr = '<a:bodyPr/>', [string] $LstStyle = '<a:lstStyle/>', [string] $Paragraphs = '')
    $ph = '<p:ph'
    if ($PhType) { $ph = $ph + ' type="' + $PhType + '"' }
    if ($PhIdx -ge 0) { $ph = $ph + ' idx="' + $PhIdx + '"' }
    $spPrXml = '<p:spPr/>'
    if ($SpPr) { $spPrXml = '<p:spPr>' + $SpPr + '</p:spPr>' }
    if (-not $Paragraphs) { $Paragraphs = '<a:p><a:endParaRPr lang="' + $Locale.Culture + '" dirty="0"/></a:p>' }
    ('<p:sp><p:nvSpPr><p:cNvPr id="{0}" name="{1}"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr>{2}/></p:nvPr></p:nvSpPr>' -f $Id, (ConvertTo-XmlText $Name), $ph) +
    $spPrXml + '<p:txBody>' + $BodyPr + $LstStyle + $Paragraphs + '</p:txBody></p:sp>'
}

function Get-PptxRectXml {
    # Rechteck ohne Text (Balken, Flaeche); Alpha 100000 = deckend.
    param([int] $Id, [string] $Name, [long] $X, [long] $Y, [long] $Cx, [long] $Cy, [string] $Color,
        [int] $Alpha = 100000, [bool] $UserDrawn = $true)
    $nvPr = '<p:nvPr/>'
    if ($UserDrawn) { $nvPr = '<p:nvPr userDrawn="1"/>' }
    $clr = '<a:srgbClr val="' + $Color + '"/>'
    if ($Alpha -lt 100000) { $clr = '<a:srgbClr val="' + $Color + '"><a:alpha val="' + $Alpha + '"/></a:srgbClr>' }
    ('<p:sp><p:nvSpPr><p:cNvPr id="{0}" name="{1}"/><p:cNvSpPr/>{2}</p:nvSpPr><p:spPr>' -f $Id, (ConvertTo-XmlText $Name), $nvPr) +
    (Get-PptxXfrmXml -X $X -Y $Y -Cx $Cx -Cy $Cy) +
    '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill>' + $clr + '</a:solidFill><a:ln><a:noFill/></a:ln></p:spPr></p:sp>'
}

function Get-PptxTextBoxXml {
    # Textfeld ohne Fuellung; Paragraphs sind fertige a:p-Elemente.
    param([int] $Id, [string] $Name, [long] $X, [long] $Y, [long] $Cx, [long] $Cy, [string] $Paragraphs,
        [string] $Anchor = 'ctr', [long] $Inset = 0, [bool] $UserDrawn = $true)
    $nvPr = '<p:nvPr/>'
    if ($UserDrawn) { $nvPr = '<p:nvPr userDrawn="1"/>' }
    ('<p:sp><p:nvSpPr><p:cNvPr id="{0}" name="{1}"/><p:cNvSpPr txBox="1"/>{2}</p:nvSpPr><p:spPr>' -f $Id, (ConvertTo-XmlText $Name), $nvPr) +
    (Get-PptxXfrmXml -X $X -Y $Y -Cx $Cx -Cy $Cy) + '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>' +
    ('<p:txBody><a:bodyPr wrap="square" lIns="{0}" tIns="0" rIns="{0}" bIns="0" rtlCol="0" anchor="{1}"><a:noAutofit/></a:bodyPr><a:lstStyle/>' -f $Inset, $Anchor) +
    $Paragraphs + '</p:txBody></p:sp>'
}

function Get-PptxPictureXml {
    # Bild (p:pic) mit Verweis auf ppt/media; SrcRect optional fuer den Zuschnitt.
    param([int] $Id, [string] $Name, [string] $RelId, [long] $X, [long] $Y, [long] $Cx, [long] $Cy,
        [string] $SrcRect = '', [bool] $UserDrawn = $false, [string] $Descr = '')
    $nvPr = '<p:nvPr/>'
    if ($UserDrawn) { $nvPr = '<p:nvPr userDrawn="1"/>' }
    $descrAttr = ''
    if ($Descr) { $descrAttr = ' descr="' + (ConvertTo-XmlText $Descr) + '"' }
    ('<p:pic><p:nvPicPr><p:cNvPr id="{0}" name="{1}"{2}/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>{3}</p:nvPicPr>' -f $Id, (ConvertTo-XmlText $Name), $descrAttr, $nvPr) +
    ('<p:blipFill><a:blip r:embed="{0}"/>{1}<a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr>' -f $RelId, $SrcRect) +
    (Get-PptxXfrmXml -X $X -Y $Y -Cx $Cx -Cy $Cy) + '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>'
}

function Get-PptxLevelXml {
    # Eine Ebene (lvlNpPr) eines Textstils; Font 'mj' = Titelschrift, 'mn' = Textschrift.
    param([string] $Tag, [long] $MarL = 0, [long] $Indent = 0, [int] $Size = 1800, [string] $Bullet = '',
        [string] $BulletColor = '', [string] $Color = '<a:schemeClr val="tx1"/>', [string] $Font = 'mn',
        [int] $SpaceBefore = 0, [int] $LineSpacing = 100000)
    $bu = '<a:buNone/>'
    if ($Bullet) {
        $bu = '<a:buClr><a:srgbClr val="' + $BulletColor + '"/></a:buClr><a:buFont typeface="Arial" panose="020B0604020202020204" pitchFamily="34" charset="0"/><a:buChar char="' + $Bullet + '"/>'
    }
    ('<a:{0} marL="{1}" indent="{2}" algn="l" defTabSz="914400" rtl="0" eaLnBrk="1" latinLnBrk="0" hangingPunct="1"><a:lnSpc><a:spcPct val="{3}"/></a:lnSpc><a:spcBef><a:spcPts val="{4}"/></a:spcBef>' -f $Tag, $MarL, $Indent, $LineSpacing, $SpaceBefore) +
    $bu + ('<a:defRPr sz="{0}" kern="1200"><a:solidFill>{1}</a:solidFill><a:latin typeface="+{2}-lt"/><a:ea typeface="+{2}-ea"/><a:cs typeface="+{2}-cs"/></a:defRPr></a:{3}>' -f $Size, $Color, $Font, $Tag)
}

function Get-PptxTextStyleXml {
    # txStyles des Masters: Titel in Primary und Titelschrift, Text in Dark, Aufzaehlungszeichen in Accent.
    param([Parameter(Mandatory)] $Color)
    $dot = [string][char]0x2022
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('<p:txStyles><p:titleStyle>')
    [void]$sb.Append((Get-PptxLevelXml -Tag 'lvl1pPr' -Size 3000 -Color ('<a:srgbClr val="' + $Color.Primary + '"/>') -Font 'mj' -LineSpacing 90000))
    [void]$sb.Append('</p:titleStyle><p:bodyStyle>')
    $sizes = @(2000, 1800, 1600, 1400, 1400)
    for ($i = 0; $i -lt 5; $i++) {
        [void]$sb.Append((Get-PptxLevelXml -Tag ('lvl{0}pPr' -f ($i + 1)) -MarL (228600 + 457200 * $i) -Indent -228600 -Size $sizes[$i] -Bullet $dot -BulletColor $Color.Accent -SpaceBefore 900))
    }
    [void]$sb.Append('</p:bodyStyle><p:otherStyle><a:defPPr><a:defRPr lang="' + $Locale.Culture + '"/></a:defPPr>')
    [void]$sb.Append((Get-PptxLevelXml -Tag 'lvl1pPr' -Size 1800))
    [void]$sb.Append('</p:otherStyle></p:txStyles>')
    $sb.ToString()
}

function Get-PptxThemeXml {
    # Theme: Farbschema (dk1 = Dark, lt1 = Weiss, Akzente Primary/Accent) und Schriften aus der CI.
    param([Parameter(Mandatory)] $Color, [string] $Name = 'CI')
    $n = ConvertTo-XmlText $Name
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="' + $n + '"><a:themeElements><a:clrScheme name="' + $n + '">')
    $slots = @(
        @('dk1', $Color.Dark), @('lt1', 'FFFFFF'), @('dk2', $Color.Primary), @('lt2', $Color.Light),
        @('accent1', $Color.Primary), @('accent2', $Color.Accent), @('accent3', $Color.PrimaryTint),
        @('accent4', $Color.AccentTint), @('accent5', $Color.Dark), @('accent6', $Color.DarkTint),
        @('hlink', $Color.Primary), @('folHlink', $Color.Accent))
    foreach ($slot in $slots) { [void]$sb.Append(('<a:{0}><a:srgbClr val="{1}"/></a:{0}>' -f $slot[0], $slot[1])) }
    [void]$sb.Append('</a:clrScheme><a:fontScheme name="' + $n + '">')
    [void]$sb.Append(('<a:majorFont><a:latin typeface="{0}"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="{1}"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>' -f (ConvertTo-XmlText $Color.TitleFont), (ConvertTo-XmlText $Color.Font)))
    [void]$sb.Append('<a:fmtScheme name="' + $n + '"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:tint val="50000"/></a:schemeClr></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:shade val="80000"/></a:schemeClr></a:solidFill></a:fillStyleLst><a:lnStyleLst>')
    foreach ($width in @(6350, 12700, 19050)) {
        [void]$sb.Append(('<a:ln w="{0}" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>' -f $width))
    }
    [void]$sb.Append('</a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>')
    [void]$sb.Append('<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:tint val="95000"/></a:schemeClr></a:solidFill><a:solidFill><a:schemeClr val="phClr"><a:shade val="90000"/></a:schemeClr></a:solidFill></a:bgFillStyleLst>')
    [void]$sb.Append('</a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>')
    $sb.ToString()
}

function Get-PptxClrMapXml {
    # Standard-Farbzuordnung fuer Folien- und Notizenmaster.
    '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
}

function Get-PptxMasterXml {
    # Folienmaster: weisser Hintergrund, Akzentbalken in Primary, Logo oben rechts, Fusszeile mit
    # Firma und Kennzeichnung. Layout-IDs ab 2147483649 (Master-ID 2147483648), Beziehungen rId1..n.
    param([Parameter(Mandatory)] $Geometry, [Parameter(Mandatory)] $Color, [int] $LayoutCount,
        [string] $LogoRelId = '', [string] $Company = '', [string] $Marking = '')
    $g = $Geometry
    $geom = '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster ' + (Get-PptxNamespace) + '><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>')
    [void]$sb.Append((Get-PptxTreeStartXml))
    $xfrm = Get-PptxXfrmXml -X $g.M -Y $g.TitleY -Cx $g.TitleCx -Cy $g.TitleCy
    [void]$sb.Append((Get-PptxPlaceholderXml -Id 2 -Name ($Office.TitlePlaceholder + ' 1') -PhType 'title' -SpPr ($xfrm + $geom) `
                -BodyPr '<a:bodyPr vert="horz" lIns="0" tIns="45720" rIns="0" bIns="45720" rtlCol="0" anchor="b"><a:normAutofit/></a:bodyPr>' `
                -Paragraphs (Get-PptxParagraphXml -Text $Office.MasterTitle)))
    $levels = @($Office.MasterText) + @($Office.Levels)
    $paras = [Text.StringBuilder]::new()
    for ($i = 0; $i -lt $levels.Count; $i++) { [void]$paras.Append((Get-PptxParagraphXml -Text $levels[$i] -Level $i)) }
    $xfrm = Get-PptxXfrmXml -X $g.M -Y $g.BodyY -Cx $g.BodyCx -Cy $g.BodyCy
    [void]$sb.Append((Get-PptxPlaceholderXml -Id 3 -Name ($Office.TextPlaceholder + ' 2') -PhType 'body' -PhIdx 1 -SpPr ($xfrm + $geom) `
                -BodyPr '<a:bodyPr vert="horz" lIns="0" tIns="45720" rIns="0" bIns="45720" rtlCol="0"><a:normAutofit/></a:bodyPr>' `
                -Paragraphs $paras.ToString()))
    [void]$sb.Append((Get-PptxRectXml -Id 4 -Name $Office.AccentBar -X 0 -Y 0 -Cx $g.W -Cy $g.Bar -Color $Color.Primary))
    if ($LogoRelId -and $g.LogoW -gt 0) {
        [void]$sb.Append((Get-PptxPictureXml -Id 5 -Name 'Logo' -RelId $LogoRelId -X $g.LogoX -Y $g.LogoY -Cx $g.LogoW -Cy $g.LogoH -UserDrawn $true -Descr 'Logo'))
    }
    $half = [long][Math]::Floor(($g.W - 2 * $g.M) / 2)
    if ($Company) {
        [void]$sb.Append((Get-PptxTextBoxXml -Id 6 -Name $Office.FooterCompany -X $g.M -Y $g.FootY -Cx $half -Cy $g.FootCy `
                    -Paragraphs (Get-PptxParagraphXml -Text $Company -Size 1000 -Color $Color.Dark)))
    }
    if ($Marking) {
        [void]$sb.Append((Get-PptxTextBoxXml -Id 7 -Name $Office.Marking -X ($g.M + $half) -Y $g.FootY -Cx $half -Cy $g.FootCy `
                    -Paragraphs (Get-PptxParagraphXml -Text $Marking -Align 'r' -Size 1000 -Bold $true -Color $Color.Primary)))
    }
    [void]$sb.Append('</p:spTree></p:cSld>').Append((Get-PptxClrMapXml)).Append('<p:sldLayoutIdLst>')
    for ($i = 1; $i -le $LayoutCount; $i++) {
        [void]$sb.Append(('<p:sldLayoutId id="{0}" r:id="rId{1}"/>' -f (2147483648 + $i), $i))
    }
    [void]$sb.Append('</p:sldLayoutIdLst>').Append((Get-PptxTextStyleXml -Color $Color)).Append('</p:sldMaster>')
    $sb.ToString()
}

function Get-PptxLayoutName {
    # Normalisiert den Layoutnamen aus dem Modell; Unbekanntes wird 'Content'.
    param([string] $Name)
    foreach ($known in @('Title', 'Content', 'ImageRight', 'ImageFull', 'Section', 'Closing')) {
        if ($known -eq $Name) { return $known }
    }
    'Content'
}

function Get-PptxLayoutXml {
    # Folienlayout; LogoRelId nur fuer 'Title' (eigenes Logo, da Masterformen ausgeblendet).
    param([Parameter(Mandatory)][string] $Layout, [Parameter(Mandatory)] $Geometry, [Parameter(Mandatory)] $Color,
        [string] $LogoRelId = '', [string] $Company = '', [string] $Marking = '')
    $g = $Geometry
    $geom = '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
    $titlePrompt = Get-PptxParagraphXml -Text $Office.MasterTitle
    $textPrompt = Get-PptxParagraphXml -Text $Office.MasterText
    $inner = $g.W - 2 * $g.M
    $sp = [Text.StringBuilder]::new()
    $name = $Office.Layouts[$Layout]
    if ($Layout -eq 'Title') {
        $attr = ' type="title" preserve="1" showMasterSp="0"'
        [void]$sp.Append((Get-PptxRectXml -Id 2 -Name $Office.TitleArea -X 0 -Y 0 -Cx $g.W -Cy $g.BandCy -Color $Color.Primary))
        [void]$sp.Append((Get-PptxRectXml -Id 3 -Name $Office.AccentLine -X 0 -Y $g.BandCy -Cx $g.W -Cy $g.Bar -Color $Color.Accent))
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 4 -Name ($Office.Title + ' 1') -PhType 'ctrTitle' -SpPr ((Get-PptxXfrmXml -X $g.M -Y 1260000 -Cx $inner -Cy 1980000) + $geom) `
                    -BodyPr '<a:bodyPr lIns="0" rIns="0" anchor="b"><a:normAutofit/></a:bodyPr>' -LstStyle (Get-PptxLstStyleXml -Size 4000 -Color 'FFFFFF') -Paragraphs $titlePrompt))
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 5 -Name ($Office.Subtitle + ' 2') -PhType 'subTitle' -PhIdx 1 -SpPr ((Get-PptxXfrmXml -X $g.M -Y 3420000 -Cx $inner -Cy 900000) + $geom) `
                    -BodyPr '<a:bodyPr lIns="0" rIns="0"><a:normAutofit/></a:bodyPr>' -LstStyle (Get-PptxLstStyleXml -Size 2000 -Color 'FFFFFF' -NoBullet $true) -Paragraphs (Get-PptxParagraphXml -Text $Office.Subtitle)))
        $areaY = $g.BandCy + $g.Bar
        $areaCy = $g.H - $areaY
        if ($LogoRelId -and $g.LogoW -gt 0) {
            $logoCy = [long]612000
            $logoCx = [long][Math]::Floor($g.LogoW * $logoCy / $g.LogoH)
            [void]$sp.Append((Get-PptxPictureXml -Id 6 -Name 'Logo' -RelId $LogoRelId -X $g.M -Y ($areaY + [long][Math]::Floor(($areaCy - $logoCy) / 2)) -Cx $logoCx -Cy $logoCy -UserDrawn $true -Descr 'Logo'))
        }
        $paras = ''
        if ($Company) { $paras = Get-PptxParagraphXml -Text $Company -Align 'r' -Size 1400 -Color $Color.Dark }
        if ($Marking) { $paras = $paras + (Get-PptxParagraphXml -Text $Marking -Align 'r' -Size 1200 -Bold $true -Color $Color.Primary) }
        if ($paras) {
            [void]$sp.Append((Get-PptxTextBoxXml -Id 7 -Name $Office.Sender -X ([long]($g.W / 2)) -Y $areaY -Cx ([long]($g.W / 2) - $g.M) -Cy $areaCy -Paragraphs $paras))
        }
    } elseif ($Layout -eq 'ImageFull') {
        $attr = ' preserve="1" userDrawn="1" showMasterSp="0"'
        $barY = $g.H - $g.FullBar
        [void]$sp.Append((Get-PptxRectXml -Id 2 -Name $Office.TitleBar -X 0 -Y $barY -Cx $g.W -Cy $g.FullBar -Color $Color.Primary -Alpha 72000))
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 3 -Name ($Office.Title + ' 1') -PhType 'title' -SpPr ((Get-PptxXfrmXml -X 0 -Y $barY -Cx $g.W -Cy 1188000) + $geom) `
                    -BodyPr ('<a:bodyPr lIns="{0}" rIns="{0}" anchor="ctr"><a:normAutofit/></a:bodyPr>' -f $g.M) -LstStyle (Get-PptxLstStyleXml -Size 2800 -Color 'FFFFFF') -Paragraphs $titlePrompt))
        $foot = Get-PptxFooterText -Company $Company -Marking $Marking
        if ($foot) {
            [void]$sp.Append((Get-PptxTextBoxXml -Id 4 -Name $Office.Footer -X 0 -Y ($g.H - 432000) -Cx $g.W -Cy 324000 -Inset $g.M `
                        -Paragraphs (Get-PptxParagraphXml -Text $foot -Size 1000 -Color 'FFFFFF')))
        }
    } elseif ($Layout -eq 'Section') {
        $attr = ' type="secHead" preserve="1"'
        $x = $g.M + 252000
        [void]$sp.Append((Get-PptxRectXml -Id 2 -Name $Office.Band -X 0 -Y 2160000 -Cx $g.W -Cy 2520000 -Color $Color.Light))
        [void]$sp.Append((Get-PptxRectXml -Id 3 -Name $Office.AccentBar -X $g.M -Y 2448000 -Cx 72000 -Cy 1944000 -Color $Color.Accent))
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 4 -Name ($Office.Title + ' 1') -PhType 'title' -SpPr ((Get-PptxXfrmXml -X $x -Y 2340000 -Cx ($inner - 252000) -Cy 1188000) + $geom) `
                    -BodyPr '<a:bodyPr lIns="0" rIns="0" anchor="b"><a:normAutofit/></a:bodyPr>' -LstStyle (Get-PptxLstStyleXml -Size 3600) -Paragraphs $titlePrompt))
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 5 -Name ($Office.Text + ' 2') -PhType 'body' -PhIdx 1 -SpPr ((Get-PptxXfrmXml -X $x -Y 3600000 -Cx ($inner - 252000) -Cy 900000) + $geom) `
                    -BodyPr '<a:bodyPr lIns="0" rIns="0"><a:normAutofit/></a:bodyPr>' -LstStyle (Get-PptxLstStyleXml -Size 2000 -NoBullet $true) -Paragraphs $textPrompt))
    } elseif ($Layout -eq 'Closing') {
        $attr = ' preserve="1" userDrawn="1"'
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 2 -Name ($Office.Title + ' 1') -PhType 'title' -SpPr ((Get-PptxXfrmXml -X $g.M -Y 1800000 -Cx $inner -Cy 1440000) + $geom) `
                    -BodyPr '<a:bodyPr lIns="0" rIns="0" anchor="b"><a:normAutofit/></a:bodyPr>' -LstStyle (Get-PptxLstStyleXml -Size 4000 -Align 'ctr') -Paragraphs $titlePrompt))
        [void]$sp.Append((Get-PptxRectXml -Id 3 -Name $Office.AccentLine -X ([long]($g.W / 2) - 720000) -Y 3420000 -Cx 1440000 -Cy 54000 -Color $Color.Accent))
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 4 -Name ($Office.Text + ' 2') -PhType 'body' -PhIdx 1 -SpPr ((Get-PptxXfrmXml -X $g.M -Y 3672000 -Cx $inner -Cy 1800000) + $geom) `
                    -BodyPr '<a:bodyPr lIns="0" rIns="0"><a:normAutofit/></a:bodyPr>' -LstStyle (Get-PptxLstStyleXml -Size 2000 -Align 'ctr' -NoBullet $true) -Paragraphs $textPrompt))
    } else {
        $attr = ' type="obj" preserve="1"'
        $bodySpPr = ''
        if ($Layout -eq 'ImageRight') {
            $attr = ' type="twoObj" preserve="1"'
            $bodySpPr = (Get-PptxXfrmXml -X $g.M -Y $g.BodyY -Cx $g.HalfCx -Cy $g.BodyCy) + $geom
        }
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 2 -Name ($Office.Title + ' 1') -PhType 'title' -Paragraphs $titlePrompt))
        [void]$sp.Append((Get-PptxPlaceholderXml -Id 3 -Name ($Office.Content + ' 2') -PhType 'body' -PhIdx 1 -SpPr $bodySpPr -Paragraphs $textPrompt))
        [void]$sp.Append((Get-PptxRectXml -Id 4 -Name $Office.AccentLine -X $g.M -Y $g.LineY -Cx 1080000 -Cy 54000 -Color $Color.Accent))
    }
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout ' + (Get-PptxNamespace) + $attr + '><p:cSld name="' + (ConvertTo-XmlText $name) + '">' +
    (Get-PptxTreeStartXml) + $sp.ToString() + '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>'
}

function Get-PptxFooterText {
    # Einzeilige Fusszeile "Firma | Kennzeichnung" fuer Folien ohne Masterformen.
    param([string] $Company, [string] $Marking)
    if ($Company -and $Marking) { return $Company + '  |  ' + $Marking }
    if ($Company) { return $Company }
    $Marking
}

function Get-PptxSlideXml {
    # Folie; Platzhalter erben Lage und Format vom Layout. Image = @{ RelId; W; H } oder $null.
    param([Parameter(Mandatory)] $Slide, [Parameter(Mandatory)][string] $Layout, [Parameter(Mandatory)] $Geometry,
        [Parameter(Mandatory)] $Color, $Image, [string] $Footer = '')
    $g = $Geometry
    $title = [string]$Slide.Title
    $sub = [string]$Slide.Subtitle
    $text = [string]$Slide.Text
    $sp = [Text.StringBuilder]::new()
    $id = 2
    if ($Layout -eq 'ImageFull' -and $Image) {
        $fit = Get-PptxImageFit -ImgW $Image.W -ImgH $Image.H -X 0 -Y 0 -Cx $g.W -Cy $g.H -Cover $true
        [void]$sp.Append((Get-PptxPictureXml -Id $id -Name ($Office.Image + ' ' + $id) -RelId $Image.RelId -X 0 -Y 0 -Cx $g.W -Cy $g.H -SrcRect $fit.SrcRect -Descr $title))
        $id++
        [void]$sp.Append((Get-PptxRectXml -Id $id -Name $Office.TitleBar -X 0 -Y ($g.H - $g.FullBar) -Cx $g.W -Cy $g.FullBar -Color $Color.Primary -Alpha 72000 -UserDrawn $false))
        $id++
    }
    if ($Layout -eq 'Title') {
        if ($title) { [void]$sp.Append((Get-PptxPlaceholderXml -Id $id -Name ($Office.Title + ' ' + ($id - 1)) -PhType 'ctrTitle' -Paragraphs (Get-PptxParagraphXml -Text $title))); $id++ }
        if (-not $sub) { $sub = $text }
        if ($sub) { [void]$sp.Append((Get-PptxPlaceholderXml -Id $id -Name ($Office.Subtitle + ' ' + ($id - 1)) -PhType 'subTitle' -PhIdx 1 -Paragraphs (Get-PptxBodyParagraphXml -Text $sub))); $id++ }
    } elseif ($Layout -eq 'ImageFull') {
        if ($title) {
            $paras = Get-PptxParagraphXml -Text $title
            if ($sub) { $paras = $paras + (Get-PptxParagraphXml -Text $sub -Size 1600) }
            [void]$sp.Append((Get-PptxPlaceholderXml -Id $id -Name ($Office.Title + ' ' + ($id - 1)) -PhType 'title' -Paragraphs $paras)); $id++
        }
        if ($Image -and $Footer) {
            [void]$sp.Append((Get-PptxTextBoxXml -Id $id -Name $Office.Footer -X 0 -Y ($g.H - 432000) -Cx $g.W -Cy 324000 -Inset $g.M -UserDrawn $false `
                        -Paragraphs (Get-PptxParagraphXml -Text $Footer -Size 1000 -Color 'FFFFFF'))); $id++
        }
    } else {
        if ($title) { [void]$sp.Append((Get-PptxPlaceholderXml -Id $id -Name ($Office.Title + ' ' + ($id - 1)) -PhType 'title' -Paragraphs (Get-PptxParagraphXml -Text $title))); $id++ }
        $plain = ($Layout -eq 'Section' -or $Layout -eq 'Closing')
        $bodyText = $text
        if ($sub) { $bodyText = $sub; if ($text) { $bodyText = $sub + "`n" + $text } }
        $body = Get-PptxBodyParagraphXml -Text $bodyText -Bullets $Slide.Bullets -BulletsAsText $plain
        if ($body) { [void]$sp.Append((Get-PptxPlaceholderXml -Id $id -Name ($Office.Content + ' ' + ($id - 1)) -PhType 'body' -PhIdx 1 -Paragraphs $body)); $id++ }
        if ($Layout -eq 'ImageRight' -and $Image) {
            $fit = Get-PptxImageFit -ImgW $Image.W -ImgH $Image.H -X $g.ImgX -Y ($g.BodyY + 114300) -Cx $g.HalfCx -Cy ($g.BodyCy - 114300) -Top $true
            [void]$sp.Append((Get-PptxPictureXml -Id $id -Name ($Office.Image + ' ' + ($id - 1)) -RelId $Image.RelId -X $fit.X -Y $fit.Y -Cx $fit.Cx -Cy $fit.Cy -Descr $title)); $id++
        }
    }
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sld ' + (Get-PptxNamespace) + '><p:cSld>' + (Get-PptxTreeStartXml) + $sp.ToString() +
    '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'
}

function Get-PptxNotesMasterXml {
    # Notizenmaster (Hochformat 6858000 x 9144000) mit Folienbild- und Notizenplatzhalter.
    param([bool] $Wide)
    $imgCx = 4572000
    if ($Wide) { $imgCx = 6096000 }
    $line = '<a:ln w="12700"><a:solidFill><a:prstClr val="black"/></a:solidFill></a:ln>'
    $geom = '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:notesMaster ' + (Get-PptxNamespace) + '><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>' +
    (Get-PptxTreeStartXml) +
    '<p:sp><p:nvSpPr><p:cNvPr id="2" name="' + (ConvertTo-XmlText $Office.SlideImage) + ' 1"/><p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/></p:cNvSpPr><p:nvPr><p:ph type="sldImg" idx="2"/></p:nvPr></p:nvSpPr><p:spPr>' +
    (Get-PptxXfrmXml -X ([long]((6858000 - $imgCx) / 2)) -Y 685800 -Cx $imgCx -Cy 3429000) + $geom + '<a:noFill/>' + $line + '</p:spPr></p:sp>' +
    (Get-PptxPlaceholderXml -Id 3 -Name ($Office.Notes + ' 2') -PhType 'body' -PhIdx 3 -SpPr ((Get-PptxXfrmXml -X 685800 -Y 4343400 -Cx 5486400 -Cy 4114800) + $geom) `
            -BodyPr '<a:bodyPr vert="horz" lIns="91440" tIns="45720" rIns="91440" bIns="45720" rtlCol="0"/>' -Paragraphs (Get-PptxParagraphXml -Text $Office.MasterText)) +
    '</p:spTree></p:cSld>' + (Get-PptxClrMapXml) + '<p:notesStyle>' + (Get-PptxLevelXml -Tag 'lvl1pPr' -Size 1200) + '</p:notesStyle></p:notesMaster>'
}

function Get-PptxNotesSlideXml {
    # Notizenseite einer Folie; jede Zeile der Notizen wird ein Absatz.
    param([string] $Text)
    $paras = [Text.StringBuilder]::new()
    foreach ($line in ($Text -split "`r?`n")) { [void]$paras.Append((Get-PptxParagraphXml -Text $line)) }
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:notes ' + (Get-PptxNamespace) + '><p:cSld>' + (Get-PptxTreeStartXml) +
    '<p:sp><p:nvSpPr><p:cNvPr id="2" name="' + (ConvertTo-XmlText $Office.SlideImage) + ' 1"/><p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/></p:cNvSpPr><p:nvPr><p:ph type="sldImg"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>' +
    (Get-PptxPlaceholderXml -Id 3 -Name ($Office.Notes + ' 2') -PhType 'body' -PhIdx 1 -Paragraphs $paras.ToString()) +
    '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>'
}

function Get-PptxPresentationXml {
    # presentation.xml; Beziehungen: rId1 Master, rId2..rId(n+1) Folien, rId(n+2) Notizenmaster.
    param([int] $SlideCount, [bool] $HasNotes, [bool] $Wide)
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentation ' + (Get-PptxNamespace) + ' saveSubsetFonts="1">')
    [void]$sb.Append('<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>')
    if ($HasNotes) { [void]$sb.Append(('<p:notesMasterIdLst><p:notesMasterId r:id="rId{0}"/></p:notesMasterIdLst>' -f ($SlideCount + 2))) }
    if ($SlideCount -gt 0) {
        [void]$sb.Append('<p:sldIdLst>')
        for ($i = 1; $i -le $SlideCount; $i++) { [void]$sb.Append(('<p:sldId id="{0}" r:id="rId{1}"/>' -f (255 + $i), ($i + 1))) }
        [void]$sb.Append('</p:sldIdLst>')
    }
    if ($Wide) { [void]$sb.Append('<p:sldSz cx="12192000" cy="6858000"/>') } else { [void]$sb.Append('<p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>') }
    [void]$sb.Append('<p:notesSz cx="6858000" cy="9144000"/><p:defaultTextStyle><a:defPPr><a:defRPr lang="' + $Locale.Culture + '"/></a:defPPr>')
    [void]$sb.Append((Get-PptxLevelXml -Tag 'lvl1pPr' -Size 1800)).Append('</p:defaultTextStyle></p:presentation>')
    $sb.ToString()
}

function Get-PptxPropertyPartXml {
    # Kleine Pflichtteile: 'presProps', 'viewProps' oder 'tableStyles'.
    param([Parameter(Mandatory)][string] $Part)
    $head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    if ($Part -eq 'presProps') { return $head + '<p:presentationPr ' + (Get-PptxNamespace) + '/>' }
    if ($Part -eq 'viewProps') {
        return $head + '<p:viewPr ' + (Get-PptxNamespace) + '><p:normalViewPr><p:restoredLeft sz="15620"/><p:restoredTop sz="94660"/></p:normalViewPr><p:gridSpacing cx="72008" cy="72008"/></p:viewPr>'
    }
    $head + '<a:tblStyleLst xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>'
}

function Get-PptxContentTypeXml {
    # [Content_Types].xml; NotesSlide = Foliennummern mit Notizen, Extension = Bild-Endungen in ppt/media.
    param([bool] $Template, [int] $SlideCount, [int] $LayoutCount, [int[]] $NotesSlide, [bool] $HasCustom, [string[]] $Extension)
    $pml = 'application/vnd.openxmlformats-officedocument.presentationml.'
    $over = '<Override PartName="{0}" ContentType="{1}"/>'
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
    [void]$sb.Append('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>')
    foreach ($ext in $Extension) { [void]$sb.Append(('<Default Extension="{0}" ContentType="image/{0}"/>' -f $ext)) }
    $main = 'presentation.main+xml'
    if ($Template) { $main = 'template.main+xml' }
    [void]$sb.Append(($over -f '/ppt/presentation.xml', ($pml + $main)))
    [void]$sb.Append(($over -f '/ppt/slideMasters/slideMaster1.xml', ($pml + 'slideMaster+xml')))
    for ($i = 1; $i -le $LayoutCount; $i++) { [void]$sb.Append(($over -f ('/ppt/slideLayouts/slideLayout{0}.xml' -f $i), ($pml + 'slideLayout+xml'))) }
    for ($i = 1; $i -le $SlideCount; $i++) { [void]$sb.Append(($over -f ('/ppt/slides/slide{0}.xml' -f $i), ($pml + 'slide+xml'))) }
    $theme = 'application/vnd.openxmlformats-officedocument.theme+xml'
    [void]$sb.Append(($over -f '/ppt/theme/theme1.xml', $theme))
    if (@($NotesSlide).Count -gt 0) {
        [void]$sb.Append(($over -f '/ppt/notesMasters/notesMaster1.xml', ($pml + 'notesMaster+xml')))
        [void]$sb.Append(($over -f '/ppt/theme/theme2.xml', $theme))
        foreach ($n in $NotesSlide) { [void]$sb.Append(($over -f ('/ppt/notesSlides/notesSlide{0}.xml' -f $n), ($pml + 'notesSlide+xml'))) }
    }
    [void]$sb.Append(($over -f '/ppt/presProps.xml', ($pml + 'presProps+xml')))
    [void]$sb.Append(($over -f '/ppt/viewProps.xml', ($pml + 'viewProps+xml')))
    [void]$sb.Append(($over -f '/ppt/tableStyles.xml', ($pml + 'tableStyles+xml')))
    [void]$sb.Append(($over -f '/docProps/core.xml', 'application/vnd.openxmlformats-package.core-properties+xml'))
    [void]$sb.Append(($over -f '/docProps/app.xml', 'application/vnd.openxmlformats-officedocument.extended-properties+xml'))
    if ($HasCustom) { [void]$sb.Append(($over -f '/docProps/custom.xml', 'application/vnd.openxmlformats-officedocument.custom-properties+xml')) }
    [void]$sb.Append('</Types>')
    $sb.ToString()
}

function Add-PptxImagePart {
    # Legt Bild-Bytes nur einmal je SHA256 in ppt/media ab und liefert den Dateinamen.
    param([Parameter(Mandatory)][byte[]] $Bytes, [string] $Format, [Parameter(Mandatory)] $List,
        [Parameter(Mandatory)][hashtable] $ByHash, [Parameter(Mandatory)] $Hasher)
    $key = [BitConverter]::ToString($Hasher.ComputeHash($Bytes))
    if ($ByHash.ContainsKey($key)) { return $ByHash[$key] }
    $ext = Get-PptxImageExtension -Format $Format
    $file = 'image{0}.{1}' -f ($List.Count + 1), $ext
    $List.Add(@{ File = $file; Bytes = $Bytes; Ext = $ext })
    $ByHash[$key] = $file
    $file
}

function Add-PptxSlidePart {
    # Schreibt Folie Number (1-basiert) samt Beziehungen und, falls vorhanden, Notizenseite.
    param([Parameter(Mandatory)] $Zip, [Parameter(Mandatory)][int] $Number, [Parameter(Mandatory)] $Slide,
        [Parameter(Mandatory)][string] $Layout, [int] $LayoutIndex, [Parameter(Mandatory)] $Geometry,
        [Parameter(Mandatory)] $Color, $Image, [string] $Footer, [datetime] $Date)
    $rels = [Collections.Generic.List[object]]::new()
    $rels.Add(@('rId1', 'slideLayout', ('../slideLayouts/slideLayout{0}.xml' -f $LayoutIndex)))
    $imageRef = $null
    if ($Image) {
        $rels.Add(@('rId2', 'image', ('../media/' + $Image.File)))
        $imageRef = @{ RelId = 'rId2'; W = $Image.W; H = $Image.H }
    }
    $notes = [string]$Slide.Notes
    if ($notes) {
        $rels.Add(@(('rId{0}' -f ($rels.Count + 1)), 'notesSlide', ('../notesSlides/notesSlide{0}.xml' -f $Number)))
    }
    $xml = Get-PptxSlideXml -Slide $Slide -Layout $Layout -Geometry $Geometry -Color $Color -Image $imageRef -Footer $Footer
    Add-ZipEntry -Zip $Zip -Name ('ppt/slides/slide{0}.xml' -f $Number) -Content $xml -Date $Date
    Add-ZipEntry -Zip $Zip -Name ('ppt/slides/_rels/slide{0}.xml.rels' -f $Number) -Content (Get-PptxRelationshipXml -Relation $rels) -Date $Date
    if ($notes) {
        $noteRels = @(@('rId1', 'notesMaster', '../notesMasters/notesMaster1.xml'), @('rId2', 'slide', ('../slides/slide{0}.xml' -f $Number)))
        Add-ZipEntry -Zip $Zip -Name ('ppt/notesSlides/notesSlide{0}.xml' -f $Number) -Content (Get-PptxNotesSlideXml -Text $notes) -Date $Date
        Add-ZipEntry -Zip $Zip -Name ('ppt/notesSlides/_rels/notesSlide{0}.xml.rels' -f $Number) -Content (Get-PptxRelationshipXml -Relation $noteRels) -Date $Date
    }
}

function Write-PptxFile {
    # Schreibt eine Praesentation (.pptx) bzw. mit Model.Template = $true eine Vorlage (.potx).
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][hashtable] $Model)
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $ci = $Model.Ci
    $color = Get-PptxColorSet -Ci $ci
    $wide = $true
    if ($null -ne $Model.Wide) { $wide = [bool]$Model.Wide }
    $geo = Get-PptxGeometry -Wide $wide -Ci $ci
    $date = [datetime]$Model.Modified
    $company = [string]$Model.Company
    $marking = [string]$Model.Marking
    $footer = Get-PptxFooterText -Company $company -Marking $marking

    # Folien, verwendete Layouts (feste Reihenfolge; Vorlage: alle), Bilder einmal je Hash
    $slides = [Collections.Generic.List[object]]::new()
    foreach ($s in @($Model.Slides)) { if ($s) { $slides.Add($s) } }
    $slideLayout = [Collections.Generic.List[string]]::new()
    foreach ($s in $slides) { $slideLayout.Add((Get-PptxLayoutName -Name $s.Layout)) }
    $layouts = [Collections.Generic.List[string]]::new()
    foreach ($n in @('Title', 'Content', 'ImageRight', 'ImageFull', 'Section', 'Closing')) {
        if ($Model.Template -or $slides.Count -eq 0 -or $slideLayout.Contains($n)) { $layouts.Add($n) }
    }
    $media = [Collections.Generic.List[object]]::new()
    $byHash = @{}
    $slideImage = @{}
    $notesSlides = [Collections.Generic.List[int]]::new()
    $logoFile = ''
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        if ($ci -and $ci.LogoPng -and $geo.LogoW -gt 0) {
            $logoFile = Add-PptxImagePart -Bytes $ci.LogoPng -Format 'png' -List $media -ByHash $byHash -Hasher $sha
        }
        for ($i = 0; $i -lt $slides.Count; $i++) {
            $img = $slides[$i].Image
            if ($slides[$i].Notes) { $notesSlides.Add($i + 1) }
            if (-not ($img -and $img.Bytes -and $slideLayout[$i] -match '^Image')) { continue }
            $file = Add-PptxImagePart -Bytes $img.Bytes -Format $img.Format -List $media -ByHash $byHash -Hasher $sha
            $size = Get-PptxImageSize -Bytes $img.Bytes -WidthPx $img.WidthPx -HeightPx $img.HeightPx
            $slideImage[$i] = @{ File = $file; W = $size[0]; H = $size[1] }
        }
    } finally { $sha.Dispose() }
    $hasNotes = $notesSlides.Count -gt 0
    $extensions = [Collections.Generic.List[string]]::new()
    foreach ($m in $media) { if (-not $extensions.Contains($m.Ext)) { $extensions.Add($m.Ext) } }
    $custom = Get-OoxmlCustomXml -Model $Model
    $themeName = 'CI'
    if ($company) { $themeName = $company }
    $n = $slides.Count
    $lc = $layouts.Count

    $pkg = Open-ZipPackage -Path $fullPath
    try {
        $zip = $pkg.Zip
        $ct = Get-PptxContentTypeXml -Template ([bool]$Model.Template) -SlideCount $n -LayoutCount $lc -NotesSlide $notesSlides.ToArray() -HasCustom ($null -ne $custom) -Extension $extensions.ToArray()
        Add-ZipEntry -Zip $zip -Name '[Content_Types].xml' -Content $ct -Date $date
        Add-ZipEntry -Zip $zip -Name '_rels/.rels' -Content (Get-OoxmlPackageRelationship -MainPart 'ppt/presentation.xml' -HasCustom ($null -ne $custom)) -Date $date
        Add-ZipEntry -Zip $zip -Name 'docProps/core.xml' -Content (Get-OoxmlCoreXml -Model $Model) -Date $date
        Add-ZipEntry -Zip $zip -Name 'docProps/app.xml' -Content (Get-OoxmlAppXml -Model $Model -Application 'Microsoft Office PowerPoint') -Date $date
        if ($null -ne $custom) { Add-ZipEntry -Zip $zip -Name 'docProps/custom.xml' -Content $custom -Date $date }

        # presentation.xml und Beziehungen (Nummernschema siehe Get-PptxPresentationXml)
        Add-ZipEntry -Zip $zip -Name 'ppt/presentation.xml' -Content (Get-PptxPresentationXml -SlideCount $n -HasNotes $hasNotes -Wide $wide) -Date $date
        $rels = [Collections.Generic.List[object]]::new()
        $rels.Add(@('rId1', 'slideMaster', 'slideMasters/slideMaster1.xml'))
        for ($i = 1; $i -le $n; $i++) { $rels.Add(@(('rId{0}' -f ($i + 1)), 'slide', ('slides/slide{0}.xml' -f $i))) }
        if ($hasNotes) { $rels.Add(@(('rId{0}' -f ($rels.Count + 1)), 'notesMaster', 'notesMasters/notesMaster1.xml')) }
        foreach ($part in @(@('presProps', 'presProps.xml'), @('viewProps', 'viewProps.xml'), @('theme', 'theme/theme1.xml'), @('tableStyles', 'tableStyles.xml'))) {
            $rels.Add(@(('rId{0}' -f ($rels.Count + 1)), $part[0], $part[1]))
        }
        Add-ZipEntry -Zip $zip -Name 'ppt/_rels/presentation.xml.rels' -Content (Get-PptxRelationshipXml -Relation $rels) -Date $date

        for ($i = 0; $i -lt $n; $i++) {
            Add-PptxSlidePart -Zip $zip -Number ($i + 1) -Slide $slides[$i] -Layout $slideLayout[$i] -LayoutIndex ($layouts.IndexOf($slideLayout[$i]) + 1) `
                -Geometry $geo -Color $color -Image $slideImage[$i] -Footer $footer -Date $date
        }

        # Layouts: rId1 Master, rId2 Logo (nur Titelfolie)
        for ($i = 0; $i -lt $lc; $i++) {
            $rels = [Collections.Generic.List[object]]::new()
            $rels.Add(@('rId1', 'slideMaster', '../slideMasters/slideMaster1.xml'))
            $logoRel = ''
            if ($layouts[$i] -eq 'Title' -and $logoFile) {
                $rels.Add(@('rId2', 'image', ('../media/' + $logoFile)))
                $logoRel = 'rId2'
            }
            $xml = Get-PptxLayoutXml -Layout $layouts[$i] -Geometry $geo -Color $color -LogoRelId $logoRel -Company $company -Marking $marking
            Add-ZipEntry -Zip $zip -Name ('ppt/slideLayouts/slideLayout{0}.xml' -f ($i + 1)) -Content $xml -Date $date
            Add-ZipEntry -Zip $zip -Name ('ppt/slideLayouts/_rels/slideLayout{0}.xml.rels' -f ($i + 1)) -Content (Get-PptxRelationshipXml -Relation $rels) -Date $date
        }

        # Master: rId1..rIdN Layouts, dann Theme, dann Logo
        $rels = [Collections.Generic.List[object]]::new()
        for ($i = 1; $i -le $lc; $i++) { $rels.Add(@(('rId{0}' -f $i), 'slideLayout', ('../slideLayouts/slideLayout{0}.xml' -f $i))) }
        $rels.Add(@(('rId{0}' -f ($lc + 1)), 'theme', '../theme/theme1.xml'))
        $logoRel = ''
        if ($logoFile) {
            $logoRel = 'rId{0}' -f ($lc + 2)
            $rels.Add(@($logoRel, 'image', ('../media/' + $logoFile)))
        }
        $xml = Get-PptxMasterXml -Geometry $geo -Color $color -LayoutCount $lc -LogoRelId $logoRel -Company $company -Marking $marking
        Add-ZipEntry -Zip $zip -Name 'ppt/slideMasters/slideMaster1.xml' -Content $xml -Date $date
        Add-ZipEntry -Zip $zip -Name 'ppt/slideMasters/_rels/slideMaster1.xml.rels' -Content (Get-PptxRelationshipXml -Relation $rels) -Date $date
        Add-ZipEntry -Zip $zip -Name 'ppt/theme/theme1.xml' -Content (Get-PptxThemeXml -Color $color -Name $themeName) -Date $date

        if ($hasNotes) {
            Add-ZipEntry -Zip $zip -Name 'ppt/notesMasters/notesMaster1.xml' -Content (Get-PptxNotesMasterXml -Wide $wide) -Date $date
            Add-ZipEntry -Zip $zip -Name 'ppt/notesMasters/_rels/notesMaster1.xml.rels' -Content (Get-PptxRelationshipXml -Relation @(, @('rId1', 'theme', '../theme/theme2.xml'))) -Date $date
            Add-ZipEntry -Zip $zip -Name 'ppt/theme/theme2.xml' -Content (Get-PptxThemeXml -Color $color -Name $themeName) -Date $date
        }
        foreach ($part in @('presProps', 'viewProps', 'tableStyles')) {
            Add-ZipEntry -Zip $zip -Name ('ppt/{0}.xml' -f $part) -Content (Get-PptxPropertyPartXml -Part $part) -Date $date
        }
        foreach ($m in $media) { Add-ZipEntry -Zip $zip -Name ('ppt/media/' + $m.File) -Content $m.Bytes -Date $date }
    } finally { Close-ZipPackage -Package $pkg }
}

#endregion
#region PDF (PDF 1.4, Type1-Standardschriften mit WinAnsi, JPEG-Bilder als DCTDecode)

# Anzeigeliste: Koordinaten in Punkt, Ursprung oben links. Elemente (Feld K):
#   Text    X Y Size Bold Serif Text Color
#   Rect    X Y W H Color
#   Line    X1 Y1 X2 Y2 Width Color
#   Poly    Points (@(x,y,x,y,...)) Color
#   Ellipse X Y W H Color
#   Image   X Y W H Bytes PixW PixH   (JPEG)
#   Sign    X Y W H Seed Color        (Unterschrift als Kurvenzug)
#   Raster-only (Stamp, Texture, Holes) ignoriert der PDF-Text-Weg.

function ConvertTo-PdfLiteral {
    # PDF-String in Klammern; Zeichen ausserhalb ASCII als Oktal-Escape im WinAnsi-Code.
    param([AllowEmptyString()][string] $Text)
    if ($Text -cmatch '^[\x20-\x27\x2A-\x5B\x5D-\x7E]*$') { return '(' + $Text + ')' }
    $sb = New-Object -TypeName System.Text.StringBuilder -ArgumentList ($Text.Length + 8)
    [void]$sb.Append('(')
    foreach ($character in $Text.ToCharArray()) {
        $code = $script:WinAnsiOf[[int]$character]
        if ($code -eq 40 -or $code -eq 41 -or $code -eq 92) { [void]$sb.Append('\').Append([char]$code) }
        elseif ($code -ge 32 -and $code -le 126) { [void]$sb.Append([char]$code) }
        else { [void]$sb.Append('\').Append([Convert]::ToString($code, 8).PadLeft(3, '0')) }
    }
    [void]$sb.Append(')')
    $sb.ToString()
}

function Format-PdfColor {
    param([int[]] $Rgb, [string] $Operator)
    '{0} {1} {2} {3}' -f (Format-PdfNumber ($Rgb[0] / 255)), (Format-PdfNumber ($Rgb[1] / 255)), (Format-PdfNumber ($Rgb[2] / 255)), $Operator
}

function Format-PdfDate {
    param([datetime] $Date)
    ('D:{0:yyyyMMddHHmmss}' -f $Date) + $Locale.PdfZone
}

function Get-SignatureCurve {
    # Deterministischer Kurvenzug einer Unterschrift im Rechteck; liefert Segmente @(x0,y0, c1x,c1y, c2x,c2y, x1,y1).
    param([double] $X, [double] $Y, [double] $W, [double] $H, [int] $Seed)
    $rng = Get-Rng -Index $Seed -Salt 61
    $segments = [System.Collections.Generic.List[object]]::new()
    $px = $X
    $py = $Y + $H * (0.45 + $rng.NextDouble() * 0.2)
    $count = 5 + $rng.Next(0, 4)
    for ($i = 0; $i -lt $count; $i++) {
        $nx = $px + $W / $count * (0.8 + $rng.NextDouble() * 0.4)
        $ny = $Y + $H * (0.2 + $rng.NextDouble() * 0.6)
        $segments.Add(@($px, $py, ($px + ($nx - $px) * 0.3), ($Y + $H * $rng.NextDouble()), ($px + ($nx - $px) * 0.7), ($Y + $H * $rng.NextDouble()), $nx, $ny))
        $px = $nx
        $py = $ny
    }
    # Abschliessender Unterstrich
    # Komma bindet in PowerShell staerker als +, daher jedes Element geklammert.
    $segments.Add(@(($X + $W * 0.1), ($Y + $H * 0.95), ($X + $W * 0.4), ($Y + $H), ($X + $W * 0.7), ($Y + $H * 0.9), ($X + $W * 0.95), ($Y + $H * 0.97)))
    , $segments.ToArray()
}

function ConvertTo-PdfContent {
    # Setzt eine Anzeigeliste in einen Inhaltsstrom um; Bilder landen in $Images (Liste @{ Name; Bytes; PixW; PixH }).
    param([Parameter(Mandatory)] $Items, [double] $PageHeight, [Parameter(Mandatory)] $Images)
    $sb = New-Object -TypeName System.Text.StringBuilder -ArgumentList 4096
    foreach ($item in $Items) {
        switch ($item.K) {
            'Text' {
                if (-not $item.Text) { break }
                $font = if ($item.Serif) { if ($item.Bold) { '/F4' } else { '/F3' } } else { if ($item.Bold) { '/F2' } else { '/F1' } }
                $color = if ($item.Color) { $item.Color } else { @(0, 0, 0) }
                [void]$sb.AppendFormat('BT {0} {1} Tf {2} {3} {4} Td {5} Tj ET', $font, (Format-PdfNumber $item.Size), (Format-PdfColor $color 'rg'), (Format-PdfNumber $item.X), (Format-PdfNumber ($PageHeight - $item.Y - $item.Size * 0.78)), (ConvertTo-PdfLiteral $item.Text)).Append("`n")
            }
            'Rect' {
                [void]$sb.AppendFormat('{0} {1} {2} {3} {4} re f', (Format-PdfColor $item.Color 'rg'), (Format-PdfNumber $item.X), (Format-PdfNumber ($PageHeight - $item.Y - $item.H)), (Format-PdfNumber $item.W), (Format-PdfNumber $item.H)).Append("`n")
            }
            'Line' {
                $color = if ($item.Color) { $item.Color } else { @(0, 0, 0) }
                [void]$sb.AppendFormat('{0} w {1} {2} {3} m {4} {5} l S', (Format-PdfNumber $item.Width), (Format-PdfColor $color 'RG'), (Format-PdfNumber $item.X1), (Format-PdfNumber ($PageHeight - $item.Y1)), (Format-PdfNumber $item.X2), (Format-PdfNumber ($PageHeight - $item.Y2))).Append("`n")
            }
            'Poly' {
                $p = $item.Points
                [void]$sb.Append((Format-PdfColor $item.Color 'rg')).AppendFormat(' {0} {1} m', (Format-PdfNumber $p[0]), (Format-PdfNumber ($PageHeight - $p[1])))
                for ($i = 2; $i -lt $p.Count; $i += 2) { [void]$sb.AppendFormat(' {0} {1} l', (Format-PdfNumber $p[$i]), (Format-PdfNumber ($PageHeight - $p[$i + 1]))) }
                [void]$sb.Append(" h f`n")
            }
            'Ellipse' {
                $k = 0.5523
                $rx = $item.W / 2
                $ry = $item.H / 2
                $cx = $item.X + $rx
                $cy = $PageHeight - $item.Y - $ry
                [void]$sb.Append((Format-PdfColor $item.Color 'rg'))
                [void]$sb.AppendFormat(' {0} {1} m', (Format-PdfNumber ($cx + $rx)), (Format-PdfNumber $cy))
                [void]$sb.AppendFormat(' {0} {1} {2} {3} {4} {5} c', (Format-PdfNumber ($cx + $rx)), (Format-PdfNumber ($cy + $ry * $k)), (Format-PdfNumber ($cx + $rx * $k)), (Format-PdfNumber ($cy + $ry)), (Format-PdfNumber $cx), (Format-PdfNumber ($cy + $ry)))
                [void]$sb.AppendFormat(' {0} {1} {2} {3} {4} {5} c', (Format-PdfNumber ($cx - $rx * $k)), (Format-PdfNumber ($cy + $ry)), (Format-PdfNumber ($cx - $rx)), (Format-PdfNumber ($cy + $ry * $k)), (Format-PdfNumber ($cx - $rx)), (Format-PdfNumber $cy))
                [void]$sb.AppendFormat(' {0} {1} {2} {3} {4} {5} c', (Format-PdfNumber ($cx - $rx)), (Format-PdfNumber ($cy - $ry * $k)), (Format-PdfNumber ($cx - $rx * $k)), (Format-PdfNumber ($cy - $ry)), (Format-PdfNumber $cx), (Format-PdfNumber ($cy - $ry)))
                [void]$sb.AppendFormat(' {0} {1} {2} {3} {4} {5} c f', (Format-PdfNumber ($cx + $rx * $k)), (Format-PdfNumber ($cy - $ry)), (Format-PdfNumber ($cx + $rx)), (Format-PdfNumber ($cy - $ry * $k)), (Format-PdfNumber ($cx + $rx)), (Format-PdfNumber $cy)).Append("`n")
            }
            'Image' {
                if (-not $item.Bytes) {
                    [void]$sb.AppendFormat('0.9 0.9 0.9 rg {0} {1} {2} {3} re f', (Format-PdfNumber $item.X), (Format-PdfNumber ($PageHeight - $item.Y - $item.H)), (Format-PdfNumber $item.W), (Format-PdfNumber $item.H)).Append("`n")
                    break
                }
                $name = 'Im{0}' -f ($Images.Count + 1)
                $Images.Add(@{ Name = $name; Bytes = $item.Bytes; PixW = $item.PixW; PixH = $item.PixH })
                [void]$sb.AppendFormat('q {0} 0 0 {1} {2} {3} cm /{4} Do Q', (Format-PdfNumber $item.W), (Format-PdfNumber $item.H), (Format-PdfNumber $item.X), (Format-PdfNumber ($PageHeight - $item.Y - $item.H)), $name).Append("`n")
            }
            'Sign' {
                $color = if ($item.Color) { $item.Color } else { @(20, 40, 140) }
                [void]$sb.Append('1.1 w 1 J 1 j ').Append((Format-PdfColor $color 'RG'))
                foreach ($s in (Get-SignatureCurve $item.X $item.Y $item.W $item.H $item.Seed)) {
                    [void]$sb.AppendFormat(' {0} {1} m {2} {3} {4} {5} {6} {7} c', (Format-PdfNumber $s[0]), (Format-PdfNumber ($PageHeight - $s[1])), (Format-PdfNumber $s[2]), (Format-PdfNumber ($PageHeight - $s[3])), (Format-PdfNumber $s[4]), (Format-PdfNumber ($PageHeight - $s[5])), (Format-PdfNumber $s[6]), (Format-PdfNumber ($PageHeight - $s[7])))
                }
                [void]$sb.Append(" S`n")
            }
        }
    }
    $sb.ToString()
}

function Write-PdfAscii {
    param([Parameter(Mandatory)] $Stream, [Parameter(Mandatory)][string] $Text)
    $bytes = [Text.Encoding]::ASCII.GetBytes($Text)
    $Stream.Write($bytes, 0, $bytes.Length)
}

function Write-PdfFile {
    # Pages: @{ W; H; Content; Images }. Info: @{ Title; Author; Creator; Producer; Subject; Keywords; Created; Modified }.
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][object[]] $Pages, [Parameter(Mandatory)][hashtable] $Info)
    $stream = New-Object -TypeName System.IO.MemoryStream
    $offsets = New-Object 'System.Collections.Generic.List[long]'
    $offsets.Add(0)
    Write-PdfAscii $stream "%PDF-1.4`n%"
    $stream.Write([byte[]](0xE2, 0xE3, 0xCF, 0xD3), 0, 4)
    Write-PdfAscii $stream "`n"

    # Objektnummern: 1 Katalog, 2 Seitenbaum, 3-6 Schriften, 7 Info, ab 8 je Seite: Seite, Inhalt, Bilder.
    $next = 8
    $layout = foreach ($page in $Pages) {
        $entry = @{ Page = $next; Content = $next + 1; Images = @() }
        $next += 2
        foreach ($image in @($page.Images)) { $entry.Images += $next; $next++ }
        $entry
    }
    $layout = @($layout)
    $objects = [System.Collections.Generic.List[object]]::new()
    $objects.Add('<< /Type /Catalog /Pages 2 0 R >>')
    $objects.Add(('<< /Type /Pages /Kids [{0}] /Count {1} >>' -f (($layout | ForEach-Object { '{0} 0 R' -f $_.Page }) -join ' '), $layout.Count))
    foreach ($font in 'Helvetica', 'Helvetica-Bold', 'Times-Roman', 'Times-Bold') {
        $objects.Add('<< /Type /Font /Subtype /Type1 /BaseFont /{0} /Encoding /WinAnsiEncoding >>' -f $font)
    }
    $infoText = '<< /Title {0} /Author {1} /Creator {2} /Producer {3} /CreationDate ({4}) /ModDate ({5})' -f (ConvertTo-PdfLiteral $Info.Title), (ConvertTo-PdfLiteral $Info.Author), (ConvertTo-PdfLiteral $Info.Creator), (ConvertTo-PdfLiteral $Info.Producer), (Format-PdfDate $Info.Created), (Format-PdfDate $Info.Modified)
    if ($Info.Subject) { $infoText += ' /Subject {0}' -f (ConvertTo-PdfLiteral $Info.Subject) }
    if ($Info.Keywords) { $infoText += ' /Keywords {0}' -f (ConvertTo-PdfLiteral $Info.Keywords) }
    $objects.Add($infoText + ' >>')

    for ($n = 1; $n -le $objects.Count; $n++) {
        $offsets.Add($stream.Position)
        Write-PdfAscii $stream ("{0} 0 obj`n{1}`nendobj`n" -f $n, $objects[$n - 1])
    }
    for ($p = 0; $p -lt $Pages.Count; $p++) {
        $page = $Pages[$p]
        $entry = $layout[$p]
        $xobjects = ''
        $pageImages = @($page.Images)
        if ($pageImages.Count) {
            $xobjects = ' /XObject << {0} >>' -f ((0..($pageImages.Count - 1) | ForEach-Object { '/{0} {1} 0 R' -f $pageImages[$_].Name, $entry.Images[$_] }) -join ' ')
        }
        $offsets.Add($stream.Position)
        Write-PdfAscii $stream ("{0} 0 obj`n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {1} {2}] /Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R /F4 6 0 R >>{3} >> /Contents {4} 0 R >>`nendobj`n" -f $entry.Page, (Format-PdfNumber $page.W), (Format-PdfNumber $page.H), $xobjects, $entry.Content)
        $contentBytes = [Text.Encoding]::ASCII.GetBytes($page.Content)
        $offsets.Add($stream.Position)
        Write-PdfAscii $stream ("{0} 0 obj`n<< /Length {1} >>`nstream`n" -f $entry.Content, $contentBytes.Length)
        $stream.Write($contentBytes, 0, $contentBytes.Length)
        Write-PdfAscii $stream "`nendstream`nendobj`n"
        for ($i = 0; $i -lt $pageImages.Count; $i++) {
            $image = $pageImages[$i]
            $offsets.Add($stream.Position)
            Write-PdfAscii $stream ("{0} 0 obj`n<< /Type /XObject /Subtype /Image /Width {1} /Height {2} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length {3} >>`nstream`n" -f $entry.Images[$i], $image.PixW, $image.PixH, $image.Bytes.Length)
            $stream.Write($image.Bytes, 0, $image.Bytes.Length)
            Write-PdfAscii $stream "`nendstream`nendobj`n"
        }
    }
    $xref = $stream.Position
    $sb = New-Object -TypeName System.Text.StringBuilder
    [void]$sb.AppendFormat("xref`n0 {0}`n0000000000 65535 f `n", $offsets.Count)
    for ($n = 1; $n -lt $offsets.Count; $n++) { [void]$sb.AppendFormat("{0:D10} 00000 n `n", $offsets[$n]) }
    [void]$sb.AppendFormat("trailer`n<< /Size {0} /Root 1 0 R /Info 7 0 R >>`nstartxref`n{1}`n%%EOF`n", $offsets.Count, $xref)
    Write-PdfAscii $stream $sb.ToString()
    [IO.File]::WriteAllBytes($Path, $stream.ToArray())
    $stream.Dispose()
}

#endregion
#region Raster (GDI+): Grundlagen, Logo, Texturen, Diagramme

function Initialize-Raster {
    # Einmal je Prozess: Assembly, Encoder, Rauschkacheln fuer Texturen und Scankorn.
    Add-Type -AssemblyName System.Drawing
    $script:JpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -EQ 'image/jpeg' | Select-Object -First 1
    $script:FontCache = @{}
    $script:BrushCache = @{}
    $rng = Get-Rng -Index 4242 -Salt 3
    $script:NoiseTiles = @(foreach ($size in 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 128) { Get-NoiseBitmap -Rng $rng -Width $size -Height $size })
    $script:StripeTiles = @(foreach ($i in 1..4) { Get-NoiseBitmap -Rng $rng -Width 2 -Height 96 })
    $script:GrainTile = Get-NoiseBitmap -Rng $rng -Width 256 -Height 256 -Alpha 22
    $script:GrainTileStrong = Get-NoiseBitmap -Rng $rng -Width 256 -Height 256 -Alpha 40
}

function Get-NoiseBitmap {
    # Graues Rauschen; mit Alpha > 0 als halbtransparentes Korn (Scans), sonst deckend (Texturen).
    param([Parameter(Mandatory)] $Rng, [int] $Width, [int] $Height, [int] $Alpha = 0)
    $bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $Width, $Height, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rect = New-Object -TypeName System.Drawing.Rectangle -ArgumentList 0, 0, $Width, $Height
    $data = $bitmap.LockBits($rect, [Drawing.Imaging.ImageLockMode]::WriteOnly, $bitmap.PixelFormat)
    $bytes = New-Object byte[] ($Width * $Height * 4)
    $Rng.NextBytes($bytes)
    for ($i = 0; $i -lt $bytes.Length; $i += 4) {
        $v = $bytes[$i]
        $bytes[$i + 1] = $v
        $bytes[$i + 2] = $v
        $bytes[$i + 3] = if ($Alpha -gt 0) { [byte]($bytes[$i + 3] % ($Alpha + 1)) } else { 255 }
    }
    [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
    $bitmap.UnlockBits($data)
    $bitmap
}

function ConvertTo-GdiColor {
    param([int[]] $Rgb, [int] $Alpha = 255)
    [Drawing.Color]::FromArgb($Alpha, $Rgb[0], $Rgb[1], $Rgb[2])
}

function Get-RasterBrush {
    param([int[]] $Rgb, [int] $Alpha = 255)
    $key = '{0},{1},{2},{3}' -f $Rgb[0], $Rgb[1], $Rgb[2], $Alpha
    if (-not $script:BrushCache.ContainsKey($key)) { $script:BrushCache[$key] = New-Object -TypeName System.Drawing.SolidBrush -ArgumentList (ConvertTo-GdiColor $Rgb $Alpha) }
    $script:BrushCache[$key]
}

function Get-RasterFont {
    param([float] $SizePx, [bool] $Bold, [string] $Family = 'Arial')
    $key = '{0}|{1}|{2}' -f $Family, [Math]::Round($SizePx, 1), $Bold
    if (-not $script:FontCache.ContainsKey($key)) {
        $style = if ($Bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
        $script:FontCache[$key] = New-Object -TypeName System.Drawing.Font -ArgumentList $Family, ([float][Math]::Max(1, $SizePx)), $style, ([Drawing.GraphicsUnit]::Pixel)
    }
    $script:FontCache[$key]
}

function ConvertTo-JpegByte {
    param([Parameter(Mandatory)] $Bitmap, [int] $Quality = 85)
    $parameters = New-Object -TypeName System.Drawing.Imaging.EncoderParameters -ArgumentList 1
    $parameters.Param[0] = New-Object -TypeName System.Drawing.Imaging.EncoderParameter -ArgumentList ([Drawing.Imaging.Encoder]::Quality), ([long]$Quality)
    $ms = New-Object -TypeName System.IO.MemoryStream
    $Bitmap.Save($ms, $script:JpegCodec, $parameters)
    $bytes = $ms.ToArray()
    $ms.Dispose()
    , $bytes
}

function ConvertTo-PngByte {
    param([Parameter(Mandatory)] $Bitmap)
    $ms = New-Object -TypeName System.IO.MemoryStream
    $Bitmap.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray()
    $ms.Dispose()
    , $bytes
}

# Signet der neuen CI: Anfangsbuchstabe von Company.Short aus zwei Flaechen (Einheitsquadrat, y nach unten).
$SignetShapes = @{
    M = @(@(0, 1, 0, 0, 0.5, 0.52, 0.5, 0.82, 0.2, 0.5, 0.2, 1), @(1, 1, 1, 0, 0.5, 0.52, 0.5, 0.82, 0.8, 0.5, 0.8, 1))
    C = @(@(1, 0, 0.25, 0, 0, 0.25, 0, 0.55, 0.22, 0.55, 0.22, 0.33, 0.33, 0.22, 1, 0.22), @(0, 0.55, 0, 0.75, 0.25, 1, 1, 1, 1, 0.78, 0.33, 0.78, 0.22, 0.67, 0.22, 0.55))
}

function Get-SignetPolygon {
    # Liefert die beiden Flaechen des Signets als Punktlisten @(x,y,...); unbekannte Buchstaben zeigen das "M".
    param([double] $X, [double] $Y, [double] $Size)
    # $script:, weil Aufrufer lokale Variablen wie $c haben (PowerShell unterscheidet Gross-/Kleinschreibung nicht).
    $letter = [string]$script:C.Company.Short.Substring(0, 1).ToUpperInvariant()
    $shape = if ($SignetShapes.ContainsKey($letter)) { $SignetShapes[$letter] } else { $SignetShapes['M'] }
    $map = { param($p) $o = New-Object double[] $p.Count; for ($i = 0; $i -lt $p.Count; $i += 2) { $o[$i] = $X + $p[$i] * $Size; $o[$i + 1] = $Y + $p[$i + 1] * $Size }; , $o }
    @((& $map $shape[0]), (& $map $shape[1]))
}

function Get-LogoItem {
    # Logo als Anzeigeliste (Punkt-Koordinaten), fuer PDF, Raster und Vorschau gleich.
    # Neue CI: Signet + Company.Wordmark in zwei Zeilen; alte CI: Company.Short in Versalien mit Linie.
    param([double] $X, [double] $Y, [double] $Height, [Parameter(Mandatory)] $Ci, [switch] $Negative)
    $items = [System.Collections.Generic.List[object]]::new()
    $textColor = if ($Negative) { @(255, 255, 255) } else { $Ci.Dark }
    if ($Ci.Mark -eq 'Signet') {
        $polys = Get-SignetPolygon $X $Y $Height
        $items.Add(@{ K = 'Poly'; Points = $polys[0]; Color = $(if ($Negative) { @(255, 255, 255) } else { $Ci.Primary }) })
        $items.Add(@{ K = 'Poly'; Points = $polys[1]; Color = $Ci.Accent })
        $items.Add(@{ K = 'Text'; X = $X + $Height * 1.25; Y = $Y + $Height * 0.02; Size = $Height * 0.52; Bold = $true; Text = $C.Company.Wordmark[0]; Color = $textColor })
        $items.Add(@{ K = 'Text'; X = $X + $Height * 1.25; Y = $Y + $Height * 0.52; Size = $Height * 0.42; Bold = $false; Text = $C.Company.Wordmark[1]; Color = $(if ($Negative) { @(255, 255, 255) } else { $Ci.Primary }) })
    }
    else {
        $color = if ($Negative) { @(255, 255, 255) } else { $Ci.Primary }
        $items.Add(@{ K = 'Text'; X = $X; Y = $Y; Size = $Height * 0.62; Bold = $true; Serif = $true; Text = $C.Company.Short.ToUpperInvariant(); Color = $color })
        $items.Add(@{ K = 'Line'; X1 = $X; Y1 = $Y + $Height * 0.78; X2 = $X + $Height * 6.6; Y2 = $Y + $Height * 0.78; Width = [Math]::Max(0.5, $Height * 0.04); Color = $color })
    }
    , $items.ToArray()
}

function Add-TextureFill {
    # Weiche, natuerliche Flaeche aus skalierten Rauschkacheln, eingefaerbt zwischen zwei Farben.
    # Kind: Clouds (Himmel, Bokeh), Wood (Maserung), Paper (Struktur), Stone (Beton).
    param([Parameter(Mandatory)] $Graphics, [Parameter(Mandatory)] $Rect, [string] $Kind, [int] $Seed, [int[]] $Color1, [int[]] $Color2)
    $rng = Get-Rng -Index $Seed -Salt 13
    $base = New-Object -TypeName System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $Rect, (ConvertTo-GdiColor $Color1), (ConvertTo-GdiColor $Color2), ([float](60 + $rng.Next(0, 60)))
    $Graphics.FillRectangle($base, $Rect)
    $base.Dispose()
    $Graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $layers = switch ($Kind) {
        'Wood' { @(@{ Tile = $script:StripeTiles[$rng.Next(0, 4)]; Alpha = 0.55 }, @{ Tile = $script:NoiseTiles[10]; Alpha = 0.12 }) }
        'Paper' { @(@{ Tile = $script:NoiseTiles[11]; Alpha = 0.18 }, @{ Tile = $script:NoiseTiles[8]; Alpha = 0.10 }) }
        'Stone' { @(@{ Tile = $script:NoiseTiles[5]; Alpha = 0.35 }, @{ Tile = $script:NoiseTiles[9]; Alpha = 0.25 }, @{ Tile = $script:NoiseTiles[11]; Alpha = 0.2 }) }
        default { @(@{ Tile = $script:NoiseTiles[$rng.Next(0, 3)]; Alpha = 0.6 }, @{ Tile = $script:NoiseTiles[3 + $rng.Next(0, 3)]; Alpha = 0.35 }, @{ Tile = $script:NoiseTiles[7]; Alpha = 0.12 }) }
    }
    foreach ($layer in $layers) {
        $matrix = New-Object -TypeName System.Drawing.Imaging.ColorMatrix
        $matrix.Matrix00 = ($Color2[0] - $Color1[0]) / 255.0
        $matrix.Matrix01 = ($Color2[1] - $Color1[1]) / 255.0
        $matrix.Matrix02 = ($Color2[2] - $Color1[2]) / 255.0
        $matrix.Matrix11 = 0
        $matrix.Matrix22 = 0
        $matrix.Matrix33 = [float]$layer.Alpha
        $matrix.Matrix40 = $Color1[0] / 255.0
        $matrix.Matrix41 = $Color1[1] / 255.0
        $matrix.Matrix42 = $Color1[2] / 255.0
        $attributes = New-Object -TypeName System.Drawing.Imaging.ImageAttributes
        $attributes.SetColorMatrix($matrix)
        $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $tile = $layer.Tile
        $destination = New-Object -TypeName System.Drawing.Rectangle -ArgumentList ([int]$Rect.X), ([int]$Rect.Y), ([int]$Rect.Width), ([int]$Rect.Height)
        $Graphics.DrawImage($tile, $destination, 0, 0, $tile.Width, $tile.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
        $attributes.Dispose()
    }
    $Graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::Bilinear
}

function Add-ChartDrawing {
    # Saeulendiagramm: Chart = @{ Labels; Series = @(@(...),...); Names; Colors = @(@(r,g,b),...) }.
    param([Parameter(Mandatory)] $Graphics, [Parameter(Mandatory)] $Rect, [Parameter(Mandatory)] $Chart, [float] $Scale = 1, [string] $Family = 'Arial')
    $Graphics.FillRectangle((Get-RasterBrush @(255, 255, 255)), $Rect)
    $max = 1.0
    foreach ($series in $Chart.Series) { foreach ($v in $series) { if ($v -gt $max) { $max = [double]$v } } }
    $font = Get-RasterFont (9 * $Scale) $false $Family
    $left = $Rect.X + 34 * $Scale
    $bottom = $Rect.Bottom - 22 * $Scale
    $top = $Rect.Y + 10 * $Scale
    $width = $Rect.Right - $left - 8 * $Scale
    $pen = New-Object -TypeName System.Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(180, 180, 180)), ([float]$Scale)
    for ($g = 0; $g -le 4; $g++) {
        $y = $bottom - ($bottom - $top) * $g / 4
        $Graphics.DrawLine($pen, [float]$left, [float]$y, [float]($left + $width), [float]$y)
        $Graphics.DrawString((Format-Number ($max * $g / 4)), $font, (Get-RasterBrush @(90, 90, 90)), [float]$Rect.X, [float]($y - 7 * $Scale))
    }
    $pen.Dispose()
    $groups = $Chart.Labels.Count
    $seriesCount = $Chart.Series.Count
    $groupWidth = $width / [Math]::Max(1, $groups)
    $barWidth = $groupWidth * 0.75 / [Math]::Max(1, $seriesCount)
    for ($i = 0; $i -lt $groups; $i++) {
        for ($s = 0; $s -lt $seriesCount; $s++) {
            $value = [double]$Chart.Series[$s][$i]
            $h = ($bottom - $top) * $value / $max
            $x = $left + $i * $groupWidth + $groupWidth * 0.125 + $s * $barWidth
            $Graphics.FillRectangle((Get-RasterBrush $Chart.Colors[$s % $Chart.Colors.Count]), [float]$x, [float]($bottom - $h), [float]($barWidth * 0.92), [float]$h)
        }
        $Graphics.DrawString([string]$Chart.Labels[$i], $font, (Get-RasterBrush @(60, 60, 60)), [float]($left + $i * $groupWidth + 2 * $Scale), [float]($bottom + 4 * $Scale))
    }
}

#endregion
#region Raster: Seiten, Scans, Bilder, Branding

# Zusaetzliche Raster-Elemente der Anzeigeliste:
#   Grad        X Y W H Color Color2 Angle
#   Texture     X Y W H Kind Seed Color Color2
#   Placeholder X Y W H Text Color      (Bildplatzhalter mit Kreuz und Motivbeschreibung)
#   Chart       X Y W H Chart
#   Stamp       X Y Text Text2 Text3 Color Angle

function Add-RasterItem {
    param([Parameter(Mandatory)] $Graphics, [Parameter(Mandatory)] $Item, [float] $S, [bool] $Gray = $false)
    $color = if ($Item.Color) { $Item.Color } else { @(0, 0, 0) }
    if ($Gray) { $l = [int](0.3 * $color[0] + 0.59 * $color[1] + 0.11 * $color[2]); $color = @($l, $l, $l) }
    switch ($Item.K) {
        'Text' {
            if (-not $Item.Text) { break }
            $family = if ($Item.Family) { $Item.Family } elseif ($Item.Serif) { 'Times New Roman' } else { 'Arial' }
            $font = Get-RasterFont ([float]($Item.Size * $S)) ([bool]$Item.Bold) $family
            $Graphics.DrawString($Item.Text, $font, (Get-RasterBrush $color), [float](($Item.X - $Item.Size * 0.08) * $S), [float](($Item.Y - $Item.Size * 0.12) * $S))
        }
        'Rect' { $Graphics.FillRectangle((Get-RasterBrush $color), [float]($Item.X * $S), [float]($Item.Y * $S), [float]($Item.W * $S), [float]($Item.H * $S)) }
        'Line' {
            $pen = New-Object -TypeName System.Drawing.Pen -ArgumentList (ConvertTo-GdiColor $color), ([float][Math]::Max(1, $Item.Width * $S))
            $Graphics.DrawLine($pen, [float]($Item.X1 * $S), [float]($Item.Y1 * $S), [float]($Item.X2 * $S), [float]($Item.Y2 * $S))
            $pen.Dispose()
        }
        'Poly' {
            $points = for ($i = 0; $i -lt $Item.Points.Count; $i += 2) { New-Object -TypeName System.Drawing.PointF -ArgumentList ([float]($Item.Points[$i] * $S)), ([float]($Item.Points[$i + 1] * $S)) }
            $Graphics.FillPolygon((Get-RasterBrush $color), [Drawing.PointF[]]$points)
        }
        'Ellipse' { $Graphics.FillEllipse((Get-RasterBrush $color), [float]($Item.X * $S), [float]($Item.Y * $S), [float]($Item.W * $S), [float]($Item.H * $S)) }
        'Grad' {
            $rect = New-Object -TypeName System.Drawing.RectangleF -ArgumentList ([float]($Item.X * $S)), ([float]($Item.Y * $S)), ([float]($Item.W * $S)), ([float]($Item.H * $S))
            $brush = New-Object -TypeName System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $rect, (ConvertTo-GdiColor $color), (ConvertTo-GdiColor $Item.Color2), ([float]$Item.Angle)
            $Graphics.FillRectangle($brush, $rect)
            $brush.Dispose()
        }
        'Texture' {
            $rect = New-Object -TypeName System.Drawing.RectangleF -ArgumentList ([float]($Item.X * $S)), ([float]($Item.Y * $S)), ([float]($Item.W * $S)), ([float]($Item.H * $S))
            Add-TextureFill -Graphics $Graphics -Rect $rect -Kind $Item.Kind -Seed $Item.Seed -Color1 $color -Color2 $Item.Color2
        }
        'Placeholder' {
            $x = [float]($Item.X * $S); $y = [float]($Item.Y * $S); $w = [float]($Item.W * $S); $h = [float]($Item.H * $S)
            $Graphics.FillRectangle((Get-RasterBrush @(225, 225, 225)), $x, $y, $w, $h)
            $pen = New-Object -TypeName System.Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(160, 160, 160)), ([float][Math]::Max(1, $S))
            $Graphics.DrawRectangle($pen, $x, $y, $w, $h)
            $Graphics.DrawLine($pen, $x, $y, $x + $w, $y + $h)
            $Graphics.DrawLine($pen, $x + $w, $y, $x, $y + $h)
            $pen.Dispose()
            $box = New-Object -TypeName System.Drawing.RectangleF -ArgumentList ($x + 10 * $S), ($y + $h / 2 - 22 * $S), ($w - 20 * $S), (44 * $S)
            $Graphics.FillRectangle((Get-RasterBrush @(255, 255, 255) 220), $box)
            $format = New-Object -TypeName System.Drawing.StringFormat
            $format.Alignment = [Drawing.StringAlignment]::Center
            $format.LineAlignment = [Drawing.StringAlignment]::Center
            $Graphics.DrawString($Item.Text, (Get-RasterFont (8.5 * $S) $false), (Get-RasterBrush @(70, 70, 70)), $box, $format)
            $format.Dispose()
        }
        'Chart' {
            $rect = New-Object -TypeName System.Drawing.RectangleF -ArgumentList ([float]($Item.X * $S)), ([float]($Item.Y * $S)), ([float]($Item.W * $S)), ([float]($Item.H * $S))
            Add-ChartDrawing -Graphics $Graphics -Rect $rect -Chart $Item.Chart -Scale $S
        }
        'Image' {
            if (-not $Item.Bytes) { break }
            $ms = New-Object -TypeName System.IO.MemoryStream -ArgumentList (, $Item.Bytes)
            $image = [Drawing.Image]::FromStream($ms)
            $Graphics.DrawImage($image, [float]($Item.X * $S), [float]($Item.Y * $S), [float]($Item.W * $S), [float]($Item.H * $S))
            $image.Dispose(); $ms.Dispose()
        }
        'Sign' {
            $pen = New-Object -TypeName System.Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(230, 25, 45, 150)), ([float](1.3 * $S))
            foreach ($seg in (Get-SignatureCurve $Item.X $Item.Y $Item.W $Item.H $Item.Seed)) {
                $Graphics.DrawBezier($pen, [float]($seg[0] * $S), [float]($seg[1] * $S), [float]($seg[2] * $S), [float]($seg[3] * $S), [float]($seg[4] * $S), [float]($seg[5] * $S), [float]($seg[6] * $S), [float]($seg[7] * $S))
            }
            $pen.Dispose()
        }
        'Stamp' {
            $stampColor = if ($Item.Color -eq 'Blue') { [Drawing.Color]::FromArgb(190, 30, 60, 170) } else { [Drawing.Color]::FromArgb(190, 190, 30, 40) }
            $state = $Graphics.Save()
            $Graphics.TranslateTransform([float]($Item.X * $S), [float]($Item.Y * $S))
            $Graphics.RotateTransform([float]$Item.Angle)
            $pen = New-Object -TypeName System.Drawing.Pen -ArgumentList $stampColor, ([float](1.6 * $S))
            $brush = New-Object -TypeName System.Drawing.SolidBrush -ArgumentList $stampColor
            $lines = @($Item.Text, $Item.Text2, $Item.Text3) | Where-Object { $_ }
            $Graphics.DrawRectangle($pen, 0, 0, [float](130 * $S), [float]((14 + 15 * $lines.Count) * $S))
            $y = 7 * $S
            foreach ($line in $lines) {
                $Graphics.DrawString($line, (Get-RasterFont (11 * $S) $true 'Courier New'), $brush, [float](8 * $S), [float]$y)
                $y += 15 * $S
            }
            $pen.Dispose(); $brush.Dispose()
            $Graphics.Restore($state)
        }
    }
}

function Export-RasterPage {
    # Rendert eine Anzeigeliste zu JPEG. Profile: @{ Dpi; Quality; Paper; Gray; Rotate; Holes; Noise }.
    param([Parameter(Mandatory)] $Items, [double] $PageW, [double] $PageH, [Parameter(Mandatory)][hashtable] $RenderProfile)
    $s = [float]($RenderProfile.Dpi / 72.0)
    $pw = [int]($PageW * $s)
    $ph = [int]($PageH * $s)
    $bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $pw, $ph, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $paper = if ($RenderProfile.Paper) { $RenderProfile.Paper } else { @(255, 255, 255) }
        $graphics.Clear((ConvertTo-GdiColor $paper))
        if ($RenderProfile.Rotate) {
            $graphics.TranslateTransform($pw / 2, $ph / 2)
            $graphics.RotateTransform([float]$RenderProfile.Rotate)
            $graphics.TranslateTransform(-$pw / 2, -$ph / 2)
        }
        foreach ($item in $Items) { try { Add-RasterItem -Graphics $graphics -Item $item -S $s -Gray ([bool]$RenderProfile.Gray) } catch { throw ("Raster-Element {0}: {1} {2}" -f $item.K, $_.Exception.Message, $_.ScriptStackTrace) } }
        $graphics.ResetTransform()
        if ($RenderProfile.Holes) {
            $d = 16 * $s
            foreach ($cy in ($ph / 2 - 113 * $s), ($ph / 2 + 113 * $s)) {
                $graphics.FillEllipse((Get-RasterBrush @(205, 205, 205)), [float](18 * $s), [float]($cy - $d / 2), [float]$d, [float]$d)
            }
        }
        if ($RenderProfile.Noise -gt 0) {
            $tile = if ($RenderProfile.Noise -gt 1) { $script:GrainTileStrong } else { $script:GrainTile }
            $brush = New-Object -TypeName System.Drawing.TextureBrush -ArgumentList $tile
            $graphics.FillRectangle($brush, 0, 0, $pw, $ph)
            $brush.Dispose()
        }
        $bytes = ConvertTo-JpegByte $bitmap $(if ($RenderProfile.Quality) { $RenderProfile.Quality } else { 82 })
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    @{ Bytes = $bytes; PixW = $pw; PixH = $ph }
}

function Get-RenderedImage {
    # Eigenstaendiges Bild (fuer DOCX/PPTX/PDF): Anzeigeliste in einem Rechteck WxH Punkt, als JPEG oder PNG.
    param([Parameter(Mandatory)] $Items, [double] $W, [double] $H, [int] $Dpi = 110, [string] $Format = 'jpeg', [int] $Quality = 84, [int] $Noise = 0)
    if ($Format -eq 'jpeg') {
        $page = Export-RasterPage -Items $Items -PageW $W -PageH $H -RenderProfile @{ Dpi = $Dpi; Quality = $Quality; Noise = $Noise }
        return @{ Bytes = $page.Bytes; Format = 'jpeg'; WidthPx = $page.PixW; HeightPx = $page.PixH }
    }
    $s = [float]($Dpi / 72.0)
    $bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList ([int]($W * $s)), ([int]($H * $s)), ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.Clear([Drawing.Color]::Transparent)
        foreach ($item in $Items) { Add-RasterItem -Graphics $graphics -Item $item -S $s }
        $bytes = ConvertTo-PngByte $bitmap
        @{ Bytes = $bytes; Format = 'png'; WidthPx = $bitmap.Width; HeightPx = $bitmap.Height }
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Get-LogoPng {
    # Logo als transparentes PNG fuer Kopfzeilen und Folienmaster (Hoehe in Punkt).
    param([Parameter(Mandatory)] $Ci, [double] $Height = 28, [int] $Dpi = 150)
    $width = if ($Ci.Mark -eq 'Signet') { $Height * 5.2 } else { $Height * 7.0 }
    Get-RenderedImage -Items (Get-LogoItem 0 ($Height * 0.05) ($Height * 0.9) $Ci) -W $width -H $Height -Dpi $Dpi -Format 'png'
}

function Get-LogoSvg {
    # Logo als SVG-Text (Edge-Branding, Logo-Ordner); Breite/Hoehe im svg-Element wie von Edge gefordert.
    param([Parameter(Mandatory)] $Ci, [int] $Width = 520, [int] $Height = 100, [switch] $SignetOnly, [switch] $Negative)
    $size = $Height * 0.9
    $polys = Get-SignetPolygon ($Height * 0.05) ($Height * 0.05) $size
    $toPath = { param($p) $parts = for ($i = 0; $i -lt $p.Count; $i += 2) { '{0},{1}' -f [Math]::Round($p[$i], 2).ToString([Globalization.CultureInfo]::InvariantCulture), [Math]::Round($p[$i + 1], 2).ToString([Globalization.CultureInfo]::InvariantCulture) }; 'M' + ($parts -join ' L') + ' Z' }
    $primary = if ($Negative) { 'FFFFFF' } else { Get-HexColor $Ci.Primary }
    $dark = if ($Negative) { 'FFFFFF' } else { Get-HexColor $Ci.Dark }
    $sb = New-Object -TypeName System.Text.StringBuilder
    [void]$sb.AppendFormat('<svg xmlns="http://www.w3.org/2000/svg" width="{0}" height="{1}" viewBox="0 0 {0} {1}">', $Width, $Height)
    [void]$sb.AppendFormat('<title>{4}</title><path d="{0}" fill="#{1}"/><path d="{2}" fill="#{3}"/>', (& $toPath $polys[0]), $primary, (& $toPath $polys[1]), (Get-HexColor $Ci.Accent), (ConvertTo-XmlText $C.Company.Short))
    if (-not $SignetOnly) {
        $x = [int]($Height * 1.3)
        [void]$sb.AppendFormat('<text x="{0}" y="{1}" font-family="Segoe UI, Arial, sans-serif" font-weight="700" font-size="{2}" fill="#{3}">{4}</text>', $x, [int]($Height * 0.5), [int]($Height * 0.46), $dark, (ConvertTo-XmlText $C.Company.Wordmark[0]))
        [void]$sb.AppendFormat('<text x="{0}" y="{1}" font-family="Segoe UI, Arial, sans-serif" font-size="{2}" fill="#{3}">{4}</text>', $x, [int]($Height * 0.9), [int]($Height * 0.36), $primary, (ConvertTo-XmlText $C.Company.Wordmark[1]))
    }
    [void]$sb.Append('</svg>')
    $sb.ToString()
}

function Export-BrandingPng {
    # Pixelgenaue Branding-Grafik: Items in Pixelkoordinaten (Dpi 72 => 1 Punkt = 1 Pixel).
    param([Parameter(Mandatory)] $Items, [int] $Width, [int] $Height, [string] $Format = 'png', [int] $Quality = 80, [int[]] $Background)
    if ($Background) { $Items = @(@{ K = 'Rect'; X = 0; Y = 0; W = $Width; H = $Height; Color = $Background }) + @($Items) }
    Get-RenderedImage -Items $Items -W $Width -H $Height -Dpi 72 -Format $Format -Quality $Quality
}

#endregion
#region Seitenumbruch: Dokumentmodell -> Anzeigelisten (fuer digitale PDFs und Scans)

# Modell wie beim DOCX-Schreiber (Blocks, Ci, Marking, HeaderLines, FooterLines) plus:
#   Sender  = Company | Foreign | None     Foreign = @{ Name; Lines }
# A4 in Punkt, Raender wie Geschaeftsbrief (DIN 5008 vereinfacht).

$PageW = 595.0
$PageH = 842.0
$MarginLeft = 68.0
$MarginRight = 56.0
$ContentBottom = 772.0

function Add-FlowText {
    param($State, [string] $Text, [double] $Size, [bool] $Bold = $false, [int[]] $Color = $null, [double] $X = -1, [double] $LineHeight = 0, [double] $Width = 0)
    if ($X -lt 0) { $X = $State.Left }
    if ($Width -le 0) { $Width = $State.Width - ($X - $State.Left) }
    if ($LineHeight -le 0) { $LineHeight = $Size * 1.35 }
    if (-not $Color) { $Color = $State.Model.Ci.Dark }
    foreach ($line in (Split-TextLine $Text $Size $Bold $Width)) {
        Assert-PageSpace $State $LineHeight
        $State.Items.Add(@{ K = 'Text'; X = $X; Y = $State.Y; Size = $Size; Bold = $Bold; Serif = $State.Serif; Text = $line; Color = $Color })
        $State.Y += $LineHeight
    }
}

function Assert-PageSpace {
    param($State, [double] $Needed)
    if ($State.Y + $Needed -le $ContentBottom) { return }
    Add-FlowPage $State
}

function Add-FlowPage {
    param($State)
    $State.Items = [System.Collections.Generic.List[object]]::new()
    $State.Pages.Add($State.Items)
    $State.Y = Add-FlowPageHead $State ($State.Pages.Count -eq 1)
}

function Add-FlowPageHead {
    # Kopf je Absender und CI; liefert die Start-Y-Position des Inhalts.
    param($State, [bool] $First)
    $m = $State.Model
    $ci = $m.Ci
    $items = $State.Items
    switch ($m.Sender) {
        'Foreign' {
            $items.Add(@{ K = 'Text'; X = $MarginLeft; Y = 42; Size = 15; Bold = $true; Text = $m.Foreign.Name; Color = @(45, 55, 70) })
            $y = 62
            foreach ($line in @($m.Foreign.Lines)) { $items.Add(@{ K = 'Text'; X = $MarginLeft; Y = $y; Size = 8; Text = $line; Color = @(90, 90, 90) }); $y += 10 }
            $items.Add(@{ K = 'Line'; X1 = $MarginLeft; Y1 = $y + 4; X2 = $PageW - $MarginRight; Y2 = $y + 4; Width = 0.6; Color = @(150, 150, 150) })
        }
        'None' {
            $items.Add(@{ K = 'Text'; X = $PageW - $MarginRight - (Measure-TextWidth $m.CompanyName 8 $false); Y = 36; Size = 8; Text = $m.CompanyName; Color = @(120, 120, 120) })
            $items.Add(@{ K = 'Line'; X1 = $MarginLeft; Y1 = 50; X2 = $PageW - $MarginRight; Y2 = 50; Width = 0.5; Color = $ci.Primary })
        }
        default {
            if ($ci.Mark -eq 'Signet') { $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = $PageW; H = 6; Color = $ci.Primary }) }
            $logoHeight = if ($First) { 30 } else { 18 }
            $logoX = if ($ci.Mark -eq 'Signet') { $PageW - $MarginRight - $logoHeight * 5.0 } else { $MarginLeft }
            foreach ($i in (Get-LogoItem $logoX 34 $logoHeight $ci)) { $items.Add($i) }
            if ($First -and $m.HeaderLines) {
                $senderLine = ($m.HeaderLines -join " $MidDot ")
                $items.Add(@{ K = 'Text'; X = $MarginLeft; Y = 128; Size = 6.8; Text = $senderLine; Color = @(110, 110, 110) })
                $items.Add(@{ K = 'Line'; X1 = $MarginLeft; Y1 = 137; X2 = $MarginLeft + (Measure-TextWidth $senderLine 6.8 $false); Y2 = 137; Width = 0.4; Color = @(150, 150, 150) })
            }
        }
    }
    if ($m.Marking) {
        $items.Add(@{ K = 'Text'; X = $MarginLeft; Y = 20; Size = 7.5; Bold = $true; Text = $m.Marking.ToUpperInvariant(); Color = $ci.Primary })
    }
    if ($First) {
        if ($m.Sender -eq 'Company' -or $m.Sender -eq 'Foreign') { return 112.0 }
        return 76.0
    }
    76.0
}

function Add-FlowPageFoot {
    param($State, $Items, [int] $Number, [int] $Count)
    $m = $State.Model
    if ($m.Sender -eq 'Company' -and $m.FooterLines) {
        $Items.Add(@{ K = 'Line'; X1 = $MarginLeft; Y1 = 786; X2 = $PageW - $MarginRight; Y2 = 786; Width = 0.4; Color = $m.Ci.Primary })
        $y = 792
        foreach ($line in $m.FooterLines) {
            $Items.Add(@{ K = 'Text'; X = $MarginLeft; Y = $y; Size = 6.5; Serif = $State.Serif; Text = $line; Color = @(100, 100, 100) })
            $y += 8.5
        }
    }
    if ($Count -gt 1) {
        $label = $L.Page -f $Number, $Count
        $Items.Add(@{ K = 'Text'; X = $PageW - $MarginRight - (Measure-TextWidth $label 7.5 $false); Y = 816; Size = 7.5; Text = $label; Color = @(100, 100, 100) })
    }
    if ($m.Marking) {
        $Items.Add(@{ K = 'Text'; X = $MarginLeft; Y = 816; Size = 7.5; Bold = $true; Text = $m.Marking; Color = $m.Ci.Primary })
    }
}

function Add-FlowTable {
    param($State, $Block)
    $widths = @($Block.Widths | ForEach-Object { $_ * $State.Width })
    $align = if ($Block.Align) { $Block.Align } else { 'L' * $widths.Count }
    $size = 9.0
    $lh = 12.0
    $rows = [System.Collections.Generic.List[object]]::new()
    if ($Block.Header) { $rows.Add(@{ Cells = $Block.Header; Header = $true }) }
    $index = 0
    foreach ($r in $Block.Rows) {
        $index++
        $rows.Add(@{ Cells = $r; Bold = ($Block.BoldLast -and $index -eq $Block.Rows.Count) })
    }
    foreach ($row in $rows) {
        $bold = [bool]($row.Header -or $row.Bold)
        $cellLines = for ($colIdx = 0; $colIdx -lt $widths.Count; $colIdx++) { , (Split-TextLine ([string]$row.Cells[$colIdx]) $size $bold ($widths[$colIdx] - 8)) }
        $lines = 1
        foreach ($cl in $cellLines) { if ($cl.Count -gt $lines) { $lines = $cl.Count } }
        $height = $lines * $lh + 5
        Assert-PageSpace $State $height
        if ($row.Header) { $State.Items.Add(@{ K = 'Rect'; X = $State.Left; Y = $State.Y; W = $State.Width; H = $height; Color = $State.Model.Ci.Light }) }
        $x = $State.Left
        for ($colIdx = 0; $colIdx -lt $widths.Count; $colIdx++) {
            $ly = $State.Y + 3
            foreach ($text in $cellLines[$colIdx]) {
                $tx = if ($align[$colIdx] -eq 'R') { $x + $widths[$colIdx] - 4 - (Measure-TextWidth $text $size $bold) } else { $x + 4 }
                $State.Items.Add(@{ K = 'Text'; X = $tx; Y = $ly; Size = $size; Bold = $bold; Serif = $State.Serif; Text = $text; Color = $State.Model.Ci.Dark })
                $ly += $lh
            }
            $x += $widths[$colIdx]
        }
        $State.Y += $height
        if (-not $Block.Plain -or $row.Bold) {
            $State.Items.Add(@{ K = 'Line'; X1 = $State.Left; Y1 = $State.Y; X2 = $State.Left + $State.Width; Y2 = $State.Y; Width = $(if ($row.Header) { 0.8 } else { 0.3 }); Color = @(150, 150, 150) })
        }
    }
    $State.Y += 8
}

function Build-FlowPage {
    # Liefert @{ W; H; Pages } mit Pages = Liste von Anzeigelisten.
    param([Parameter(Mandatory)] $Model)
    $state = @{
        Model = $Model; Pages = ([System.Collections.Generic.List[object]]::new()); Items = $null; Y = 0
        Left = $MarginLeft; Width = $PageW - $MarginLeft - $MarginRight; Serif = ($Model.Ci.Font -match 'Times|Georgia')
    }
    Add-FlowPage $state
    $addressBottom = 0
    foreach ($block in $Model.Blocks) {
        switch ($block.T) {
            'Address' {
                $y = 145
                foreach ($line in $block.Lines) { $state.Items.Add(@{ K = 'Text'; X = $MarginLeft; Y = $y; Size = 10; Serif = $state.Serif; Text = $line; Color = $Model.Ci.Dark }); $y += 13 }
                $addressBottom = [Math]::Max($addressBottom, $y)
            }
            'Info' {
                $y = 145
                foreach ($key in $block.Rows.Keys) {
                    $state.Items.Add(@{ K = 'Text'; X = 372; Y = $y; Size = 7.5; Text = [string]$key; Color = @(110, 110, 110) })
                    $state.Items.Add(@{ K = 'Text'; X = 450; Y = $y - 0.5; Size = 9; Serif = $state.Serif; Text = [string]$block.Rows[$key]; Color = $Model.Ci.Dark })
                    $y += 12.5
                }
                $addressBottom = [Math]::Max($addressBottom, $y)
            }
            'Title' {
                if ($addressBottom -gt 0) { $state.Y = [Math]::Max($state.Y, $addressBottom + 26); $addressBottom = 0 }
                $state.Y += 6
                Add-FlowText $state $block.Text 13.5 $true $Model.Ci.Primary
                $state.Y += 6
            }
            'Heading' {
                $state.Y += 8
                Assert-PageSpace $state 40
                Add-FlowText $state $block.Text 11 $true $Model.Ci.Primary
                $state.Y += 2
            }
            'Para' {
                if ($addressBottom -gt 0) { $state.Y = [Math]::Max($state.Y, $addressBottom + 26); $addressBottom = 0 }
                Add-FlowText $state $block.Text 10 $false $null -1 13.4
                $state.Y += 6
            }
            'Bullets' {
                foreach ($item in $block.Items) {
                    Assert-PageSpace $state 14
                    $state.Items.Add(@{ K = 'Text'; X = $MarginLeft + 2; Y = $state.Y; Size = 10; Text = $Bullet; Color = $Model.Ci.Primary })
                    Add-FlowText $state $item 10 $false $null ($MarginLeft + 14) 13.4
                    $state.Y += 2
                }
                $state.Y += 4
            }
            'Table' {
                if ($addressBottom -gt 0) { $state.Y = [Math]::Max($state.Y, $addressBottom + 26); $addressBottom = 0 }
                Add-FlowTable $state $block
            }
            'Image' {
                $w = [Math]::Min($state.Width, $block.WidthCm * 28.35)
                $h = $w * $block.HeightPx / [Math]::Max(1, $block.WidthPx)
                Assert-PageSpace $state ($h + 20)
                $state.Items.Add(@{ K = 'Image'; X = $MarginLeft; Y = $state.Y; W = $w; H = $h; Bytes = $(if ($block.Format -eq 'jpeg') { $block.Bytes } else { $null }); PixW = $block.WidthPx; PixH = $block.HeightPx })
                $state.Y += $h + 4
                if ($block.Caption) { Add-FlowText $state $block.Caption 8 $false @(110, 110, 110) }
                $state.Y += 6
            }
            'Sign' {
                Assert-PageSpace $state 72
                $state.Items.Add(@{ K = 'Sign'; X = $MarginLeft; Y = $state.Y + 4; W = 130; H = 30; Seed = $(if ($block.Seed) { $block.Seed } else { $block.Name.Length * 7 }) })
                $state.Y += 40
                $state.Items.Add(@{ K = 'Line'; X1 = $MarginLeft; Y1 = $state.Y; X2 = $MarginLeft + 170; Y2 = $state.Y; Width = 0.4; Color = @(120, 120, 120) })
                $state.Y += 4
                Add-FlowText $state $block.Name 9.5 $false
                if ($block.Role) { Add-FlowText $state $block.Role 8.5 $false @(100, 100, 100) }
                $state.Y += 8
            }
            'Stamp' {
                $state.Items.Add(@{ K = 'Stamp'; X = $PageW - 230; Y = 96; Text = $block.Text; Text2 = $block.Text2; Text3 = $block.Text3; Color = $block.Color; Angle = -5 - ($block.Text.Length % 4) })
            }
            'Space' { $state.Y += 12 }
            'Break' { Add-FlowPage $state }
        }
    }
    for ($p = 0; $p -lt $state.Pages.Count; $p++) { Add-FlowPageFoot $state $state.Pages[$p] ($p + 1) $state.Pages.Count }
    @{ W = $PageW; H = $PageH; Pages = $state.Pages }
}

function Export-FlowPdf {
    # Modell als digitales PDF oder als Scan (Model.Scan = Profil). Ohne Raster wird ein Scan zum digitalen PDF.
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)] $Model)
    $layout = Build-FlowPage $Model
    $pages = [System.Collections.Generic.List[object]]::new()
    $scan = $Model.Scan -and $UseRaster
    foreach ($items in $layout.Pages) {
        $images = [System.Collections.Generic.List[object]]::new()
        if ($scan) {
            $raster = Export-RasterPage -Items $items -PageW $layout.W -PageH $layout.H -RenderProfile $Model.Scan
            $content = ConvertTo-PdfContent @(@{ K = 'Image'; X = 0; Y = 0; W = $layout.W; H = $layout.H; Bytes = $raster.Bytes; PixW = $raster.PixW; PixH = $raster.PixH }) $layout.H $images
        }
        else {
            $content = ConvertTo-PdfContent $items $layout.H $images
        }
        $pages.Add(@{ W = $layout.W; H = $layout.H; Content = $content; Images = $images })
    }
    $creator = if ($scan -and $Model.Scan.Device) { $Model.Scan.Device } elseif ($scan) { $Model.ScanDevice } elseif ($Model.Creator) { $Model.Creator } else { 'Microsoft Word' }
    $producer = if ($scan) { 'Scan-to-Folder' } else { 'Microsoft: Print To PDF' }
    Write-PdfFile -Path $Path -Pages $pages.ToArray() -Info @{ Title = $Model.Title; Author = $(if ($scan) { '' } else { $Model.Author }); Creator = $creator; Producer = $producer; Created = $Model.Created; Modified = $Model.Modified; Keywords = $Model.Classification }
}

#endregion
#region Fiktive Personendaten (fuer Vertraulichkeitsbezeichnungen, DLP und FSRM-Klassifizierung)

# Prinzip: Formate und Pruefziffern stimmen, damit Purview-SITs und Regex-Regeln greifen. Die Werte treffen keine
# echten Konten oder Karten:
#   - IBAN: BLZ beginnt mit 9; die Bundesbank vergibt als erste Ziffer nur die Clearinggebiete 1 bis 8.
#   - Kreditkarten: veroeffentlichte Testnummern der Kartenanbieter.
#   - Personalausweis der Person aus Locale.Specimen: Nummer des amtlichen Musterausweises.
#   - Telefon: Rufnummern der Bundesnetzagentur fuer Medienproduktionen, E-Mail nur *.example.*.
# Steuer-ID, Ausweis- und Rentenversicherungsnummern anderer Personen sind formal gueltig, aber frei erzeugt.
# Die Kennungen haengen vom Land ab (Locale.Country, siehe Get-NationalId); Get-De* sind die deutschen Verfahren.

$TestCreditCards = @('4111 1111 1111 1111', '4012 8888 8888 1881', '5555 5555 5555 4444', '5105 1051 0510 5100', '3782 822463 10005')
$IdCardFirst = 'LMNPRTVWXY'
$PassportFirst = 'CFGHJK'
$DocumentChars = '0123456789CFGHJKLMNPRTVWXYZ'
$SpecimenIdCard = 'T22000129'

function Get-IcaoCheckDigit {
    # Pruefziffer 7-3-1 (ICAO 9303): Ziffern 0-9, Buchstaben A=10 bis Z=35.
    param([Parameter(Mandatory)][string] $Value)
    $weights = 7, 3, 1
    $sum = 0
    for ($i = 0; $i -lt $Value.Length; $i++) {
        $ch = [char]::ToUpperInvariant($Value[$i])
        $v = if ([char]::IsDigit($ch)) { [int][string]$ch } else { [int]$ch - 55 }
        $sum += $v * $weights[$i % 3]
    }
    $sum % 10
}

function Get-DeIdCardNumber {
    # Personalausweis (seit 2010): 9 Zeichen plus Pruefziffer; fuer das Muster die amtliche Musternummer.
    param([Parameter(Mandatory)] $Rng, [switch] $Specimen)
    $serial = if ($Specimen) { $SpecimenIdCard } else {
        $IdCardFirst[$Rng.Next(0, $IdCardFirst.Length)] + (-join (1..8 | ForEach-Object { $DocumentChars[$Rng.Next(0, $DocumentChars.Length)] }))
    }
    '{0}{1}' -f $serial, (Get-IcaoCheckDigit $serial)
}

function Get-DePassportNumber {
    param([Parameter(Mandatory)] $Rng)
    $serial = $PassportFirst[$Rng.Next(0, $PassportFirst.Length)] + (-join (1..8 | ForEach-Object { $DocumentChars[$Rng.Next(0, $DocumentChars.Length)] }))
    '{0}{1}' -f $serial, (Get-IcaoCheckDigit $serial)
}

function Get-TaxIdCheckDigit {
    # ISO 7064 MOD 11,10 ueber die ersten zehn Ziffern.
    param([Parameter(Mandatory)][string] $Digits)
    $product = 10
    foreach ($ch in $Digits.ToCharArray()) {
        $sum = ([int][string]$ch + $product) % 10
        if ($sum -eq 0) { $sum = 10 }
        $product = ($sum * 2) % 11
    }
    $check = 11 - $product
    if ($check -eq 10) { $check = 0 }
    $check
}

function Get-DeTaxId {
    # Steuer-ID: 11 Ziffern, erste nicht 0, unter den ersten zehn genau eine Ziffer doppelt, Pruefziffer MOD 11,10.
    param([Parameter(Mandatory)] $Rng)
    $pool = @(0..9 | Sort-Object { $Rng.Next() })
    $digits = @($pool[0..8]) + @($pool[$Rng.Next(0, 9)])
    $digits = @($digits | Sort-Object { $Rng.Next() })
    if ($digits[0] -eq 0) {
        $swap = 1 + $Rng.Next(0, 9)
        $digits[0], $digits[$swap] = $digits[$swap], $digits[0]
    }
    $first = -join $digits
    $id = $first + (Get-TaxIdCheckDigit $first)
    '{0} {1} {2} {3}' -f $id.Substring(0, 2), $id.Substring(2, 3), $id.Substring(5, 3), $id.Substring(8, 3)
}

function Get-DeSocialNumber {
    # Rentenversicherungsnummer: Bereich, Geburtsdatum TTMMJJ, Anfangsbuchstabe des Geburtsnamens,
    # Seriennummer (00-49 maennlich, 50-99 weiblich), Pruefziffer.
    param([Parameter(Mandatory)] $Rng, [Parameter(Mandatory)][datetime] $BirthDate, [Parameter(Mandatory)][string] $Surname, [bool] $Female)
    $area = '{0:D2}' -f (Get-RandomEntry $Rng @(12, 13, 15, 23, 24, 25, 28, 65))
    $serial = if ($Female) { 50 + $Rng.Next(0, 50) } else { $Rng.Next(0, 50) }
    $letter = [char]::ToUpperInvariant(($Surname -replace '[^A-Za-z]', 'X')[0])
    $letterNumber = '{0:D2}' -f ([int]$letter - 64)
    $digits = '{0}{1:ddMMyy}{2}{3:D2}' -f $area, $BirthDate, $letterNumber, $serial
    $weights = 2, 1, 2, 5, 7, 1, 2, 1, 2, 1, 2, 1
    $sum = 0
    for ($i = 0; $i -lt 12; $i++) {
        $product = [int][string]$digits[$i] * $weights[$i]
        $sum += [Math]::Floor($product / 10) + ($product % 10)
    }
    '{0} {1:ddMMyy} {2} {3:D2}{4}' -f $area, $BirthDate, $letter, $serial, ($sum % 10)
}

function Get-DeIban {
    # Deutsche IBAN mit korrekter Pruefziffer (MOD 97) und BLZ 9xxxxxxx (nicht vergebenes Clearinggebiet).
    param([Parameter(Mandatory)] $Rng)
    $blz = '9' + (-join (1..7 | ForEach-Object { $Rng.Next(0, 10) }))
    $account = -join (1..10 | ForEach-Object { $Rng.Next(0, 10) })
    $numeric = $blz + $account + '131400'
    $remainder = 0
    foreach ($ch in $numeric.ToCharArray()) { $remainder = ($remainder * 10 + [int][string]$ch) % 97 }
    $iban = 'DE{0:D2}{1}{2}' -f (98 - $remainder), $blz, $account
    ($iban -replace '(.{4})', '$1 ').Trim()
}

function Get-GbTaxReference {
    # Unique Taxpayer Reference (HMRC): 10 Ziffern, die erste ist die Pruefziffer ueber die Ziffern 2-10
    # (Gewichte 6,7,8,9,10,5,4,3,2, Rest MOD 11 ueber Tabelle).
    param([Parameter(Mandatory)] $Rng)
    $digits = @(1..9 | ForEach-Object { $Rng.Next(0, 10) })
    $weights = 6, 7, 8, 9, 10, 5, 4, 3, 2
    $sum = 0
    for ($i = 0; $i -lt 9; $i++) { $sum += $digits[$i] * $weights[$i] }
    $check = @(2, 1, 9, 8, 7, 6, 5, 4, 3, 2, 1)[$sum % 11]
    $id = '{0}{1}' -f $check, (-join $digits)
    '{0} {1}' -f $id.Substring(0, 5), $id.Substring(5, 5)
}

function Get-GbInsuranceNumber {
    # National Insurance number: zwei Buchstaben (ohne D, F, I, Q, U, V; zweiter auch ohne O; nicht BG, GB, NK, KN,
    # TN, NT, ZZ), sechs Ziffern, Endbuchstabe A-D.
    param([Parameter(Mandatory)] $Rng)
    $first = 'ABCEGHJKLMNOPRSTWXYZ'
    $second = 'ABCEGHJKLMNPRSTWXYZ'
    do { $prefix = '{0}{1}' -f $first[$Rng.Next(0, $first.Length)], $second[$Rng.Next(0, $second.Length)] } while ($prefix -in 'BG', 'GB', 'NK', 'KN', 'TN', 'NT', 'ZZ')
    '{0} {1:D2} {2:D2} {3:D2} {4}' -f $prefix, $Rng.Next(0, 100), $Rng.Next(0, 100), $Rng.Next(0, 100), 'ABCD'[$Rng.Next(0, 4)]
}

function Get-GbPassportNumber {
    # Britischer Reisepass: neun Ziffern; fuer die Musterperson eine feste Nummer.
    param([Parameter(Mandatory)] $Rng, [switch] $Specimen)
    if ($Specimen) { return '123456789' }
    '{0}{1}' -f (1 + $Rng.Next(0, 9)), (-join (1..8 | ForEach-Object { $Rng.Next(0, 10) }))
}

function Get-GbIban {
    # Britische IBAN: Bankkuerzel XMPL (fiktiv), Sort Code, Kontonummer, Pruefziffer MOD 97 (Buchstaben A=10 bis Z=35).
    param([Parameter(Mandatory)] $Rng)
    $bank = 'XMPL'
    $sortCode = '{0}{1}' -f (10 + $Rng.Next(0, 90)), (-join (1..4 | ForEach-Object { $Rng.Next(0, 10) }))
    $account = -join (1..8 | ForEach-Object { $Rng.Next(0, 10) })
    $numeric = -join (($bank + $sortCode + $account + 'GB00').ToCharArray() | ForEach-Object { if ([char]::IsDigit($_)) { [string]$_ } else { [string]([int]$_ - 55) } })
    $remainder = 0
    foreach ($ch in $numeric.ToCharArray()) { $remainder = ($remainder * 10 + [int][string]$ch) % 97 }
    $iban = 'GB{0:D2}{1}{2}{3}' -f (98 - $remainder), $bank, $sortCode, $account
    ($iban -replace '(.{4})', '$1 ').Trim()
}

function Get-NationalId {
    # Landesspezifische Kennung nach Locale.Country: TaxId, Social, IdCard oder Iban.
    # Ein weiteres Land braucht hier einen eigenen Zweig (gleiche Reihenfolge der Zufallszahlen ist nicht noetig).
    param(
        [Parameter(Mandatory)][ValidateSet('TaxId', 'Social', 'IdCard', 'Iban')][string] $Kind,
        [Parameter(Mandatory)] $Rng,
        [datetime] $BirthDate,
        [string] $Surname = '',
        [bool] $Female = $false,
        [switch] $Specimen
    )
    switch ($Locale.Country) {
        'DE' {
            switch ($Kind) {
                'TaxId' { return Get-DeTaxId $Rng }
                'Social' { return Get-DeSocialNumber $Rng $BirthDate $Surname $Female }
                'IdCard' { return Get-DeIdCardNumber $Rng -Specimen:$Specimen }
                'Iban' { return Get-DeIban $Rng }
            }
        }
        'GB' {
            switch ($Kind) {
                'TaxId' { return Get-GbTaxReference $Rng }
                'Social' { return Get-GbInsuranceNumber $Rng }
                'IdCard' { return Get-GbPassportNumber $Rng -Specimen:$Specimen }
                'Iban' { return Get-GbIban $Rng }
            }
        }
        default { throw "Locale.Country '$($Locale.Country)' wird nicht unterstuetzt (Get-NationalId)." }
    }
}

function Get-CreditCard {
    param([Parameter(Mandatory)] $Rng)
    Get-RandomEntry $Rng $TestCreditCards
}

function Get-Dial {
    # Durchwahl-Format (Sites[].Dial) zum Standort oder Ort; sonst die Zentrale.
    param([string] $Place)
    if ($Place -and $DialByPlace.ContainsKey($Place)) { return $DialByPlace[$Place] }
    $HqSite.Dial
}

function Get-DramaPhone {
    # Rufnummern fuer Medienproduktionen (Bundesnetzagentur, Mitteilung 148/2021): Festnetz aus Sites[].Dial,
    # Mobil aus Locale.Mobiles. Private Nummern ab 600, damit sie nicht mit den Firmennummern kollidieren.
    param([Parameter(Mandatory)] $Rng, [string] $City = $HqSite.City, [switch] $Mobile)
    if ($Mobile) {
        $range = $Locale.Mobiles[$Rng.Next(0, $Locale.Mobiles.Count)]
        return $range.Format -f ($range.Min + $Rng.Next(0, $range.Span))
    }
    (Get-Dial $City) -f (600 + $Rng.Next(0, 400))
}

function Get-PrivateMail {
    param([Parameter(Mandatory)] $Rng, [Parameter(Mandatory)][string] $GivenName, [Parameter(Mandatory)][string] $Surname)
    $local = ('{0}.{1}' -f $GivenName, $Surname).ToLowerInvariant()
    $local = $local.Replace([string][char]0xE4, 'ae').Replace([string][char]0xF6, 'oe').Replace([string][char]0xFC, 'ue').Replace([string][char]0xDF, 'ss') -replace '[^a-z0-9.\-]', ''
    '{0}@{1}' -f $local, (Get-RandomEntry $Rng @('mail.example.com', 'post.example.net', 'web.example.org'))
}

function Get-PersonProfile {
    # Stabile Stammdaten einer Person (gleicher Schluessel = gleiche Daten in allen Dokumenten).
    param([Parameter(Mandatory)][string] $Key, [Parameter(Mandatory)][string] $GivenName, [Parameter(Mandatory)][string] $Surname, [int] $BirthYear = 1985, [string] $City = $HqSite.City, [bool] $Female = $false)
    $hash = 0
    foreach ($ch in $Key.ToCharArray()) { $hash = ($hash * 31 + [int]$ch) % 1000003 }
    $rng = Get-Rng -Index $hash -Salt 71
    $birth = (New-Object -TypeName DateTime -ArgumentList $BirthYear, 1, 1).AddDays($rng.Next(0, 365))
    # Musterperson des Landes (Locale.Specimen): amtliche Musternummer und Geburtsdatum des Musterausweises.
    $isSpecimen = [bool]$Locale.Specimen -and (('{0} {1}' -f $GivenName, $Surname) -eq $Locale.Specimen.Name)
    if ($isSpecimen) { $birth = [datetime]::ParseExact($Locale.Specimen.Birth, 'yyyy-MM-dd', $Inv) }
    @{
        Name     = '{0} {1}' -f $GivenName, $Surname
        Birth    = $birth
        BirthPlace = Get-RandomEntry $rng $C.BirthPlaces
        Street   = $Locale.StreetLine -f (Get-RandomEntry $rng $C.Streets), $rng.Next(1, 140)
        City     = $Locale.CityLine -f (Get-PostalCode $rng $City), $City
        Phone    = Get-DramaPhone $rng $City
        Mobile   = Get-DramaPhone $rng -Mobile
        Mail     = Get-PrivateMail $rng $GivenName $Surname
        TaxId    = Get-NationalId 'TaxId' $rng
        Social   = Get-NationalId 'Social' $rng -BirthDate $birth -Surname $Surname -Female $Female
        IdCard   = Get-NationalId 'IdCard' $rng -Specimen:$isSpecimen
        Iban     = Get-NationalId 'Iban' $rng
        Bank     = Get-RandomEntry $rng $C.Banks
        Insurer  = Get-RandomEntry $rng $C.Insurers
        TaxClass = Get-RandomEntry $rng $Locale.TaxClasses
        Marital  = Get-RandomEntry $rng @($L.Single, $L.Single, $L.Married)
        Confession = Get-RandomEntry $rng @($L.NoConfession, $L.NoConfession, $L.Catholic, $L.Protestant)
        Children = $rng.Next(0, 3)
    }
}

#endregion
#region Welt: Korpus, Personen, Kunden, CI, Texte

function Import-SampleCorpus {
    # Korpus aus -CorpusPath (lokal/Tests) oder aus der userData der VM (gzip-JSON, per IMDS).
    $target = Join-Path $ScriptDir 'corpus'
    if (-not $CorpusPath) {
        try {
            # IMDS ist kurz nach dem Start oder bei Last nicht immer sofort erreichbar: bis zu fuenf Versuche.
            for ($attempt = 1; ; $attempt++) {
                try {
                    $request = [Net.WebRequest]::Create('http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text')
                    $request.Headers.Add('Metadata', 'true')
                    $request.Proxy = $null
                    $request.Timeout = 15000
                    $response = $request.GetResponse()
                    $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $response.GetResponseStream()
                    $b64 = $reader.ReadToEnd().Trim()
                    $reader.Dispose(); $response.Dispose()
                    break
                }
                catch {
                    if ($attempt -ge 5) { throw }
                    Write-LabLog "userData (IMDS) nicht lesbar, Versuch $attempt/5: $($_.Exception.Message)"
                    Start-Sleep -Seconds 15
                }
            }
            $inputStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList (, [Convert]::FromBase64String($b64))
            $gzip = New-Object -TypeName System.IO.Compression.GZipStream -ArgumentList $inputStream, ([IO.Compression.CompressionMode]::Decompress)
            $output = New-Object -TypeName System.IO.MemoryStream
            $gzip.CopyTo($output)
            $gzip.Dispose()
            $json = [Text.Encoding]::UTF8.GetString($output.ToArray()) | ConvertFrom-Json
            New-Item -Path $target -ItemType Directory -Force | Out-Null
            foreach ($property in $json.PSObject.Properties) { Write-Utf8File -Path (Join-Path $target $property.Name) -Content $property.Value }
            Write-LabLog "Textkorpus aus userData gelesen ($(@($json.PSObject.Properties).Count) Dateien)."
        }
        catch {
            Write-LabLog "WARNUNG: userData nicht lesbar ($($_.Exception.Message)), nutze vorhandene Kopie."
        }
        $script:CorpusPath = $target
    }
    $files = @(Get-ChildItem -Path $CorpusPath -Filter '*.psd1' -File)
    if (-not ($files | Where-Object Name -EQ 'Company.psd1')) { throw "Textkorpus fehlt: $CorpusPath\Company.psd1" }
    $script:C = Import-PowerShellDataFile -Path (Join-Path $CorpusPath 'Company.psd1')
    $script:L = $C.Labels
    $script:F = $C.FolderNames
    # Alles Sprach- und Landesabhaengige kommt aus dem Korpus (siehe scripts/data/README.md).
    $script:Locale = $C.Locale
    $script:Culture = [Globalization.CultureInfo]::GetCultureInfo($Locale.Culture)
    $script:Paths = $C.Paths
    $script:Roles = $C.Roles
    $script:Office = $C.Office
    $script:Patterns = $C.Patterns
    # Name eines Bereichs im Archiv = letzter Teil seines Pfads (Abteilungen\Buchhaltung -> Buchhaltung).
    $script:AreaName = @{}
    foreach ($key in $Paths.Keys) { $AreaName[$key] = ($Paths[$key] -split '\\')[-1] }
    # Anrede im Kontakt (Locale.Salutations), z. B. "Frau " vor dem Namen.
    $script:SalutationPattern = '^({0}) ' -f ((@($Locale.Salutations.Keys) | ForEach-Object { [regex]::Escape($_) }) -join '|')
    $script:T = @{}
    foreach ($file in $files | Where-Object Name -Like 'Texts-*') {
        $data = Import-PowerShellDataFile -Path $file.FullName
        foreach ($key in $data.Keys) { $script:T[$key] = @($data[$key]) }
    }
}

function Test-Female {
    param([string] $GivenName)
    $GivenName -match $Patterns.Female
}

function Initialize-World {
    # Personen (aktuell und ehemalig), Kunden, Standorte; Daten relativ zum Stichtag.
    $labUsers = (Import-PowerShellDataFile -Path $LabUsersPath).Users
    $script:People = @(foreach ($e in $C.Employees) {
            $lab = $labUsers | Where-Object SamAccountName -EQ $e.Sam | Select-Object -First 1
            $given = if ($lab) { $lab.GivenName } else { $e.GivenName }
            $surname = if ($lab) { $lab.Surname } else { $e.Surname }
            $rng = Get-Rng -Index ($e.Sam.Length * 977 + [int][char]$e.Sam[1]) -Salt 17
            $entryDate = $Reference.AddDays( - [int]($e.Entry * 365)).AddDays( - $rng.Next(0, 120))
            $entryDate = New-Object -TypeName DateTime -ArgumentList $entryDate.Year, $entryDate.Month, 1
            $leaveDate = if ($e.Leave -gt 0) { $Reference.AddDays( - [int]($e.Leave * 365)) } else { $null }
            @{
                Sam = $e.Sam; GivenName = $given; Surname = $surname; Name = "$given $surname"; Initials = ('{0}{1}' -f $given[0], $surname[0]).ToLowerInvariant()
                Role = $e.Role; Department = $e.Department; Site = $e.Site; Salary = $e.Salary; Born = $e.Born; Grade = $e.Grade
                # Female im Drehbuch schlaegt die Erkennung am Vornamen (Patterns.Female), z. B. fuer Megan oder Lee.
                Entry = $entryDate; Leave = $leaveDate; Lab = [bool]$lab; Female = $(if ($e.ContainsKey('Female')) { [bool]$e.Female } else { Test-Female $given })
            }
        })
    $script:PeopleBySam = @{}
    foreach ($p in $People) { $PeopleBySam[$p.Sam] = $p }
    $script:SiteOpened = @{}
    foreach ($site in $C.Company.Sites) { $SiteOpened[$site.Name] = $Reference.AddDays( - [int]($site.OpenedYearsAgo * 365)) }
    # Zentrale (Key HQ) und Niederlassung (Key Branch); Durchwahl je Standortname und Ort.
    $script:HqSite = $C.Company.Sites | Where-Object Key -EQ 'HQ' | Select-Object -First 1
    $script:BranchSite = $C.Company.Sites | Where-Object Key -EQ 'Branch' | Select-Object -First 1
    $script:DialByPlace = @{}
    foreach ($site in $C.Company.Sites) { $DialByPlace[$site.City] = $site.Dial; $DialByPlace[$site.Name] = $site.Dial }
    $script:TaxAdvisor = $C.Suppliers | Where-Object Role -EQ 'TaxAdvisor' | Select-Object -First 1
    $script:Founded = $SiteOpened[$HqSite.Name]
    $scanner = $C.Timeline | Where-Object Event -EQ 'Scanner' | Select-Object -First 1
    $script:ScannerDate = if ($scanner) { New-Object -TypeName DateTime -ArgumentList ($Reference.Year - $scanner.YearsAgo), $scanner.Month, 1 } else { $Reference }
}

function Get-ActivePerson {
    # Personen, die am Datum beschaeftigt sind; optional Standort/Abteilung.
    param([datetime] $Date, [string] $Site = '', [string] $Department = '')
    @($People | Where-Object { $_.Entry -le $Date -and (-not $_.Leave -or $_.Leave -gt $Date) -and (-not $Site -or $_.Site -eq $Site) -and (-not $Department -or $_.Department -eq $Department) })
}

function Get-Person {
    # Bevorzugt die genannte Person (bei einer Liste, z. B. Roles mit Nachfolge, die erste am Datum beschaeftigte),
    # sonst jemand Aktives vom Standort.
    param($Sam, [datetime] $Date, [string] $Site = $HqSite.Name, $Rng)
    foreach ($candidate in @($Sam)) {
        $p = $PeopleBySam[[string]$candidate]
        if ($p -and $p.Entry -le $Date -and (-not $p.Leave -or $p.Leave -gt $Date)) { return $p }
    }
    $active = Get-ActivePerson -Date $Date -Site $Site
    if (-not $active) { $active = Get-ActivePerson -Date $Date }
    if (-not $active) { return $People[0] }
    Get-RandomEntry $Rng $active
}

function Test-CustomerActive {
    param($Customer, [int] $YearsAgo)
    ($Customer.Since -ge $YearsAgo) -and ($Customer.Until -le $YearsAgo)
}

function Get-DocumentCi {
    # CI zum Datum: vor dem Rebranding alt, danach neu; mit Logo (PNG), Kopf- und Fusszeilen des Standorts.
    param([datetime] $Date, [string] $Site = $HqSite.Name)
    $old = ($Reference - $Date).TotalDays -gt ($C.Ci.RebrandYearsAgo * 365)
    $key = '{0}|{1}|{2}' -f $old, $Site, ($Date -lt $Reference.AddDays( - [int]((5 * 365))))
    if (-not $script:CiCache) { $script:CiCache = @{} }
    if ($CiCache.ContainsKey($key)) { return $CiCache[$key] }
    $base = if ($old) { $C.Ci.Old } else { $C.Ci.New }
    $siteData = $C.Company.Sites | Where-Object Name -EQ $Site | Select-Object -First 1
    if (-not $siteData) { $siteData = $C.Company.Sites[0] }
    # Vor dem Umzug (Move vor 5 Jahren) die alte Adresse der Zentrale (OldStreet).
    $street = if ($siteData.OldStreet -and $Date -lt $Reference.AddDays( - 5 * 365)) { $siteData.OldStreet } else { $siteData.Street }
    $ci = @{
        Primary = $base.Primary; Accent = $base.Accent; Light = $base.Light; Dark = $base.Dark; Font = $base.Font; TitleFont = $base.TitleFont; Mark = $base.Mark
        HeaderLines = @($C.Company.Name, $street, ($Locale.CityLine -f $siteData.PostalCode, $siteData.City))
        FooterLines = @(
            ('{0} {1} {2} {3} {4} {8} {5} {6} {7}' -f $C.Company.Name, $MidDot, $street, ($Locale.CityLine -f $siteData.PostalCode, $siteData.City), $MidDot, $siteData.Phone, $MidDot, $C.Company.Web, $L.Phone)
            ('{0} {1} {2} {3} {7} {4} {5} {6}' -f $C.Company.Managers, $MidDot, $C.Company.Register, $MidDot, $script:CompanyIban, $MidDot, $C.Company.VatId, $L.Iban)
        )
        LogoPng = $null; LogoWidthPx = 0; LogoHeightPx = 0
    }
    if ($UseRaster) {
        $logo = Get-LogoPng $ci
        $ci.LogoPng = $logo.Bytes; $ci.LogoWidthPx = $logo.WidthPx; $ci.LogoHeightPx = $logo.HeightPx
    }
    $CiCache[$key] = $ci
    $ci
}

function Get-TextRecord {
    # Eintrag einer Art; bevorzugt passende Branche und Stimme, faellt auf allgemeine Eintraege zurueck.
    param([Parameter(Mandatory)][string] $Kind, [Parameter(Mandatory)] $Rng, [string] $Industry = '', [string] $Voice = '', [hashtable] $Where = @{})
    $all = @($T[$Kind])
    if (-not $all) { return @{ Text = '' } }
    foreach ($key in $Where.Keys) { $all = @($all | Where-Object { "$($_[$key])" -eq "$($Where[$key])" }) }
    $fitting = @($all | Where-Object { (-not $_.Industry -or $_.Industry -eq $Industry) -and (-not $_.Voice -or $_.Voice -eq $Voice) })
    if (-not $fitting) { $fitting = $all }
    $special = @($fitting | Where-Object { ($Industry -and $_.Industry -eq $Industry) -or ($Voice -and $_.Voice -eq $Voice) })
    if ($special -and $Rng.Next(0, 10) -lt 7) { return Get-RandomEntry $Rng $special }
    Get-RandomEntry $Rng $fitting
}

function Get-SampleText {
    param([Parameter(Mandatory)][string] $Kind, [Parameter(Mandatory)] $Rng, [Parameter(Mandatory)][hashtable] $Context, [hashtable] $Where = @{})
    $record = Get-TextRecord -Kind $Kind -Rng $Rng -Industry $Context.Industry -Voice $Context.Voice -Where $Where
    Expand-SampleText $record.Text $Context
}

function Get-Salutation {
    # Kontakt "<Anrede> [Titel] Vorname Nachname" -> Locale.Salutations[<Anrede>] [Titel] Nachname,
    # z. B. "Frau Dr. Karin Vogt" -> "Sehr geehrte Frau Dr. Vogt". Ohne bekannte Anrede Labels.Salutation.
    param([string] $Contact)
    $parts = $Contact -split ' '
    $title = ($parts | Where-Object { $_ -match $Patterns.AcademicTitle }) -join ' '
    $lead = $Locale.Salutations[$parts[0]]
    if (-not $lead) { return $L.Salutation }
    ('{0} {1} {2}' -f $lead, $title, $parts[-1]) -replace '\s+', ' '
}

function Get-TextContext {
    # Platzhalterwerte fuer Texte (siehe scripts/data/README.md).
    param([Parameter(Mandatory)] $Rng, [datetime] $Date, $Customer = $null, [string] $Project = '', $Author = $null, $Colleague = $null)
    if (-not $Author) { $Author = Get-Person $Roles.Ceo $Date $HqSite.Name $Rng }
    if (-not $Colleague) {
        $others = @(Get-ActivePerson -Date $Date -Site $Author.Site | Where-Object Sam -NE $Author.Sam)
        $Colleague = if ($others) { Get-RandomEntry $Rng $others } else { $Author }
    }
    $lead = $PeopleBySam[($C.Company.Sites | Where-Object Name -EQ $Author.Site | Select-Object -First 1).Lead]
    $ctx = @{
        Firma = $C.Company.Name; Standort = $Author.Site; Ich = $Author.Name; IchVorname = $Author.GivenName; Voice = $Author.Sam
        Kollege = $Colleague.Name; KollegeVorname = $Colleague.GivenName; Leitung = $(if ($lead) { $lead.Name } else { $Author.Name })
        Datum = (Format-LocalDate $Date); Termin = (Format-LocalDate $Date.AddDays($Rng.Next(7, 21))); Termin2 = (Format-LocalDate $Date.AddDays($Rng.Next(25, 60)))
        Vortermin = (Format-LocalDate $Date.AddDays( - $Rng.Next(5, 20))); Monat = $C.Months[$Date.Month - 1]; Jahr = $Date.Year; Quartal = ('Q{0}' -f [Math]::Ceiling($Date.Month / 3))
        Betrag = (Format-Money ($Rng.Next(12, 160) * 100)); Budget = (Format-Money ($Rng.Next(8, 90) * 500)); Stunden = $Rng.Next(8, 80)
        Auflage = (Format-Number ($Rng.Next(1, 40) * 500)); Prozent = $Rng.Next(5, 40)
        Zielgruppe = (Get-RandomEntry $Rng $C.Audiences); Kanal = (Get-RandomEntry $Rng $C.Channels); Kanal2 = (Get-RandomEntry $Rng $C.Channels)
        Lieferant = (Get-RandomEntry $Rng $C.Suppliers).Name; Projekt = $Project; Stelle = (Get-RandomEntry $Rng $C.Positions)
        Mitarbeiter = $Colleague.Name; Bewerber = ('{0} {1}' -f (Get-RandomEntry $Rng $C.FirstNames), (Get-RandomEntry $Rng $C.LastNames))
        Eintritt = (Format-LocalDate $Colleague.Entry); Austritt = $(if ($Colleague.Leave) { Format-LocalDate $Colleague.Leave } else { Format-LocalDate $Date })
        Kunde = ''; KundeKurz = ''; Anrede = $L.Salutation; Ansprechpartner = ''; Branche = ''; Produkt = ''; Stadt = $HqSite.City; Claim = ''; Motiv = ''
        # Branchen-ID fuer die Textauswahl (Industry in Texts-*.psd1); Branche ist der Anzeigename.
        Industry = ''
    }
    if ($Customer) {
        $ctx.Kunde = $Customer.Name; $ctx.KundeKurz = $Customer.Short; $ctx.Anrede = Get-Salutation $Customer.Contact
        $ctx.Ansprechpartner = $Customer.Contact; $ctx.Branche = $C.Industries[$Customer.Industry]; $ctx.Produkt = $Customer.Product; $ctx.Stadt = $Customer.City
        $ctx.Industry = $Customer.Industry
    }
    if ($T.Claim) { $ctx.Claim = Expand-SampleText (Get-TextRecord -Kind 'Claim' -Rng $Rng -Industry $ctx.Industry).Text $ctx }
    if ($T.Motif) { $ctx.Motiv = Expand-SampleText (Get-TextRecord -Kind 'Motif' -Rng $Rng -Industry $ctx.Industry).Text $ctx }
    $ctx
}

function ConvertFrom-HexColor {
    param([string] $Hex)
    @([Convert]::ToInt32($Hex.Substring(0, 2), 16), [Convert]::ToInt32($Hex.Substring(2, 2), 16), [Convert]::ToInt32($Hex.Substring(4, 2), 16))
}

#endregion

function Get-PostalCode {
    # Plausible Postleitzahl je Ort (Locale.PostalCodes: Format, Minimum, Anzahl); sonst Locale.PostalCode.
    param([Parameter(Mandatory)] $Rng, [string] $City)
    if ($City -and $Locale.PostalCodes.ContainsKey($City)) {
        $range = $Locale.PostalCodes[$City]
        return $range[0] -f ($range[1] + $Rng.Next(0, $range[2]))
    }
    $Locale.PostalCode
}

function Get-ScanProfile {
    # Scanprofil je Datum: bis zum Scanner-Wechsel der alte Kopierer (200 dpi, oft grau, schief, Rauschen),
    # danach das Multifunktionsgeraet (150 dpi, Farbe, sauberer). Gelocht wird nur, was abgeheftet war.
    param([Parameter(Mandatory)] $Rng, [datetime] $Date)
    $sign = if ($Rng.Next(0, 2) -eq 0) { -1 } else { 1 }
    if ($Date -lt $ScannerDate) {
        return @{ Device = $L.Copier; Dpi = 200; Quality = 72; Gray = ($Rng.Next(0, 10) -lt 7); Paper = @(246, 244, 236)
            Rotate = $sign * (0.2 + $Rng.NextDouble() * 0.7); Holes = ($Rng.Next(0, 10) -lt 4); Noise = 2 }
    }
    @{ Device = 'MFP Scan-to-Folder'; Dpi = 150; Quality = 80; Gray = ($Rng.Next(0, 10) -lt 3); Paper = @(252, 252, 250)
        Rotate = $sign * $Rng.NextDouble() * 0.4; Holes = ($Rng.Next(0, 4) -eq 0); Noise = 1 }
}

function Get-DistinctSampleText {
    # Mehrere verschiedene Texte einer Art (so viele, wie der Korpus hergibt).
    param([Parameter(Mandatory)][string] $Kind, [Parameter(Mandatory)] $Rng, [hashtable] $Context = @{}, [int] $Count = 2)
    $texts = [System.Collections.Generic.List[string]]::new()
    for ($try = 0; $try -lt $Count * 6 -and $texts.Count -lt $Count; $try++) {
        $text = Get-SampleText $Kind $Rng $Context
        if ($text -and -not $texts.Contains($text)) { $texts.Add($text) }
    }
    , $texts.ToArray()
}
#region Gestaltung: Entwuerfe, Druckdaten, Moodboard, Folien (Anzeigelisten in Punkt)

# Masse der Werbemittel je Motifs[].Format (Punkt) und Aufloesung fuer Entwurf und Druckdaten.
$ShapeSizes = @{
    Flyer         = @{ W = 420; H = 595; DraftDpi = 90; PrintDpi = 300 }
    Poster        = @{ W = 1684; H = 2384; DraftDpi = 30; PrintDpi = 150 }
    Brochure      = @{ W = 595; H = 842; DraftDpi = 72; PrintDpi = 300 }
    Ad            = @{ W = 595; H = 842; DraftDpi = 80; PrintDpi = 300 }
    SocialPost    = @{ W = 540; H = 540; DraftDpi = 96; PrintDpi = 144; Online = $true }
    Banner        = @{ W = 900; H = 300; DraftDpi = 96; PrintDpi = 160; Online = $true }
    # Grossformate 1:1 mit niedriger Aufloesung, wie im Digitaldruck ueblich.
    TradeShowWall = @{ W = 8504; H = 7087; DraftDpi = 6; PrintDpi = 50 }
    SiteSign      = @{ W = 8504; H = 5669; DraftDpi = 6; PrintDpi = 50 }
    Vehicle       = @{ W = 12756; H = 5102; DraftDpi = 5; PrintDpi = 40 }
    DieCut        = @{ W = 1684; H = 1191; DraftDpi = 40; PrintDpi = 300 }
    PosterSeries  = @{ W = 1684; H = 2384; DraftDpi = 30; PrintDpi = 150 }
    AdSeries      = @{ W = 595; H = 842; DraftDpi = 80; PrintDpi = 300 }
    SocialSeries  = @{ W = 540; H = 540; DraftDpi = 72; PrintDpi = 144; Online = $true }
    WebDesign     = @{ W = 1440; H = 3200; DraftDpi = 36; PrintDpi = 72; Online = $true }
}
$IndustryTexture = @{ Hospitality = 'Wood'; Crafts = 'Wood'; Hotel = 'Clouds'; Energy = 'Clouds'; RealEstate = 'Stone'; Health = 'Paper'; IT = 'Stone'; Culture = 'Clouds'; Leisure = 'Clouds'; Club = 'Clouds'; Education = 'Paper'; Retail = 'Paper' }

function Get-MixedColor {
    param([int[]] $A, [int[]] $B, [double] $T)
    @([int]($A[0] + ($B[0] - $A[0]) * $T), [int]($A[1] + ($B[1] - $A[1]) * $T), [int]($A[2] + ($B[2] - $A[2]) * $T))
}

function Add-WrappedItem {
    # Mehrzeiliger Text als Anzeigeliste; liefert die Y-Position unter dem Text.
    param($Items, [string] $Text, [double] $X, [double] $Y, [double] $Width, [double] $Size, [bool] $Bold, [int[]] $Color, [int] $MaxLines = 6, [string] $Family = '')
    $lines = Split-TextLine $Text $Size $Bold $Width
    if ($lines.Count -gt $MaxLines) { $lines = $lines[0..($MaxLines - 1)] }
    foreach ($line in $lines) {
        $Items.Add(@{ K = 'Text'; X = $X; Y = $Y; Size = $Size; Bold = $Bold; Text = $line; Color = $Color; Family = $Family })
        $Y += $Size * 1.18
    }
    $Y
}

function Get-DesignItem {
    # Werbemittel eines Kunden: Variante A (Bild oben), B (Vollflaeche mit Band), C (geteilt).
    # Stage Draft = Entwurf mit Bildplatzhaltern und Vermerk, Final = Druckdaten mit Schnittmarken.
    param([Parameter(Mandatory)] $Ctx, [Parameter(Mandatory)] $Customer, [double] $W, [double] $H, [string] $Variant = 'A', [string] $Stage = 'Draft', [int] $Seed = 1, [string] $Motif = '', [datetime] $Date)
    $rng = Get-Rng -Index $Seed -Salt 23
    $colors = $Customer.Colors -split ' '
    $c1 = ConvertFrom-HexColor $colors[0]
    $c2 = ConvertFrom-HexColor $colors[1]
    $light = Get-MixedColor $c2 @(255, 255, 255) 0.75
    $kind = $IndustryTexture[$Customer.Industry]
    if (-not $kind) { $kind = 'Paper' }
    $placeholder = ($Stage -eq 'Draft' -and $rng.Next(0, 10) -lt 5)
    $items = [System.Collections.Generic.List[object]]::new()
    $u = [Math]::Min($W, $H)
    $claim = if ($Ctx.Claim) { $Ctx.Claim } else { $Customer.Short }
    $copy = Get-SampleText -Kind 'AdCopy' -Rng $rng -Context $Ctx
    $initials = (-join (($Customer.Short -split ' ') | Where-Object { $_ } | Select-Object -First 2 | ForEach-Object { $_[0] })).ToUpperInvariant()
    $addImage = {
        param($x, $y, $w, $h)
        if ($placeholder) { $items.Add(@{ K = 'Placeholder'; X = $x; Y = $y; W = $w; H = $h; Text = ('{0}: {1}' -f $L.Motif, $Ctx.Motiv) }) }
        else { $items.Add(@{ K = 'Texture'; X = $x; Y = $y; W = $w; H = $h; Kind = $kind; Seed = $Seed; Color = (Get-MixedColor $c1 @(0, 0, 0) 0.15); Color2 = $c2 }) }
    }
    switch ($Variant) {
        'B' {
            & $addImage 0 0 $W $H
            $items.Add(@{ K = 'Rect'; X = 0; Y = $H * 0.62; W = $W; H = $H * 0.38; Color = $c1 })
            $y = Add-WrappedItem $items $claim ($u * 0.07) ($H * 0.66) ($W - $u * 0.14) ($u * 0.085) $true @(255, 255, 255) 3
            $null = Add-WrappedItem $items $copy ($u * 0.07) ($y + $u * 0.02) ($W * 0.7) ($u * 0.03) $false @(255, 255, 255) 4
            $logoColor = $c2
        }
        'C' {
            $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = $W * 0.48; H = $H; Color = $c1 })
            & $addImage ($W * 0.48) 0 ($W * 0.52) $H
            $y = Add-WrappedItem $items $claim ($u * 0.06) ($H * 0.18) ($W * 0.48 - $u * 0.1) ($u * 0.075) $true @(255, 255, 255) 4
            $null = Add-WrappedItem $items $copy ($u * 0.06) ($y + $u * 0.03) ($W * 0.48 - $u * 0.1) ($u * 0.03) $false $light 6
            $logoColor = $c2
        }
        default {
            & $addImage 0 0 $W ($H * 0.58)
            $items.Add(@{ K = 'Rect'; X = 0; Y = $H * 0.58; W = $W; H = $H * 0.42; Color = $light })
            $y = Add-WrappedItem $items $claim ($u * 0.06) ($H * 0.62) ($W - $u * 0.12) ($u * 0.08) $true $c1 3
            $null = Add-WrappedItem $items $copy ($u * 0.06) ($y + $u * 0.02) ($W * 0.72) ($u * 0.03) $false @(50, 50, 50) 4
            $logoColor = $c1
        }
    }
    $d = $u * 0.14
    $items.Add(@{ K = 'Ellipse'; X = $W - $d - $u * 0.05; Y = $H - $d - $u * 0.05; W = $d; H = $d; Color = $logoColor })
    $items.Add(@{ K = 'Text'; X = $W - $d - $u * 0.05 + $d * 0.2; Y = $H - $d - $u * 0.05 + $d * 0.28; Size = $d * 0.4; Bold = $true; Text = $initials; Color = @(255, 255, 255) })
    $items.Add(@{ K = 'Text'; X = $u * 0.06; Y = $H - $u * 0.07; Size = $u * 0.022; Text = ('www.{0}' -f $Customer.Domain); Color = @(90, 90, 90) })
    if ($Stage -eq 'Draft') {
        $items.Add(@{ K = 'Text'; X = $u * 0.02; Y = $u * 0.015; Size = $u * 0.018; Text = ('{0} {1} {2} {3} {4}' -f $L.Draft.ToUpperInvariant(), $Variant, $MidDot, $L.Version, (Format-LocalDate $Date)); Color = @(120, 120, 120) })
    }
    else {
        foreach ($corner in @(@(0, 0, 1, 1), @($W, 0, -1, 1), @(0, $H, 1, -1), @($W, $H, -1, -1))) {
            $items.Add(@{ K = 'Line'; X1 = $corner[0] + $corner[2] * 3; Y1 = $corner[1]; X2 = $corner[0] + $corner[2] * 14; Y2 = $corner[1]; Width = 0.5; Color = @(0, 0, 0) })
            $items.Add(@{ K = 'Line'; X1 = $corner[0]; Y1 = $corner[1] + $corner[3] * 3; X2 = $corner[0]; Y2 = $corner[1] + $corner[3] * 14; Width = 0.5; Color = @(0, 0, 0) })
        }
    }
    , $items.ToArray()
}

$LoremIpsum = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'

function Get-BrochurePageItem {
    # Seite einer mehrseitigen Drucksache (A4). Seite 1 = Titel wie das Werbemittel, letzte Seite = Rueckseite
    # mit Kontakt, dazwischen Innenseiten mit Bildflaeche, Ueberschrift und zwei Spalten. Entwurf: Blindtext und Platzhalter.
    param([Parameter(Mandatory)] $Ctx, [Parameter(Mandatory)] $Customer, [double] $W, [double] $H, [int] $Page, [int] $PageCount, [string] $Variant = 'A', [string] $Stage = 'Draft', [int] $Seed = 1, [datetime] $Date)
    if ($Page -eq 1) { return Get-DesignItem $Ctx $Customer $W $H $Variant $Stage $Seed 'Brochure' $Date }
    $rng = Get-Rng -Index ($Seed * 31 + $Page) -Salt 29
    $colors = $Customer.Colors -split ' '
    $c1 = ConvertFrom-HexColor $colors[0]
    $c2 = ConvertFrom-HexColor $colors[1]
    $kind = $IndustryTexture[$Customer.Industry]
    if (-not $kind) { $kind = 'Paper' }
    $draft = $Stage -eq 'Draft'
    $items = [System.Collections.Generic.List[object]]::new()
    $m = 42
    $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = $W; H = $H; Color = @(255, 255, 255) })
    if ($Page -eq $PageCount) {
        $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = $W; H = $H; Color = $c1 })
        $y = Add-WrappedItem $items $Customer.Name $m ($H * 0.6) ($W - 2 * $m) 22 $true @(255, 255, 255) 2
        foreach ($line in @($Customer.City, ('www.{0}' -f $Customer.Domain), ('{0}@{1}' -f $L.MailContact, $Customer.Domain))) {
            if (-not $line) { continue }
            $items.Add(@{ K = 'Text'; X = $m; Y = $y + 10; Size = 11; Text = $line; Color = (Get-MixedColor $c2 @(255, 255, 255) 0.5) })
            $y += 16
        }
    }
    else {
        $colW = ($W - 2 * $m - 18) / 2
        $imageTop = ($Page % 2 -eq 0)
        $imageH = if ($imageTop) { $H * (0.3 + 0.15 * $rng.NextDouble()) } else { $H - 120 }
        $imageY = if ($imageTop) { 0 } else { 60 }
        $imageX = if ($imageTop) { 0 } else { $m + $colW + 18 }
        $imageW = if ($imageTop) { $W } else { $colW }
        if ($draft) { $items.Add(@{ K = 'Placeholder'; X = $imageX; Y = $imageY; W = $imageW; H = $imageH; Text = ('{0}: {1}' -f $L.Motif, $Ctx.Motiv) }) }
        else { $items.Add(@{ K = 'Texture'; X = $imageX; Y = $imageY; W = $imageW; H = $imageH; Kind = $kind; Seed = $Seed + $Page; Color = (Get-MixedColor $c1 @(0, 0, 0) (0.1 * ($Page % 3))); Color2 = $c2 }) }
        $y = if ($imageTop) { $imageH + 34 } else { 60 }
        $items.Add(@{ K = 'Rect'; X = $m; Y = $y - 12; W = 40; H = 4; Color = $c2 })
        $headline = if ($draft) { 'Headline lorem ipsum' } else { Get-SampleText 'Claim' $rng $Ctx }
        $y = Add-WrappedItem $items $headline $m $y ($W - 2 * $m) 20 $true $c1 2
        $y += 8
        $lines = if ($imageTop) { 18 } else { 28 }
        # Je Spalte zwei Absaetze; im Entwurf Blindtext.
        $paragraphs = if ($imageTop) { 2 } else { 4 }
        $left = if ($draft) { (@($LoremIpsum) * $paragraphs) -join "`n`n" } else { (Get-DistinctSampleText 'AdCopy' $rng $Ctx $paragraphs) -join "`n`n" }
        $right = if ($draft) { "$LoremIpsum`n`n$LoremIpsum" } else { (Get-DistinctSampleText 'AdCopy' $rng $Ctx 2) -join "`n`n" }
        $null = Add-WrappedItem $items $left $m $y $colW 10.5 $false @(45, 45, 45) $lines
        if ($imageTop) { $null = Add-WrappedItem $items $right ($m + $colW + 18) $y $colW 10.5 $false @(45, 45, 45) $lines }
        $pageX = if ($Page % 2 -eq 0) { $m } else { $W - $m - 12 }
        $items.Add(@{ K = 'Text'; X = $pageX; Y = $H - 28; Size = 8; Bold = $true; Text = [string]$Page; Color = $c1 })
        $items.Add(@{ K = 'Text'; X = $(if ($Page % 2 -eq 0) { $m + 24 } else { $m }); Y = $H - 28; Size = 7; Text = $Customer.Short; Color = @(120, 120, 120) })
    }
    if ($draft) {
        $items.Add(@{ K = 'Text'; X = 12; Y = 10; Size = 7; Text = ('{0} {1} {2} {3}/{4} {2} {5}' -f $L.Draft.ToUpperInvariant(), $Variant, $MidDot, $Page, $PageCount, (Format-LocalDate $Date)); Color = @(120, 120, 120) })
    }
    else {
        foreach ($corner in @(@(0, 0, 1, 1), @($W, 0, -1, 1), @(0, $H, 1, -1), @($W, $H, -1, -1))) {
            $items.Add(@{ K = 'Line'; X1 = $corner[0] + $corner[2] * 3; Y1 = $corner[1]; X2 = $corner[0] + $corner[2] * 14; Y2 = $corner[1]; Width = 0.5; Color = @(0, 0, 0) })
            $items.Add(@{ K = 'Line'; X1 = $corner[0]; Y1 = $corner[1] + $corner[3] * 3; X2 = $corner[0]; Y2 = $corner[1] + $corner[3] * 14; Width = 0.5; Color = @(0, 0, 0) })
        }
    }
    , $items.ToArray()
}

function Get-WebPageItem {
    # Screendesign einer Website-Seite: Navigation, Buehne, Teaser, Fusszeile. Entwurf = Wireframe in Grau.
    param([Parameter(Mandatory)] $Ctx, [Parameter(Mandatory)] $Customer, [double] $W, [double] $H, [int] $Page, [int] $PageCount, [string] $Stage = 'Draft', [int] $Seed = 1, [datetime] $Date)
    $rng = Get-Rng -Index ($Seed * 37 + $Page) -Salt 31
    $colors = $Customer.Colors -split ' '
    $c1 = ConvertFrom-HexColor $colors[0]
    $c2 = ConvertFrom-HexColor $colors[1]
    $kind = $IndustryTexture[$Customer.Industry]
    if (-not $kind) { $kind = 'Paper' }
    $draft = $Stage -eq 'Draft'
    $ink = if ($draft) { @(90, 90, 90) } else { $c1 }
    $menu = @($C.WebMenu)
    $items = [System.Collections.Generic.List[object]]::new()
    $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = $W; H = $H; Color = @(255, 255, 255) })
    $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = $W; H = 90; Color = $(if ($draft) { @(235, 235, 235) } else { @(255, 255, 255) }) })
    $items.Add(@{ K = 'Ellipse'; X = 60; Y = 20; W = 50; H = 50; Color = $(if ($draft) { @(180, 180, 180) } else { $c1 }) })
    $items.Add(@{ K = 'Text'; X = 125; Y = 32; Size = 20; Bold = $true; Text = $Customer.Short; Color = $ink })
    for ($i = 0; $i -lt 5; $i++) {
        $items.Add(@{ K = 'Text'; X = 760 + $i * 120; Y = 36; Size = 15; Bold = ($i -eq ($Page - 1) % 5); Text = $menu[$i]; Color = $ink })
    }
    $heroH = 560 + 80 * ($Page % 2)
    if ($draft) { $items.Add(@{ K = 'Placeholder'; X = 0; Y = 90; W = $W; H = $heroH; Text = ('{0}: {1}' -f $L.Motif, $Ctx.Motiv) }) }
    else { $items.Add(@{ K = 'Texture'; X = 0; Y = 90; W = $W; H = $heroH; Kind = $kind; Seed = $Seed + $Page; Color = (Get-MixedColor $c1 @(0, 0, 0) 0.2); Color2 = $c2 }) }
    $title = if ($Page -eq 1) { $Ctx.Claim } else { $menu[($Page - 1) % $menu.Count] }
    $items.Add(@{ K = 'Rect'; X = 80; Y = 90 + $heroH - 220; W = 760; H = 170; Color = $(if ($draft) { @(210, 210, 210) } else { $c1 }) })
    $null = Add-WrappedItem $items $title 110 (90 + $heroH - 195) 700 40 $true @(255, 255, 255) 3
    $y = 90 + $heroH + 80
    $card = 0
    while ($y + 560 -lt $H - 260) {
        for ($col = 0; $col -lt 3; $col++) {
            $x = 80 + $col * 440
            if ($draft) { $items.Add(@{ K = 'Placeholder'; X = $x; Y = $y; W = 400; H = 240; Text = $Office.Image }) }
            else { $items.Add(@{ K = 'Texture'; X = $x; Y = $y; W = 400; H = 240; Kind = $kind; Seed = $Seed + $Page * 10 + $card; Color = (Get-MixedColor $c1 @(255, 255, 255) (0.15 * $col)); Color2 = $c2 }) }
            if ($draft) { $headline = $L.Teaser; $text = $LoremIpsum }
            else {
                $copy = Get-SampleText 'AdCopy' $rng $Ctx
                $cut = $copy.IndexOfAny([char[]]'.!?')
                if ($cut -gt 8 -and $cut -lt 70) { $headline = $copy.Substring(0, $cut + 1); $text = $copy.Substring($cut + 1).Trim() }
                else { $headline = $menu[($card + $Page) % $menu.Count]; $text = $copy }
                if (-not $text) { $text = $copy }
            }
            $ty = Add-WrappedItem $items $headline $x ($y + 262) 400 22 $true $ink 2
            $null = Add-WrappedItem $items $text $x ($ty + 8) 400 14 $false @(60, 60, 60) 6
            $items.Add(@{ K = 'Text'; X = $x; Y = $y + 500; Size = 14; Bold = $true; Text = $L.ReadMore; Color = $(if ($draft) { @(120, 120, 120) } else { $c2 }) })
            $card++
        }
        $y += 600
    }
    $items.Add(@{ K = 'Rect'; X = 0; Y = $H - 220; W = $W; H = 220; Color = $(if ($draft) { @(70, 70, 70) } else { (Get-MixedColor $c1 @(0, 0, 0) 0.35) }) })
    $fy = $H - 180
    foreach ($line in @($Customer.Name, $Customer.City, ('www.{0}' -f $Customer.Domain), ('{0}@{1}' -f $L.MailContact, $Customer.Domain), $L.WebFooter)) {
        if (-not $line) { continue }
        $items.Add(@{ K = 'Text'; X = 80; Y = $fy; Size = 14; Text = $line; Color = @(235, 235, 235) })
        $fy += 26
    }
    if ($draft) {
        $items.Add(@{ K = 'Text'; X = 20; Y = 4; Size = 11; Text = ('WIREFRAME {0} {1}/{2} {0} {3}' -f $MidDot, $Page, $PageCount, (Format-LocalDate $Date)); Color = @(150, 150, 150) })
    }
    , $items.ToArray()
}

function Get-ProofItem {
    # Proof-Vermerk der Druckerei am Seitenrand (Auftrag, Seite, Datum, Labels.ProofNote).
    param([double] $W, [double] $H, [string] $Job, [int] $Page, [int] $PageCount, [datetime] $Date)
    $u = [Math]::Min($W, $H)
    $size = [Math]::Max(6, $u * 0.014)
    $text = 'PROOF {0} {1} {2} {1} {3} {1} {4}' -f $Job, $MidDot, ($L.Page -f $Page, $PageCount), (Format-LocalDate $Date), $L.ProofNote
    @(
        @{ K = 'Rect'; X = 0; Y = $H - $size * 2.6; W = $W; H = $size * 2.6; Color = @(255, 255, 255) }
        @{ K = 'Text'; X = $size; Y = $H - $size * 1.9; Size = $size; Bold = $true; Text = $text; Color = @(200, 30, 60) }
        @{ K = 'Rect'; X = $W - $size * 9; Y = $H - $size * 2.2; W = $size * 1.6; H = $size * 1.6; Color = @(0, 160, 220) }
        @{ K = 'Rect'; X = $W - $size * 7; Y = $H - $size * 2.2; W = $size * 1.6; H = $size * 1.6; Color = @(220, 0, 130) }
        @{ K = 'Rect'; X = $W - $size * 5; Y = $H - $size * 2.2; W = $size * 1.6; H = $size * 1.6; Color = @(250, 220, 0) }
        @{ K = 'Rect'; X = $W - $size * 3; Y = $H - $size * 2.2; W = $size * 1.6; H = $size * 1.6; Color = @(20, 20, 20) }
    )
}

function Get-MoodboardItem {
    # Moodboard: Farbpalette, Texturen, Typografie, Stichworte.
    param([Parameter(Mandatory)] $Ctx, [Parameter(Mandatory)] $Customer, [int] $Seed, $Ci)
    $colors = $Customer.Colors -split ' '
    $c1 = ConvertFrom-HexColor $colors[0]
    $c2 = ConvertFrom-HexColor $colors[1]
    $items = [System.Collections.Generic.List[object]]::new()
    $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = 842; H = 595; Color = @(248, 247, 244) })
    $items.Add(@{ K = 'Text'; X = 40; Y = 30; Size = 22; Bold = $true; Text = ('{0} {1}' -f $L.Moodboard, $Ctx.Projekt); Color = $Ci.Primary })
    $items.Add(@{ K = 'Text'; X = 40; Y = 60; Size = 10; Text = ('{0} {1} {2}' -f $Customer.Name, $MidDot, $Ctx.Datum); Color = @(90, 90, 90) })
    $kinds = 'Clouds', 'Wood', 'Paper', 'Stone', 'Clouds', 'Paper'
    for ($i = 0; $i -lt 6; $i++) {
        $x = 40 + ($i % 3) * 190
        $y = 90 + [Math]::Floor($i / 3) * 200
        $a = Get-MixedColor $c1 @(255, 255, 255) (0.1 * $i)
        $items.Add(@{ K = 'Texture'; X = $x; Y = $y; W = 180; H = 185; Kind = $kinds[$i]; Seed = $Seed + $i; Color = $a; Color2 = $c2 })
    }
    $y = 90
    foreach ($swatch in @($c1, $c2, (Get-MixedColor $c1 @(255, 255, 255) 0.6), (Get-MixedColor $c2 @(0, 0, 0) 0.4))) {
        $items.Add(@{ K = 'Rect'; X = 620; Y = $y; W = 50; H = 50; Color = $swatch })
        $items.Add(@{ K = 'Text'; X = 680; Y = $y + 18; Size = 9; Text = ('#{0:X2}{1:X2}{2:X2}' -f $swatch[0], $swatch[1], $swatch[2]); Color = @(60, 60, 60) })
        $y += 62
    }
    $items.Add(@{ K = 'Text'; X = 620; Y = 350; Size = 26; Bold = $true; Text = 'Aa Bb'; Color = $c1 })
    $null = Add-WrappedItem $items $Ctx.Claim 620 395 190 14 $true $c1 3
    $null = Add-WrappedItem $items ('{0}: {1}' -f $L.Motif, $Ctx.Motiv) 620 460 190 9 $false @(80, 80, 80) 6
    , $items.ToArray()
}

function Get-SlideItem {
    # Folie 16:9 (960 x 540 Punkt) fuer den PDF-Export einer Praesentation.
    param([Parameter(Mandatory)] $Slide, [Parameter(Mandatory)] $Ci, [int] $Number, [string] $Footer)
    $items = [System.Collections.Generic.List[object]]::new()
    $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = 960; H = 540; Color = @(255, 255, 255) })
    switch ($Slide.Layout) {
        'Title' {
            $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = 960; H = 540; Color = $Ci.Primary })
            $null = Add-WrappedItem $items $Slide.Title 70 190 780 40 $true @(255, 255, 255) 3
            $null = Add-WrappedItem $items $Slide.Subtitle 70 330 780 18 $false @(235, 235, 235) 2
            foreach ($i in (Get-LogoItem 70 450 34 $Ci -Negative)) { $items.Add($i) }
        }
        'ImageFull' {
            if ($Slide.Image) { $items.Add(@{ K = 'Image'; X = 0; Y = 0; W = 960; H = 540; Bytes = $Slide.Image.Bytes; PixW = $Slide.Image.WidthPx; PixH = $Slide.Image.HeightPx }) }
            $items.Add(@{ K = 'Rect'; X = 0; Y = 430; W = 960; H = 70; Color = $Ci.Primary })
            $null = Add-WrappedItem $items $Slide.Title 50 448 860 26 $true @(255, 255, 255) 1
        }
        default {
            $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = 960; H = 10; Color = $Ci.Primary })
            $null = Add-WrappedItem $items $Slide.Title 50 40 760 28 $true $Ci.Primary 2
            $textWidth = if ($Slide.Image) { 470 } else { 860 }
            $y = 120
            foreach ($point in @($Slide.Bullets)) {
                if (-not $point) { continue }
                $items.Add(@{ K = 'Text'; X = 50; Y = $y; Size = 16; Text = $script:Bullet; Color = $Ci.Accent })
                $y = Add-WrappedItem $items $point 74 $y $textWidth 16 $false $Ci.Dark 4
                $y += 10
            }
            if ($Slide.Text) { $null = Add-WrappedItem $items $Slide.Text 50 $y $textWidth 14 $false $Ci.Dark 10 }
            if ($Slide.Image) {
                $items.Add(@{ K = 'Image'; X = 560; Y = 120; W = 360; H = [Math]::Min(380, 360 * $Slide.Image.HeightPx / [Math]::Max(1, $Slide.Image.WidthPx)); Bytes = $Slide.Image.Bytes; PixW = $Slide.Image.WidthPx; PixH = $Slide.Image.HeightPx })
            }
            foreach ($i in (Get-LogoItem 820 500 20 $Ci)) { $items.Add($i) }
        }
    }
    $items.Add(@{ K = 'Text'; X = 50; Y = 515; Size = 8; Text = ('{0}   {1}' -f $Footer, $Number); Color = @(140, 140, 140) })
    , $items.ToArray()
}

#endregion
#region Bausteine: gemeinsame Helfer und Kundenprojekt

function Get-DocModel {
    # Gemeinsames Modell fuer DOCX und PDF (Seitenumbruch); Sender Company/Foreign/None.
    param([string] $Title, $Author, [datetime] $Created, [datetime] $Modified, $Ci, [string] $SenderKind = 'Company', $Foreign = $null, [string] $Marking = $null, [string] $Classification = $null, $LastBy = $null)
    @{
        Title = $Title; Author = $Author.Name; LastModifiedBy = $(if ($LastBy) { $LastBy.Name } else { $Author.Name }); Created = $Created; Modified = $Modified
        Revision = 1 + [Math]::Floor(($Modified - $Created).TotalMinutes / 45); Company = $C.Company.Name; CompanyName = $C.Company.Name
        Ci = $Ci; HeaderLines = $Ci.HeaderLines; FooterLines = $Ci.FooterLines; Sender = $SenderKind; Foreign = $Foreign
        Marking = $Marking; Classification = $Classification; Blocks = ([System.Collections.Generic.List[object]]::new()); Comments = ([System.Collections.Generic.List[object]]::new())
        Scan = $null; ScanDevice = 'MFP Scan-to-Folder'; Template = $false
    }
}

function Add-Block {
    # Baustein an ein Dokumentmodell anhaengen; T = Typ (Title, Para, Table, Address ...).
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)][string] $Type, [hashtable] $Data = @{})
    $Data['T'] = $Type
    $Model.Blocks.Add($Data)
}

function Get-LetterModel {
    # Geschaeftsbrief: Anschrift, Betreff, Anrede, Text aus dem Korpus, Gruss mit Name.
    param($Record, [hashtable] $Context, $Author, [datetime] $Date, $Ci, [string[]] $Address)
    $subject = Expand-SampleText $Record.Subject $Context
    $letter = Get-DocModel -Title $subject -Author $Author -Created $Date -Modified $Date -Ci $Ci
    Add-Block $letter 'Address' @{ Lines = $Address }
    Add-Block $letter 'Info' @{ Rows = [ordered]@{ $L.Date = (Format-LocalDate $Date) } }
    Add-Block $letter 'Title' @{ Text = $subject }
    Add-Block $letter 'Para' @{ Text = ('{0},' -f $Context.Anrede) }
    Add-Block $letter 'Para' @{ Text = (Expand-SampleText $Record.Text $Context) }
    Add-Block $letter 'Para' @{ Text = $L.Regards }
    Add-Block $letter 'Sign' @{ Name = $Author.Name; Role = $C.Company.Name; Seed = $Date.DayOfYear }
    $letter
}

function Add-DocComment {
    # Kommentar am zuletzt hinzugefuegten Block.
    param($Model, $Person, [datetime] $Date, [string] $Text)
    if (-not $Text) { return }
    $Model.Comments.Add(@{ Author = $Person.Name; Initials = $Person.Initials.ToUpperInvariant(); Date = $Date; Text = $Text; Block = $Model.Blocks.Count - 1 })
}

function Add-Spec {
    # Datei in die Liste der Einheit; Aenderungszeit nach Art realistisch versetzt.
    param($List, [string] $Path, [string] $Kind, [datetime] $Date, $Rng, [hashtable] $Data = @{}, [int] $EditMinutes = -1)
    if ($Date -ge $Reference) { return }
    if ($EditMinutes -lt 0) { $EditMinutes = if ($Kind -in 'docx', 'xlsx', 'pptx') { $Rng.Next(15, 480) } else { $Rng.Next(1, 6) } }
    $modified = $Date.AddMinutes($EditMinutes)
    if ($modified -ge $Reference) { $modified = $Date }
    $Data.Path = $Path; $Data.Kind = $Kind; $Data.Created = $Date; $Data.Modified = $modified
    if ($Data.Model) { $Data.Model.Created = $Date; $Data.Model.Modified = $modified }
    $List.Add($Data)
}

function Get-WorkDate {
    # Folgetermin: Werktage, Buerozeit, ab und zu spaet abends vor einer Abgabe.
    param([datetime] $From, $Rng, [int] $MinDays, [int] $MaxDays)
    $d = $From.Date.AddDays($Rng.Next($MinDays, $MaxDays + 1))
    if ($d.DayOfWeek -eq [DayOfWeek]::Saturday) { $d = $d.AddDays(2) }
    if ($d.DayOfWeek -eq [DayOfWeek]::Sunday) { $d = $d.AddDays(1) }
    $hour = if ($Rng.Next(0, 12) -eq 0) { 19 + $Rng.Next(0, 3) } else { 8 + $Rng.Next(0, 9) }
    $d.AddHours($hour).AddMinutes($Rng.Next(0, 60))
}

function Get-ServiceLine {
    param([Parameter(Mandatory)] $Rng)
    $service = Get-RandomEntry $Rng $C.Services
    # Menge nach Einheit (Labels.Hour, Day, Month): Stunden 2 bis 40, Tage und Monate 1 bis 3, sonst 1.
    $quantity = if ($service.Unit -eq $L.Hour) { $Rng.Next(2, 41) } elseif ($service.Unit -eq $L.Day -or $service.Unit -eq $L.Month) { $Rng.Next(1, 4) } else { 1 }
    @{ Text = $service.Text; Qty = $quantity; Unit = $service.Unit; Price = [Math]::Round(($service.Min + $Rng.NextDouble() * ($service.Max - $service.Min)) / 5) * 5 }
}

function Add-PositionTable {
    # Positionen mit Netto, USt und Gesamt; liefert den Gesamtbetrag.
    param([Parameter(Mandatory)] $Model, [Parameter(Mandatory)][object[]] $Lines)
    $rows = [System.Collections.Generic.List[object]]::new()
    $net = 0.0
    $pos = 1
    foreach ($line in $Lines) {
        $amount = [Math]::Round($line.Qty * $line.Price, 2)
        $net += $amount
        $rows.Add([string[]]@([string]$pos, $line.Text, (Format-Number $line.Qty), $line.Unit, (Format-Money $line.Price), (Format-Money $amount)))
        $pos++
    }
    $vat = [Math]::Round($net * $Locale.Vat, 2)
    Add-Block $Model 'Table' @{ Header = [string[]]@($L.Pos, $L.Description, $L.Quantity, $L.Unit, $L.Price, $L.Amount); Rows = $rows.ToArray(); Widths = @(0.07, 0.41, 0.1, 0.1, 0.16, 0.16); Align = 'LLRLRR' }
    $sums = [System.Collections.Generic.List[object]]::new()
    $sums.Add([string[]]@($L.Net, (Format-Money $net)))
    $sums.Add([string[]]@($L.Vat, (Format-Money $vat)))
    $sums.Add([string[]]@($L.Total, (Format-Money ($net + $vat))))
    Add-Block $Model 'Table' @{ Header = $null; Rows = $sums.ToArray(); Widths = @(0.68, 0.32); Align = 'RR'; BoldLast = $true; Plain = $true }
    $net + $vat
}

function Get-CalculationModel {
    # Kalkulation mit echten Formeln (Menge x Satz, Summen, Marge).
    param($Lines, [string] $Title, $Author, $Ci)
    $rows = [System.Collections.Generic.List[object]]::new()
    $rows.Add(@{ Style = 'Title'; Cells = @(@{ V = $Title }) })
    $rows.Add(@{ Style = 'Header'; Cells = @(@{ V = $L.Description }, @{ V = $L.Quantity }, @{ V = $L.Unit }, @{ V = $L.Rate }, @{ V = $L.Amount }) })
    $r = 3
    $total = 0.0
    foreach ($line in $Lines) {
        $amount = [Math]::Round($line.Qty * $line.Price, 2)
        $total += $amount
        $rows.Add(@{ Cells = @(@{ V = $line.Text }, @{ V = [double]$line.Qty; Fmt = 'Number' }, @{ V = $line.Unit }, @{ V = [double]$line.Price; Fmt = 'Money' }, @{ V = $amount; F = "B$r*D$r"; Fmt = 'Money' }) })
        $r++
    }
    $rows.Add(@{ Style = 'Total'; Cells = @(@{ V = $L.Net }, @{ V = $null }, @{ V = $null }, @{ V = $null }, @{ V = $total; F = ('SUM(E3:E{0})' -f ($r - 1)); Fmt = 'Money' }) })
    $rows.Add(@{ Cells = @(@{ V = $L.Margin }, @{ V = 0.18; Fmt = 'Percent' }, @{ V = $null }, @{ V = $null }, @{ V = [Math]::Round($total * 0.18, 2); F = ('E{0}*B{1}' -f $r, ($r + 1)); Fmt = 'Money' }) })
    @{
        Title = $Title; Author = $Author.Name; Company = $C.Company.Name; Ci = $Ci; Classification = $L.Internal
        Sheets = @(@{ Name = $L.Calculation; Columns = @(@{ Width = 44 }, @{ Width = 10 }, @{ Width = 10 }, @{ Width = 14 }, @{ Width = 16 }); Rows = $rows.ToArray(); Freeze = 2; AutoFilter = $false })
    }
}

function Build-ProjectUnit {
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $rng = Get-Rng -Index $Unit.Seed -Salt 101
    $customer = $Unit.Customer
    $name = $Unit.Project
    $year = $Reference.Year - $Unit.YearsAgo
    # Startmonat nach Patterns.Seasons (erster Treffer auf den Projektnamen, plus Zufall unter Spread), sonst zufaellig.
    $month = 0
    foreach ($season in $Patterns.Seasons) {
        if ($name -match $season.Match) {
            $month = if ($season.Spread) { $season.Month + $rng.Next(0, $season.Spread) } else { $season.Month }
            break
        }
    }
    if (-not $month) { $month = 1 + $rng.Next(0, 11) }
    $start = (New-Object -TypeName DateTime -ArgumentList $year, $month, (1 + $rng.Next(0, 27))).AddHours(8 + $rng.Next(0, 9)).AddMinutes($rng.Next(0, 60))
    if ($start -ge $Reference.AddDays(-2) -or $start -lt $Founded) { return , $specs.ToArray() }
    # Kunden am Ort der Niederlassung betreut die Niederlassung, sobald es sie gibt.
    $site = if ($customer.City -eq $BranchSite.City -and $start -ge $SiteOpened[$BranchSite.Name]) { $BranchSite.Name } else { $HqSite.Name }
    $owner = Get-Person $customer.Owner $start $site $rng
    $team = @(Get-ActivePerson -Date $start -Site $owner.Site | Where-Object { $_.Sam -ne $owner.Sam -and $_.Department -eq 'Marketing' })
    $colleague = if ($team) { Get-RandomEntry $rng $team } else { $owner }
    $ci = Get-DocumentCi $start $owner.Site
    $ctx = Get-TextContext -Rng $rng -Date $start -Customer $customer -Project $name -Author $owner -Colleague $colleague
    $num = '{0}-{1:D4}' -f $year, ($Unit.Seed % 10000)
    $folder = ConvertTo-SafeName ('{0}_{1}_{2}' -f $year, $customer.Short, $name)
    $base = Get-AreaPath $start ('{0}\{1}' -f $Paths.Projects, $folder) ('{0}\{1}' -f $AreaName.Projects, $folder)
    $step = $F.ProjectSteps
    $short = ConvertTo-SafeName $customer.Short
    $lines = @(1..(3 + $rng.Next(0, 4)) | ForEach-Object { Get-ServiceLine $rng })
    $address = @($customer.Name, $customer.Contact, ($Locale.StreetLine -f (Get-RandomEntry (Get-Rng -Index $customer.Name.Length -Salt 29) $C.Streets), (3 + $customer.Name.Length)), ($Locale.CityLine -f (Get-PostalCode (Get-Rng -Index $customer.Domain.Length -Salt 31) $customer.City), $customer.City))
    $customerNo = '{0}{1}' -f $L.CustomerId, (10001 + $C.Customers.IndexOf($customer))
    # Nummern von Angebot, Auftragsbestaetigung und Rechnung, z. B. AN-2024-0001.
    $offerNo = $L.OfferId + $num
    $orderNo = $L.OrderId + $num
    $invoiceNo = $L.InvoiceId + $num

    # Anfrage und Kalkulation
    $note = Get-DocModel -Title "$($L.Request) $($customer.Name)" -Author $owner -Created $start -Modified $start -Ci $ci -SenderKind 'None'
    Add-Block $note 'Title' @{ Text = ('{0}: {1}' -f $L.Request, $name) }
    Add-Block $note 'Para' @{ Text = (Get-SampleText 'RequestNote' $rng $ctx) }
    Add-Spec $specs ('{0}\{1}\{2}_{3:yyyy-MM-dd}_{4}.docx' -f $base, $step[0], $L.Request, $start, $owner.Initials) 'docx' $start $rng @{ Model = $note }
    $dOffer = Get-WorkDate $start $rng 2 6
    Add-Spec $specs ('{0}\{1}\{2}_{3}.xlsx' -f $base, $step[0], $L.Calculation, (ConvertTo-SafeName $name)) 'xlsx' $dOffer.AddHours(-2) $rng @{ Model = (Get-CalculationModel $lines ('{0} {1} {2}' -f $L.Calculation, $customer.Short, $name) $owner $ci) }

    # Angebot (Word und PDF; PDF zusaetzlich in der Vertriebsablage)
    $offer = Get-DocModel -Title "$($L.Offer) $offerNo" -Author $owner -Created $dOffer -Modified $dOffer -Ci $ci
    Add-Block $offer 'Address' @{ Lines = $address }
    Add-Block $offer 'Info' @{ Rows = [ordered]@{ $L.Number = $offerNo; $L.Date = (Format-LocalDate $dOffer); $L.CustomerNo = $customerNo; $L.Project = $name } }
    Add-Block $offer 'Title' @{ Text = "$($L.Offer) $offerNo $MidDot $name" }
    Add-Block $offer 'Para' @{ Text = ('{0},' -f $ctx.Anrede) }
    Add-Block $offer 'Para' @{ Text = (Get-SampleText 'OfferIntro' $rng $ctx) }
    $total = Add-PositionTable $offer $lines
    Add-Block $offer 'Para' @{ Text = (Get-SampleText 'OfferClose' $rng $ctx) }
    Add-Block $offer 'Para' @{ Text = $L.Regards }
    Add-Block $offer 'Sign' @{ Name = $owner.Name; Role = $owner.Role; Seed = $Unit.Seed }
    $offerName = '{0}_{1}_{2}' -f $L.Offer, $offerNo, $short
    Add-Spec $specs ('{0}\{1}\{2}.docx' -f $base, $step[0], $offerName) 'docx' $dOffer $rng @{ Model = $offer }
    Add-Spec $specs ('{0}\{1}\{2}.pdf' -f $base, $step[0], $offerName) 'pdf' $dOffer.AddMinutes(30) $rng @{ Model = $offer }
    $salesPath = Get-AreaPath $dOffer ('{0}\{1}\{2}' -f $Paths.Sales, $F.Offers, $year) ('{0}\{1}' -f $AreaName.Sales, $F.Offers)
    Add-Spec $specs ('{0}\{1}.pdf' -f $salesPath, $offerName) 'copy' $dOffer.AddMinutes(32) $rng @{ Source = ('{0}\{1}\{2}.pdf' -f $base, $step[0], $offerName) }

    if ($rng.Next(0, 100) -lt 8) {
        $cancel = Get-DocModel -Title $L.Note -Author $owner -Created $dOffer -Modified $dOffer -Ci $ci -SenderKind 'None'
        Add-Block $cancel 'Title' @{ Text = ('{0} {1} {2}' -f $name, $MidDot, $L.Cancelled) }
        Add-Block $cancel 'Para' @{ Text = (Get-SampleText 'CancelNote' $rng $ctx) }
        Add-Spec $specs ('{0}\{1}\{2}_{3}.docx' -f $base, $step[0], $L.Note, $L.Cancelled) 'docx' (Get-WorkDate $dOffer $rng 10 30) $rng @{ Model = $cancel }
        return , $specs.ToArray()
    }

    # Auftragsbestaetigung, Briefing
    $dConfirm = Get-WorkDate $dOffer $rng 4 15
    $confirm = Get-DocModel -Title "$($L.Confirmation) $orderNo" -Author $owner -Created $dConfirm -Modified $dConfirm -Ci $ci
    Add-Block $confirm 'Address' @{ Lines = $address }
    Add-Block $confirm 'Info' @{ Rows = [ordered]@{ $L.Number = $orderNo; $L.Date = (Format-LocalDate $dConfirm); $L.Offer = $offerNo } }
    Add-Block $confirm 'Title' @{ Text = "$($L.Confirmation) $orderNo" }
    Add-Block $confirm 'Para' @{ Text = ('{0},' -f $ctx.Anrede) }
    $null = Add-PositionTable $confirm $lines
    Add-Block $confirm 'Para' @{ Text = $L.Regards }
    Add-Block $confirm 'Sign' @{ Name = $owner.Name; Role = $owner.Role; Seed = $Unit.Seed + 1 }
    Add-Spec $specs ('{0}\{1}\{2}_{3}.pdf' -f $base, $step[0], $orderNo, $short) 'pdf' $dConfirm $rng @{ Model = $confirm }

    $dBrief = Get-WorkDate $dConfirm $rng 2 7
    $brief = Get-DocModel -Title "$($L.Briefing) $name" -Author $owner -Created $dBrief -Modified $dBrief -Ci $ci -SenderKind 'None' -Classification $L.Internal
    Add-Block $brief 'Title' @{ Text = "$($L.Briefing) $name" }
    Add-Block $brief 'Info' @{ Rows = [ordered]@{ $L.Customer = $customer.Name; $L.Contact = $customer.Contact; $L.Budget = (Format-Money $total); $L.Due = $ctx.Termin2 } }
    foreach ($part in @(@($L.Background, 'BriefingBackground'), @($L.Goal, 'BriefingGoal'), @($L.Audience, 'BriefingAudience'), @($L.Mandatory, 'BriefingMandatory'), @($L.Timing, 'BriefingTiming'))) {
        Add-Block $brief 'Heading' @{ Text = $part[0] }
        Add-Block $brief 'Para' @{ Text = (Get-SampleText $part[1] $rng $ctx) }
    }
    Add-DocComment $brief $colleague $dBrief.AddHours(3) (Get-SampleText 'InternalComment' $rng (Get-TextContext -Rng $rng -Date $dBrief -Customer $customer -Project $name -Author $colleague -Colleague $owner))
    Add-Spec $specs ('{0}\{1}\{2}_{3}.docx' -f $base, $step[1], $L.Briefing, (ConvertTo-SafeName $name)) 'docx' $dBrief $rng @{ Model = $brief }

    # Konzept in drei Fassungen, Kommentare, Moodboard
    $dConcept = Get-WorkDate $dBrief $rng 6 12
    $versions = @('v1', 'v2', (Get-RandomEntry $rng @('final', 'final', $L.FinalNew, ('{0}_{1}' -f $L.FinalNew, $colleague.Initials))))
    $moodboard = $null
    if ($UseRaster) { $moodboard = Get-RenderedImage -Items (Get-MoodboardItem $ctx $customer $Unit.Seed $ci) -W 842 -H 595 -Dpi 120 -Quality 86 -Noise 1 }
    for ($v = 0; $v -lt 3; $v++) {
        $writer = if ($v -eq 1) { $colleague } else { $owner }
        $concept = Get-DocModel -Title "$($L.Concept) $name" -Author $owner -Created $dConcept -Modified $dConcept -Ci $ci -SenderKind 'None' -LastBy $writer -Classification $L.Internal
        Add-Block $concept 'Title' @{ Text = "$($L.Concept) $name" }
        Add-Block $concept 'Para' @{ Text = ('{0} {1} {2} {3}' -f $customer.Name, $MidDot, $L.Version, (Format-LocalDate $dConcept)) }
        $parts = @(@($L.Situation, 'ConceptSituation'), @($L.Idea, 'ConceptIdea'), @($L.Measures, 'ConceptMeasures'))
        if ($v -ge 1) { $parts += , @($L.Goals, 'ConceptGoals'); $parts += , @($L.Risks, 'ConceptRisks') }
        foreach ($part in $parts) {
            Add-Block $concept 'Heading' @{ Text = $part[0] }
            Add-Block $concept 'Para' @{ Text = (Get-SampleText $part[1] (Get-Rng -Index ($Unit.Seed + [array]::IndexOf($parts, $part)) -Salt 7) $ctx) }
        }
        if ($v -ge 1 -and $moodboard) { Add-Block $concept 'Image' @{ Bytes = $moodboard.Bytes; Format = 'jpeg'; WidthPx = $moodboard.WidthPx; HeightPx = $moodboard.HeightPx; WidthCm = 15; Caption = $L.Moodboard } }
        if ($v -eq 2) {
            $rows = @(foreach ($phase in 0..3) { , [string[]]@($C.Phases[$phase], ('{0} {1}' -f $L.Week, $Culture.Calendar.GetWeekOfYear($dConcept.AddDays(7 * $phase), 2, 1))) })
            Add-Block $concept 'Heading' @{ Text = $L.Schedule }
            Add-Block $concept 'Table' @{ Header = [string[]]@($L.Phase, $L.Due); Rows = $rows; Widths = @(0.6, 0.4); Align = 'LL' }
        }
        if ($v -lt 2) {
            Add-DocComment $concept $colleague $dConcept.AddHours(2) (Get-SampleText 'InternalComment' $rng (Get-TextContext -Rng $rng -Date $dConcept -Customer $customer -Project $name -Author $colleague -Colleague $owner))
            Add-DocComment $concept $owner $dConcept.AddHours(5) (Get-SampleText 'CustomerFeedback' $rng $ctx)
        }
        Add-Spec $specs ('{0}\{1}\{2}_{3}_{4}.docx' -f $base, $step[2], $L.Concept, (ConvertTo-SafeName $name), $versions[$v]) 'docx' $dConcept $rng @{ Model = $concept }
        $dConcept = Get-WorkDate $dConcept $rng 3 9
    }
    if ($moodboard) {
        Add-Spec $specs ('{0}\{1}\{2}_{3}.pdf' -f $base, $step[2], $L.Moodboard, $short) 'pdfpages' $dBrief.AddDays(5) $rng @{ Pages = @(@{ W = 842; H = 595; Image = $moodboard }); Info = @{ Title = $L.Moodboard; Author = $colleague.Name; Creator = $L.LayoutApp } }
    }

    # Entwuerfe, Korrektur, Freigabe, Druckdaten
    $dDraft = Get-WorkDate $dConcept $rng 2 8
    # Projekttypische Lieferungen (Messewand, Broschuere, Screendesign ...) plus allgemeine Werbemittel.
    $matched = @($C.Motifs | Where-Object { $_.Match -and $name -match $_.Match } | Select-Object -First 2)
    $pool = @($C.Motifs | Where-Object { -not $_.Match })
    $genericCount = if ($matched) { $rng.Next(0, 2) } else { 1 + $rng.Next(0, 3) }
    $motifs = @($matched) + @(Get-RandomSubset $rng $pool $genericCount)
    $finalImage = $null
    $printFiles = [System.Collections.Generic.List[string]]::new()
    $dZip = $dDraft
    foreach ($motif in $motifs) {
        $size = $ShapeSizes[$motif.Format]
        $delivery = if ($size.Online) { 'Final' } else { $L.PrintData }
        $pageCount = if ($motif.Pages) { [int]$motif.Pages + [int][Math]::Ceiling($motif.Pages / 3) * $rng.Next(-1, 2) } else { 1 }
        foreach ($variant in @('A', 'B', 'C') | Select-Object -First (2 + $rng.Next(0, 2))) {
            Add-Spec $specs ('{0}\{1}\{2}_{3}_{4}_{5}.pdf' -f $base, $step[3], $motif.File, $short, $L.Draft, $variant) 'design' $dDraft $rng @{ Ctx = $ctx; Customer = $customer; Motif = $motif; Variant = $variant; Stage = 'Draft'; Dpi = $size.DraftDpi; Seed = $Unit.Seed; DesignDate = $dDraft; Author = $colleague.Name; Pages = $pageCount }
        }
        $finalVariant = Get-RandomEntry $rng @('A', 'B', 'C')
        $dPrint = Get-WorkDate $dDraft $rng 12 25
        if ($rng.Next(0, 2) -eq 0) {
            Add-Spec $specs ('{0}\{1}\{2}\{3}_{4}_v1.pdf' -f $base, $step[3], $delivery, $motif.File, $short) 'design' $dPrint.AddDays(-3) $rng @{ Ctx = $ctx; Customer = $customer; Motif = $motif; Variant = $finalVariant; Stage = 'Final'; Dpi = $size.PrintDpi; Seed = $Unit.Seed + 5; DesignDate = $dPrint; Author = $colleague.Name; Pages = $pageCount }
        }
        $finalPath = '{0}\{1}\{2}\{3}_{4}_final.pdf' -f $base, $step[3], $delivery, $motif.File, $short
        Add-Spec $specs $finalPath 'design' $dPrint $rng @{ Ctx = $ctx; Customer = $customer; Motif = $motif; Variant = $finalVariant; Stage = 'Final'; Dpi = $size.PrintDpi; Seed = $Unit.Seed; DesignDate = $dPrint; Author = $colleague.Name; Pages = $pageCount }
        if (-not $size.Online) { $printFiles.Add($finalPath) }
        if (-not $size.Online -and $rng.Next(0, 10) -lt 7) {
            $printer = ($C.Suppliers | Select-Object -First 1).Name
            $job = '{0:yyyy}-{1:D4}' -f $dPrint, $rng.Next(100, 9999)
            Add-Spec $specs ('{0}\{1}\{2}\{3}\Proof_{4}_{5}.pdf' -f $base, $step[3], $L.PrintData, $F.Proofs, $job, $motif.File) 'design' $dPrint.AddDays(2) $rng @{ Ctx = $ctx; Customer = $customer; Motif = $motif; Variant = $finalVariant; Stage = 'Proof'; Dpi = $size.PrintDpi; Seed = $Unit.Seed; DesignDate = $dPrint.AddDays(2); Pages = $pageCount; Printer = $printer; Job = $job; Author = $printer } -EditMinutes 1
        }
        if ($dPrint -gt $dZip) { $dZip = $dPrint }
        if (-not $finalImage -and $UseRaster) { $finalImage = Get-RenderedImage -Items (Get-DesignItem $ctx $customer $size.W $size.H $finalVariant 'Final' $Unit.Seed $motif.Format $dPrint) -W $size.W -H $size.H -Dpi ([Math]::Max(30, [int](1600 / [Math]::Max($size.W, $size.H) * 72))) -Quality 86 -Noise 1 }
    }
    # Versand an die Druckerei: Paket der finalen Druckdaten (meist aufgehoben)
    if ($printFiles.Count -gt 0 -and $rng.Next(0, 10) -lt 7) {
        Add-Spec $specs ('{0}\{1}\{2}_{3}_{4:yyyy-MM-dd}.zip' -f $base, $step[3], $L.PrintData, $short, $dZip) 'zip' $dZip.AddMinutes(20) $rng @{ Sources = $printFiles.ToArray() } -EditMinutes 1
    }
    $dCorrection = Get-WorkDate $dDraft $rng 3 7
    $correction = Get-DocModel -Title "$($L.Correction) $name" -Author $owner -Created $dCorrection -Modified $dCorrection -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = $customer.Name; Lines = @("www.$($customer.Domain)") }
    Add-Block $correction 'Stamp' @{ Text = $L.Correction.ToUpperInvariant(); Text2 = (Format-LocalDate $dCorrection); Color = 'Red' }
    Add-Block $correction 'Title' @{ Text = ('{0}: {1}' -f $L.Feedback, $name) }
    Add-Block $correction 'Bullets' @{ Items = @(1..(3 + $rng.Next(0, 3)) | ForEach-Object { Get-SampleText 'CustomerFeedback' $rng $ctx }) }
    Add-Block $correction 'Sign' @{ Name = ($customer.Contact -replace $SalutationPattern, ''); Role = $customer.Name; Seed = $Unit.Seed + 7 }
    $correction.Scan = Get-ScanProfile $rng $dCorrection
    Add-Spec $specs ('{0}\{1}\{2}_{3}_{4:yyyy-MM-dd}.pdf' -f $base, $step[3], $L.Correction, $short, $dCorrection) 'pdf' $dCorrection $rng @{ Model = $correction }
    $dRelease = Get-WorkDate $dCorrection $rng 5 12
    $release = Get-DocModel -Title $L.PrintRelease -Author $owner -Created $dRelease -Modified $dRelease -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = $customer.Name; Lines = @("www.$($customer.Domain)") }
    Add-Block $release 'Stamp' @{ Text = $L.Released; Text2 = (Format-LocalDate $dRelease); Color = 'Blue' }
    Add-Block $release 'Title' @{ Text = ('{0} {1}' -f $L.PrintRelease, $name) }
    Add-Block $release 'Para' @{ Text = (Get-SampleText 'PrintRelease' $rng $ctx) }
    Add-Block $release 'Sign' @{ Name = ($customer.Contact -replace $SalutationPattern, ''); Role = $customer.Name; Seed = $Unit.Seed + 9 }
    $release.Scan = Get-ScanProfile $rng $dRelease
    Add-Spec $specs ('{0}\{1}\{2}_{3}.pdf' -f $base, $step[3], $L.PrintRelease, $short) 'pdf' $dRelease $rng @{ Model = $release }

    # Praesentation (PPTX und PDF-Export)
    $dPres = Get-WorkDate $dDraft $rng 1 5
    $footer = '{0} {1} {2} {3} {4}' -f $C.Company.Short, $MidDot, $customer.Short, $MidDot, (Format-LocalDate $dPres)
    $slides = @(
        @{ Layout = 'Title'; Title = $name; Subtitle = ('{0} {1} {2}' -f $customer.Name, $MidDot, (Format-LocalDate $dPres)) }
        @{ Layout = 'Content'; Title = $L.Situation; Text = (Get-SampleText 'ConceptSituation' $rng $ctx) }
        @{ Layout = 'Content'; Title = $L.Audience; Text = (Get-SampleText 'BriefingAudience' $rng $ctx) }
        @{ Layout = 'ImageRight'; Title = $L.Idea; Text = (Get-SampleText 'ConceptIdea' $rng $ctx); Image = $moodboard }
        @{ Layout = 'ImageFull'; Title = $ctx.Claim; Image = $finalImage }
        @{ Layout = 'Content'; Title = $L.Measures; Text = (Get-SampleText 'ConceptMeasures' $rng $ctx) }
        @{ Layout = 'Content'; Title = $L.NextSteps; Bullets = @(1..3 | ForEach-Object { Get-SampleText 'NextStep' $rng $ctx }) }
        @{ Layout = 'Closing'; Title = $L.Thanks; Subtitle = $owner.Name }
    )
    $presName = '{0}_{1}_{2:yyyy-MM-dd}' -f $L.Presentation, $short, $dPres
    $presModel = @{ Title = "$name $MidDot $($customer.Name)"; Author = $owner.Name; LastModifiedBy = $colleague.Name; Company = $C.Company.Name; Ci = $ci; Wide = $true; Slides = $slides; Classification = $L.Internal }
    Add-Spec $specs ('{0}\{1}\{2}.pptx' -f $base, $step[4], $presName) 'pptx' $dPres $rng @{ Model = $presModel }
    Add-Spec $specs ('{0}\{1}\{2}.pdf' -f $base, $step[4], $presName) 'slides' $dPres.AddMinutes(40) $rng @{ Slides = $slides; Ci = $ci; Footer = $footer; Info = @{ Title = $presModel.Title; Author = $owner.Name; Creator = 'Microsoft PowerPoint' } }

    # Rechnung (auch in der Buchhaltung), Bericht, Pressemitteilung, Gewinnspiel
    $dInvoice = Get-WorkDate $dRelease $rng 7 25
    $invoice = Get-DocModel -Title "$($L.Invoice) $invoiceNo" -Author $owner -Created $dInvoice -Modified $dInvoice -Ci $ci
    Add-Block $invoice 'Address' @{ Lines = $address }
    Add-Block $invoice 'Info' @{ Rows = [ordered]@{ $L.Number = $invoiceNo; $L.Date = (Format-LocalDate $dInvoice); $L.CustomerNo = $customerNo; $L.Project = $name } }
    Add-Block $invoice 'Title' @{ Text = "$($L.Invoice) $invoiceNo" }
    Add-Block $invoice 'Para' @{ Text = ('{0},' -f $ctx.Anrede) }
    $invoiceTotal = Add-PositionTable $invoice $lines
    Add-Block $invoice 'Para' @{ Text = ('{0} {1}' -f $L.Regards, $C.Company.Name) }
    $invoiceName = '{0}_{1}.pdf' -f $invoiceNo, $short
    Add-Spec $specs ('{0}\{1}\{2}' -f $base, $step[5], $invoiceName) 'pdf' $dInvoice $rng @{ Model = $invoice }
    $accounting = Get-AreaPath $dInvoice ('{0}\{1}\{2}' -f $Paths.Accounting, $F.Outgoing, $year) ('{0}\{1}' -f $AreaName.Accounting, $F.Outgoing)
    Add-Spec $specs ('{0}\{1}' -f $accounting, $invoiceName) 'copy' $dInvoice.AddMinutes(5) $rng @{ Source = ('{0}\{1}\{2}' -f $base, $step[5], $invoiceName) }

    # Korrespondenz: Brief an den Kunden, bei Druckprojekten gelegentlich an die Druckerei
    if ($rng.Next(0, 10) -lt 4 -and $T.LetterCustomer) {
        # Nur projektbezogene Briefe; Rundbriefe wie Preisanpassungen gehoeren nicht in den Projektordner.
        $record = Get-RandomEntry $rng @($T.LetterCustomer | Where-Object { ('{0} {1}' -f $_.Subject, $_.Text) -match '\{Projekt\}' })
        $dLetter = if ($record.Subject -match $Patterns.Thanks) { Get-WorkDate $dInvoice $rng 3 10 } else { Get-WorkDate $dBrief $rng 2 12 }
        $letterCtx = Get-TextContext -Rng $rng -Date $dLetter -Customer $customer -Project $name -Author $owner
        $letterCtx.Claim = $ctx.Claim
        Add-Spec $specs ('{0}\{1}\{2:yyyy-MM-dd}_{3}.docx' -f $base, $F.Letters, $dLetter, (ConvertTo-SafeName (Expand-SampleText $record.Subject $letterCtx))) 'docx' $dLetter $rng @{ Model = (Get-LetterModel $record $letterCtx $owner $dLetter $ci $address) }
    }
    if ($printFiles.Count -gt 0 -and $rng.Next(0, 10) -lt 2 -and $T.LetterSupplier) {
        $printer = $C.Suppliers | Select-Object -First 1
        $record = Get-RandomEntry $rng @($T.LetterSupplier | Where-Object { $_.Subject -match '\{Projekt\}' })
        $dLetter = Get-WorkDate $dRelease $rng 3 9
        $letterCtx = Get-TextContext -Rng $rng -Date $dLetter -Customer $customer -Project $name -Author $owner
        $printerAddress = @($printer.Name, ('www.{0}' -f $printer.Domain), $printer.City)
        Add-Spec $specs ('{0}\{1}\{2:yyyy-MM-dd}_{3}.docx' -f $base, $F.Letters, $dLetter, (ConvertTo-SafeName (Expand-SampleText $record.Subject $letterCtx))) 'docx' $dLetter $rng @{ Model = (Get-LetterModel $record $letterCtx $owner $dLetter $ci $printerAddress) }
    }
    # Zahlungserinnerung und Mahnung, wenn der Kunde nicht zahlt
    if ($rng.Next(0, 10) -lt 2 -and $T.Reminder) {
        $booker = Get-Person $Roles.Accountant $dInvoice $HqSite.Name $rng
        if ($booker.Department -ne 'Accounting') { $booker = $PeopleBySam[$Roles.Ceo] }
        $level = 1
        $dRemind = Get-WorkDate $dInvoice $rng 21 30
        while ($level -le 2 -and $dRemind -lt $Reference) {
            $record = Get-RandomEntry $rng @($T.Reminder | Where-Object { [int]$_.Level -eq $level })
            $remindCtx = Get-TextContext -Rng $rng -Date $dRemind -Customer $customer -Project $name -Author $booker
            $remindCtx.Vortermin = Format-LocalDate $(if ($level -eq 1) { $dInvoice.AddDays(14) } else { $dPrevious })
            $title = if ($level -eq 1) { $L.Reminder } else { $L.Dunning }
            $remind = Get-DocModel -Title "$title $invoiceNo" -Author $booker -Created $dRemind -Modified $dRemind -Ci $ci
            Add-Block $remind 'Address' @{ Lines = $address }
            Add-Block $remind 'Info' @{ Rows = [ordered]@{ $L.Number = $invoiceNo; $L.Date = (Format-LocalDate $dRemind); $L.CustomerNo = $customerNo } }
            Add-Block $remind 'Title' @{ Text = "$title $invoiceNo" }
            Add-Block $remind 'Para' @{ Text = ('{0},' -f $remindCtx.Anrede) }
            Add-Block $remind 'Para' @{ Text = (Expand-SampleText $record.Text $remindCtx) }
            Add-Block $remind 'Table' @{ Header = [string[]]@($L.Invoice, $L.Date, $L.Amount); Rows = @(, [string[]]@($invoiceNo, (Format-LocalDate $dInvoice), (Format-Money $invoiceTotal))); Widths = @(0.4, 0.3, 0.3); Align = 'LLR' }
            Add-Block $remind 'Para' @{ Text = ('{0} {1}' -f $L.Regards, $C.Company.Name) }
            $remindPath = Get-AreaPath $dRemind ('{0}\{1}\{2}' -f $Paths.Accounting, $F.Reminders, $dRemind.Year) ('{0}\{1}' -f $AreaName.Accounting, $F.Reminders)
            Add-Spec $specs ('{0}\{1:yyyy-MM-dd}_{2}_{3}.pdf' -f $remindPath, $dRemind, $title, $invoiceNo) 'pdf' $dRemind $rng @{ Model = $remind }
            if ($rng.Next(0, 10) -lt 6) { break }
            $dPrevious = $dRemind
            $dRemind = Get-WorkDate $dRemind $rng 14 21
            $level++
        }
    }

    if ($name -match $Patterns.Report) {
        $dReport = Get-WorkDate $dInvoice $rng 30 60
        $report = Get-DocModel -Title "$($L.Report) $name" -Author $owner -Created $dReport -Modified $dReport -Ci $ci -SenderKind 'None' -Classification $L.Internal
        Add-Block $report 'Title' @{ Text = "$($L.Report) $name $MidDot $($customer.Short)" }
        Add-Block $report 'Heading' @{ Text = $L.Results }
        Add-Block $report 'Para' @{ Text = (Get-SampleText 'ReportSummary' $rng $ctx) }
        $series = @(@(1..4 | ForEach-Object { 1000 + $rng.Next(0, 9000) }), @(1..4 | ForEach-Object { 1000 + $rng.Next(0, 9000) }))
        if ($UseRaster) {
            $chart = Get-RenderedImage -Items @(@{ K = 'Chart'; X = 0; Y = 0; W = 480; H = 260; Chart = @{ Labels = @($C.Months[($dInvoice.Month - 1) % 12], $C.Months[$dInvoice.Month % 12], $C.Months[($dInvoice.Month + 1) % 12], $C.Months[($dInvoice.Month + 2) % 12]); Series = $series; Colors = @($ci.Primary, $ci.Accent) } }) -W 480 -H 260 -Dpi 110 -Format 'png'
            Add-Block $report 'Image' @{ Bytes = $chart.Bytes; Format = 'png'; WidthPx = $chart.WidthPx; HeightPx = $chart.HeightPx; WidthCm = 15; Caption = ('{0} / {1}' -f $L.Plan, $L.Actual) }
        }
        Add-Block $report 'Heading' @{ Text = $L.Learnings }
        Add-Block $report 'Para' @{ Text = (Get-SampleText 'ReportLearnings' $rng $ctx) }
        $reportPath = Get-AreaPath $dReport ('{0}\{1}\{2}\{3}' -f $Paths.Marketing, $owner.Site, $F.Reports, $year) ('{0}\{1}' -f $AreaName.Marketing, $F.Reports)
        Add-Spec $specs ('{0}\{1}_{2}_{3}.docx' -f $reportPath, $L.Report, $short, (ConvertTo-SafeName $name)) 'docx' $dReport $rng @{ Model = $report }
        if ($rng.Next(0, 4) -eq 0) {
            $press = Get-DocModel -Title $L.Press -Author $owner -Created $dReport -Modified $dReport -Ci $ci -Classification $L.Public
            Add-Block $press 'Title' @{ Text = (Get-SampleText 'PressHeadline' $rng $ctx) }
            Add-Block $press 'Para' @{ Text = (Get-SampleText 'PressBody' $rng $ctx) }
            Add-Block $press 'Para' @{ Text = (Get-SampleText 'PressQuote' $rng $ctx) }
            $pressPath = Get-AreaPath $dReport ('{0}\{1}\{2}\{3}' -f $Paths.Marketing, $owner.Site, $F.Press, $year) ('{0}\{1}' -f $AreaName.Marketing, $F.Press)
            Add-Spec $specs ('{0}\{1}_{2}_{3:yyyy-MM-dd}.docx' -f $pressPath, $L.PressFile, $short, $dReport) 'docx' $dReport $rng @{ Model = $press }
        }
        if ($rng.Next(0, 5) -eq 0) {
            Add-Spec $specs ('{0}\{1}\{2}_{3}.xlsx' -f $base, $step[1], $L.Raffle, $L.Participants) 'xlsx' $dReport.AddDays(-20) $rng @{ Model = (Get-RaffleModel $rng $owner $ci $name) }
        }
    }
    , $specs.ToArray()
}

function Get-RaffleModel {
    # Gewinnspiel-Teilnehmende mit vollstaendigen Kontaktdaten - absichtlich nicht geloescht und ohne Kennzeichnung.
    param($Rng, $Author, $Ci, [string] $Project)
    $rows = [System.Collections.Generic.List[object]]::new()
    $rows.Add(@{ Style = 'Header'; Cells = @(@{ V = $L.Name }, @{ V = $L.Address }, @{ V = $L.BirthDate }, @{ V = $L.Email }, @{ V = $L.Phone }) })
    foreach ($n in 1..(40 + $Rng.Next(0, 120))) {
        $given = Get-RandomEntry $Rng $C.FirstNames
        $sur = Get-RandomEntry $Rng $C.LastNames
        $city = Get-RandomEntry $Rng $C.LocalCities
        $rows.Add(@{ Cells = @(@{ V = "$given $sur" }, @{ V = ('{0}, {1}' -f ($Locale.StreetLine -f (Get-RandomEntry $Rng $C.Streets), $Rng.Next(1, 120)), ($Locale.CityLine -f (Get-PostalCode $Rng $city), $city)) }, @{ V = (New-Object -TypeName DateTime -ArgumentList (1950 + $Rng.Next(0, 55)), (1 + $Rng.Next(0, 12)), (1 + $Rng.Next(0, 28))); Fmt = 'Date' }, @{ V = (Get-PrivateMail $Rng $given $sur) }, @{ V = (Get-DramaPhone $Rng -Mobile) }) })
    }
    @{ Title = "$($L.Raffle) $Project"; Author = $Author.Name; Company = $C.Company.Name; Ci = $Ci; Sheets = @(@{ Name = $L.Participants; Columns = @(@{ Width = 24 }, @{ Width = 40 }, @{ Width = 14 }, @{ Width = 32 }, @{ Width = 20 }); Rows = $rows.ToArray(); Freeze = 1; AutoFilter = $true }) }
}

#endregion
#region Bausteine: Buchhaltung, Jahr, Ereignisse, IT und Branding

function Get-XlsxTable {
    # Einfaches Blatt aus Kopf und Zeilen (Werte), optional mit Summenzeile ueber Spalte $SumColumn (1-basiert).
    param([string] $Title, $Author, $Ci, [string] $Sheet, [string[]] $Header, [object[]] $Rows, [int[]] $Widths, [string[]] $Formats = @(), [string] $Marking = $null, [string] $Classification = $null, [int] $SumColumn = 0)
    $out = [System.Collections.Generic.List[object]]::new()
    $out.Add(@{ Style = 'Header'; Cells = @($Header | ForEach-Object { @{ V = $_ } }) })
    foreach ($row in $Rows) {
        $cells = for ($colIdx = 0; $colIdx -lt $row.Count; $colIdx++) { @{ V = $row[$colIdx]; Fmt = $(if ($colIdx -lt $Formats.Count -and $Formats[$colIdx]) { $Formats[$colIdx] } else { $null }) } }
        $out.Add(@{ Cells = @($cells) })
    }
    if ($SumColumn -gt 0) {
        $col = [char](64 + $SumColumn)
        $sum = 0.0
        foreach ($row in $Rows) { $sum += [double]$row[$SumColumn - 1] }
        $cells = for ($colIdx = 1; $colIdx -le $Header.Count; $colIdx++) { if ($colIdx -eq 1) { @{ V = $L.Sum } } elseif ($colIdx -eq $SumColumn) { @{ V = $sum; F = ('SUM({0}2:{0}{1})' -f $col, ($Rows.Count + 1)); Fmt = $Formats[$SumColumn - 1] } } else { @{ V = $null } } }
        $out.Add(@{ Style = 'Total'; Cells = @($cells) })
    }
    @{ Title = $Title; Author = $Author.Name; Company = $C.Company.Name; Ci = $Ci; Marking = $Marking; Classification = $Classification
        Sheets = @(@{ Name = $Sheet; Columns = @($Widths | ForEach-Object { @{ Width = $_ } }); Rows = $out.ToArray(); Freeze = 1; AutoFilter = $true }) }
}

function Get-ReceiptSheetItem {
    # A4-Blatt mit aufgeklebten Kassenbons eines Monats (Belegordner), Bons in Thermodruck-Optik.
    param([Parameter(Mandatory)] $Rng, [datetime] $Month)
    $items = [System.Collections.Generic.List[object]]::new()
    $items.Add(@{ K = 'Rect'; X = 0; Y = 0; W = 595; H = 842; Color = @(255, 255, 255) })
    $count = 2 + $Rng.Next(0, 3)
    for ($r = 0; $r -lt $count; $r++) {
        $shop = Get-RandomEntry $Rng $C.Shops
        $x = 70 + ($r % 2) * 250 + $Rng.Next(-15, 16)
        $y = 60 + [Math]::Floor($r / 2) * 380 + $Rng.Next(-20, 21)
        $date = $Month.AddDays($Rng.Next(0, 27)).AddHours(8 + $Rng.Next(0, 11)).AddMinutes($Rng.Next(0, 60))
        $positions = @(Get-RandomSubset $Rng $shop.Items (1 + $Rng.Next(0, 3)))
        $height = 150 + 12 * $positions.Count
        $items.Add(@{ K = 'Rect'; X = $x; Y = $y; W = 180; H = $height; Color = @(247, 246, 240) })
        $ty = $y + 14
        $lines = [System.Collections.Generic.List[object]]::new()
        $lines.Add(@($shop.Name, $true))
        $lines.Add(@($date.ToString($Locale.ReceiptDate, $Culture), $false))
        $lines.Add(@('--------------------------', $false))
        $sum = 0.0
        foreach ($position in $positions) {
            $part = $position -split '\|'
            $min = [double]::Parse($part[1], $Inv)
            $max = [double]::Parse($part[2], $Inv)
            $price = [Math]::Round($min + $Rng.NextDouble() * ($max - $min), 2)
            $sum += $price
            $lines.Add(@(('{0,-16}{1,9}' -f $(if ($part[0].Length -gt 16) { $part[0].Substring(0, 16) } else { $part[0] }), $price.ToString('N2', $Culture)), $false))
        }
        $lines.Add(@('--------------------------', $false))
        $lines.Add(@(('{0,-16}{1,9}' -f $L.ReceiptTotal, $sum.ToString('N2', $Culture)), $true))
        $lines.Add(@(('{0,-16}{1,9}' -f $L.ReceiptVat, ($sum - $sum / (1 + $Locale.Vat)).ToString('N2', $Culture)), $false))
        $lines.Add(@('', $false))
        $lines.Add(@(($L.ReceiptNo -f $Rng.Next(1000, 99999)), $false))
        foreach ($line in $lines) {
            $items.Add(@{ K = 'Text'; X = $x + 10; Y = $ty; Size = 7.5; Bold = [bool]$line[1]; Text = [string]$line[0]; Color = @(55, 55, 55); Family = 'Courier New' })
            $ty += 11
        }
    }
    , $items.ToArray()
}

function Get-IncomingInvoiceModel {
    param($Rng, [datetime] $Date, [long] $Index, $Ci)
    $supplierIndex = $Rng.Next(0, $C.Suppliers.Count)
    $supplier = $C.Suppliers[$supplierIndex]
    $number = '{0}-{1:D6}' -f $supplier.Name.Substring(0, 2).ToUpperInvariant(), (($Index * 37) % 1000000)
    $stable = Get-Rng -Index $supplierIndex -Salt 31
    $foreign = @{ Name = $supplier.Name; Lines = @(('{0} {1} {2}' -f ($Locale.StreetLine -f (Get-RandomEntry $stable $C.Streets), $stable.Next(1, 90)), $MidDot, ($Locale.CityLine -f (Get-PostalCode $stable $supplier.City), $supplier.City)), ('www.{0} {1} {2}@{0}' -f $supplier.Domain, $MidDot, $L.MailInvoice)) }
    $model = Get-DocModel -Title "$($L.Invoice) $number" -Author @{ Name = $supplier.Name } -Created $Date -Modified $Date -Ci $Ci -SenderKind 'Foreign' -Foreign $foreign
    $stamp = @{ Text = $L.Received; Text2 = (Format-LocalDate $Date.AddDays($Rng.Next(1, 5))); Color = 'Red' }
    if ($Rng.Next(0, 3) -gt 0) { $stamp.Text3 = $L.Booked }
    Add-Block $model 'Stamp' $stamp
    Add-Block $model 'Address' @{ Lines = $Ci.HeaderLines }
    Add-Block $model 'Info' @{ Rows = [ordered]@{ $L.Number = $number; $L.Date = (Format-LocalDate $Date); $L.CustomerNo = ('{0}{1}' -f $L.SupplierRef, (20000 + $supplierIndex * 17)) } }
    Add-Block $model 'Title' @{ Text = "$($L.Invoice) $number" }
    # Posten aus dem Drehbuch: Text|Preis von|Preis bis|Einheit|Menge bis
    $lines = @(foreach ($item in @(Get-RandomSubset $Rng $supplier.Items (1 + $Rng.Next(0, 3)))) {
            $part = $item -split '\|'
            $min = if ($part.Count -gt 1) { [double]::Parse($part[1], $Inv) } else { 25 }
            $max = if ($part.Count -gt 2) { [double]::Parse($part[2], $Inv) } else { 400 }
            $qtyMax = if ($part.Count -gt 4) { [int]$part[4] } else { 1 }
            @{ Text = $part[0]; Qty = 1 + $Rng.Next(0, $qtyMax); Unit = $(if ($part.Count -gt 3) { $part[3] } else { $L.Piece }); Price = [Math]::Round($min + $Rng.NextDouble() * ($max - $min), 2) }
        })
    $null = Add-PositionTable $model $lines
    $model.Scan = Get-ScanProfile $Rng $Date
    @{ Model = $model; Supplier = $supplier; Number = $number }
}

function Build-AccountingUnit {
    # Ein Monat Buchhaltung: Eingangsrechnungen (Scans), Kontoauszug, BWA, Lohnjournal, Entgeltabrechnungen,
    # Kreditkarte (quartalsweise), Reisekosten, Scan-Eingang.
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $rng = Get-Rng -Index $Unit.Seed -Salt 211
    $month = $Unit.Month
    $year = $month.Year
    $ci = Get-DocumentCi $month $HqSite.Name
    $staff = Get-ActivePerson -Date $month
    $booker = Get-Person $Roles.Accountant $month $HqSite.Name $rng
    if ($booker.Department -ne 'Accounting') { $booker = $PeopleBySam[$Roles.Ceo] }
    $bh = $Paths.Accounting
    $folder = [System.Collections.Generic.List[object]]::new()
    foreach ($n in 1..(2 + [Math]::Ceiling($staff.Count / 3) + $rng.Next(0, 3))) {
        $date = Get-WorkDate $month $rng 0 26
        $invoice = Get-IncomingInvoiceModel $rng $date ($Unit.Seed * 50 + $n) $ci
        $folder.Add($invoice.Model)
        $path = Get-AreaPath $date ('{0}\{1}\{2}' -f $bh, $F.Incoming, $year) ('{0}\{1}' -f $AreaName.Accounting, $F.Incoming)
        Add-Spec $specs ('{0}\{1:yyyy-MM-dd}_{2}_{3}.pdf' -f $path, $date, (Get-ShortName $invoice.Supplier.Name), $invoice.Number) 'pdf' $date $rng @{ Model = $invoice.Model }
        if ($date -gt $Reference.AddMonths(-18) -and $rng.Next(0, 3) -eq 0) {
            $scanDate = $date.AddDays($rng.Next(1, 4))
            Add-Spec $specs ('{0}\Scan_{1:yyyyMMdd_HHmmss}.pdf' -f $Paths.Scans, $scanDate) 'pdf' $scanDate $rng @{ Model = $invoice.Model }
        }
    }
    $end = $month.AddMonths(1).AddDays(-1).AddHours(18)
    # Kontoauszug
    $bank = Get-DocModel -Title ('{0} {1:MM}/{1:yyyy}' -f $L.Statement, $month) -Author @{ Name = $C.Company.Bank } -Created $end -Modified $end -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = $C.Company.Bank; Lines = @(('{0} {1}' -f $L.Iban, $script:CompanyIban)) }
    Add-Block $bank 'Address' @{ Lines = $ci.HeaderLines }
    Add-Block $bank 'Title' @{ Text = ('{0} {1} {2}' -f $L.Statement, $C.Months[$month.Month - 1], $year) }
    $balance = [double]$rng.Next(15000, 90000)
    $start = $balance
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($n in 1..(10 + $rng.Next(0, 14))) {
        $kind = $rng.Next(0, 10)
        if ($kind -lt 4) { $text = '{0}{1}-{2:D4} {3}' -f $L.InvoiceId, $year, $rng.Next(1, 9999), (Get-RandomEntry $rng $C.Customers).Name; $amount = [double]$rng.Next(400, 18000) }
        elseif ($kind -lt 7) { $text = (Get-RandomEntry $rng $C.Suppliers).Name; $amount = - [double]$rng.Next(40, 4000) }
        else { $text = Get-RandomEntry $rng $C.Bookings; $amount = - [double]$rng.Next(60, 9000) }
        $balance += $amount
        $rows.Add([string[]]@((Format-LocalDate $month.AddDays([Math]::Min(27, $n * 2))), $text, (Format-Money $amount)))
    }
    Add-Block $bank 'Table' @{ Header = [string[]]@($L.Date, $L.Booking, $L.Amount); Rows = $rows.ToArray(); Widths = @(0.18, 0.57, 0.25); Align = 'LLR' }
    Add-Block $bank 'Table' @{ Header = $null; Rows = @([string[]]@($L.OldBalance, (Format-Money $start)), [string[]]@($L.NewBalance, (Format-Money $balance))); Widths = @(0.7, 0.3); Align = 'RR'; BoldLast = $true; Plain = $true }
    $bank.Creator = $C.Company.Bank
    Add-Spec $specs ('{0}\{1:yyyy-MM}.pdf' -f (Get-AreaPath $end ('{0}\{1}\{2}' -f $bh, $F.Statements, $year) ('{0}\{1}' -f $AreaName.Accounting, $F.Statements)), $month) 'pdf' $end $rng @{ Model = $bank }
    # Belegordner des Monats fuer die Steuerkanzlei: komplett gescannt, 300 dpi, gelocht, mit aufgeklebten Kassenbons.
    $folder.Add($bank)
    $sheets = @(1..(1 + $rng.Next(0, 3)) | ForEach-Object { , (Get-ReceiptSheetItem $rng $month) })
    $folderDate = Get-WorkDate $end $rng 2 6
    $folderScan = Get-ScanProfile $rng $folderDate
    $folderScan.Dpi = 300
    $folderScan.Holes = $true
    $folderPath = Get-AreaPath $folderDate ('{0}\{1}\{2}' -f $bh, $F.Receipts, $year) ('{0}\{1}' -f $AreaName.Accounting, $F.Receipts)
    Add-Spec $specs ('{0}\{1}_{2:yyyy-MM}.pdf' -f $folderPath, $F.Receipts, $month) 'scanbundle' $folderDate $rng @{ Models = $folder.ToArray(); Sheets = $sheets; Profile = $folderScan; Device = $folderScan.Device } -EditMinutes 2
    # BWA der Steuerkanzlei
    $bwaDate = Get-WorkDate $end $rng 8 15
    $advisorLine = 'www.{0} {1} {2}' -f $TaxAdvisor.Domain, $MidDot, ((Get-Dial $TaxAdvisor.City) -f 310)
    $bwa = Get-DocModel -Title ('{0} {1:MM}/{1:yyyy}' -f $L.Bwa, $month) -Author @{ Name = $TaxAdvisor.Name } -Created $bwaDate -Modified $bwaDate -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = $TaxAdvisor.Name; Lines = @($advisorLine) } -Classification $L.Confidential
    Add-Block $bwa 'Title' @{ Text = ('{0} {1} {2}' -f $L.Bwa, $C.Months[$month.Month - 1], $year) }
    $revenue = [double](20000 + $staff.Count * $rng.Next(5000, 9000))
    $values = @($revenue) + @(0.22, 0.4, 0.07, 0.05, 0.03, 0.04 | ForEach-Object { - [Math]::Round($revenue * $_ * (0.8 + $rng.NextDouble() * 0.4)) })
    $values += ($values | Measure-Object -Sum).Sum
    $bwaRows = for ($k = 0; $k -lt $C.BwaRows.Count; $k++) { , [string[]]@($C.BwaRows[$k], (Format-Money $values[$k]), (Format-Money ($values[$k] * $month.Month))) }
    Add-Block $bwa 'Table' @{ Header = [string[]]@($L.Kpi, $L.Month, $L.Cumulative); Rows = @($bwaRows); Widths = @(0.46, 0.27, 0.27); Align = 'LRR'; BoldLast = $true }
    Add-Spec $specs ('{0}\{1}_{2:yyyy-MM}.pdf' -f (Get-AreaPath $bwaDate ('{0}\{1}\{2}' -f $Paths.Management, $F.Bwa, $year) ('{0}\{1}' -f $AreaName.Management, $F.Bwa)), $L.BwaFile, $month) 'pdf' $bwaDate $rng @{ Model = $bwa }
    # Lohnjournal und Entgeltabrechnungen (personenbezogen, streng vertraulich)
    $secret = '{0} {1} {2}' -f $L.Secret, ([char]0x2013), $C.Departments.HR
    $payRows = foreach ($p in $staff) {
        $pdata = Get-PersonProfile -Key $p.Sam -GivenName $p.GivenName -Surname $p.Surname -BirthYear $p.Born -City $p.Site -Female $p.Female
        , @($p.Name, $pdata.TaxId, $pdata.Social, $pdata.Iban, [double]$p.Salary)
    }
    $journal = Get-XlsxTable -Title ('{0} {1:MM}/{1:yyyy}' -f $L.Payroll, $month) -Author $booker -Ci $ci -Sheet $L.Payroll -Header @($L.Name, $L.TaxId, $L.SocialNo, $L.Iban, $L.Gross) -Rows @($payRows) -Widths @(24, 18, 22, 30, 14) -Formats @($null, $null, $null, $null, 'Money') -Marking $secret -Classification $L.Secret -SumColumn 5
    Add-Spec $specs ('{0}\{1}_{2:yyyy-MM}.xlsx' -f (Get-AreaPath $end ('{0}\{1}\{2}' -f $bh, $F.Payroll, $year) ('{0}\{1}' -f $AreaName.Accounting, $F.Payroll)), $L.Payroll, $month) 'xlsx' $end.AddDays(-3) $rng @{ Model = $journal }
    foreach ($p in $staff) {
        $pdata = Get-PersonProfile -Key $p.Sam -GivenName $p.GivenName -Surname $p.Surname -BirthYear $p.Born -City $p.Site -Female $p.Female
        $slip = Get-DocModel -Title ('{0} {1:MM}/{1:yyyy}' -f $L.Salary, $month) -Author @{ Name = $TaxAdvisor.Name } -Created $end -Modified $end -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = $TaxAdvisor.Name; Lines = @(($L.OnBehalf -f $C.Company.Name)) } -Marking $secret -Classification $L.Secret
        Add-Block $slip 'Address' @{ Lines = @($p.Name, $pdata.Street, $pdata.City) }
        Add-Block $slip 'Info' @{ Rows = [ordered]@{ $L.Month = ('{0} {1}' -f $C.Months[$month.Month - 1], $year); $L.TaxId = $pdata.TaxId; $L.SocialNo = $pdata.Social; $L.TaxClass = $pdata.TaxClass } }
        Add-Block $slip 'Title' @{ Text = ('{0} {1} {2}' -f $L.Salary, $C.Months[$month.Month - 1], $year) }
        $gross = [double]$p.Salary
        $tax = [Math]::Round($gross * $Locale.Tax, 2)
        $social = [Math]::Round($gross * $Locale.Social, 2)
        Add-Block $slip 'Table' @{ Header = $null; Rows = @([string[]]@($L.Gross, (Format-Money $gross)), [string[]]@($L.Tax, (Format-Money (-$tax))), [string[]]@($L.Social, (Format-Money (-$social))), [string[]]@($L.NetSalary, (Format-Money ($gross - $tax - $social)))); Widths = @(0.7, 0.3); Align = 'LR'; BoldLast = $true }
        Add-Block $slip 'Para' @{ Text = ('{0}: {1} ({2})' -f $L.Iban, $pdata.Iban, $pdata.Bank) }
        $folder = '{0}\{1}\{2}, {3}\{4}\{5}' -f $Paths.HR, $F.Files, $p.Surname, $p.GivenName, $F.Payslips, $year
        Add-Spec $specs ('{0}\{1}_{2:yyyy-MM}.pdf' -f $folder, $L.PayslipFile, $month) 'pdf' $end $rng @{ Model = $slip }
    }
    # Firmenkreditkarte (quartalsweise, Testkartennummer)
    if ($month.Month % 3 -eq 0) {
        $card = Get-DocModel -Title $L.CreditCard -Author @{ Name = $C.Company.Bank } -Created $end -Modified $end -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = $C.Company.Bank; Lines = @($L.CreditCard) }
        Add-Block $card 'Info' @{ Rows = [ordered]@{ $L.CardNumber = (Get-CreditCard (Get-Rng -Index 7 -Salt 5)); $L.Holder = $PeopleBySam[$Roles.Ceo].Name; $L.Period = ('{0} {1}' -f $C.Months[$month.Month - 1], $year) } }
        Add-Block $card 'Title' @{ Text = ('{0} {1}/{2}' -f $L.CreditCard, [Math]::Ceiling($month.Month / 3), $year) }
        $cardRows = @(1..(4 + $rng.Next(0, 8)) | ForEach-Object { , [string[]]@((Format-LocalDate $month.AddDays(-$rng.Next(0, 80))), (Get-RandomEntry $rng $C.CardBookings), (Format-Money ($rng.Next(900, 60000) / 100.0))) })
        Add-Block $card 'Table' @{ Header = [string[]]@($L.Date, $L.Booking, $L.Amount); Rows = $cardRows; Widths = @(0.2, 0.55, 0.25); Align = 'LLR' }
        Add-Spec $specs ('{0}\{1}_{2:yyyy-MM}.pdf' -f (Get-AreaPath $end ('{0}\{1}\{2}' -f $bh, $F.CreditCard, $year) ('{0}\{1}' -f $AreaName.Accounting, $F.CreditCard)), $L.CreditCard, $month) 'pdf' $end $rng @{ Model = $card }
    }
    # Reisekosten mit Belegscan
    if ($rng.Next(0, 3) -eq 0) {
        $traveller = Get-RandomEntry $rng $staff
        $date = Get-WorkDate $month $rng 0 25
        $customer = Get-RandomEntry $rng $C.Customers
        $tctx = Get-TextContext -Rng $rng -Date $date -Customer $customer -Author $traveller
        $km = $rng.Next(20, 620)
        $hotel = [double]$rng.Next(79, 140)
        $travel = Get-DocModel -Title $L.Travel -Author $traveller -Created $date -Modified $date -Ci $ci -SenderKind 'None'
        Add-Block $travel 'Title' @{ Text = $L.Travel }
        Add-Block $travel 'Info' @{ Rows = [ordered]@{ $L.Employee = $traveller.Name; $L.Period = (Format-LocalDate $date); $L.Purpose = ('{0} {1}' -f $customer.Name, $customer.City) } }
        Add-Block $travel 'Table' @{ Header = [string[]]@($L.Description, $L.Amount); Rows = @([string[]]@(('{0}: {1} {2}' -f $L.Mileage, $km, $Locale.Distance), (Format-Money ($km * $Locale.Mileage))), [string[]]@($L.Allowance, (Format-Money $Locale.Allowance)), [string[]]@($L.Hotel, (Format-Money $hotel)), [string[]]@($L.Sum, (Format-Money ($km * $Locale.Mileage + $Locale.Allowance + $hotel)))); Widths = @(0.7, 0.3); Align = 'LR'; BoldLast = $true }
        Add-Block $travel 'Sign' @{ Name = $traveller.Name; Role = $L.Signature; Seed = $Unit.Seed }
        $path = Get-AreaPath $date ('{0}\{1}\{2}' -f $bh, $F.Travel, $year) ('{0}\{1}' -f $AreaName.Accounting, $F.Travel)
        Add-Spec $specs ('{0}\{1}_{2}_{3:yyyy-MM-dd}.docx' -f $path, $L.Travel, $traveller.Surname, $date) 'docx' $date $rng @{ Model = $travel }
        $receipt = Get-DocModel -Title $L.Receipt -Author $traveller -Created $date -Modified $date -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = (Get-RandomEntry $rng $C.Hotels); Lines = @($customer.City) }
        Add-Block $receipt 'Title' @{ Text = $L.Invoice }
        $null = Add-PositionTable $receipt @(@{ Text = $L.Hotel; Qty = 1; Unit = $L.Night; Price = $hotel })
        $receipt.Scan = Get-ScanProfile $rng $date
        Add-Spec $specs ('{0}\{1}_{2}_{3:yyyy-MM-dd}.pdf' -f $path, $L.Receipt, $traveller.Surname, $date) 'pdf' $date.AddDays(1) $rng @{ Model = $receipt }
        $null = $tctx
    }
    , $specs.ToArray()
}

#endregion
#region Bausteine: Personal, Bewerbungen, Basisordner

function Build-PersonUnit {
    # Personalakte (Personalbogen, Vertrag als Scan, Krankmeldungen, Gespraeche, Zeugnis/Abmahnung) und Basisordner.
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $p = $Unit.Person
    $rng = Get-Rng -Index $Unit.Seed -Salt 307
    $hr = Get-Person $Roles.Office $p.Entry $HqSite.Name $rng
    if ($hr.Department -ne 'HR') { $hr = $PeopleBySam[$Roles.ManagingDirector] }
    $ci = Get-DocumentCi $p.Entry $p.Site
    $pdata = Get-PersonProfile -Key $p.Sam -GivenName $p.GivenName -Surname $p.Surname -BirthYear $p.Born -City $p.Site -Female $p.Female
    $folder = '{0}\{1}\{2}, {3}' -f $Paths.HR, $F.Files, $p.Surname, $p.GivenName
    $secret = '{0} {1} {2}' -f $L.Secret, ([char]0x2013), $C.Departments.HR
    $ctx = Get-TextContext -Rng $rng -Date $p.Entry -Author $hr -Colleague $p
    $ctx.Stelle = $p.Role
    $ctx.Betrag = Format-Money $p.Salary

    # Personalbogen: alle Stammdaten (Ausweis, Steuer-ID, SV-Nummer, IBAN, Konfession)
    $created = $p.Entry.AddDays(-$rng.Next(5, 20))
    $sheet = Get-DocModel -Title "$($L.PersonnelSheet) $($p.Name)" -Author $hr -Created $created -Modified $created -Ci $ci -SenderKind 'None' -Marking $secret -Classification $L.Secret
    Add-Block $sheet 'Title' @{ Text = "$($L.PersonnelSheet) $($p.Name)" }
    $rows = @(
        @($L.Name, $p.Name), @($L.BirthDate, (Format-LocalDate $pdata.Birth)), @($L.BirthPlace, $pdata.BirthPlace), @($L.Address, ('{0}, {1}' -f $pdata.Street, $pdata.City))
        @($L.Phone, $pdata.Phone), @($L.Mobile, $pdata.Mobile), @($L.Email, $pdata.Mail), @($L.IdDocument, $pdata.IdCard)
        @($L.TaxId, $pdata.TaxId), @($L.TaxClass, $pdata.TaxClass), @($L.SocialNo, $pdata.Social), @($L.Insurance, $pdata.Insurer)
        @($L.Confession, $pdata.Confession), @($L.Marital, $pdata.Marital), @($L.Children, [string]$pdata.Children)
        @($L.Iban, $pdata.Iban), @($L.Bank, $pdata.Bank), @($L.Position, $p.Role), @($L.Location, $p.Site), @($L.Entry, (Format-LocalDate $p.Entry))
    )
    if ($p.Leave) { $rows += , @($L.Leave, (Format-LocalDate $p.Leave)) }
    Add-Block $sheet 'Table' @{ Header = $null; Rows = @($rows | ForEach-Object { , [string[]]$_ }); Widths = @(0.35, 0.65); Align = 'LL' }
    Add-Spec $specs ('{0}\{1}.docx' -f $folder, $L.PersonnelSheet) 'docx' $created $rng @{ Model = $sheet }

    # Arbeitsvertrag, unterschrieben und gescannt
    $contract = Get-DocModel -Title "$($L.Contract) $($p.Name)" -Author $hr -Created $created -Modified $created -Ci $ci -Classification $L.Secret
    Add-Block $contract 'Title' @{ Text = $L.Contract }
    Add-Block $contract 'Para' @{ Text = ('{0} {1} {2}' -f $C.Company.Name, $MidDot, $p.Name) }
    foreach ($para in @($T.ContractParagraph)) {
        Add-Block $contract 'Heading' @{ Text = $para.Title }
        Add-Block $contract 'Para' @{ Text = (Expand-SampleText $para.Text $ctx) }
    }
    Add-Block $contract 'Sign' @{ Name = $PeopleBySam[$Roles.Ceo].Name; Role = $PeopleBySam[$Roles.Ceo].Role; Seed = 11 }
    Add-Block $contract 'Sign' @{ Name = $p.Name; Role = $L.Employee; Seed = $Unit.Seed }
    $contract.Scan = Get-ScanProfile $rng $created
    Add-Spec $specs ('{0}\{1}_{2}.pdf' -f $folder, $L.Contract, $p.Surname) 'pdf' $created.AddDays(3) $rng @{ Model = $contract }

    # Krankmeldungen (Gesundheitsdaten, Art. 9 DSGVO)
    $end = if ($p.Leave) { $p.Leave } else { $Reference }
    $years = [Math]::Max(1, [int](($end - $p.Entry).TotalDays / 365))
    foreach ($n in 1..[Math]::Min(12, $rng.Next(0, $years + 2))) {
        $date = Get-WorkDate $p.Entry $rng 30 ([int]($end - $p.Entry).TotalDays - 5)
        $sick = Get-DocModel -Title $L.SickNote -Author $p -Created $date -Modified $date -Ci $ci -SenderKind 'Foreign' -Foreign @{ Name = ($L.Doctor -f (Get-RandomEntry $rng $C.LastNames)); Lines = @($pdata.City) } -Classification $L.Secret
        Add-Block $sick 'Title' @{ Text = $L.SickNote }
        Add-Block $sick 'Info' @{ Rows = [ordered]@{ $L.Name = $p.Name; $L.BirthDate = (Format-LocalDate $pdata.Birth); $L.Insurance = $pdata.Insurer; $L.From = (Format-LocalDate $date); $L.To = (Format-LocalDate $date.AddDays($rng.Next(2, 12))) } }
        Add-Block $sick 'Sign' @{ Name = $sick.Foreign.Name; Seed = $n + $Unit.Seed }
        $sick.Scan = Get-ScanProfile $rng $date
        Add-Spec $specs ('{0}\{1}\{2:yyyy-MM-dd}_{3}.pdf' -f $folder, $F.SickNotes, $date, $L.SickNote.Substring(0, 3)) 'pdf' $date.AddDays(2) $rng @{ Model = $sick }
    }
    # Mitarbeitergespraeche, Abmahnung, Zeugnis
    foreach ($n in 1..[Math]::Min(4, $years)) {
        $date = Get-WorkDate $p.Entry.AddYears($n) $rng 0 40
        if ($date -ge $end) { break }
        $review = Get-DocModel -Title ('{0} {1}' -f $L.Review, $p.Name) -Author $hr -Created $date -Modified $date -Ci $ci -SenderKind 'None' -Marking $secret -Classification $L.Secret
        Add-Block $review 'Title' @{ Text = ('{0} {1} {2}' -f $L.Note, $MidDot, $p.Name) }
        Add-Block $review 'Para' @{ Text = (Get-SampleText 'ReviewNote' $rng $ctx) }
        Add-Spec $specs ('{0}\{1}_{2:yyyy-MM-dd}.docx' -f $folder, $L.ReviewFile, $date) 'docx' $date $rng @{ Model = $review }
    }
    if ($p.Grade -ge 3 -and $T.Warning) {
        $date = Get-WorkDate $p.Entry.AddDays(200) $rng 0 60
        $warning = Get-DocModel -Title $L.Warning -Author $PeopleBySam[$Roles.Ceo] -Created $date -Modified $date -Ci $ci -Marking $secret -Classification $L.Secret
        Add-Block $warning 'Address' @{ Lines = @($p.Name, $pdata.Street, $pdata.City) }
        Add-Block $warning 'Para' @{ Text = (Expand-SampleText $T.Warning[0].Text $ctx) }
        Add-Block $warning 'Sign' @{ Name = $PeopleBySam[$Roles.Ceo].Name; Role = $PeopleBySam[$Roles.Ceo].Role; Seed = 12 }
        Add-Spec $specs ('{0}\{1}_{2:yyyy-MM-dd}.docx' -f $folder, $L.Warning, $date) 'docx' $date $rng @{ Model = $warning }
    }
    if ($p.Leave) {
        $ref = @($T.Reference | Where-Object { [int]$_.Grade -eq [int]$p.Grade }) | Select-Object -First 1
        if ($ref) {
            $refModel = Get-DocModel -Title "$($L.Reference) $($p.Name)" -Author $hr -Created $p.Leave -Modified $p.Leave -Ci (Get-DocumentCi $p.Leave $p.Site) -Classification $L.Confidential
            Add-Block $refModel 'Title' @{ Text = $L.Reference }
            Add-Block $refModel 'Para' @{ Text = (Expand-SampleText $ref.Text $ctx) }
            Add-Block $refModel 'Sign' @{ Name = $PeopleBySam[$Roles.Ceo].Name; Role = $PeopleBySam[$Roles.Ceo].Role; Seed = 13 }
            Add-Spec $specs ('{0}\{1}_{2}.docx' -f $folder, $L.Reference, $p.Surname) 'docx' $p.Leave $rng @{ Model = $refModel }
            Add-Spec $specs ('{0}\{1}\{2}_{3}_{4}.pdf' -f $Paths.HR, $F.References, $L.Reference, $p.Surname, $p.GivenName) 'pdf' $p.Leave.AddHours(2) $rng @{ Model = $refModel }
        }
    }

    # Basisordner: Arbeitsnotizen in der eigenen Stimme, Privates (Verstoss gegen die IT-Richtlinie)
    if ($p.Sam -eq $Roles.Intern) { return , $specs.ToArray() }
    $homeFolder = '{0}\{1}' -f $Paths.Home, $p.Sam
    foreach ($n in 1..(4 + $rng.Next(0, 10))) {
        $date = Get-WorkDate $p.Entry $rng 10 ([int]($end - $p.Entry).TotalDays - 2)
        $nctx = Get-TextContext -Rng $rng -Date $date -Customer (Get-RandomEntry $rng $C.Customers) -Author $p
        $note = Get-DocModel -Title $L.Note -Author $p -Created $date -Modified $date -Ci (Get-DocumentCi $date $p.Site) -SenderKind 'None'
        Add-Block $note 'Para' @{ Text = (Get-SampleText 'HomeNote' $rng $nctx) }
        Add-Spec $specs ('{0}\{1}\{2}_{3:yyyy-MM-dd}.docx' -f $homeFolder, $F.Documents, (Get-RandomEntry $rng $C.NoteNames), $date) 'docx' $date $rng @{ Model = $note }
    }
    $privateCount = if ($p.Sam -eq $Roles.PrivateFiles) { 4 } elseif ($rng.Next(0, 3) -eq 0) { 1 + $rng.Next(0, 3) } else { 0 }
    foreach ($n in 1..$privateCount) {
        if ($privateCount -eq 0) { break }
        $record = Get-TextRecord -Kind 'PrivateNote' -Rng $rng
        $date = Get-WorkDate $p.Entry $rng 10 ([int]($end - $p.Entry).TotalDays - 2)
        $privCtx = Get-TextContext -Rng $rng -Date $date -Author $p
        $subject = Expand-SampleText $record.Subject $privCtx
        $priv = Get-DocModel -Title $subject -Author $p -Created $date -Modified $date -Ci (Get-DocumentCi $date $p.Site) -SenderKind 'None'
        Add-Block $priv 'Title' @{ Text = $subject }
        Add-Block $priv 'Para' @{ Text = (Expand-SampleText $record.Text $privCtx) }
        Add-Spec $specs ('{0}\{1}\{2}.docx' -f $homeFolder, $F.Private, (ConvertTo-SafeName $subject)) 'docx' $date $rng @{ Model = $priv }
    }
    , $specs.ToArray()
}

function Build-ApplicationUnit {
    # Bewerbungen eines Jahres: Unterlagen als Scan, Antworten, Uebersicht (Altlast: aelter als 6 Monate nicht geloescht).
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $rng = Get-Rng -Index $Unit.Seed -Salt 401
    $year = $Reference.Year - $Unit.YearsAgo
    $hr = Get-Person $Roles.Office (New-Object -TypeName DateTime -ArgumentList $year, 6, 1) $HqSite.Name $rng
    $folder = '{0}\{1}\{2}' -f $Paths.HR, $F.Applications, $year
    $overview = [System.Collections.Generic.List[object]]::new()
    foreach ($n in 1..(3 + $rng.Next(0, 7))) {
        $date = (New-Object -TypeName DateTime -ArgumentList $year, (1 + $rng.Next(0, 12)), (1 + $rng.Next(0, 27))).AddHours(9)
        if ($date -ge $Reference) { continue }
        $given = Get-RandomEntry $rng $C.FirstNames
        $sur = Get-RandomEntry $rng $C.LastNames
        $position = Get-RandomEntry $rng $C.Positions
        $pdata = Get-PersonProfile -Key "$given$sur$year$n" -GivenName $given -Surname $sur -BirthYear ($year - 22 - $rng.Next(0, 18)) -City $HqSite.City -Female (Test-Female $given)
        $ctx = Get-TextContext -Rng $rng -Date $date -Author $hr
        $ctx.Bewerber = "$given $sur"; $ctx.Stelle = $position
        $cover = $rng.Next(0, [Math]::Max(1, @($T.CoverOpening).Count))
        $app = Get-DocModel -Title ($L.Application -f $position) -Author @{ Name = "$given $sur" } -Created $date -Modified $date -Ci (Get-DocumentCi $date $HqSite.Name) -SenderKind 'Foreign' -Foreign @{ Name = "$given $sur"; Lines = @(('{0} {1} {2}' -f $pdata.Street, $MidDot, $pdata.City), ('{0} {1} {2}' -f $pdata.Mobile, $MidDot, $pdata.Mail)) }
        Add-Block $app 'Address' @{ Lines = (Get-DocumentCi $date $HqSite.Name).HeaderLines }
        Add-Block $app 'Title' @{ Text = ($L.Application -f $position) }
        foreach ($kind in 'CoverOpening', 'CoverExperience', 'CoverMotivation', 'CoverClosing') {
            $list = @($T[$kind])
            if ($list) { Add-Block $app 'Para' @{ Text = (Expand-SampleText $list[$cover % $list.Count].Text $ctx) } }
        }
        Add-Block $app 'Sign' @{ Name = "$given $sur"; Seed = $n + $Unit.Seed }
        Add-Block $app 'Break'
        Add-Block $app 'Title' @{ Text = $L.Cv }
        Add-Block $app 'Info' @{ Rows = [ordered]@{ $L.Name = "$given $sur"; $L.BirthDate = (Format-LocalDate $pdata.Birth); $L.Address = ('{0}, {1}' -f $pdata.Street, $pdata.City) } }
        Add-Block $app 'Bullets' @{ Items = @(Get-RandomSubset $rng $T.CvStation 4 | ForEach-Object { Expand-SampleText $_.Text $ctx }) }
        $app.Scan = Get-ScanProfile $rng $date
        $file = '{0}_{1}_{2}' -f $sur, $given, (ConvertTo-SafeName (($position -split '[ /(]')[0]))
        Add-Spec $specs ('{0}\{1}.pdf' -f $folder, $file) 'pdf' $date $rng @{ Model = $app }
        $invite = $rng.Next(0, 3) -eq 0
        $reply = Get-TextRecord -Kind 'ApplicationReply' -Rng $rng -Where @{}
        $replies = @($T.ApplicationReply | Where-Object { ($_.Subject -match $Patterns.Invitation) -eq $invite })
        if ($replies) { $reply = Get-RandomEntry $rng $replies }
        $replyDate = Get-WorkDate $date $rng 5 20
        $answer = Get-DocModel -Title (Expand-SampleText $reply.Subject $ctx) -Author $hr -Created $replyDate -Modified $replyDate -Ci (Get-DocumentCi $replyDate $HqSite.Name) -Classification $L.Confidential
        Add-Block $answer 'Address' @{ Lines = @("$given $sur", $pdata.Street, $pdata.City) }
        Add-Block $answer 'Title' @{ Text = (Expand-SampleText $reply.Subject $ctx) }
        Add-Block $answer 'Para' @{ Text = (Expand-SampleText $reply.Text $ctx) }
        Add-Block $answer 'Para' @{ Text = $L.Regards }
        Add-Block $answer 'Sign' @{ Name = $hr.Name; Role = $hr.Role; Seed = 21 }
        Add-Spec $specs ('{0}\{1}_{2}.docx' -f $folder, $file, $L.ReplyFile) 'docx' $replyDate $rng @{ Model = $answer }
        $overview.Add(@("$given $sur", $position, $date, $pdata.Mail, $pdata.Mobile, $(if ($invite) { $L.Interview } else { $L.Rejection })))
    }
    if ($overview.Count) {
        $model = Get-XlsxTable -Title ('{0} {1}' -f $L.Applicants, $year) -Author $hr -Ci (Get-DocumentCi (New-Object -TypeName DateTime -ArgumentList $year, 12, 1) $HqSite.Name) -Sheet $L.Applicants -Header @($L.Name, $L.Position, $L.Date, $L.Email, $L.Mobile, $L.Status) -Rows $overview.ToArray() -Widths @(22, 34, 12, 30, 18, 12) -Formats @($null, $null, 'Date') -Classification $L.Confidential
        $last = ($overview | ForEach-Object { $_[2] } | Sort-Object | Select-Object -Last 1)
        Add-Spec $specs ('{0}\{1}_{2}.xlsx' -f $folder, $L.Applicants, $year) 'xlsx' $last.AddDays(10) $rng @{ Model = $model }
    }
    , $specs.ToArray()
}

#endregion
#region Bausteine: Jahr, Ereignisse, Besprechungen, IT, Branding, Vorlagen

function Get-PolicyModel {
    param($Record, $Author, [datetime] $Date, [int] $Version)
    # Record.Classification ist ein Schluessel in Labels (Public, Internal, Confidential, Secret).
    $classification = $L[$Record.Classification]
    $marking = if ($Record.Classification -in 'Confidential', 'Secret') { $classification } else { $null }
    $policyCtx = Get-TextContext -Rng (Get-Rng -Index $Version -Salt 3) -Date $Date -Author $Author
    $title = Expand-SampleText $Record.Title $policyCtx
    $model = Get-DocModel -Title $title -Author $Author -Created $Date -Modified $Date -Ci (Get-DocumentCi $Date $HqSite.Name) -SenderKind 'None' -Marking $marking -Classification $classification
    Add-Block $model 'Title' @{ Text = $title }
    Add-Block $model 'Para' @{ Text = ($L.VersionOf -f $Version, (Format-LocalDate $Date)) }
    foreach ($section in $Record.Sections) {
        Add-Block $model 'Heading' @{ Text = (Expand-SampleText $section.Title $policyCtx) }
        Add-Block $model 'Para' @{ Text = (Expand-SampleText $section.Text $policyCtx) }
    }
    $model
}

function Build-YearUnit {
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $rng = Get-Rng -Index $Unit.Seed -Salt 503
    $year = $Reference.Year - $Unit.YearsAgo
    $jan = (New-Object -TypeName DateTime -ArgumentList $year, 1, 8).AddHours(10)
    if ($jan -lt $Founded) { $jan = $Founded.AddDays(20) }
    $boss = $PeopleBySam[$Roles.Ceo]
    $ci = Get-DocumentCi $jan $HqSite.Name
    $staff = Get-ActivePerson -Date $jan.AddMonths(6)
    # Jahresauftakt der Geschaeftsleitung
    $slides = @(@{ Layout = 'Title'; Title = ('{0} {1}' -f $F.Kickoff, $year); Subtitle = $C.Company.Name })
    foreach ($s in @($T.KickoffSlide)) { $slides += @{ Layout = 'Content'; Title = (Expand-SampleText $s.Title @{ Jahr = $year - 1 }); Bullets = @((Expand-SampleText $s.Text (Get-TextContext -Rng $rng -Date $jan -Author $boss)) -split "`n" | Where-Object { $_ }) } }
    $slides += @{ Layout = 'Closing'; Title = $L.Thanks; Subtitle = $boss.Name }
    $kick = @{ Title = ('{0} {1}' -f $F.Kickoff, $year); Author = $boss.Name; Company = $C.Company.Name; Ci = $ci; Wide = $true; Slides = $slides; Classification = $L.Confidential; Marking = $L.Confidential }
    Add-Spec $specs ('{0}\{1}\{1}_{2}.pptx' -f $Paths.Management, $F.Kickoff, $year) 'pptx' $jan $rng @{ Model = $kick }
    # Einladungen Sommerfest und Weihnachtsfeier
    foreach ($occasion in 'Summer', 'Christmas') {
        $record = Get-TextRecord -Kind 'Announcement' -Rng $rng -Where @{ Event = $occasion }
        if (-not $record.Subject) { continue }
        $date = Get-WorkDate (New-Object -TypeName DateTime -ArgumentList $year, $(if ($occasion -eq 'Summer') { 5 } else { 11 }), 2) $rng 0 14
        $eventCtx = Get-TextContext -Rng $rng -Date $date
        $subject = Expand-SampleText $record.Subject $eventCtx
        $model = Get-DocModel -Title $subject -Author $(Get-Person $Roles.ManagingDirector $date $HqSite.Name $rng) -Created $date -Modified $date -Ci (Get-DocumentCi $date $HqSite.Name) -Classification $L.Internal
        Add-Block $model 'Title' @{ Text = $subject }
        Add-Block $model 'Para' @{ Text = (Expand-SampleText $record.Text $eventCtx) }
        Add-Spec $specs ('{0}\{1}\{2}\{3:yyyy-MM-dd}_{4}.docx' -f $Paths.General, $F.Announcements, $year, $date, (ConvertTo-SafeName $subject)) 'docx' $date $rng @{ Model = $model }
    }
    # Listen: Telefon, Kunden, Umsatz, Urlaub
    $phoneRows = foreach ($p in $staff) { $pd = Get-PersonProfile -Key $p.Sam -GivenName $p.GivenName -Surname $p.Surname -BirthYear $p.Born -City $p.Site -Female $p.Female; , @($p.Name, $p.Role, $p.Site, ((Get-Dial $p.Site) -f (100 + [Math]::Abs($p.Sam.GetHashCode()) % 400)), $pd.Mobile) }
    Add-Spec $specs ('{0}\{1}_{2}.xlsx' -f $Paths.General, $L.PhoneList, $year) 'xlsx' $jan.AddDays(3) $rng @{ Model = (Get-XlsxTable -Title $L.PhoneList -Author $boss -Ci $ci -Sheet $L.PhoneList -Header @($L.Name, $L.Position, $L.Location, $L.Phone, $L.Mobile) -Rows @($phoneRows) -Widths @(24, 30, 12, 20, 20) -Classification $L.Internal) }
    $active = @($C.Customers | Where-Object { Test-CustomerActive $_ $Unit.YearsAgo })
    if ($active) {
        $customerRows = foreach ($cust in $active) { , @($cust.Name, $cust.Contact, ('{0}@{1}' -f $L.MailContact, $cust.Domain), $cust.City, $C.Industries[$cust.Industry], $(if ($PeopleBySam[$cust.Owner]) { $PeopleBySam[$cust.Owner].Name } else { '' })) }
        Add-Spec $specs ('{0}\{1}\{2}_{3}.xlsx' -f $Paths.Sales, $F.Customers, $L.CustomerList, $year) 'xlsx' $jan.AddDays(5) $rng @{ Model = (Get-XlsxTable -Title $L.CustomerList -Author $boss -Ci $ci -Sheet $L.CustomerList -Header @($L.Customer, $L.Contact, $L.Email, $L.Location, $L.Industry, $L.Owner) -Rows @($customerRows) -Widths @(34, 26, 34, 14, 14, 20) -Classification $L.Internal) }
        $revenueRows = foreach ($cust in $active) { , @($cust.Name, [double]($rng.Next(4, 80) * 1000)) }
        Add-Spec $specs ('{0}\{1}_{2}.xlsx' -f $Paths.Management, $L.Revenue, $year) 'xlsx' (New-Object -TypeName DateTime -ArgumentList $year, 12, 18).AddHours(16) $rng @{ Model = (Get-XlsxTable -Title ('{0} {1}' -f $L.Revenue, $year) -Author $boss -Ci $ci -Sheet $L.Revenue -Header @($L.Customer, $L.Revenue) -Rows @($revenueRows) -Widths @(40, 16) -Formats @($null, 'Money') -Classification $L.Confidential -SumColumn 2) }
    }
    foreach ($site in $C.Company.Sites) {
        if ($SiteOpened[$site.Name] -gt $jan) { continue }
        $vacRows = foreach ($p in (Get-ActivePerson -Date $jan -Site $site.Name)) { $start = (New-Object -TypeName DateTime -ArgumentList $year, (6 + $rng.Next(0, 3)), (1 + $rng.Next(0, 20))); , @($p.Name, $start, $start.AddDays(7 + 7 * $rng.Next(0, 2)), [double](10 + $rng.Next(0, 10))) }
        Add-Spec $specs ('{0}\{1}_{2}_{3}.xlsx' -f $Paths.General, $L.Vacation, $site.Name, $year) 'xlsx' $jan.AddDays(10) $rng @{ Model = (Get-XlsxTable -Title $L.Vacation -Author $boss -Ci $ci -Sheet $L.Vacation -Header @($L.Name, $L.From, $L.To, $L.Days) -Rows @($vacRows) -Widths @(24, 12, 12, 8) -Formats @($null, 'Date', 'Date', 'Integer')) }
    }
    # Richtlinien: Fassungen verteilt ueber die Jahre
    $index = 0
    foreach ($policy in @($T.Policy)) {
        $index++
        if (($Unit.YearsAgo + $index) % 3 -ne 0) { continue }
        $date = Get-WorkDate $jan $rng 20 200
        $model = Get-PolicyModel $policy $boss $date (1 + [Math]::Floor((12 - $Unit.YearsAgo) / 3))
        # Policy.Folder ist ein Schluessel in Paths (General, IT ...).
        $path = '{0}\{1}\{2}_{3}' -f $Paths[$policy.Folder], $F.Policies, (ConvertTo-SafeName $policy.Title), $year
        Add-Spec $specs "$path.docx" 'docx' $date $rng @{ Model = $model }
        if ($rng.Next(0, 2) -eq 0) { Add-Spec $specs "$path.pdf" 'pdf' $date.AddMinutes(20) $rng @{ Model = $model } }
    }
    # Onboarding fuer neue Mitarbeitende des Jahres
    if (@($People | Where-Object { $_.Entry.Year -eq $year }) -and $T.OnboardingSlide) {
        $onboardingCtx = Get-TextContext -Rng $rng -Date $jan.AddDays(30) -Author (Get-Person $Roles.Office $jan $HqSite.Name $rng)
        $slides = @(@{ Layout = 'Title'; Title = $L.Welcome; Subtitle = $C.Company.Name }) + @($T.OnboardingSlide | ForEach-Object { @{ Layout = 'Content'; Title = (Expand-SampleText $_.Title $onboardingCtx); Bullets = @(((Expand-SampleText $_.Text $onboardingCtx) -split "`n") | Where-Object { $_ }) } })
        Add-Spec $specs ('{0}\{1}\{1}_{2}.pptx' -f $Paths.General, $F.Onboarding, $year) 'pptx' $jan.AddDays(30) $rng @{ Model = @{ Title = "$($L.Welcome) $year"; Author = (Get-Person $Roles.Office $jan $HqSite.Name $rng).Name; Company = $C.Company.Name; Ci = $ci; Wide = $true; Slides = $slides } }
    }
    # Fehlablagen (Uebung Datenklassifizierung): Gehaltsliste ohne Kennzeichnung im Basisordner und im Marketing
    if ($Unit.YearsAgo -le 1) {
        $payRows = foreach ($p in $staff) { $pd = Get-PersonProfile -Key $p.Sam -GivenName $p.GivenName -Surname $p.Surname -BirthYear $p.Born -City $p.Site -Female $p.Female; , @($p.Name, $pd.Iban, [double]$p.Salary) }
        $payModel = Get-XlsxTable -Title ('{0} {1}' -f $L.SalaryList, $year) -Author $PeopleBySam[$Roles.ManagingDirector] -Ci $ci -Sheet $L.Payroll -Header @($L.Name, $L.Iban, $L.Gross) -Rows @($payRows) -Widths @(24, 30, 14) -Formats @($null, $null, 'Money') -SumColumn 3
        $payPath = '{0}\{1}\{2}\{3}_{4}.xlsx' -f $Paths.Home, $Roles.ManagingDirector, $F.Documents, $L.SalaryList, $year
        Add-Spec $specs $payPath 'xlsx' $jan.AddDays(40) $rng @{ Model = $payModel }
        Add-Spec $specs ('{0}\{1}\{2}_{3}_{4}.xlsx' -f $Paths.Marketing, $HqSite.Name, $L.SalaryList, $year, $L.CopyFile) 'copy' $jan.AddDays(41) $rng @{ Source = $payPath }
    }
    if ($Unit.YearsAgo -eq 0) {
        $bdayRows = foreach ($p in $staff) { $pd = Get-PersonProfile -Key $p.Sam -GivenName $p.GivenName -Surname $p.Surname -BirthYear $p.Born -City $p.Site -Female $p.Female; , @($p.Name, $pd.Birth, $pd.Street, $pd.City) }
        Add-Spec $specs ('{0}\{1}\{2}\{3}.xlsx' -f $Paths.Home, $Roles.ManagingDirector, $F.Private, $L.Birthdays) 'xlsx' $jan.AddDays(12) $rng @{ Model = (Get-XlsxTable -Title $L.Birthdays -Author $PeopleBySam[$Roles.ManagingDirector] -Ci $ci -Sheet $L.Birthdays -Header @($L.Name, $L.BirthDate, $L.Address, '') -Rows @($bdayRows) -Widths @(24, 12, 28, 20) -Formats @($null, 'Date')) }
    }
    , $specs.ToArray()
}

function Build-EventUnit {
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $timelineEvent = $Unit.Event
    $rng = Get-Rng -Index $Unit.Seed -Salt 601
    $date = (New-Object -TypeName DateTime -ArgumentList ($Reference.Year - $timelineEvent.YearsAgo), $timelineEvent.Month, (3 + $rng.Next(0, 20))).AddHours(9 + $rng.Next(0, 6))
    if ($date -ge $Reference) { return , $specs.ToArray() }
    $customer = if ($timelineEvent.Customer) { $C.Customers | Where-Object Short -EQ $timelineEvent.Customer | Select-Object -First 1 } else { $null }
    $author = Get-Person $(if ($timelineEvent.Event -in 'Scanner', 'FileServer') { $Roles.Office } else { $Roles.Ceo }) $date $HqSite.Name $rng
    $ci = Get-DocumentCi $date $HqSite.Name
    $ctx = Get-TextContext -Rng $rng -Date $date -Customer $customer -Author $author
    $record = Get-TextRecord -Kind 'Announcement' -Rng $rng -Where @{ Event = $timelineEvent.Event }
    if ($record.Subject) {
        $subject = Expand-SampleText $record.Subject $ctx
        $model = Get-DocModel -Title $subject -Author $author -Created $date -Modified $date -Ci $ci -Classification $L.Internal
        Add-Block $model 'Title' @{ Text = $subject }
        Add-Block $model 'Para' @{ Text = (Expand-SampleText $record.Text $ctx) }
        $path = '{0}\{1}\{2}\{3:yyyy-MM-dd}_{4}' -f $Paths.General, $F.Announcements, $date.Year, $date, (ConvertTo-SafeName $subject)
        Add-Spec $specs "$path.docx" 'docx' $date $rng @{ Model = $model }
        Add-Spec $specs "$path.pdf" 'pdf' $date.AddMinutes(10) $rng @{ Model = $model }
    }
    # Vertrag zum Ereignis: Patterns.Agreements[Event] passt auf den Titel in Texts-Company.Agreement.
    $agreementTitle = $Patterns.Agreements[$timelineEvent.Event]
    if ($agreementTitle) {
        $agreement = @($T.Agreement | Where-Object { $_.Title -match $agreementTitle }) | Select-Object -First 1
        if ($agreement) {
            $model = Get-DocModel -Title $agreement.Title -Author $author -Created $date -Modified $date -Ci $ci -Classification $L.Confidential
            Add-Block $model 'Title' @{ Text = $agreement.Title }
            Add-Block $model 'Para' @{ Text = ('{0} {1} {2}' -f $C.Company.Name, $MidDot, (Expand-SampleText $agreement.Party $ctx)) }
            foreach ($s in $agreement.Sections) { Add-Block $model 'Heading' @{ Text = $s.Title }; Add-Block $model 'Para' @{ Text = (Expand-SampleText $s.Text $ctx) } }
            Add-Block $model 'Sign' @{ Name = $author.Name; Role = $author.Role; Seed = 31 }
            Add-Block $model 'Sign' @{ Name = (Expand-SampleText $agreement.Party $ctx); Seed = 32 }
            $model.Scan = Get-ScanProfile $rng $date
            Add-Spec $specs ('{0}\{1}\{2}_{3:yyyy}.pdf' -f $Paths.Management, $F.Agreements, (ConvertTo-SafeName $agreement.Title), $date) 'pdf' $date.AddDays(3) $rng @{ Model = $model }
        }
    }
    if ($timelineEvent.Event -eq 'FileServer') {
        foreach ($doc in @($T.ItDoc)) {
            $model = Get-DocModel -Title $doc.Title -Author $author -Created $date -Modified $date -Ci $ci -SenderKind 'None' -Classification $L.Internal
            Add-Block $model 'Title' @{ Text = $doc.Title }
            Add-Block $model 'Para' @{ Text = (Expand-SampleText $doc.Text $ctx) }
            Add-Spec $specs ('{0}\{1}\{2}.docx' -f $Paths.IT, $F.Docs, (ConvertTo-SafeName $doc.Title)) 'docx' (Get-WorkDate $date $rng 0 30) $rng @{ Model = $model }
        }
    }
    if ($timelineEvent.Event -eq 'Anniversary') {
        $anniversaryCtx = Get-TextContext -Rng $rng -Date $date -Author $author
        $slides = @(@{ Layout = 'Title'; Title = $L.Anniversary; Subtitle = $C.Company.Name }) + @(@($T.KickoffSlide) | Select-Object -First 3 | ForEach-Object { @{ Layout = 'Content'; Title = (Expand-SampleText $_.Title $anniversaryCtx); Bullets = @(((Expand-SampleText $_.Text $anniversaryCtx) -split "`n") | Where-Object { $_ }) } })
        Add-Spec $specs ('{0}\{1}\{2}_{3}.pptx' -f $Paths.General, $F.Events, $L.Anniversary.Replace(' ', '_'), $C.Company.Short.Replace(' ', '_')) 'pptx' $date $rng @{ Model = @{ Title = $L.Anniversary; Author = $author.Name; Company = $C.Company.Name; Ci = $ci; Wide = $true; Slides = $slides } }
    }
    if ($timelineEvent.Event -eq 'Rebranding') {
        $hb = Get-DocModel -Title $L.CiHandbook -Author $PeopleBySam[$Roles.ManagingDirector] -Created $date -Modified $date -Ci $ci -SenderKind 'None' -Classification $L.Internal
        Add-Block $hb 'Title' @{ Text = $L.CiHandbook }
        if ($UseRaster) { $logo = Get-LogoPng $ci 60 200; Add-Block $hb 'Image' @{ Bytes = $logo.Bytes; Format = 'png'; WidthPx = $logo.WidthPx; HeightPx = $logo.HeightPx; WidthCm = 10 } }
        $hbCtx = Get-TextContext -Rng $rng -Date $date -Author $PeopleBySam[$Roles.ManagingDirector]
        foreach ($chapter in @($T.CiHandbook)) { Add-Block $hb 'Heading' @{ Text = (Expand-SampleText $chapter.Title $hbCtx) }; Add-Block $hb 'Para' @{ Text = (Expand-SampleText $chapter.Text $hbCtx) } }
        $ciFile = '{0}\{1}\{2}' -f $Paths.General, $F.Ci, $L.CiHandbook
        Add-Spec $specs "$ciFile.docx" 'docx' $date $rng @{ Model = $hb }
        Add-Spec $specs "$ciFile.pdf" 'pdf' $date.AddHours(1) $rng @{ Model = $hb }
        $slides = @(@{ Layout = 'Title'; Title = $L.NewLook; Subtitle = $C.Company.Name }) + @($T.CiHandbook | ForEach-Object { @{ Layout = 'Content'; Title = (Expand-SampleText $_.Title $hbCtx); Text = (Expand-SampleText $_.Text $hbCtx) } })
        Add-Spec $specs "$ciFile.pptx" 'pptx' $date.AddHours(2) $rng @{ Model = @{ Title = $L.CiTitle; Author = $PeopleBySam[$Roles.ManagingDirector].Name; Company = $C.Company.Name; Ci = $ci; Wide = $true; Slides = $slides } }
        Build-TemplateSpec $specs $date $ci $rng
    }
    , $specs.ToArray()
}

function Build-TemplateSpec {
    # Office-Vorlagen der neuen CI (echte Vorlagenformate).
    param($Specs, [datetime] $Date, $Ci, $Rng)
    $author = $PeopleBySam[$Roles.Designer]
    $folder = '{0}\{1}' -f $Paths.General, $F.Templates
    $letter = Get-DocModel -Title $L.Letterhead -Author $author -Created $Date -Modified $Date -Ci $Ci
    $letter.Template = $true
    Add-Block $letter 'Address' @{ Lines = @($L.TemplateAddress) }
    Add-Block $letter 'Info' @{ Rows = [ordered]@{ $L.Date = $L.DateMask } }
    Add-Block $letter 'Title' @{ Text = $L.Subject }
    Add-Block $letter 'Para' @{ Text = ('{0},' -f $L.Salutation) }
    Add-Block $letter 'Para' @{ Text = $Office.Text }
    Add-Block $letter 'Para' @{ Text = $L.Regards }
    Add-Spec $Specs "$folder\$($L.Letterhead).dotx" 'dotx' $Date $Rng @{ Model = $letter }
    Add-Spec $Specs "$folder\$($L.Presentation).potx" 'potx' $Date $Rng @{ Model = @{ Title = $L.Presentation; Author = $author.Name; Company = $C.Company.Name; Ci = $Ci; Wide = $true; Template = $true; Slides = @(@{ Layout = 'Title'; Title = $Office.Title; Subtitle = $Office.Subtitle }, @{ Layout = 'Content'; Title = $Office.Title; Bullets = @($L.Point) }) } }
    $calc = Get-CalculationModel @(@{ Text = $L.Description; Qty = 1; Unit = $L.Hour; Price = 95 }) $L.Calculation $author $Ci
    $calc.Template = $true
    Add-Spec $Specs "$folder\$($L.Calculation).xltx" 'xltx' $Date $Rng @{ Model = $calc }
}

function Build-MeetingUnit {
    # Teambesprechungen eines Standorts in einem Jahr (alle zwei Wochen).
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $rng = Get-Rng -Index $Unit.Seed -Salt 701
    $year = $Reference.Year - $Unit.YearsAgo
    $date = (New-Object -TypeName DateTime -ArgumentList $year, 1, 6).AddHours(9)
    while ($date.Year -eq $year -and $date -lt $Reference) {
        if ($date -ge $SiteOpened[$Unit.Site]) {
            $team = @(Get-ActivePerson -Date $date -Site $Unit.Site)
            if ($team.Count -ge 2) {
                $keeper = Get-RandomEntry $rng $team
                $ctx = Get-TextContext -Rng $rng -Date $date -Customer (Get-RandomEntry $rng $C.Customers) -Author $keeper
                $model = Get-DocModel -Title "$($L.Minutes) $($Unit.Site)" -Author $keeper -Created $date -Modified $date -Ci (Get-DocumentCi $date $Unit.Site) -SenderKind 'None' -Classification $L.Internal
                Add-Block $model 'Title' @{ Text = ('{0} {1} {2}' -f $L.Minutes, $MidDot, (Format-LocalDate $date)) }
                Add-Block $model 'Info' @{ Rows = [ordered]@{ $L.Attendees = (($team | Select-Object -First 7 | ForEach-Object { $_.Name }) -join ', '); $L.Owner = $keeper.Name } }
                foreach ($topic in (Get-RandomSubset $rng $T.MinutesTopic (2 + $rng.Next(0, 2)))) {
                    Add-Block $model 'Heading' @{ Text = (Expand-SampleText $topic.Title $ctx) }
                    Add-Block $model 'Para' @{ Text = (Expand-SampleText $topic.Text $ctx) }
                }
                $path = Get-AreaPath $date ('{0}\{1}\{2}\{3}' -f $Paths.Marketing, $Unit.Site, $F.Minutes, $year) ('{0}\{1}\{2}' -f $AreaName.Marketing, $Unit.Site, $F.Minutes)
                Add-Spec $specs ('{0}\{1}_{2:yyyy-MM-dd}.docx' -f $path, $L.Minutes, $date) 'docx' $date.AddHours(2) $rng @{ Model = $model }
            }
        }
        $date = $date.AddDays(14)
    }
    , $specs.ToArray()
}

function Build-ItUnit {
    # IT-Listen und Branding (einmal): Inventar, Lizenzen, alte Zugangsdaten (Altlast), Branding fuer Entra und Edge.
    param([Parameter(Mandatory)] $Unit)
    $specs = [System.Collections.Generic.List[object]]::new()
    $rng = Get-Rng -Index $Unit.Seed -Salt 801
    $date = $Reference.AddDays(-$rng.Next(20, 90)).Date.AddHours(10)
    $it = Get-Person $Roles.Office $date $HqSite.Name $rng
    $ci = Get-DocumentCi $date $HqSite.Name
    # Zwei von drei Geraeten stehen in der Zentrale, eines in der Niederlassung (Sites[].Code im Geraetenamen).
    $devices = foreach ($n in 1..(14 + $rng.Next(0, 10))) { $type = Get-RandomEntry $rng $C.DeviceTypes; $site = if ($n % 3) { $HqSite } else { $BranchSite }; , @(('{0}-{1:D3}' -f $site.Code, $n), $type, ('10.0.1.{0}' -f (20 + $n)), $site.Name, (New-Object -TypeName DateTime -ArgumentList ($Reference.Year - $rng.Next(0, 6)), (1 + $rng.Next(0, 12)), 1)) }
    Add-Spec $specs ('{0}\{1}\{2}.xlsx' -f $Paths.IT, $F.Docs, $L.Inventory) 'xlsx' $date $rng @{ Model = (Get-XlsxTable -Title $L.Inventory -Author $it -Ci $ci -Sheet $L.Inventory -Header @($L.Hostname, $L.Device, $L.IpAddress, $L.Location, $L.Purchase) -Rows @($devices) -Widths @(14, 22, 14, 12, 12) -Formats @($null, $null, $null, $null, 'Date') -Classification $L.Internal) }
    $licenses = foreach ($s in $C.Software) { , @($s, [double]$rng.Next(2, 18), $Reference.AddDays($rng.Next(-60, 400)).Date) }
    Add-Spec $specs ('{0}\{1}\{2}.xlsx' -f $Paths.IT, $F.Docs, $L.LicenseList) 'xlsx' $date $rng @{ Model = (Get-XlsxTable -Title $L.LicenseList -Author $it -Ci $ci -Sheet $L.LicenseList -Header @($L.Product, $L.Licenses, $L.ValidUntil) -Rows @($licenses) -Widths @(26, 10, 14) -Formats @($null, 'Integer', 'Date')) }
    $creds = foreach ($s in $C.Systems) { , @($s, ('admin{0}' -f $rng.Next(1, 9)), ('{0}{1}!' -f (Get-RandomEntry $rng $C.PasswordWords), (2016 + $rng.Next(0, 9)))) }
    Add-Spec $specs ('{0}\{1}_{2}.xlsx' -f $Paths.IT, $L.Credentials, $L.OldFile) 'xlsx' $date.AddYears(-3) $rng @{ Model = (Get-XlsxTable -Title $L.Credentials -Author $it -Ci (Get-DocumentCi $date.AddYears(-3) $HqSite.Name) -Sheet $L.Credentials -Header @($L.System, $L.Username, $L.Password) -Rows @($creds) -Widths @(30, 16, 20)) }
    if ($UseRaster) { Build-BrandingSpec $specs $date $rng }
    , $specs.ToArray()
}

function Build-BrandingSpec {
    # Entra- und Edge-Branding aus derselben CI wie die Dokumente; Groessen und Grenzen nach Microsoft Learn.
    param($Specs, [datetime] $Date, $Rng)
    $ciNew = Get-DocumentCi $Reference $HqSite.Name
    $ciOld = Get-DocumentCi $Founded $HqSite.Name
    $folder = '{0}\{1}' -f $Paths.IT, $F.Branding
    $signet = { param($x, $y, $s, $neg) $p = Get-SignetPolygon $x $y $s; @(@{ K = 'Poly'; Points = $p[0]; Color = $(if ($neg) { @(255, 255, 255) } else { $ciNew.Primary }) }, @{ K = 'Poly'; Points = $p[1]; Color = $ciNew.Accent }) }
    $add = {
        param($name, $image, [int] $maxKb)
        if ($image.Bytes.Length -gt $maxKb * 1024) { Write-LabLog "WARNUNG: Branding $name hat $([int]($image.Bytes.Length / 1KB)) KB (Grenze $maxKb KB)." }
        Add-Spec $Specs "$folder\$name" 'bin' $Date $Rng @{ Bytes = $image.Bytes }
    }
    & $add 'favicon_32x32.png' (Export-BrandingPng -Items (& $signet 2 2 28 $false) -Width 32 -Height 32) 5
    $bg = @(@{ K = 'Texture'; X = 0; Y = 0; W = 1920; H = 1080; Kind = 'Clouds'; Seed = 5; Color = $ciNew.Primary; Color2 = (Get-MixedColor $ciNew.Primary @(255, 255, 255) 0.35) }, @{ K = 'Rect'; X = 0; Y = 1000; W = 1920; H = 80; Color = $ciNew.Accent })
    & $add ('{0}_1920x1080.jpg' -f $L.BrandBackground) (Export-BrandingPng -Items $bg -Width 1920 -Height 1080 -Format 'jpeg' -Quality 70) 300
    & $add ('{0}_245x36.png' -f $L.BrandHeader) (Export-BrandingPng -Items (Get-LogoItem 4 2 32 $ciNew) -Width 245 -Height 36) 10
    & $add 'logo_banner_245x36.png' (Export-BrandingPng -Items (Get-LogoItem 4 2 32 $ciNew) -Width 245 -Height 36) 50
    & $add ('{0}.png' -f $L.BrandLight) (Export-BrandingPng -Items (& $signet 30 30 180 $false) -Width 240 -Height 240 -Background @(255, 255, 255)) 50
    & $add ('{0}.png' -f $L.BrandDark) (Export-BrandingPng -Items (& $signet 30 30 180 $true) -Width 240 -Height 240 -Background @(32, 32, 32)) 50
    Add-Spec $Specs "$folder\edge_logo.svg" 'text' $Date $Rng @{ Text = (Get-LogoSvg $ciNew 520 100) }
    Add-Spec $Specs ('{0}\{1}.svg' -f $folder, $L.BrandTaskbar) 'text' $Date $Rng @{ Text = (Get-LogoSvg $ciNew 100 100 -SignetOnly) }
    $logoFile = '{0}\Logo\Logo_{1}' -f $folder, $C.Company.Short.Replace(' ', '_')
    Add-Spec $Specs "$logoFile.svg" 'text' $Date $Rng @{ Text = (Get-LogoSvg $ciNew 520 100) }
    Add-Spec $Specs ('{0}_{1}.svg' -f $logoFile, $L.BrandNegative) 'text' $Date $Rng @{ Text = (Get-LogoSvg $ciNew 520 100 -Negative) }
    Add-Spec $Specs "$($logoFile)_1200.png" 'bin' $Date $Rng @{ Bytes = (Get-LogoPng $ciNew 200 300).Bytes }
    Add-Spec $Specs ('{0}\{1}.png' -f $folder, $L.BrandOld) 'bin' $Date.AddYears(-5) $Rng @{ Bytes = (Get-LogoPng $ciOld 120 200).Bytes }
    foreach ($doc in @(@{ Kind = 'BrandingGuide'; Name = $L.BrandGuide }, @{ Kind = 'SignInText'; Name = $L.BrandSignIn })) {
        $model = Get-DocModel -Title ($doc.Name -replace '_', ' ') -Author (Get-Person $Roles.Office $Date $HqSite.Name $Rng) -Created $Date -Modified $Date -Ci $ciNew -SenderKind 'None' -Classification $L.Internal
        Add-Block $model 'Title' @{ Text = ($doc.Name -replace '_', ' ') }
        $docCtx = Get-TextContext -Rng $Rng -Date $Date -Author (Get-Person $Roles.Office $Date $HqSite.Name $Rng)
        foreach ($chapter in @($T[$doc.Kind])) { Add-Block $model 'Heading' @{ Text = (Expand-SampleText $chapter.Title $docCtx) }; Add-Block $model 'Para' @{ Text = (Expand-SampleText $chapter.Text $docCtx) } }
        Add-Spec $Specs "$folder\$($doc.Name).docx" 'docx' $Date $Rng @{ Model = $model }
    }
}

#endregion
#region Ablauf: Einheiten, Export, Worker, Kopien, Zeitstempel, Hauptablauf

function Get-ProjectScale {
    # Projekte je Kunde und Jahr vervielfachen, wenn das Ziel ueber der Kapazitaet einer einfachen Einheitenliste liegt
    # (gemessen 2026-11-25: rund 68 GB eigene Dokumente mit Rastergrafik). Sonst fuellten nur Kopien das Ziel.
    param([long] $UniqueTarget)
    [Math]::Max(1, [int][Math]::Ceiling(($UniqueTarget / 1GB) / $UnitCapacityGB))
}

function Get-TargetByte {
    # Ziel in Byte: TargetSizeMB (Tests) vor TargetPercent (Anteil am Volume von TargetPath) vor TargetSizeGB.
    if ($TargetSizeMB -gt 0) { return [long]$TargetSizeMB * 1MB }
    if ($TargetPercent -gt 0) { return [long]((Get-TargetVolume).TotalSize * $TargetPercent / 100) }
    [long]($TargetSizeGB * 1GB)
}

function Get-TargetVolume {
    New-Object -TypeName System.IO.DriveInfo -ArgumentList ([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($TargetPath)))
}

function Test-VolumeFull {
    # Schutz vor voller Disk: Cluster-Verschnitt und MFT zaehlen nicht zum Ziel, belegen aber Platz.
    $volume = Get-TargetVolume
    $volume.AvailableFreeSpace -lt $volume.TotalSize * $MinFreeShare
}

function Get-WorkUnit {
    # Deterministische Einheitenliste. Kernbausteine zuerst, der Rest gemischt, damit jeder Anfang alle Jahre abdeckt.
    param([int] $Scale = 1)
    $core = [System.Collections.Generic.List[object]]::new()
    $rest = [System.Collections.Generic.List[object]]::new()
    $unitSeed = 1
    $core.Add(@{ Type = 'It'; Seed = $unitSeed++ })
    foreach ($p in $People) { $core.Add(@{ Type = 'Person'; Person = $p; Seed = $unitSeed++ }) }
    foreach ($e in @($C.Timeline | Where-Object { $null -ne $_.YearsAgo })) { $core.Add(@{ Type = 'Event'; Event = $e; Seed = $unitSeed++ }) }
    $yearSpan = $Reference.Year - $Founded.Year
    for ($y = 0; $y -le $yearSpan; $y++) {
        $core.Add(@{ Type = 'Year'; YearsAgo = $y; Seed = $unitSeed++ })
        $rest.Add(@{ Type = 'Application'; YearsAgo = $y; Seed = $unitSeed++ })
        foreach ($site in $C.Company.Sites) { $rest.Add(@{ Type = 'Meeting'; Site = $site.Name; YearsAgo = $y; Seed = $unitSeed++ }) }
        foreach ($customer in $C.Customers) {
            if (-not (Test-CustomerActive $customer $y)) { continue }
            $rng = Get-Rng -Index ($unitSeed * 13) -Salt 9
            $names = @($customer.Projects)
            $count = (4 + $rng.Next(0, 3)) * $Scale
            for ($n = 0; $n -lt $count; $n++) {
                $name = if ($n -eq 0 -and $customer.Yearly) { $customer.Yearly } else { $names[($n + $y) % $names.Count] }
                if ($n -ge $names.Count + 1) { $name = '{0} {1}' -f $name, ($n - $names.Count + 1) }
                $rest.Add(@{ Type = 'Project'; Customer = $customer; YearsAgo = $y; Project = $name; Seed = $unitSeed++ })
            }
        }
    }
    $month = New-Object -TypeName DateTime -ArgumentList $Founded.Year, $Founded.Month, 1
    while ($month -lt $Reference.AddDays(-25)) { $rest.Add(@{ Type = 'Accounting'; Month = $month; Seed = $unitSeed++ }); $month = $month.AddMonths(1) }
    $rng = Get-Rng -Index 1 -Salt 1
    $items = $rest.ToArray()
    for ($i = $items.Count - 1; $i -gt 0; $i--) { $j = $rng.Next(0, $i + 1); $tmp = $items[$i]; $items[$i] = $items[$j]; $items[$j] = $tmp }
    , (@($core.ToArray()) + @($items))
}

function Build-Unit {
    param([Parameter(Mandatory)] $Unit)
    switch ($Unit.Type) {
        'Project' { return Build-ProjectUnit $Unit }
        'Accounting' { return Build-AccountingUnit $Unit }
        'Person' { return Build-PersonUnit $Unit }
        'Application' { return Build-ApplicationUnit $Unit }
        'Year' { return Build-YearUnit $Unit }
        'Event' { return Build-EventUnit $Unit }
        'Meeting' { return Build-MeetingUnit $Unit }
        'It' { return Build-ItUnit $Unit }
    }
    , @()
}

function Write-FileTimestamp {
    param([string] $Path, [datetime] $Created, [datetime] $Modified)
    try {
        [IO.File]::SetCreationTime($Path, $Created)
        [IO.File]::SetLastWriteTime($Path, $Modified)
        $access = $Modified.AddDays([Math]::Min(30, ($Reference - $Modified).TotalDays) * 0.5)
        [IO.File]::SetLastAccessTime($Path, $access)
    }
    catch { Write-Verbose -Message "Zeitstempel nicht gesetzt: $Path" }
}

function Export-PagePdf {
    # Seiten aus Anzeigelisten (gerastert oder als Vektor) zu einem PDF.
    param([string] $Path, [object[]] $Pages, [hashtable] $Info)
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($page in $Pages) {
        $images = [System.Collections.Generic.List[object]]::new()
        if ($page.Image) {
            $content = ConvertTo-PdfContent @(@{ K = 'Image'; X = 0; Y = 0; W = $page.W; H = $page.H; Bytes = $page.Image.Bytes; PixW = $page.Image.WidthPx; PixH = $page.Image.HeightPx }) $page.H $images
        }
        elseif ($UseRaster -and $page.Profile) {
            $raster = Export-RasterPage -Items $page.Items -PageW $page.W -PageH $page.H -RenderProfile $page.Profile
            $content = ConvertTo-PdfContent @(@{ K = 'Image'; X = 0; Y = 0; W = $page.W; H = $page.H; Bytes = $raster.Bytes; PixW = $raster.PixW; PixH = $raster.PixH }) $page.H $images
        }
        else { $content = ConvertTo-PdfContent @($page.Items | Where-Object { $_.K -in 'Text', 'Rect', 'Line', 'Poly', 'Ellipse' }) $page.H $images }
        $out.Add(@{ W = $page.W; H = $page.H; Content = $content; Images = $images })
    }
    Write-PdfFile -Path $Path -Pages $out.ToArray() -Info $Info
}

function Export-Spec {
    # Schreibt eine Datei (atomar ueber Temp-Datei) und liefert ihre Groesse; vorhandene Dateien bleiben (Wiederaufnahme).
    param([Parameter(Mandatory)] $Spec)
    $full = Join-SamplePath $TargetPath $Spec.Path
    if ($full.Length -gt 245) { Write-Verbose -Message "Pfad zu lang: $full"; return 0 }
    if ([IO.File]::Exists($full)) { return (New-Object -TypeName System.IO.FileInfo -ArgumentList $full).Length }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full))
    $tmp = $full + $TempSuffix
    $info = @{ Title = ''; Author = $Spec.Author; Creator = $L.LayoutApp; Producer = $L.PdfExport; Created = $Spec.Created; Modified = $Spec.Modified }
    switch ($Spec.Kind) {
        { $_ -in 'docx', 'dotx' } { if ($_ -eq 'dotx') { $Spec.Model.Template = $true }; Write-DocxFile -Path $tmp -Model $Spec.Model }
        { $_ -in 'xlsx', 'xltx' } { $Spec.Model.Created = $Spec.Created; $Spec.Model.Modified = $Spec.Modified; if ($_ -eq 'xltx') { $Spec.Model.Template = $true }; Write-XlsxFile -Path $tmp -Model $Spec.Model }
        { $_ -in 'pptx', 'potx' } { $Spec.Model.Created = $Spec.Created; $Spec.Model.Modified = $Spec.Modified; if ($_ -eq 'potx') { $Spec.Model.Template = $true }; Write-PptxFile -Path $tmp -Model $Spec.Model }
        'pdf' { Export-FlowPdf -Path $tmp -Model $Spec.Model }
        'design' {
            # Druckdaten mit feinem Korn und hoher Qualitaet (gross wie echte Druck-PDFs), Entwuerfe klein.
            $size = $ShapeSizes[$Spec.Motif.Format]
            $info.Title = '{0} {1}' -f $Spec.Motif.Name, $Spec.Customer.Short
            $pageProfile = switch ($Spec.Stage) {
                'Final' { @{ Dpi = $Spec.Dpi; Quality = 100; Noise = 1 } }
                'Proof' { @{ Dpi = [int]($Spec.Dpi * 0.75); Quality = 92; Noise = 1 } }
                default { @{ Dpi = $Spec.Dpi; Quality = 78 } }
            }
            $stage = if ($Spec.Stage -eq 'Proof') { 'Final' } else { $Spec.Stage }
            $pageCount = [Math]::Max(1, [int]$Spec.Pages)
            $pages = for ($p = 1; $p -le $pageCount; $p++) {
                $items = switch ($Spec.Motif.Layout) {
                    'Brochure' { Get-BrochurePageItem $Spec.Ctx $Spec.Customer $size.W $size.H $p $pageCount $Spec.Variant $stage $Spec.Seed $Spec.DesignDate }
                    'Web' { Get-WebPageItem $Spec.Ctx $Spec.Customer $size.W $size.H $p $pageCount $stage $Spec.Seed $Spec.DesignDate }
                    'Series' { Get-DesignItem $Spec.Ctx $Spec.Customer $size.W $size.H (@('A', 'B', 'C')[($p + [int][char]$Spec.Variant) % 3]) $stage ($Spec.Seed * 100 + $p) $Spec.Motif.Format $Spec.DesignDate }
                    default { Get-DesignItem $Spec.Ctx $Spec.Customer $size.W $size.H $Spec.Variant $stage $Spec.Seed $Spec.Motif.Format $Spec.DesignDate }
                }
                if ($Spec.Stage -eq 'Proof') { $items = @($items) + @(Get-ProofItem $size.W $size.H $Spec.Job $p $pageCount $Spec.DesignDate) }
                @{ W = $size.W; H = $size.H; Items = $items; Profile = $pageProfile }
            }
            if ($Spec.Stage -eq 'Proof') { $info.Creator = 'Prepress-Workflow'; $info.Producer = $Spec.Printer; $info.Author = $Spec.Printer }
            Export-PagePdf -Path $tmp -Pages @($pages) -Info $info
        }
        'pdfpages' { foreach ($k in $Spec.Info.Keys) { $info[$k] = $Spec.Info[$k] }; Export-PagePdf -Path $tmp -Pages $Spec.Pages -Info $info }
        'slides' {
            foreach ($k in $Spec.Info.Keys) { $info[$k] = $Spec.Info[$k] }
            $pages = for ($s = 0; $s -lt $Spec.Slides.Count; $s++) { @{ W = 960; H = 540; Items = (Get-SlideItem $Spec.Slides[$s] $Spec.Ci ($s + 1) $Spec.Footer); Profile = @{ Dpi = 110; Quality = 84 } } }
            Export-PagePdf -Path $tmp -Pages @($pages) -Info $info
        }
        'bin' { [IO.File]::WriteAllBytes($tmp, $Spec.Bytes) }
        'text' { [IO.File]::WriteAllText($tmp, $Spec.Text, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false)) }
        'copy' {
            $source = Join-SamplePath $TargetPath $Spec.Source
            if (-not [IO.File]::Exists($source)) { return 0 }
            [IO.File]::Copy($source, $tmp, $true)
        }
        'scanbundle' {
            # Mehrere Dokumente als ein Scan (Belegordner): Seiten aller Modelle plus Belegblaetter.
            $pages = [System.Collections.Generic.List[object]]::new()
            foreach ($model in $Spec.Models) {
                $layout = Build-FlowPage $model
                foreach ($pageItems in $layout.Pages) { $pages.Add(@{ W = $layout.W; H = $layout.H; Items = $pageItems; Profile = $Spec.Profile }) }
            }
            foreach ($sheet in $Spec.Sheets) { $pages.Add(@{ W = 595; H = 842; Items = $sheet; Profile = $Spec.Profile }) }
            $info.Creator = $Spec.Device; $info.Producer = 'Scan-to-Folder'; $info.Author = ''
            Export-PagePdf -Path $tmp -Pages $pages.ToArray() -Info $info
        }
        'zip' {
            # Paket fuer die Druckerei aus bereits geschriebenen Dateien der Einheit.
            $sources = @($Spec.Sources | ForEach-Object { Join-SamplePath $TargetPath $_ } | Where-Object { [IO.File]::Exists($_) })
            if (-not $sources) { return 0 }
            $stream = [IO.File]::Open($tmp, [IO.FileMode]::Create)
            $archive = New-Object -TypeName System.IO.Compression.ZipArchive -ArgumentList $stream, ([IO.Compression.ZipArchiveMode]::Create)
            try {
                foreach ($source in $sources) {
                    $entry = $archive.CreateEntry([IO.Path]::GetFileName($source), [IO.Compression.CompressionLevel]::Fastest)
                    $entry.LastWriteTime = [IO.File]::GetLastWriteTime($source)
                    $out = $entry.Open(); $in = [IO.File]::OpenRead($source)
                    try { $in.CopyTo($out) } finally { $in.Dispose(); $out.Dispose() }
                }
            }
            finally { $archive.Dispose(); $stream.Dispose() }
        }
        default { throw "Unbekannte Dateiart $($Spec.Kind)" }
    }
    if ([IO.File]::Exists($full)) { [IO.File]::Delete($tmp) } else { [IO.File]::Move($tmp, $full) }
    Write-FileTimestamp $full $Spec.Created $Spec.Modified
    (New-Object -TypeName System.IO.FileInfo -ArgumentList $full).Length
}

$ProgressSeen = @{}

function Get-UniqueProgress {
    # Summe der Worker-Fortschritte. Schreibt ein Worker gerade, gilt sein zuletzt gelesener Stand.
    $sum = 0L
    foreach ($file in [IO.Directory]::GetFiles($ProgressDir, 'worker-*.txt')) {
        try {
            $text = [IO.File]::ReadAllText($file).Trim()
            if ($text) { $script:ProgressSeen[$file] = [long]($text -split ' ')[0] }
        }
        catch [IO.IOException] { Write-Verbose -Message "Fortschritt gesperrt: $file" }
        if ($script:ProgressSeen.ContainsKey($file)) { $sum += $script:ProgressSeen[$file] }
    }
    $sum
}

function Write-WorkerProgress {
    # Atomar ueber Temp-Datei, mit Wiederholung, falls ein anderer Prozess gerade liest.
    param([string] $Path, [string] $Text)
    for ($try = 1; $try -le 20; $try++) {
        try {
            $tmp = $Path + '.tmp'
            [IO.File]::WriteAllText($tmp, $Text)
            if ([IO.File]::Exists($Path)) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) } else { [IO.File]::Move($tmp, $Path) }
            return
        }
        catch [IO.IOException] { Start-Sleep -Milliseconds (50 * $try) }
    }
    Write-LabLog "WARNUNG: Fortschritt nicht geschrieben: $Path"
}

function Invoke-WorkerLoop {
    param([int] $WorkerIndex, [int] $Count, [long] $UniqueTarget)
    $units = Get-WorkUnit -Scale (Get-ProjectScale $UniqueTarget)
    $progressFile = Join-Path $ProgressDir ('worker-{0}.txt' -f $WorkerIndex)
    $bytes = 0L; $files = 0; $failed = 0
    for ($i = $WorkerIndex; $i -lt $units.Count; $i += $Count) {
        if ((Get-UniqueProgress) -ge $UniqueTarget) { break }
        if (Test-VolumeFull) { Write-LabLog ('Volume fast voll (unter {0:P0} frei), Worker {1} stoppt.' -f $MinFreeShare, $WorkerIndex); break }
        try { $specs = Build-Unit $units[$i] }
        catch { $failed++; Write-LabLog "WARNUNG: Einheit $i ($($units[$i].Type)) nicht gebaut: $($_.Exception.Message) $($_.ScriptStackTrace)"; continue }
        foreach ($spec in $specs) {
            try { $bytes += Export-Spec $spec; $files++ }
            catch {
                $failed++
                Write-LabLog "WARNUNG: [$($units[$i].Type)/$($spec.Kind)] $($spec.Path): $($_.Exception.Message) $($_.ScriptStackTrace -split "`n" | Select-Object -First 2)"
                if ($failed -gt 50 -and $failed -gt $files) { throw "Zu viele Fehler ($failed), letzter: $($_.Exception.Message)" }
            }
        }
        Write-WorkerProgress $progressFile ('{0} {1} {2}' -f $bytes, $files, $i)
    }
    Write-LabLog ('Worker {0} fertig: {1:N1} GB in {2} Dateien, {3} Fehler.' -f $WorkerIndex, ($bytes / 1GB), $files, $failed)
}

function Get-BackupDate {
    # Quartalssicherung nach dem Aenderungsdatum (z. B. Sicherung_2021-06-30).
    param([datetime] $Date)
    $quarterEnd = (New-Object -TypeName DateTime -ArgumentList $Date.Year, ([Math]::Ceiling($Date.Month / 3) * 3), 1).AddMonths(1).AddDays(-1)
    if ($quarterEnd -ge $Reference) { $quarterEnd = $Reference.AddDays(-7) }
    $quarterEnd
}

function Invoke-DuplicatePass {
    # Kopien wie auf echten Servern: Basisordner, "Kopie von", Versionen, Quartalssicherungen im Archiv.
    param([long] $TargetBytes)
    $files = @([IO.Directory]::GetFiles($TargetPath, '*', [IO.SearchOption]::AllDirectories) | Where-Object { -not $_.EndsWith($TempSuffix) } | ForEach-Object { New-Object -TypeName System.IO.FileInfo -ArgumentList $_ })
    $total = ($files | Measure-Object -Property Length -Sum).Sum
    if ($total -ge $TargetBytes) { return $total }
    $sep = [string][IO.Path]::DirectorySeparatorChar
    $sources = @($files | Where-Object { $_.Length -gt 50KB -and $_.FullName -notmatch ('\{0}{1}\{0}' -f $sep, [regex]::Escape($Paths.Home)) } | Sort-Object FullName)
    $homes = @($People | Where-Object { $_.Lab })
    $rng = Get-Rng -Index 99 -Salt 99
    $attempts = 0
    while ($total -lt $TargetBytes -and $attempts -lt 400000 -and $sources) {
        $attempts++
        if (($attempts % 500) -eq 0 -and (Test-VolumeFull)) { Write-LabLog ('Volume fast voll (unter {0:P0} frei), keine weiteren Kopien.' -f $MinFreeShare); break }
        $src = $sources[$rng.Next(0, $sources.Count)]
        $relative = $src.FullName.Substring($TargetPath.Length).TrimStart('\', '/')
        $kind = $rng.Next(0, 10)
        $target = if ($kind -lt 3) { Join-SamplePath $TargetPath ('{0}\{1}\{2}\{3}' -f $Paths.Home, (Get-RandomEntry $rng $homes).Sam, $F.Documents, $src.Name) }
        elseif ($kind -lt 5) { Join-Path $src.DirectoryName ($L.Copy + $src.Name) }
        elseif ($kind -lt 6) { Join-Path $src.DirectoryName ('{0}_{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($src.Name), $L.OldFile, $src.Extension) }
        else { Join-SamplePath $TargetPath ('{0}\{1}_{2:yyyy-MM-dd}\{3}' -f $Paths.Archive, $F.Backup, (Get-BackupDate $src.LastWriteTime), $relative) }
        if ([IO.File]::Exists($target)) { continue }
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        [IO.File]::Copy($src.FullName, $target)
        $created = $src.LastWriteTime.AddDays($rng.Next(0, 400))
        if ($created -ge $Reference) { $created = $src.LastWriteTime }
        Write-FileTimestamp $target $created $src.LastWriteTime
        $total += $src.Length
    }
    $total
}

function Sync-FolderTimestamp {
    # Ordner: Erstellt = aeltestes, Geaendert = juengstes Kind (tiefste Ordner zuerst).
    $dirs = @([IO.Directory]::GetDirectories($TargetPath, '*', [IO.SearchOption]::AllDirectories) | Sort-Object { $_.Length } -Descending)
    foreach ($dir in $dirs) {
        $children = @([IO.Directory]::GetFileSystemEntries($dir))
        if (-not $children) { continue }
        $times = @($children | ForEach-Object { [IO.File]::GetLastWriteTime($_) } | Sort-Object)
        $created = @($children | ForEach-Object { [IO.File]::GetCreationTime($_) } | Sort-Object)
        try {
            [IO.Directory]::SetCreationTime($dir, $created[0])
            [IO.Directory]::SetLastWriteTime($dir, $times[-1])
        }
        catch { Write-Verbose -Message "Ordnerzeit nicht gesetzt: $dir" }
    }
}

function Write-SampleStatus {
    param([string] $State, [long] $Bytes, [int] $Files, [long] $Target)
    $status = [ordered]@{ State = $State; WrittenGB = [Math]::Round($Bytes / 1GB, 2); TargetGB = [Math]::Round($Target / 1GB, 2); Files = $Files; Updated = (Get-Date).ToString('s'); Reference = $Reference.ToString('yyyy-MM-dd') }
    [IO.File]::WriteAllText($StatusFile, ($status | ConvertTo-Json))
}

function Initialize-Generator {
    # Gemeinsame Vorbereitung fuer Haupt- und Worker-Prozess.
    if (-not $LabUsersPath) { $script:LabUsersPath = Join-Path $ScriptDir 'LabUsers.psd1' }
    if (-not $TargetPath) {
        $fs = Import-PowerShellDataFile -Path (Join-Path $ScriptDir 'FileServer.psd1')
        $script:TargetPath = $fs.Root
    }
    $script:TargetPath = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\', '/')
    if (-not [IO.Directory]::Exists($TargetPath)) { [void][IO.Directory]::CreateDirectory($TargetPath) }
    if ($ReferenceDate) { $script:Reference = [datetime]::ParseExact($ReferenceDate, 'yyyy-MM-dd', $Inv) }
    elseif (Test-Path -Path $PlanFile) { $script:Reference = [datetime]::ParseExact((Get-Content -Path $PlanFile -Raw | ConvertFrom-Json).Reference, 'yyyy-MM-dd', $Inv) }
    else { $script:Reference = (Get-Date).Date }
    if ($Worker -lt 0) { [IO.File]::WriteAllText($PlanFile, (@{ Reference = $Reference.ToString('yyyy-MM-dd'); Seed = $Seed } | ConvertTo-Json)) }
    Import-SampleCorpus
    Initialize-World
    $script:CompanyIban = Get-NationalId 'Iban' (Get-Rng -Index 2 -Salt 9)
    if ($UseRaster) { Initialize-Raster }
}

function Get-ScriptCopy {
    $copy = Join-Path $ScriptDir 'New-SampleDocuments.ps1'
    if ($PSCommandPath -and ([IO.Path]::GetFullPath($PSCommandPath) -ne [IO.Path]::GetFullPath($copy))) { Copy-Item -Path $PSCommandPath -Destination $copy -Force }
    elseif (-not (Test-Path -Path $copy)) { Set-Content -Path $copy -Value $SelfText -Encoding ASCII }
    $copy
}

function Invoke-MainPhase {
    $targetBytes = Get-TargetByte
    $uniqueTarget = [long]($targetBytes * (1 - $DuplicateShare))
    $count = if ($WorkerCount -gt 0) { $WorkerCount } else { [Environment]::ProcessorCount }
    Write-LabLog ("Start: Ziel {0:N1} GB ({1:N1} GB eigene Dokumente), Stichtag {2:yyyy-MM-dd}, {3} Worker, Raster {4}." -f ($targetBytes / 1GB), ($uniqueTarget / 1GB), $Reference, $count, $UseRaster)
    $isSystem = $IsWindowsHost -and [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
    if ($isSystem) { try { Add-MpPreference -ExclusionPath $TargetPath; Write-LabLog 'Defender-Ausschluss waehrend der Erzeugung gesetzt.' } catch { Write-LabLog "Defender-Ausschluss nicht gesetzt: $($_.Exception.Message)" } }
    foreach ($stale in [IO.Directory]::GetFiles($TargetPath, "*$TempSuffix", [IO.SearchOption]::AllDirectories)) { [IO.File]::Delete($stale) }
    foreach ($old in [IO.Directory]::GetFiles($ProgressDir, 'worker-*.txt')) { [IO.File]::Delete($old) }
    $deadline = if ($Continue -or $TimeBudgetMinutes -le 0) { [datetime]::MaxValue } else { (Get-Date).AddMinutes($TimeBudgetMinutes) }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Write-SampleStatus 'laeuft' 0 0 $targetBytes

    if ($count -le 1) { Invoke-WorkerLoop 0 1 $uniqueTarget }
    else {
        $copy = Get-ScriptCopy
        $exe = (Get-Process -Id $PID).Path
        $workers = foreach ($w in 0..($count - 1)) {
            $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Worker {1} -WorkerCount {2} -TargetPath "{3}" -TargetSizeMB {4} -LabRoot "{5}" -CorpusPath "{6}" -LabUsersPath "{7}" -ReferenceDate {8:yyyy-MM-dd} -Seed {9}' -f $copy, $w, $count, $TargetPath, [long]($targetBytes / 1MB), $LabRoot, $CorpusPath, $LabUsersPath, $Reference, $Seed
            if ($NoRaster) { $arguments += ' -NoRaster' }
            $process = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru -WindowStyle Hidden
            $null = $process.Handle
            $process
        }
        $lastLog = Get-Date
        while (@($workers | Where-Object { -not $_.HasExited }).Count) {
            Start-Sleep -Seconds 15
            $written = Get-UniqueProgress
            if ((Get-Date) -gt $lastLog.AddMinutes(1)) {
                Write-LabLog ('Fortschritt: {0:N1} von {1:N1} GB, {2:N1} MB/s.' -f ($written / 1GB), ($uniqueTarget / 1GB), ($written / 1MB / [Math]::Max(1, $watch.Elapsed.TotalSeconds)))
                Write-SampleStatus 'laeuft' $written 0 $targetBytes
                $lastLog = Get-Date
            }
            if ((Get-Date) -gt $deadline) {
                $workers | Where-Object { -not $_.HasExited } | ForEach-Object { Stop-Process -Id $_.Id -Force }
                Register-ContinuationTask $copy $targetBytes
                Write-SampleStatus 'wird im Hintergrund fortgesetzt' $written 0 $targetBytes
                Write-LabLog ('WARNUNG: Zeitbudget von {0} Minuten erreicht ({1:N1} GB). Der Task {2} setzt nach dem Start fort.' -f $TimeBudgetMinutes, ($written / 1GB), $TaskName)
                return
            }
        }
        $failedWorkers = @($workers | Where-Object { $_.ExitCode -ne 0 })
        if ($failedWorkers.Count -eq $workers.Count) { throw 'Alle Worker sind mit Fehler beendet, siehe New-SampleDocuments-W*.log.' }
    }
    $total = Invoke-DuplicatePass $targetBytes
    Sync-FolderTimestamp
    $fileCount = [IO.Directory]::GetFiles($TargetPath, '*', [IO.SearchOption]::AllDirectories).Count
    Write-SampleStatus 'fertig' $total $fileCount $targetBytes
    Write-LabLog ('Fertig: {0:N1} GB in {1} Dateien nach {2:N0} Minuten.' -f ($total / 1GB), $fileCount, $watch.Elapsed.TotalMinutes)
    if ($isSystem) { try { Remove-MpPreference -ExclusionPath $TargetPath } catch { Write-LabLog "Defender-Ausschluss nicht entfernt: $($_.Exception.Message)" } }
    if (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue }
}

function Register-ContinuationTask {
    param([string] $Copy, [long] $TargetBytes)
    $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Continue -TargetPath "{1}" -TargetSizeMB {2} -LabRoot "{3}" -CorpusPath "{4}" -LabUsersPath "{5}"' -f $Copy, $TargetPath, [long]($TargetBytes / 1MB), $LabRoot, $CorpusPath, $LabUsersPath
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Exit-GeneratorLock
    Start-ScheduledTask -TaskName $TaskName
}

function Enter-GeneratorLock {
    # Nur eine Hauptinstanz je VM (Run Command, Fortsetzungs-Task, erneutes Deployment). Ein benannter Mutex wird
    # beim Prozessende frei, auch nach einem Absturz. Zwei Minuten Wartezeit decken die Uebergabe an den Task ab.
    if (-not $IsWindowsHost) { return $true }
    $script:GeneratorMutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, 'Global\TraineeLab-SampleDocuments'
    try { $acquired = $script:GeneratorMutex.WaitOne([TimeSpan]::FromMinutes(2)) }
    catch [System.Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { $script:GeneratorMutex = $null }
    return $acquired
}

function Exit-GeneratorLock {
    if ($script:GeneratorMutex) {
        try { $script:GeneratorMutex.ReleaseMutex() } catch { Write-LabLog "Sperre nicht freigegeben: $($_.Exception.Message)" }
        $script:GeneratorMutex = $null
    }
}

#endregion

try {
    if ($Worker -lt 0 -and -not (Enter-GeneratorLock)) {
        Write-LabLog 'Eine andere Instanz erzeugt bereits Beispieldokumente, diese endet ohne Aenderung.'
        exit 0
    }
    Initialize-Generator
    if ($Worker -ge 0) {
        $targetBytes = Get-TargetByte
        Invoke-WorkerLoop $Worker $WorkerCount ([long]($targetBytes * (1 - $DuplicateShare)))
    }
    else { Invoke-MainPhase }
    exit 0
}
catch {
    Write-LabLog "FEHLER: $($_.Exception.Message)"
    Write-LabLog $_.ScriptStackTrace
    exit 1
}
