# Contributing to Intune Atlas

Thanks for helping. The most valuable contributions are the ones that save someone else a weekend: a remediation whose detection actually detects something, a policy export with the *why* written next to it, or a "here's what broke" write-up.

This page is the rulebook. The [README](README.md) explains what the repo is for; [SECURITY.md](SECURITY.md) explains what must never be committed.

## Before you start

- **Small fix?** Open a pull request.
- **New doc, script, artifact, or remediation?** Open a [proposal issue](https://github.com/aappuupatell/Microsoft-Intune/issues/new?template=new-content.yml) first if you are unsure where it goes or whether it fits. Five minutes of discussion beats a rewrite.
- **Found something sensitive in the repo?** Do not open an issue. Use private vulnerability reporting (see SECURITY.md).

## Where things go

The [README's repo structure](README.md#repo-structure) is the map, and every folder has its own `README.md` saying what belongs there. [`docs/README.md`](docs/README.md) maps each topic area in the main README to the folders, scripts, and remediations that serve it.

| You are adding...                          | Put it in                                                                      |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| Conceptual doc, how-to, decision guide     | `docs/<area>/`                                                                 |
| Policy export (JSON) and its doc           | `artifacts/policies/<area>/`                                                   |
| Admin / Graph script                       | `scripts/powershell/`                                                          |
| REST request collection                    | `scripts/graph/`                                                               |
| Remediation pair                           | `remediations/detection/` + `remediations/remediation/` + `remediations/docs/` |
| Operational procedure                      | `runbooks/`                                                                    |
| End-to-end walkthrough                     | `examples/<name>/`                                                             |
| Post-mortem / lesson learned               | `docs/lessons-learned/`                                                        |

## The two rules that matter most

### 1. Artifact + doc

If it changes device or app behavior, it ships as two things: the **artifact** (what) and a **doc** (why, who it targets, what it conflicts with, how to undo it). A JSON export with no doc is not mergeable. A doc that says "configure BitLocker" with no artifact is a blog post.

For policy artifacts, the doc is a Markdown file with the same base name next to the JSON:

```text
artifacts/policies/compliance/win-baseline.compliance.json
artifacts/policies/compliance/win-baseline.compliance.md
```

For remediations, the doc is `remediations/docs/<Name>.md`, one per pair.

### 2. Sanitize everything

Exports from the admin center and Graph contain tenant IDs, group object IDs, timestamps, and sometimes display names you do not want public. Before committing:

1. Run `scripts/powershell/ConvertTo-SanitizedIntuneExport.ps1` on the file. It removes export metadata that only means something in the source tenant (`id`, `createdDateTime`, `lastModifiedDateTime`, `version`, and similar), replaces known identifiers with placeholders, and writes stable, sorted JSON.
2. Replace anything tenant-specific that survives with a placeholder from the table below.
3. Run `./.github/scripts/Test-RepoSanitized.ps1 -Path .` locally. CI runs the same check and fails the PR on findings.

| Placeholder                    | Use it for                                                        |
| ------------------------------ | ----------------------------------------------------------------- |
| `<TENANT-ID>`                  | Entra tenant GUID                                                 |
| `<TENANT>.onmicrosoft.com`     | Tenant domain (or `contoso.onmicrosoft.com`)                      |
| `<GROUP-OBJECT-ID>`            | Entra group object ID in an assignment                            |
| `<GROUP:Display Name>`         | Group referenced by name so it can be resolved in another tenant  |
| `<FILTER:Display Name>`        | Assignment filter referenced by name                              |
| `<CLIENT-ID>`                  | App registration (client) ID                                      |
| `<CERT-THUMBPRINT>`            | Certificate thumbprint for app-only auth                          |
| `<UPN>` or `user@contoso.com`  | A user principal name                                             |
| `<DEVICE-NAME>`, `<SERIAL>`    | Device identifiers                                                |

Never commit, even in history: tokens, client secrets, private keys, Autopilot hardware hashes, serial numbers, IMEIs, MAC addresses, real UPNs, internal hostnames, or employee IDs. If you realize you pushed one, rotate it first, then tell the maintainer.

## Conventions

### Naming

- Folders and Markdown files: `kebab-case` (`docs/updates/ring-strategy.md`).
- PowerShell scripts: `Verb-Noun.ps1` with an [approved verb](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands) (`Export-IntuneConfiguration.ps1`).
- Remediation pairs: `Detect-<Name>.ps1`, `Remediate-<Name>.ps1`, `<Name>.md`, where `<Name>` is PascalCase and identical across all three (`Detect-TimeSync.ps1`, `Remediate-TimeSync.ps1`, `TimeSync.md`).
- Policy artifacts: `<platform>-<what>.<type>.json` with the platform prefix `win`, `macos`, `ios`, `android`, `linux`, or `xplat` and the type one of `settings-catalog`, `admx`, `oma-uri`, `compliance`, `endpoint-security`, `baseline`, `update-ring`, `feature-update`, `quality-update`, `driver-update`, `app-config`, `app-protection`, `enrollment`. Assignments, if included, go in a sidecar `<same-name>.assignments.json`.

### Doc front matter

Every doc under `docs/`, `runbooks/`, and `examples/` starts with:

```yaml
---
title: Compliance states explained
platforms: [windows, macos, ios, android, linux]   # or a subset
licensing: Intune Plan 1                            # name anything beyond Plan 1 explicitly
status: ga                                          # ga | preview | deprecated
last_verified: 2026-10                              # YYYY-MM you last confirmed this against the product
---
```

`last_verified` is how readers judge staleness. Update it when you re-check a page, not when you touch a typo.

### PowerShell

- Must parse on **Windows PowerShell 5.1**: the Intune Management Extension runs scripts with 5.1, so no ternary operator, no `??`, no `&&`/`||` chains, no `-Parallel`. CI enforces this with PSScriptAnalyzer's compatible-syntax rule.
- `#Requires -Version 5.1`, `[CmdletBinding()]`, `Set-StrictMode -Version Latest`, and comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`).
- Anything that writes to a tenant or a device supports `-WhatIf` (`SupportsShouldProcess`).
- Secrets never appear in code. Document the app registration + certificate pattern and leave values out.
- No `Invoke-Expression`, no download-and-execute, no `Install-Module` inside remediations, no persistent execution-policy changes. CI blocks all of these.
- **Pure ASCII, no BOM.** Windows PowerShell 5.1 reads BOM-less files as ANSI and Intune's signature check rejects BOM files, so the only safe choice is plain ASCII: straight quotes, plain hyphens. Markdown can use whatever characters it likes; scripts cannot.
- CRLF line endings for `.ps1`/`.psm1`/`.psd1` (handled by `.gitattributes`).
- State validation status in `.NOTES`: `Validated: 2026-10 against a test tenant` or `Validated: not yet validated against a tenant`. Unvalidated scripts are welcome; unlabelled ones are not.

### Remediation contract

Every pair in `remediations/` follows this contract (the full version will live in [`remediations/README.md`](remediations/README.md)):

- Detection exits `1` when the issue is found and `0` when it is not. Any other exit code, or empty output, is treated by Intune as "issue not found".
- Output is one line, under 2,048 characters, written with `Write-Output`.
- Remediation is idempotent, never reboots or prompts, re-runs the detection logic at the end, and exits non-zero if the issue persists.
- The doc states what the pair checks, what it changes, **what it explicitly does not touch**, the run context (SYSTEM or user, 32- or 64-bit), the schedule, and the rollback.

## Running the checks locally

```powershell
# Lint (same settings as CI)
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1

# Tests
Invoke-Pester -Path ./tests

# Sanitization guard
./.github/scripts/Test-RepoSanitized.ps1 -Path .

# Markdown
npx markdownlint-cli2 "**/*.md"
```

Install the tooling once with `Install-Module PSScriptAnalyzer, Pester -Scope CurrentUser`.

## Pull requests

The [PR template](.github/pull_request_template.md) is the review checklist. Fill it in honestly. "Untested" is an acceptable answer; it changes how the reviewer reads the change, it does not block it.

Commits: short imperative subject, body explains why. No tenant names in commit messages either.

## Licensing of contributions

By contributing you agree your work is released under the repo's [MIT License](LICENSE). Keep attribution to a GitHub handle; no employee IDs, no internal team names.
