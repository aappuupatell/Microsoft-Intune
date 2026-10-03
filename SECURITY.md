# Security Policy

This repo doesn't ship a product — it ships scripts, policy exports, and documentation that people run against production tenants. That changes what "security issue" means here. A bad detection rule or a leaked tenant ID can do real damage even though there's no binary involved.

## Reporting a vulnerability

Don't open a public issue for anything security-related.

Use GitHub's private vulnerability reporting: go to the **Security** tab of this repo and select **Report a vulnerability**. That keeps the details between you and the maintainer until there's a fix.

Include what you can:

- The file path and commit (or branch) where you found the problem
- What the issue is and how it could be triggered or abused
- Which platforms, Intune features, or script execution contexts it affects
- Whether you've seen it happen in a real environment or found it through review

You'll get an acknowledgement within a few days. This is a side project maintained around a full-time job, so I can't promise enterprise SLAs — but security reports jump the queue and I'll keep you updated until it's resolved.

## What counts as a security issue here

- **Scripts with exploitable flaws** — command injection, unsafe handling of credentials or tokens, privilege escalation paths, insecure temp file usage, anything that runs with SYSTEM rights and can be hijacked
- **Committed secrets or identifiers** — tokens, client secrets, certificate private keys, tenant IDs, hardware hashes, serial numbers, user PII, internal hostnames. Even in git history
- **Policy artifacts that weaken security without saying so** — a baseline or compliance export that disables a control and the accompanying doc doesn't call it out
- **Remediation scripts that do more than documented** — a "fix" that touches things beyond what the detection logic and doc describe
- **Supply-chain concerns** — scripts that download and execute content from URLs that could be changed or hijacked

## What's out of scope

- **Bugs in Intune, Entra ID, Graph API, Defender, or any Microsoft service** — those go to the [Microsoft Security Response Center](https://msrc.microsoft.com/report), not here
- **"This policy is too permissive / too strict for my environment"** — that's a design discussion. Open a regular issue
- **Third-party tools that are linked but not hosted here** — report those to their own maintainers

## If you're contributing

Before you push:

- **Sanitize everything.** Exported JSON from the admin center includes tenant IDs, GUIDs, and sometimes display names you don't want public. Replace with placeholders like `<TENANT-ID>` or `<GROUP-OBJECT-ID>` and note what goes there in the doc.
- **No real hardware hashes, serial numbers, or device names** in Autopilot examples or sample report output.
- **No credentials, ever.** Not in scripts, not in comments, not in commit messages. If a script needs auth, document the app registration pattern and leave the values out.

If you realize you've committed something sensitive, rotate it first and then let me know. Rewriting history is a second step, not a fix — assume anything pushed to a public repo has been seen.

## Using what's here

Everything is provided as-is. Read a script before you run it. Test in a non-production tenant. Validate your assignment targeting before you hit "Create." The remediation scripts in particular run as SYSTEM on every device you assign them to — treat them accordingly.
