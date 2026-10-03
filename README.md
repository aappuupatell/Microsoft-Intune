# Intune Atlas

Documentation, exported configs, PowerShell automation, remediations, and operational context for Microsoft Intune — built from managing real environments, not just reading about them.

If you've ever inherited a tenant with 200 configuration profiles and no notes explaining why any of them exist, this repo is the thing you wished someone had left behind.

---

## What this is

Intune is broad. Enrollment alone covers five platforms, each with its own enrollment types, restrictions, and gotchas. Stack configuration profiles, compliance policies, app deployments, security baselines, Conditional Access ties, update management, and the ever-growing Intune Suite on top of that — and suddenly one person's undocumented portal work becomes the whole team's problem.

Microsoft's docs are good reference material, but they're written to explain features in isolation. They won't tell you that a security baseline and a Settings Catalog profile are silently fighting over the same setting, or why your compliance policy shows "Not applicable" on devices you're sure it targets, or that the Intune Management Extension runs scripts in SYSTEM context but your detection rule assumed the user profile.

This repo is the layer between official docs and real operations:

- **Documentation that explains intent** — not "this setting exists" but "here's why you'd configure it this way, what it conflicts with, and what to check when it doesn't apply."
- **Exported policy artifacts** — compliance policies, configuration profiles, security baselines, update rings, and endpoint security policies as sanitized JSON ready for import. Your configs belong in version control, not just in a portal.
- **PowerShell and Graph automation** — export/import workflows, drift detection, bulk operations, reporting. If you're doing it in the admin center more than twice, it should be scripted.
- **Remediation scripts** — detection + fix pairs for common endpoint issues, documented with what they check, what they change, and what they leave alone.
- **Operational runbooks and lessons learned** — device wipe procedures, break-glass scenarios, and the "this is what went wrong and how to avoid it" notes that are usually the most valuable part of any knowledge base.

---

## What's covered

