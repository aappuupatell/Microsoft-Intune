# Microsoft Intune

A structured, long-term knowledge base for Microsoft Intune.

This repository is built to document Intune end to end — from prerequisites and tenant setup to advanced automation, policy engineering, security, reporting, and platform operations.

## Purpose

This repo is intended to become a practical reference for building, managing, securing, and scaling Intune in real environments.

## What this repo covers

The scope of this repository is broad by design. It is meant to cover the full Intune lifecycle, including:

### Fundamentals
- Tenant readiness
- Identity and access prerequisites
- Licensing considerations
- RBAC and scope design
- Naming standards
- Assignment strategy
- Change control and rollout methodology

### Enrollment and onboarding
- Windows enrollment
- Windows Autopilot
- Apple enrollment
- Android Enterprise enrollment
- macOS enrollment
- Linux enrollment
- Enrollment restrictions
- Device categories
- Enrollment Status Page and onboarding flow design

### Configuration management
- Settings Catalog
- Administrative Templates
- Device restrictions
- Custom profiles and OMA-URI
- Configuration standards
- Conflict awareness
- Baseline design
- Policy organization and cleanup strategy
- Policy Sets
- PowerShell Scripts and Remediations

### Application management
- Win32 app packaging and deployment
- Microsoft 365 Apps
- Store and line-of-business apps
- App assignment strategy
- Detection and requirement rules
- Dependencies and supersedence
- App configuration policies
- Enterprise app lifecycle management

### App protection
- App Protection Policies
- BYOD protection models
- Managed vs unmanaged app controls
- Data protection and access controls
- Selective wipe and app-based protection strategy

### Security and compliance
- Endpoint security policies
- Security baselines
- Disk encryption
- Firewall and antivirus
- ASR and endpoint hardening
- Compliance policies
- Conditional Access integration
- Secure access design patterns

### Updates and servicing
- Windows Autopatch
- Update rings
- Feature updates
- Quality updates
- Driver updates
- Servicing rings
- Rollout sequencing
- User experience considerations
- Patch governance

### Automation and reporting
- Microsoft Graph 
- Scripted PowerShell Automations with Graph
- Configuration export and comparison
- Bulk administration workflows
- Reporting exports
- Compliance and inventory reporting
- Operational dashboards and data pipelines

### Operations
- Drift correction
- Remote actions
- Device recovery procedures
- Offboarding actions
- Standard runbooks
- Repeatable operational tasks

### Advanced and optional capabilities
- Remote support
- Privilege management
- Application catalog workflows
- Certificate management
- Advanced analytics
- Tunnel and related mobility scenarios

## Who this repo is for

This repository is written for people who work with Intune in a serious way, including:

- Intune administrators
- Endpoint engineers
- Cloud engineers
- Security engineers
- Platform architects
- IT operations teams
- Consultants and MSPs

It should be useful whether you are building a new tenant, standardizing an existing one, cleaning up technical debt, or trying to make Intune more supportable at scale.

## Repository principles

A few standards shape how this repo is built:

- **Documentation and artifacts stay together.** If a configuration matters, it should have both the artifact and the explanation behind it.
- **Operational clarity matters.** Every major item should make clear what it does, where it applies, what it depends on, and how to back it out.
- **Reusability matters.** Examples should be sanitized, portable, and easy to adapt.
- **Consistency matters.** Structure, naming, and formatting should be predictable across the repo.
- **Automation is preferred where it improves repeatability.** Especially for reporting, export, comparison, and large-scale administration.
- **Production safety matters.** Nothing here should assume direct use in production without validation.



## Contribution standard

Contributions are welcome, but they should meet a clear standard.

A good contribution should include:

- A clear purpose
- Clean formatting
- Sanitized content
- Environment assumptions
- Assignment or usage notes where relevant
- Validation guidance
- Rollback or recovery guidance when applicable

Do not commit:
- Secrets
- Tokens
- Certificates
- Tenant-specific identifiers
- Hardware hashes
- User data
- Anything pulled directly from production without sanitization

## Long-term goal

The long-term goal is for this repository to become a complete, organized, and practical Microsoft Intune reference that can be used for:

- Learning the platform properly
- Standardizing enterprise deployments
- Reusing proven configurations
- Accelerating administration and support
- Improving consistency across environments
- Reducing dependence on undocumented portal knowledge

In short: one place for Intune documentation, engineering patterns, artifacts, and operational execution.

## Disclaimer

This is an independent repository and is not affiliated with Microsoft.

Everything in this repo should be reviewed, tested, and validated in your own environment before production use.
