# Einstellungen fuer PSScriptAnalyzer (lokal und in der CI).
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # False Positive: Die Skriptparameter werden innerhalb von Funktionen auf Skriptebene genutzt,
        # das erkennt die Regel nicht.
        'PSReviewUnusedParameter'
    )
    Rules        = @{
        # Die VM-Skripte laufen unter Windows PowerShell 5.1 (Run Command), Werkzeuge und Tests auch unter pwsh 7.
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.4')
        }
    }
}
