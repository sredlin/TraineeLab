# Einstellungen fuer PSScriptAnalyzer (lokal und in der CI).
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # False Positive: Die Skriptparameter werden innerhalb von Funktionen auf Skriptebene genutzt,
        # das erkennt die Regel nicht.
        'PSReviewUnusedParameter'
    )
}
