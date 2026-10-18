# scripts/powershell/

Admin scripts and Graph tooling.

| Script | What it does | Needs Graph? |
| ------ | ------------ | ------------ |
| `ConvertTo-SanitizedIntuneExport.ps1` | Strips tenant-specific data from JSON exports and writes stable, sorted JSON for `artifacts/`. | No, offline |

Read a script before you run it. Anything that writes to a tenant supports `-WhatIf`; use it first.

Placeholder content for the rest of this folder is added as it is built. See the [repo structure](../../README.md#repo-structure) for where this fits.