### Enrollment & Autopilot
Windows Autopilot (user-driven, self-deploying, pre-provisioning — and the Device Preparation experience that's replacing classic Autopilot), Apple Automated Device Enrollment and Configurator-based flows, Android Enterprise (fully managed, work profile, dedicated devices), macOS enrollment via Company Portal and automated enrollment, and Linux. Enrollment restrictions, device categories, device limits, assignment filters on enrollment profiles, and the Enrollment Status Page — including the timing issues that cause half the support tickets during a rollout.

### Device Configuration
Settings Catalog is where you should start — it's what Microsoft is investing in going forward. But you'll also hit Administrative Templates (ADMX-backed policies delivered through Intune), device restriction templates, and custom OMA-URI for CSP settings that haven't surfaced in the catalog yet. This section covers the decision tree for when to use which profile type, how conflicts resolve when multiple profiles target the same setting, scope tags for RBAC, and assignment filters — because getting assignment right matters more than getting the setting right.

### Applications
Win32 app packaging (IntuneWin), detection rules that actually work across x64 and ARM, dependency chains, supersedence, required vs. available install behavior, the Enterprise App Catalog, Microsoft 365 Apps deployment, LOB apps, and Store apps (both the new Microsoft Store integration and legacy flows). App configuration policies for managed apps and managed devices. What the IME logs (`IntuneManagementExtension.log`) are actually telling you when an install fails. The ESP app install phase and why apps sometimes look stuck at 50%.

### App Protection (MAM)
App protection policies for iOS, Android, and Windows — data transfer restrictions, copy/paste controls, conditional launch settings, PIN requirements, selective wipe. Covers both MDM-enrolled and unenrolled/BYOD scenarios, because most environments run both. Includes app configuration for managed apps and how MAM-WE (without enrollment) and MAM on enrolled devices differ in practice.

### Compliance & Conditional Access
Compliance policies per platform, custom compliance with PowerShell scripts, the evaluation cycle and why compliance state isn't instant, grace periods, notification actions, and non-compliance actions like retire/wipe on continued non-compliance. How compliance state feeds into Entra ID Conditional Access — patterns for gating Microsoft 365 access, VPN, and LOB apps. What "Not compliant" vs. "Not evaluated" vs. "In grace period" actually mean for your users and when each state blocks access.

### Security
Endpoint security policies — antivirus (Defender AV), firewall, disk encryption (BitLocker and FileVault), attack surface reduction, endpoint detection and response — and how these relate to (and sometimes conflict with) configuration profiles targeting the same settings. Security baselines as a starting posture and why you should treat them as a starting point to customize, not a finished product. Defender for Endpoint onboarding through Intune, the Security Management for Microsoft Defender for Endpoint (MDE-attach) scenario, and the compliance → Conditional Access → Defender signal chain.

### Updates & Servicing
Update rings (deferral windows, deadlines, user experience settings), feature update policies, quality update policies including expedited updates, and driver update management. How Intune's update policies map to what Windows Autopatch does under the hood. Practical strategy for deferral and deadline settings, why active hours matter more than you think, and how to push a critical patch without destroying the end-user experience. Notes on servicing mixed Windows 10/11 fleets and planning for Windows 10 EOS.

### Remediations
Detection and remediation script pairs (what used to be called Proactive Remediations before the rebrand). Real-world examples: stale registry keys, broken services, certificate health checks, time sync issues, local admin group drift. Each script pair is documented with its detection logic, what the remediation changes, and what it explicitly does not touch. Covers the execution context (SYSTEM vs. user), output requirements for detection scripts, and scheduling.

### Reporting & Graph Automation
Built-in Intune reports and their limitations, Graph API export patterns for compliance status, app install failures, device inventory, and anything the portal can't slice the way you need. Authentication patterns for Graph (app registrations, delegated vs. application permissions, certificate-based auth), the `Microsoft.Graph` PowerShell module and direct REST calls, and the reality that many Intune Graph endpoints still live on the beta API. Reusable functions for backup/export, configuration comparison, bulk assignment changes, and scheduled reporting.

### Remote Actions & Runbooks
Wipe, retire, fresh start, Autopilot reset, remote lock, passcode reset, sync, collect diagnostics, and device rename — and the platform differences that matter. A "wipe" on iOS and a "wipe" on Windows are not the same operation with the same consequences. Runbooks for repeatable procedures: lost/stolen device response, device offboarding, BitLocker key rotation, certificate renewal, and break-glass access.

### Migrations
Co-management with Configuration Manager — workload sliders, staged transitions, and running two management authorities without creating policy conflicts. Migration from third-party MDM (moving devices without wiping them where possible, and planning for when you can't). Moving from Hybrid Azure AD Join to Entra Join (cloud-native), including the Group Policy to Intune translation work and user-impact planning.

### Intune Suite & Add-ons
Remote Help, Endpoint Privilege Management (just-in-time elevation without giving out local admin), Enterprise Application Management (the curated app catalog), Cloud PKI (cloud-hosted certificate lifecycle management), Advanced Analytics, and Microsoft Tunnel (including Tunnel for MAM on unenrolled devices). Each documented with prerequisites, licensing context, and practical guidance on when it's worth enabling. With many of these capabilities rolling into M365 E3/E5 licensing throughout 2026, the licensing notes are kept current.

---

## Repo structure

```
/
├── docs/
│   ├── fundamentals/                  # Licensing, prereqs, tenant setup, Entra ID relationship
│   ├── platforms/                     # Windows / macOS / iOS-iPadOS / Android / Linux
│   ├── security-and-compliance/       # Compliance, Conditional Access, baselines, endpoint security
│   ├── apps/                          # Deployment, config, protection, ESP/DPP
│   ├── updates/                       # Rings, feature/quality updates, drivers, Autopatch
│   ├── reporting-and-analytics/       # Reports, Graph exports, operational dashboards
│   ├── automation/                    # Graph + PowerShell, auth, reusable functions
│   ├── troubleshooting/              # Logs, known issues, platform-specific gotchas
│   └── migrations/                    # Co-management, third-party MDM, cloud-native transition
│
├── artifacts/
│   ├── policies/
│   │   ├── configuration/             # Settings Catalog, ADMX, OMA-URI
│   │   ├── compliance/                # Compliance policy JSON (per platform)
│   │   ├── endpoint-security/         # AV, firewall, disk encryption, ASR, EDR
│   │   ├── security-baselines/        # Baseline exports + customization notes
│   │   ├── updates/                   # Update rings, feature/quality/driver policies
│   │   └── apps/                      # App config templates, assignment metadata
│   └── reports/                       # Export templates, sample output (sanitized)
│
├── scripts/
│   ├── powershell/                    # Modules, admin scripts, Graph tooling
│   └── graph/                         # REST collections, request samples
│
├── remediations/
│   ├── detection/                     # Detection scripts (read-only checks)
│   └── remediation/                   # Fix scripts, paired with detection
│
├── runbooks/                          # Operational procedures
├── examples/                          # End-to-end walkthroughs
└── .github/                           # PR templates, issue templates, CI
```

If it changes device or app behavior, it gets two things: an artifact and a doc. The artifact is the *what*. The doc is the *why*, who it targets, and how to undo it.

---

## How to use this

Start with `/docs` for your scenario. Greenfield rollout → `fundamentals/`. Hardening an existing tenant → `security-and-compliance/`. Cleaning up configuration drift → `automation/` and `troubleshooting/`. Migrating off ConfigMgr or a third-party MDM → `migrations/`.

Then pull matching artifacts and scripts. Everything is modular — grab what applies, adapt it, and deploy through your own change process.

A few principles this is built around:

- **The admin center is where you deploy, not where you document.** Portal-only knowledge leaves when people leave. Version-controlled configs and written rationale stick around.
- **Ring everything.** Pilot → limited → broad. Have a rollback plan *before* you deploy.
- **Automate what repeats.** Intune is Graph-native — if you're clicking through the same portal workflow regularly, script it.
- **"Deployed" ≠ "applied."** A green checkmark in the portal doesn't mean the setting took effect. Check, validate, then trust.

---

## Contributing

Contributions are welcome — especially the "here's what broke and why" stories that save someone else a weekend.

A good contribution includes:

- A markdown doc with the problem it solves, who it's for, and a rollback path.
- A sanitized artifact (JSON, script, template) — no tenant IDs, tokens, hardware hashes, or PII. Use placeholders like `<YOUR-TENANT-ID>` and note what goes there.
- Platform and licensing context (especially for Suite add-ons or features that require Plan 2 or E5).

---

## Disclaimer

Not a Microsoft project. Community-built by people who manage Intune environments day to day.

Everything is provided as-is. Test in a non-production environment. Validate your targeting. Have a rollback plan.

---

## References

When the repo and the official docs disagree, the official docs win:

- [Microsoft Intune documentation](https://learn.microsoft.com/en-us/intune/)
- [What is Intune](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/what-is-intune)
- [Enrollment guidance](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/deployment-guide-enrollment)
- [Settings Catalog](https://learn.microsoft.com/en-us/intune/intune-service/configuration/settings-catalog)
- [Administrative Templates (ADMX)](https://learn.microsoft.com/en-us/intune/intune-service/configuration/administrative-templates-windows)
- [Endpoint security & baselines](https://learn.microsoft.com/en-us/intune/intune-service/protect/endpoint-security-policy)
- [Compliance + Conditional Access](https://learn.microsoft.com/en-us/intune/intune-service/protect/conditional-access)
- [App protection & configuration](https://learn.microsoft.com/en-us/intune/intune-service/apps/app-protection-policy)
- [Remediations](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)
- [Graph API — Intune](https://learn.microsoft.com/en-us/graph/intune-concept-overview)
- [Report exports via Graph](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/reports-export-graph-apis)
- [Co-management](https://learn.microsoft.com/en-us/intune/configmgr/comanage/)
- [Intune Suite & add-ons](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/intune-add-ons)
- [Cloud PKI](https://learn.microsoft.com/en-us/intune/cloud-pki/)
- [Enterprise App Management](https://learn.microsoft.com/en-us/intune/intune-service/apps/apps-enterprise-app-man)

---

## License

Released under the [MIT License](LICENSE). See [SECURITY.md](SECURITY.md) for responsible disclosure.
