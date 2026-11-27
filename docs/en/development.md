# Development

**English** · [Deutsch](../de/development.md)

For everyone working on the lab itself: repository layout, build, tests and acceptance.

## Repository layout

- Source code: `infra/` (Bicep) and `scripts/` (PowerShell, ASCII only, Windows PowerShell 5.1). The scripts are embedded into the template via `loadTextContent`; there are no downloads from the repo.
- Lab data per language in `scripts/data/<language>` (`de`, `en`): `LabUsers.psd1`, `FileServer.psd1` and the text corpus `corpus`. Both languages have the same structure; the tests check this.
- Documentation in `docs/de` and `docs/en` with the same file names. Keep changes in both languages. The readme contains an English and a German section; English always comes first, including in the table of contents and language switchers.

## Build the template

`azuredeploy.json` is **generated**; never edit it by hand:

```bash
az bicep build --file infra/main.bicep --outfile azuredeploy.json
```

## Lab data and sample documents

Sample documents: the script and texts are kept readable in `scripts/data/<language>/corpus` (rules in [scripts/data/README.md](../../scripts/data/README.md), German), the generator in `scripts/New-SampleDocuments.ps1`. From these, the embedded artefacts `scripts/SampleCorpus.<language>.gz` (VM userData, at most 64 KB Base64 per language) and `scripts/Start-SampleDocuments.ps1` (packed generator) are built. Rebuild after every change; the tests check that they match:

```powershell
./tools/Build-SampleArtifacts.ps1
```

## Run the generator locally

Try the generator locally (Windows PowerShell 5.1, without Azure):

```powershell
.\scripts\New-SampleDocuments.ps1 -TargetPath C:\Temp\Daten -TargetSizeMB 500 -LabRoot C:\Temp\Lab `
    -CorpusPath .\scripts\data\de\corpus -LabUsersPath .\scripts\data\de\LabUsers.psd1 -ReferenceDate 2026-11-24
```

## Checks

Checks (also run in CI, on Linux with pwsh 7 and on Windows PowerShell 5.1). `tests/Haertung.Tests.ps1` covers the error classes found in test deployments: Run Command parameters against the scripts, arguments of scheduled tasks, format strings of the lab info, stderr of native commands under 5.1, time limits, DPAPI:

```powershell
'scripts', 'tools' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 }
Invoke-Pester -Path tests
```

## Check downloads

Before every acceptance and after every version change, `./tools/Test-Downloads.ps1` checks all pinned downloads (hash, size) and module versions. If your own network blocks GitHub downloads, run it from a lab VM with `-ResourceGroup <rg> -VmName <vm>`.

## Acceptance

Acceptance of a change: deploy a DE and an EN lab in parallel (both with DC02, client, file server), without intervention, then `./tools/Test-LabDeployment.ps1 -ResourceGroup <rg> -Wait` with exit code 0 on both.
