<#
.SYNOPSIS
    Scans the repository for secrets, tenant-specific identifiers, and script conventions
    that must never be committed to a public Intune repo.

.DESCRIPTION
    This is the automated half of SECURITY.md. It walks every text file under -Path and
    reports:

      Secrets          private key blocks, GitHub tokens, JWTs, SAS signatures, secret
                       assignments with literal values
      Identifiers      real tenant domains (*.onmicrosoft.com), real e-mail addresses /
                       UPNs, tenant or group object IDs in known JSON keys, device
                       identifiers (serial numbers, IMEI, MAC addresses), Autopilot
                       hardware hashes, CSVs of device identifiers
      Unsanitized      artifacts/**/*.json that still carry id / createdDateTime /
                       lastModifiedDateTime from a raw Graph export
      Script hygiene   non-ASCII bytes or a UTF-8 BOM in .ps1/.psm1/.psd1 (Windows
                       PowerShell 5.1 and Intune's signature check disagree about
                       encodings, so scripts stay pure ASCII), Invoke-Expression,
                       download-and-execute, PSGallery installs inside remediations,
                       execution policy weakening

    Placeholders are recognised and ignored: <TENANT-ID>, {{var}}, $Variable,
    00000000-0000-0000-0000-000000000000, contoso / fabrikam / example domains, and
    values containing PLACEHOLDER, YOUR-, REDACTED, xxxx.

    To suppress a single line that is a documented false positive, put the marker
    sanitize-allow in a comment on that line.

    The script writes findings to the pipeline as objects, so it can be used from tests
    and other tooling. With -FailOnFindings it throws when anything is found, which makes
    a CI step fail.

.PARAMETER Path
    Root directory to scan. Defaults to the current directory.

.PARAMETER FailOnFindings
    Throw a terminating error if one or more findings are reported.

.PARAMETER Exclude
    Additional repo-relative paths or path fragments to skip, in addition to .git,
    node_modules, and this script's own files.

.PARAMETER Quiet
    Suppress the human-readable summary. Findings are still returned as objects.

.EXAMPLE
    ./.github/scripts/Test-RepoSanitized.ps1 -Path . -FailOnFindings

.EXAMPLE
    $findings = ./.github/scripts/Test-RepoSanitized.ps1 -Path ./artifacts -Quiet
    $findings | Group-Object Rule | Sort-Object Count -Descending

.NOTES
    Runs on Windows PowerShell 5.1 and PowerShell 7. No modules required.
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter()]
    [string]$Path = (Get-Location).Path,

    [Parameter()]
    [switch]$FailOnFindings,

    [Parameter()]
    [string[]]$Exclude = @(),

    [Parameter()]
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration

$root = (Resolve-Path -LiteralPath $Path).Path
$suppressMarker = 'sanitize-allow'

$textExtensions = @(
    '.md', '.markdown', '.txt', '.json', '.jsonc', '.yml', '.yaml', '.xml', '.csv', '.tsv',
    '.ps1', '.psm1', '.psd1', '.ps1xml', '.sh', '.cmd', '.bat', '.reg', '.ini', '.cfg', '.conf',
    '.toml', '.mobileconfig', '.plist', '.html', '.htm', '.js', '.ts', '.py', '.sql'
)
$textFileNames = @('LICENSE', 'CODEOWNERS', 'README', 'CONTRIBUTING', 'SECURITY')

# Test files that deliberately build fake identifiers as fixtures are excluded; everything
# else under tests/ is scanned like any other file.
$defaultExcludes = @(
    '.git/',
    'node_modules/',
    '.github/scripts/Test-RepoSanitized.ps1',
    'tests/Test-RepoSanitized.Tests.ps1',
    'tests/ConvertTo-SanitizedIntuneExport.Tests.ps1'
)
$allExcludes = @($defaultExcludes + $Exclude | Where-Object { $_ })

$guidPattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

