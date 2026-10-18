# tests/

Pester tests that run in CI.

- `Test-RepoSanitized.Tests.ps1` covers the sanitization guard in `.github/scripts/`.
- `RepoStructure.Tests.ps1` checks that every folder in the README's structure block exists and has a `README.md`.
- `ConvertTo-SanitizedIntuneExport.Tests.ps1` covers the export sanitizer in `scripts/powershell/`: removal and replacement rules, the stable JSON writer, file modes, and that its output passes the guard.

Run them with `Invoke-Pester -Path ./tests`.
