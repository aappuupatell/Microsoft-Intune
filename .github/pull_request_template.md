<!--
Thanks for contributing. Keep what is useful below and delete the rest.
The checklist is the review gate. If a box does not apply, say why instead of deleting it.
-->

## What this changes

<!-- One or two sentences. What problem does it solve, and for whom? -->

## Type of change

- [ ] Documentation (`docs/`, `runbooks/`, `examples/`)
- [ ] Policy artifact (`artifacts/`)
- [ ] Script (`scripts/`)
- [ ] Remediation pair (`remediations/`)
- [ ] Repo tooling / CI
- [ ] Other:

## Platform and licensing

<!-- Which platforms does this apply to? Does it need Intune Plan 2, Intune Suite, Windows E3/E5, or an add-on? -->

## Testing

<!-- Where was it tested? Tenant type (dev/test), OS versions, enrollment type. "Untested" is an acceptable answer; it just changes how the reviewer reads it. -->

## Checklist

- [ ] **Sanitized.** No tenant IDs, group object IDs, hardware hashes, serial numbers, real UPNs, internal hostnames, tokens, or secrets. Placeholders look like `<TENANT-ID>`.
- [ ] **Artifact + doc.** Anything that changes device or app behavior ships with both the artifact (the *what*) and a doc (the *why*, who it targets, how to undo it).
- [ ] **Rollback documented.** The doc says how to back the change out.
- [ ] **"Does not touch" section.** Remediation and script docs say what they explicitly leave alone.
- [ ] **Exit codes.** Detection scripts exit `1` when the issue is found and `0` when it is not; remediation scripts exit `0` on success.
- [ ] **Lint clean.** `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` reports nothing.
- [ ] **Tested in a non-production tenant**, or marked untested above.