# Domains that are documentation placeholders by convention.
$placeholderDomains = @(
    'example.com', 'example.org', 'example.net', 'contoso.com', 'fabrikam.com',
    'domain.com', 'yourdomain.com', 'yourcompany.com', 'company.com', 'tenant.com',
    'org.com', 'microsoft.com', 'github.com', 'learn.microsoft.com'
)
$placeholderTenantLabels = @(
    'contoso', 'fabrikam', 'tenant', 'tenantname', 'yourtenant', 'your-tenant', 'mytenant',
    'example', 'yourorg', 'org', 'company', 'yourcompany', 'tenantid', 'tenant-name', 'label'
)

#endregion Configuration

#region Helpers

function Test-IsPlaceholderValue {
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    $v = $Value.Trim()
    if ($v -match '^<[^>]*>$') { return $true }                    # <TENANT-ID>
    if ($v -match '^\{\{.*\}\}$') { return $true }                  # {{ tenant_id }}
    if ($v -match '^\$') { return $true }                           # $TenantId, ${var}, $(expr)
    if ($v -match '^%[^%]+%$') { return $true }                     # %TENANT_ID%
    if ($v -match '^0{8}-0{4}-0{4}-0{4}-0{12}$') { return $true }   # empty GUID
    if ($v -match '(?i)placeholder|your[-_ ]?|example|contoso|fabrikam|redacted|sanitized|xxxx|^null$|^n/?a$|^tbd$|^changeme$|^string$|^value$') { return $true }
    return $false
}

function Test-IsPlaceholderDomain {
    [CmdletBinding()]
    [OutputType([bool])]
    param([string]$Domain)

    $d = $Domain.ToLowerInvariant().TrimEnd('.')
    if ($placeholderDomains -contains $d) { return $true }
    if ($d -match '^(?<label>[a-z0-9-]+)\.onmicrosoft\.com$') {
        return ($placeholderTenantLabels -contains $Matches['label'])
    }
    foreach ($p in $placeholderDomains) {
        if ($d.EndsWith('.' + $p)) { return $true }
    }
    return $false
}

function Get-RedactedText {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Text)

    if ($Text.Length -le 12) { return $Text }
    return ('{0}...({1} chars)' -f $Text.Substring(0, 8), $Text.Length)
}

