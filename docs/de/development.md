# Entwicklung

[English](../en/development.md) · **Deutsch**

Für alle, die am Lab selbst mitarbeiten: Aufbau des Repositorys, Build, Tests und Abnahme.

## Aufbau des Repositorys

- Quellcode: `infra/` (Bicep) und `scripts/` (PowerShell, nur ASCII, Windows PowerShell 5.1). Die Skripte werden per `loadTextContent` ins Template eingebettet, es gibt keine Downloads aus dem Repo.
- Lab-Daten je Sprache in `scripts/data/<Sprache>` (`de`, `en`): `LabUsers.psd1`, `FileServer.psd1` und der Textkorpus `corpus`. Beide Sprachen haben denselben Aufbau, die Tests prüfen das.
- Dokumentation in `docs/de` und `docs/en` mit gleichen Dateinamen. Änderungen in beiden Sprachen pflegen. Die readme hat einen englischen und einen deutschen Teil; Englisch steht immer zuerst, auch in Inhaltsverzeichnis und Sprachumschaltern.

## Template bauen

`azuredeploy.json` wird **generiert**, nie von Hand bearbeiten:

```bash
az bicep build --file infra/main.bicep --outfile azuredeploy.json
```

## Lab-Daten und Beispieldokumente

Beispieldokumente: Drehbuch und Texte liegen lesbar in `scripts/data/<Sprache>/corpus` (Regeln in [scripts/data/README.md](../../scripts/data/README.md)), der Generator in `scripts/New-SampleDocuments.ps1`. Daraus entstehen die eingebetteten Artefakte `scripts/SampleCorpus.<Sprache>.gz` (userData der VM, je Sprache höchstens 64 KB Base64) und `scripts/Start-SampleDocuments.ps1` (gepackter Generator). Nach jeder Änderung neu bauen, die Tests prüfen den Abgleich:

```powershell
./tools/Build-SampleArtifacts.ps1
```

## Generator lokal

Generator lokal ausprobieren (Windows PowerShell 5.1, ohne Azure):

```powershell
.\scripts\New-SampleDocuments.ps1 -TargetPath C:\Temp\Daten -TargetSizeMB 500 -LabRoot C:\Temp\Lab `
    -CorpusPath .\scripts\data\de\corpus -LabUsersPath .\scripts\data\de\LabUsers.psd1 -ReferenceDate 2026-11-24
```

## Prüfungen

Prüfungen (laufen auch in der CI, unter Linux mit pwsh 7 und unter Windows PowerShell 5.1). `tests/Haertung.Tests.ps1` prüft die Fehlerklassen der Testdeployments: Run-Command-Parameter gegen die Skripte, Argumente geplanter Tasks, Formatstrings der Lab-Info, stderr nativer Befehle unter 5.1, Zeitlimits, DPAPI:

```powershell
'scripts', 'tools' | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 }
Invoke-Pester -Path tests
```

## Downloads prüfen

Vor jeder Abnahme und nach jeder Versionsänderung prüft `./tools/Test-Downloads.ps1` alle festgelegten Downloads (Hash, Größe) und Modulversionen. Blockiert das eigene Netz GitHub-Downloads, mit `-ResourceGroup <rg> -VmName <vm>` von einer Lab-VM aus.

## Abnahme

Abnahme einer Änderung: DE- und EN-Lab parallel bereitstellen (beide mit DC02, Client, Fileserver), ohne Eingriff, danach `./tools/Test-LabDeployment.ps1 -ResourceGroup <rg> -Wait` mit Exit-Code 0 auf beiden.
