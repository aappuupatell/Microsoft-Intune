# tests/

Pester tests that run in CI.

- `Test-RepoSanitized.Tests.ps1` covers the sanitization guard in `.github/scripts/`.
- `RepoStructure.Tests.ps1` checks that every folder in the README's structure block exists and has a `README.md`.

Run them with `Invoke-Pester -Path ./tests`.