function Test-IsExcluded {
    [CmdletBinding()]
    [OutputType([bool])]
    param([string]$RelativePath)

    $p = $RelativePath.Replace('\', '/')
    foreach ($ex in $allExcludes) {
        $e = $ex.Replace('\', '/').TrimStart('./')
        if ($e.EndsWith('/')) {
            if ($p.StartsWith($e) -or $p.Contains('/' + $e)) { return $true }
        } elseif ($p -eq $e -or $p.EndsWith('/' + $e)) {
            return $true
        }
    }
    return $false
}

function Test-IsTextFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param([System.IO.FileInfo]$File)

    $ext = $File.Extension.ToLowerInvariant()
    if ($textExtensions -contains $ext) { return $true }
    if ($File.Name.StartsWith('.')) { return $true }
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    if ($textFileNames -contains $baseName.ToUpperInvariant()) { return $true }
    return $false
}

#endregion Helpers

#region Rules
# Each rule: Name, Pattern (regex, evaluated per line), Scope (regex on the repo-relative
# path, or $null for every file), Message, and an optional Validate scriptblock that
# receives the [regex] Match and returns $true when the match is a real finding.

$rules = @(
    @{
        Name     = 'PrivateKeyBlock'
        Pattern  = '-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----'
        Scope    = $null
        Message  = 'Private key material. Rotate the key, then remove it (including from history).'
    },
    @{
        Name     = 'GitHubToken'
        Pattern  = '\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})\b'
        Scope    = $null
        Message  = 'GitHub personal access token. Revoke it in GitHub settings before anything else.'
    },
    @{
        Name     = 'JwtToken'
        Pattern  = '\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}\b'
        Scope    = $null
        Message  = 'JSON Web Token (bearer/access token). Treat as compromised.'
    },
    @{
        Name     = 'AzureSasSignature'
        Pattern  = '(?i)[?&]sig=[A-Za-z0-9%+/=]{40,}'
        Scope    = $null
        Message  = 'Azure Storage SAS signature in a URL.'
    },
    @{
        Name     = 'SecretAssignment'
        # Matches  key = value,  key: value  and the JSON form  "key": "value".
        Pattern  = '(?i)\b(?<key>client[_-]?secret|app[_-]?secret|api[_-]?key|access[_-]?token|refresh[_-]?token|sas[_-]?token|account[_-]?key|connection[_-]?string|password|passwd|pwd|pre[_-]?shared[_-]?key|shared[_-]?secret|proxy[_-]?password|passphrase|psk)\b["'']?\s*[:=]\s*["'']?(?<v>[^\s"''`,;]{12,})'
        Scope    = $null
        Message  = 'Secret assigned as a literal value. Use a placeholder and document the app registration / Key Vault pattern instead.'
        Validate = { param($m) -not (Test-IsPlaceholderValue $m.Groups['v'].Value) }
    },
    @{
        Name     = 'SecretParameterLiteral'
        Pattern  = '(?i)-(?<key>ClientSecret|AccessToken|Password|Secret|Token|ApiKey|SasToken)\s+["''](?<v>[^"'']{12,})["'']'
        Scope    = '\.(ps1|psm1|psd1|md)$'
        Message  = 'Secret passed as a string literal to a cmdlet parameter.'
        Validate = { param($m) -not (Test-IsPlaceholderValue $m.Groups['v'].Value) }
    },
    @{
        Name     = 'HardwareHashOrBinaryBlob'
        Pattern  = '[A-Za-z0-9+/]{800,}={0,2}'
        Scope    = $null
        Message  = 'Very long base64 blob. Autopilot hardware hashes look exactly like this and are device secrets.'
    },
    @{
        Name     = 'TenantDomain'
        # The optional .mail segment is consumed so that the real label is what gets checked, and a
        # match may not start right after '.' or '>' (so <TENANT>.mail.onmicrosoft.com is not flagged).
        Pattern  = '(?i)(?<![\p{L}\p{N}.>-])(?<label>[a-z0-9-]+)(?:\.mail)?\.onmicrosoft\.com\b'
        Scope    = $null
        Message  = 'Real tenant domain. Use contoso.onmicrosoft.com or <TENANT>.onmicrosoft.com.'
        Validate = { param($m) -not ($placeholderTenantLabels -contains $m.Groups['label'].Value.ToLowerInvariant()) }
    },
    @{
        Name     = 'EmailOrUpn'
        # Also matches guest UPNs (name_domain.com#EXT#@tenant), %40-encoded and non-ASCII local parts.
        Pattern  = '(?<local>[\p{L}\p{N}._%+''#-]+)(?:@|%40)(?<domain>[A-Za-z0-9.-]+\.[A-Za-z]{2,})(?![\p{L}\p{N}-])'
        Scope    = $null
        Message  = 'E-mail address / UPN that is not a documented placeholder domain. Use user@contoso.com.'
        Validate = {
            param($m)
            # JSON keys such as definition@odata.bind are not addresses.
            if ($m.Groups['domain'].Value -like 'odata.*') { return $false }
            if (Test-IsPlaceholderDomain $m.Groups['domain'].Value) { return $false }
            return $true
        }
    },
    @{
        Name     = 'TenantObjectIdInJson'
        Pattern  = '"(?<key>tenantId|tenantid|groupId|targetGroupId|azureADDeviceId|azureAdDeviceId|azureActiveDirectoryDeviceId|aadDeviceId|deviceId|managedDeviceId|intuneDeviceId|entraDeviceId|userId|enrolledByUserId|ownerId|principalId|createdByUserId|sourceId|roleScopeTagId|filterId|assignmentFilterId|deviceAndAppManagementAssignmentFilterId|notificationTemplateId|secretReferenceValueId)"\s*:\s*"(?<v>[^"]*)"'
        Scope    = $null
        Message  = 'Tenant-specific object ID in a known key. Replace with a placeholder such as <GROUP-OBJECT-ID> and note what goes there in the doc.'
        Validate = {
            param($m)
            $v = $m.Groups['v'].Value
            return ($v -match ('^' + $guidPattern + '$')) -and -not (Test-IsPlaceholderValue $v)
        }
    },
    @{
        Name     = 'DeviceOrUserIdentifierInJson'
        Pattern  = '"(?<key>userPrincipalName|emailAddress|enrolledByUserPrincipalName|serialNumber|hardwareIdentifier|imei|meid|wifiMacAddress|ethernetMacAddress|macAddress|phoneNumber|iccid|udid|hardwareHash)"\s*:\s*"(?<v>[^"]*)"'
        Scope    = $null
        Message  = 'Device or user identifier in a known key. Replace with a placeholder.'
        Validate = { param($m) -not (Test-IsPlaceholderValue $m.Groups['v'].Value) }
    },
    @{
        Name     = 'UnsanitizedExportMetadata'
        Pattern  = '"(?<key>id|createdDateTime|lastModifiedDateTime|modifiedDateTime|createdBy|lastModifiedBy|supportsScopeTags|settingCount|priorityMetaData|isAssigned)"\s*:\s*(?<v>"[^"]*"|\d+|true|false|null)'
        Scope    = '^artifacts/.*\.json$'
        Message  = 'Raw Graph export metadata in an artifact. Run scripts/powershell/ConvertTo-SanitizedIntuneExport.ps1 on the file before committing.'
        Validate = {
            param($m)
            $key = $m.Groups['key'].Value
            $v = $m.Groups['v'].Value.Trim('"')
            if ($key -eq 'id') { return ($v -match ('^' + $guidPattern + '$')) -and -not (Test-IsPlaceholderValue $v) }
            if ($key -in @('createdDateTime', 'lastModifiedDateTime', 'modifiedDateTime')) { return -not [string]::IsNullOrWhiteSpace($v) -and $v -ne 'null' }
            if ($key -in @('createdBy', 'lastModifiedBy')) { return -not (Test-IsPlaceholderValue $v) }
            return $true
        }
    },
    @{
        Name     = 'InvokeExpression'
        Pattern  = '(?i)(?<![\w-])(Invoke-Expression|iex)(?![\w-])'
        Scope    = '^(scripts|remediations|examples|artifacts)/.*\.(ps1|psm1)$'
        Message  = 'Invoke-Expression in a script that runs on endpoints or against a tenant. Build commands explicitly instead.'
    },
    @{
        Name     = 'DownloadAndExecute'
        Pattern  = '(?i)(DownloadString|DownloadFile|Invoke-WebRequest|iwr|Invoke-RestMethod|irm)\b[^\n]*\|\s*(iex|Invoke-Expression|&\s)'
        Scope    = '^(scripts|remediations|examples|artifacts)/.*\.(ps1|psm1)$'
        Message  = 'Downloads content and executes it. A hijacked URL becomes code execution on every assigned device (see SECURITY.md, supply chain).'
    },
    @{
        Name     = 'GalleryInstallInRemediation'
        Pattern  = '(?i)\b(Install-Module|Install-Script|Install-PackageProvider|Save-Module|Update-Module)\b'
        Scope    = '^remediations/.*\.(ps1|psm1)$'
        Message  = 'Remediations must not pull from the PowerShell Gallery at run time. Package what you need, or detect-and-skip when a module is missing.'
    },
    @{
        Name     = 'ExecutionPolicyWeakening'
        Pattern  = '(?i)Set-ExecutionPolicy\s+(?:-ExecutionPolicy\s+)?(?:Unrestricted|Bypass)\b(?![^\n]*-Scope\s+Process)'
        Scope    = '^(scripts|remediations|examples)/.*\.(ps1|psm1)$'
        Message  = 'Persistently weakens execution policy. The Intune Management Extension already bypasses it for the scripts it runs; a process-scoped change is the most that should ever be needed.'
    }
)

#endregion Rules

#region Scan

$findings = New-Object System.Collections.Generic.List[object]
$scanned = 0

$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

foreach ($file in $files) {
    $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    if (Test-IsExcluded $relative) { continue }
    if (-not (Test-IsTextFile $file)) { continue }

    $scanned++
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $isScript = $file.Extension -in @('.ps1', '.psm1', '.psd1')

    # Script encoding rules work on raw bytes so a BOM or stray UTF-8 is caught exactly.
    if ($isScript) {
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $findings.Add([pscustomobject]@{
                    Rule     = 'ScriptHasBom'
                    File     = $relative
                    Line     = 1
                    Message  = 'UTF-8 BOM at the start of a script. Intune rejects BOM-encoded scripts when signature checks are enforced. Save as ASCII / UTF-8 without BOM.'
                    Match    = 'EF BB BF'
                })
        }
        $lineNo = 1
        $flaggedNonAscii = $false
        for ($i = 0; $i -lt $bytes.Length -and -not $flaggedNonAscii; $i++) {
            if ($bytes[$i] -eq 0x0A) { $lineNo++; continue }
            if ($bytes[$i] -gt 0x7F -and -not ($i -lt 3 -and $bytes[0] -eq 0xEF)) {
                $findings.Add([pscustomobject]@{
                        Rule     = 'NonAsciiInScript'
                        File     = $relative
                        Line     = $lineNo
                        Message  = 'Non-ASCII byte in a PowerShell file. Windows PowerShell 5.1 reads BOM-less files as ANSI and will corrupt it; keep scripts pure ASCII (plain quotes and hyphens, no smart punctuation).'
                        Match    = ('0x{0:X2}' -f $bytes[$i])
                    })
                $flaggedNonAscii = $true
            }
        }
    }

    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $lines = $text -split "`r?`n"

    # CSV files that look like device inventories.
    if ($file.Extension -eq '.csv' -and $lines.Count -gt 0) {
        $header = $lines[0]
        $dataRows = @($lines | Select-Object -Skip 1 | Where-Object { $_.Trim() })
        if ($header -match '(?i)hardware\s*hash|serial\s*number|serialnumber|\bimei\b' -and $dataRows.Count -gt 0) {
            $suppressed = $header -match $suppressMarker
            if (-not $suppressed) {
                $findings.Add([pscustomobject]@{
                        Rule     = 'DeviceIdentifierCsv'
                        File     = $relative
                        Line     = 2
                        Message  = 'CSV with device identifier columns and data rows. Hardware hashes and serial numbers never belong in the repo; commit a header-only sample instead.'
                        Match    = ('{0} data row(s)' -f $dataRows.Count)
                    })
            }
        }
    }

    foreach ($rule in $rules) {
        if ($rule.Scope -and $relative -notmatch $rule.Scope) { continue }
        $regex = [regex]$rule.Pattern
        for ($n = 0; $n -lt $lines.Count; $n++) {
            $line = $lines[$n]
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match $suppressMarker) { continue }
            $matchesInLine = $regex.Matches($line)
            foreach ($m in $matchesInLine) {
                if ($rule.ContainsKey('Validate') -and -not (& $rule.Validate $m)) { continue }
                $findings.Add([pscustomobject]@{
                        Rule     = $rule.Name
                        File     = $relative
                        Line     = $n + 1
                        Message  = $rule.Message
                        Match    = (Get-RedactedText $m.Value)
                    })
            }
        }
    }
}

#endregion Scan

#region Report

if (-not $Quiet) {
    if ($findings.Count -gt 0) {
        $findings | Sort-Object File, Line | Format-Table Rule, File, Line, Match -AutoSize | Out-String -Width 200 | Write-Host
        foreach ($f in $findings) {
            Write-Host ('  {0}:{1}  [{2}] {3}' -f $f.File, $f.Line, $f.Rule, $f.Message)
            if ($env:GITHUB_ACTIONS -eq 'true') {
                Write-Host ('::error file={0},line={1},title={2}::{3}' -f $f.File, $f.Line, $f.Rule, $f.Message)
            }
        }
    }
    Write-Host ('Sanitization guard: scanned {0} file(s), {1} finding(s).' -f $scanned, $findings.Count)
}

$findings | ForEach-Object { $_ }

if ($FailOnFindings -and $findings.Count -gt 0) {
    throw ('Sanitization guard found {0} issue(s). See SECURITY.md for what is allowed and how to use placeholders.' -f $findings.Count)
}

#endregion Report
