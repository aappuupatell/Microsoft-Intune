# tests/

Pester tests that run in CI.

- `Test-RepoSanitized.Tests.ps1` covers the sanitization guard in `.github/scripts/`.
- `RepoStructure.Tests.ps1` checks that every folder in the README's structure block exists and has a `README.md`.
- `Remediations.Tests.ps1` checks that every detection script has a matching remediation script (or is declared detection-only) and a doc.

Run them with `Invoke-Pester -Path ./tests`.
