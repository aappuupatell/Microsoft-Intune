#Requires -Version 5.1
<#
.SYNOPSIS
    Removes tenant-specific data from Intune policy exports so they can be committed to this repo.

.DESCRIPTION
    Takes one or more JSON files (or folders of JSON files) exported from the Intune admin center
    ("Export JSON" on a Settings Catalog profile) or from Microsoft Graph, and writes sanitized copies.

    Removed everywhere
        createdDateTime, lastModifiedDateTime, modifiedDateTime, version, supportsScopeTags,
        settingCount, priorityMetaData, isAssigned, createdBy, lastModifiedBy, sourceId, physicalIds,
        every *@odata.context, *@odata.count, *@odata.nextLink, *@odata.deltaLink annotation
    Removed when they identify a tenant object
        id when its value is a GUID or contains one (policy ids, assignment ids such as
        <policyId>_<groupId>, enrollment configuration ids such as <tenantId>_Default...).
        Ids of ADMX definitions, presentations and categories are kept: they are global and an
        import needs them.
    Replaced with typed placeholders (see CONTRIBUTING.md)
        groupId, targetGroupId, notificationMessageCCList, *group* ids   -> <GROUP:Display Name> or <GROUP-OBJECT-ID>
        deviceAndAppManagementAssignmentFilterId, filterId              -> <FILTER:Display Name> or <FILTER-ID>
        tenantId                                                        -> <TENANT-ID>
        userId, ownerId, principalId, *user* ids                        -> <USER-OBJECT-ID>
        deviceId, azureADDeviceId, managedDeviceId, *device* ids        -> <DEVICE-ID>
        other *Id keys holding a GUID (apps, policies, templates that are tenant objects) -> <APP-ID>, <POLICY-ID>, <OBJECT-ID>
        userPrincipalName, emailAddress                                 -> <UPN>
        userDisplayName, userName, addressableUserName                  -> <USER-DISPLAY-NAME>
        deviceName, managedDeviceName, computerName, hostName           -> <DEVICE-NAME>
        serialNumber, serial, serialNumbers, deviceSerialNumber         -> <SERIAL>
        hardwareIdentifier, hardwareHash, deviceHardwareData            -> <HARDWARE-HASH>
        imei, meid, MAC addresses, phoneNumber, iccid, udid, productKey, thumbprint -> <IMEI>, <MEID>, <MAC-ADDRESS>, ...
        password, preSharedKey, sharedSecret, clientSecret, apiKey, *Token, *Secret, *Passphrase, psk,
        any value of a *SecretSettingValue, any omaSetting value with isEncrypted = true -> <SECRET>
        secretReferenceValueId                                          -> <SECRET-REFERENCE-ID>
        payload, certificate data and any base64 blob of 200+ characters -> <BASE64-BLOB-REMOVED:n-CHARS>
    Replaced inside any string value (and inside object keys)
        the tenant GUID(s): from -TenantId and from every tenantId key in the file, dashed or not -> <TENANT-ID>
        e-mail addresses / UPNs that are not documentation placeholders (also guest #EXT# and %40 forms) -> <UPN>
        <label>.onmicrosoft.com and <label>.mail.onmicrosoft.com         -> <TENANT>.onmicrosoft.com
        <label>.sharepoint.com, <label>-my.sharepoint.com, /personal/<user> paths -> <TENANT>.sharepoint.com, /personal/<UPN-PATH>
        /groups/<guid>, /users/<guid>, /directoryObjects/<guid>, /devices/<guid> in URLs -> typed placeholders
        MAC addresses, \\server UNC hosts, hosts ending in .local/.corp/.internal/.lan, RFC 1918 IPv4 addresses
    Kept
        displayName, description, settingDefinitionId, templateReference, settingInstanceTemplateReference,
        settingValueTemplateReference, roleScopeTagIds, definition@odata.bind, and every ordinary setting value

    Keys are sorted recursively (ordinal) and the JSON is written with 2-space indentation, LF line
    endings and UTF-8 without BOM by the script's own serializer, so two exports of the same policy
    produce a readable git diff and the output is identical on Windows PowerShell 5.1 and PowerShell 7.
    Sanitizing already-sanitized output changes nothing.

    The script works entirely offline. It never connects to Graph. The optional name map lets
    assignments keep a human-readable group or filter name instead of an opaque placeholder:

        { "groups": { "<GROUP-OBJECT-ID>": "WIN-Ring-R1" }, "filters": { "<FILTER-ID>": "Corporate Windows" } }

    The per-file summary ends with ReviewHints: lines of the output that still contain a GUID or an
    IPv4 address. Those are usually global ids (ASR rule ids, ADMX definitions) but read them before
    you commit. The CI guard (.github/scripts/Test-RepoSanitized.ps1) has the final word.

.PARAMETER Path
    One or more JSON files or folders. Folders are searched recursively for *.json. Files that already
    end in .sanitized.json are skipped when a folder is given, unless -InPlace is used.

.PARAMETER OutputPath
    Folder to write the sanitized files into. For folder input the relative structure is mirrored.
    When omitted (and -InPlace is not used) each output is written next to its input as
    <name>.sanitized.json.

.PARAMETER InPlace
    Overwrite each input file with its sanitized content. Cannot be combined with -OutputPath.

.PARAMETER TenantId
    The source tenant's GUID. Every occurrence inside any string is replaced with <TENANT-ID>. The
    script also learns tenant ids from tenantId keys inside each file, so this is optional when the
    export carries one.

.PARAMETER NameMapPath
    JSON file with "groups" and/or "filters" objects that map object ids to display names. Names may
    not contain <, >, quotes, line breaks or an @ sign.

.PARAMETER RemoveProperty
    Additional property names to remove wherever they occur (case-insensitive).

.PARAMETER KeepProperty
    Property names that must be kept even though the default rules would remove or replace them,
    e.g. 'version'. Use with care: the name is matched everywhere in the document.

.PARAMETER RemoveAssignments
    Drop the assignments array entirely instead of replacing the group and filter ids in it.

.PARAMETER PassThru
    Return the sanitized objects instead of the per-file summary.

.EXAMPLE
    .\ConvertTo-SanitizedIntuneExport.ps1 -Path .\exports\win-bitlocker.json -OutputPath .\artifacts\policies\endpoint-security

    Sanitizes one portal export and writes artifacts\policies\endpoint-security\win-bitlocker.json.

.EXAMPLE
    .\ConvertTo-SanitizedIntuneExport.ps1 -Path .\exports -OutputPath .\artifacts\policies\configuration -TenantId 11111111-2222-3333-4444-555555555555 -NameMapPath .\exports\names.json -WhatIf

    Shows which files would be written for a whole export folder, with group names resolved.

.EXAMPLE
    .\ConvertTo-SanitizedIntuneExport.ps1 -Path .\artifacts -InPlace

    Re-sanitizes everything already committed, in place. Safe to repeat: the output is idempotent.

.NOTES
    Validated: 2026-10 on PowerShell 7.6 with synthetic exports, Pester tests and an adversarial
               review; not yet run against a real tenant export.
    Run as:    any user, offline. No Graph connection and no modules required.
    Exit code: none. The script throws on bad input so it can be used from other scripts and tests.
    Known gaps (the script cannot recognise these; read your output):
               DOMAIN\user account names, employee ids, people's names in display names and
               descriptions, public hostnames that are not .local/.corp/.internal/.lan, IMEI or
               serial numbers typed into free text, GUIDs under keys that do not end in Id (the
               ReviewHints list points at them), base64 blobs under 200 characters.
    Numbers:   fractional numbers are normalized the way PowerShell 7 parses them (1.0 -> 1,
               2.50 -> 2.5) so both PowerShell versions write the same bytes.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string[]]$Path,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$InPlace,

    [Parameter()]
    [string]$TenantId,

    [Parameter()]
    [string]$NameMapPath,

    [Parameter()]
    [string[]]$RemoveProperty = @(),

    [Parameter()]
    [string[]]$KeepProperty = @(),

    [Parameter()]
    [switch]$RemoveAssignments,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Rules

$script:RemovedProperties = @(
    'createdDateTime', 'lastModifiedDateTime', 'modifiedDateTime', 'version', 'supportsScopeTags',
    'settingCount', 'priorityMetaData', 'isAssigned', 'createdBy', 'lastModifiedBy', 'sourceId', 'physicalIds'
)
$script:RemovedPropertySuffixes = @('@odata.context', '@odata.count', '@odata.nextLink', '@odata.deltaLink')

# Objects whose id is a global catalog id, not a tenant object. Matched on the parent key or @odata.type.
$script:GlobalIdParentKeys = @('definition', 'presentation', 'category')
$script:GlobalIdTypePattern = '(?i)groupPolicy(Definition|Presentation|Category|UploadedDefinitionFile)'

# Keys that end in Id but hold global catalog identifiers; never replaced.
$script:KeptIdKeys = @(
    'templateId', 'settingInstanceTemplateId', 'settingValueTemplateId', 'settingDefinitionId', 'definitionId',
    'presentationId', 'categoryId', 'groupPolicyCategoryId', 'settingInstanceId', 'mobileAppIdentifier',
    'bundleId', 'packageId', 'productId', 'skuId', 'appStoreId', 'offerId', 'planId', 'vendorId', 'clientId'
)

$script:GroupIdKeys = @(
    'groupId', 'targetGroupId', 'notificationMessageCCList', 'groupIds', 'includedGroups', 'excludedGroups',
    'includeGroups', 'excludeGroups', 'includeGroupIds', 'excludeGroupIds', 'targetedGroupIds', 'targetGroupIds'
)
$script:FilterIdKeys = @('deviceAndAppManagementAssignmentFilterId', 'filterId', 'assignmentFilterId')

# Keys whose GUID values become a typed placeholder.
$script:GuidPlaceholderByKey = @{
    'tenantId'                     = '<TENANT-ID>'
    'userId'                       = '<USER-OBJECT-ID>'
    'enrolledByUserId'             = '<USER-OBJECT-ID>'
    'ownerId'                      = '<USER-OBJECT-ID>'
    'principalId'                  = '<USER-OBJECT-ID>'
    'createdByUserId'              = '<USER-OBJECT-ID>'
    'members'                      = '<OBJECT-ID>'
    'includeUsers'                 = '<USER-OBJECT-ID>'
    'excludeUsers'                 = '<USER-OBJECT-ID>'
    'deviceId'                     = '<DEVICE-ID>'
    'azureADDeviceId'              = '<DEVICE-ID>'
    'azureActiveDirectoryDeviceId' = '<DEVICE-ID>'
    'aadDeviceId'                  = '<DEVICE-ID>'
    'managedDeviceId'              = '<DEVICE-ID>'
    'intuneDeviceId'               = '<DEVICE-ID>'
    'entraDeviceId'                = '<DEVICE-ID>'
    'notificationTemplateId'       = '<NOTIFICATION-TEMPLATE-ID>'
    'roleScopeTagId'               = '<ROLE-SCOPE-TAG-ID>'
    'secretReferenceValueId'       = '<SECRET-REFERENCE-ID>'
}

# Keys whose non-empty string values become a typed placeholder regardless of shape.
$script:ValuePlaceholderByKey = @{
    'userPrincipalName'           = '<UPN>'
    'emailAddress'                = '<UPN>'
    'enrolledByUserPrincipalName' = '<UPN>'
    'ownerUserPrincipalName'      = '<UPN>'
    'userDisplayName'             = '<USER-DISPLAY-NAME>'
    'enrolledByUserDisplayName'   = '<USER-DISPLAY-NAME>'
    'addressableUserName'         = '<USER-DISPLAY-NAME>'
    'userName'                    = '<USER-DISPLAY-NAME>'
    'deviceName'                  = '<DEVICE-NAME>'
    'managedDeviceName'           = '<DEVICE-NAME>'
    'computerName'                = '<DEVICE-NAME>'
    'hostName'                    = '<DEVICE-NAME>'
    'serialNumber'                = '<SERIAL>'
    'serial'                      = '<SERIAL>'
    'serialNumbers'               = '<SERIAL>'
    'deviceSerialNumber'          = '<SERIAL>'
    'hardwareIdentifier'          = '<HARDWARE-HASH>'
    'hardwareHash'                = '<HARDWARE-HASH>'
    'deviceHardwareData'          = '<HARDWARE-HASH>'
    'imei'                        = '<IMEI>'
    'meid'                        = '<MEID>'
    'wifiMacAddress'              = '<MAC-ADDRESS>'
    'ethernetMacAddress'          = '<MAC-ADDRESS>'
    'macAddress'                  = '<MAC-ADDRESS>'
    'phoneNumber'                 = '<PHONE-NUMBER>'
    'iccid'                       = '<ICCID>'
    'udid'                        = '<UDID>'
    'productKey'                  = '<PRODUCT-KEY>'
    'thumbprint'                  = '<CERT-THUMBPRINT>'
    'certificateThumbprint'       = '<CERT-THUMBPRINT>'
    'secretReferenceValueId'      = '<SECRET-REFERENCE-ID>'
}

$script:SecretKeys = @(
    'password', 'passwordValue', 'preSharedKey', 'sharedSecret', 'proxyPassword', 'clientSecret', 'secret',
    'apiKey', 'accessToken', 'refreshToken', 'bearerToken', 'sasToken', 'connectionString', 'passphrase',
    'psk', 'privateKey', 'encryptionKey', 'recoveryKey', 'recoveryPassword'
)
$script:SecretKeySuffixPattern = '(?i)(password|secret|passphrase|token|apikey|psk)$'

$script:BlobKeys = @(
    'payload', 'trustedRootCertificate', 'rootCertificate', 'certificate', 'encodedCertificate',
    'certificateData', 'rawData', 'pfxBlob', 'blob'
)
$script:BlobMinLength = 200

$script:GuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$script:GuidAnywherePattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
$script:EmptyGuid = '00000000-0000-0000-0000-000000000000'

$script:PlaceholderTenantLabels = @(
    'contoso', 'fabrikam', 'tenant', 'tenantname', 'yourtenant', 'your-tenant', 'mytenant',
    'example', 'yourorg', 'org', 'company', 'yourcompany', 'tenant-name', 'label'
)
$script:PlaceholderEmailDomains = @(
    'example.com', 'example.org', 'example.net', 'contoso.com', 'fabrikam.com', 'domain.com',
    'yourdomain.com', 'yourcompany.com', 'company.com', 'tenant.com', 'microsoft.com'
)

#endregion Rules

#region Helpers

function Test-IsGuidValue {
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $false }
    if ($Value -is [guid]) { return $true }
    if ($Value -isnot [string]) { return $false }
    $v = $Value.Trim().Trim('{', '}')
    return ($v -match $script:GuidPattern)
}

function Test-IsPlaceholderText {
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    $v = $Value.Trim()
    if ($v -match '^<[^>]*>$') { return $true }
    if ($v -match '^\{\{.*\}\}$') { return $true }
    if ($v -eq $script:EmptyGuid) { return $true }
    return $false
}

function Test-IsPlaceholderDomain {
    [CmdletBinding()]
    [OutputType([bool])]
    param([string]$Domain)

    $d = $Domain.ToLowerInvariant().TrimEnd('.')
    # JSON keys such as definition@odata.bind look like e-mail addresses; they are not.
    if ($d.StartsWith('odata.')) { return $true }
    if ($script:PlaceholderEmailDomains -contains $d) { return $true }
    foreach ($p in $script:PlaceholderEmailDomains) {
        if ($d.EndsWith('.' + $p)) { return $true }
    }
    if ($d -match '^(?<label>[a-z0-9-]+)(\.mail)?\.onmicrosoft\.com$') {
        if ($script:PlaceholderTenantLabels -contains $Matches['label']) { return $true }
    }
    return $false
}

function Initialize-SanitizeContext {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$TenantId,
        [hashtable]$GroupNames,
        [hashtable]$FilterNames,
        [string[]]$RemoveProperty,
        [string[]]$KeepProperty,
        [switch]$RemoveAssignments
    )

    $remove = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $script:RemovedProperties) { [void]$remove.Add($p) }
    foreach ($p in $RemoveProperty) { if ($p) { [void]$remove.Add($p) } }

    $keep = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $KeepProperty) { if ($p) { [void]$keep.Add($p) } }

    $groups = @{}
    if ($GroupNames) { foreach ($k in $GroupNames.Keys) { $groups[[string]$k] = [string]$GroupNames[$k] } }
    $filters = @{}
    if ($FilterNames) { foreach ($k in $FilterNames.Keys) { $filters[[string]$k] = [string]$FilterNames[$k] } }

    $tenantIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if ($TenantId) { [void]$tenantIds.Add($TenantId.Trim().Trim('{', '}')) }

    return @{
        TenantIds         = $tenantIds
        Groups            = $groups
        Filters           = $filters
        Remove            = $remove
        Keep              = $keep
        RemoveAssignments = [bool]$RemoveAssignments
        Stats             = @{ PropertiesRemoved = 0; ValuesReplaced = 0 }
        Placeholders      = New-Object 'System.Collections.Generic.HashSet[string]'
    }
}

function Add-Replacement {
    [CmdletBinding()]
    param([hashtable]$Context, [string]$Placeholder)

    $Context.Stats.ValuesReplaced++
    [void]$Context.Placeholders.Add($Placeholder)
}

function Add-TenantIdFromObject {
    # First pass: learn tenant ids from tenantId keys anywhere in the document.
    [CmdletBinding()]
    param([AllowNull()][object]$Value, [hashtable]$Context)

    if ($null -eq $Value) { return }
    if ($Value -is [string]) { return }
    if (Test-IsObjectLike $Value) {
        foreach ($pair in (Get-ObjectPair -Object $Value)) {
            if ($pair.Key -eq 'tenantId' -and (Test-IsGuidValue $pair.Value) -and $pair.Value -ne $script:EmptyGuid) {
                [void]$Context.TenantIds.Add(([string]$pair.Value).Trim().Trim('{', '}'))
            } else {
                Add-TenantIdFromObject -Value $pair.Value -Context $Context
            }
        }
        return
    }
    if (Test-IsArrayLike $Value) {
        foreach ($item in $Value) { Add-TenantIdFromObject -Value $item -Context $Context }
    }
}

function Get-TypedGuidPlaceholder {
    # Placeholder for a GUID under a key the rules do not list explicitly, chosen from the key name.
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Key)

    if ($Key -match '(?i)group') { return '<GROUP-OBJECT-ID>' }
    if ($Key -match '(?i)(user|owner|principal|createdby|modifiedby)') { return '<USER-OBJECT-ID>' }
    if ($Key -match '(?i)device') { return '<DEVICE-ID>' }
    if ($Key -match '(?i)filter') { return '<FILTER-ID>' }
    if ($Key -match '(?i)app') { return '<APP-ID>' }
    if ($Key -match '(?i)(polic|profile|configuration|intent|script|rule|assignment|baseline)') { return '<POLICY-ID>' }
    return '<OBJECT-ID>'
}

function Convert-TextRule {
    # Applies a regex to $Text, replacing each match for which $Test returns $true (or every match
    # when no $Test is given) with $Replacement (a string, or a scriptblock receiving the match),
    # and counts replacements.
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][string]$Text,
        [regex]$Regex,
        [AllowNull()][scriptblock]$Test,
        [object]$Replacement,
        [hashtable]$Context
    )

    $found = $Regex.Matches($Text)
    if ($found.Count -eq 0) { return $Text }
    $builder = New-Object System.Text.StringBuilder
    $last = 0
    foreach ($m in $found) {
        [void]$builder.Append($Text.Substring($last, $m.Index - $last))
        if ($null -eq $Test -or (& $Test $m)) {
            $replacementText = [string]$Replacement
            if ($Replacement -is [scriptblock]) { $replacementText = [string](& $Replacement $m) }
            [void]$builder.Append($replacementText)
            Add-Replacement -Context $Context -Placeholder ($replacementText -replace '^.*?(<[^>]+>).*$', '$1')
        } else {
            [void]$builder.Append($m.Value)
        }
        $last = $m.Index + $m.Length
    }
    [void]$builder.Append($Text.Substring($last))
    return $builder.ToString()
}

function ConvertTo-SanitizedText {
    # The free-text rules, applied to every string value and every object key.
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowEmptyString()][string]$Value, [hashtable]$Context)

    if ([string]::IsNullOrEmpty($Value)) { return $Value }
    $result = $Value

    # 1. Tenant GUIDs, dashed (any case) and dash-less.
    foreach ($tid in $Context.TenantIds) {
        if ($result.IndexOf($tid, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $result = [regex]::Replace($result, [regex]::Escape($tid), '<TENANT-ID>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            Add-Replacement -Context $Context -Placeholder '<TENANT-ID>'
        }
        $bare = $tid.Replace('-', '')
        if ($result.IndexOf($bare, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $result = [regex]::Replace($result, [regex]::Escape($bare), '<TENANT-ID>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            Add-Replacement -Context $Context -Placeholder '<TENANT-ID>'
        }
    }

    # 2. E-mail addresses / UPNs, including guest (#EXT#), %40-encoded and non-ASCII forms. Runs before
    #    the domain rules so user@tenant.onmicrosoft.com is replaced as a whole.
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'(?<local>[\p{L}\p{N}._%+''#-]+)(?:@|%40)(?<domain>[A-Za-z0-9.-]+\.[A-Za-z]{2,})(?![\p{L}\p{N}-])') `
        -Test { param($m) -not (Test-IsPlaceholderDomain $m.Groups['domain'].Value) } `
        -Replacement '<UPN>'

    # 3. Tenant domains: label.onmicrosoft.com and label.mail.onmicrosoft.com.
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'(?i)(?<![\p{L}\p{N}.>-])(?<label>[a-z0-9][a-z0-9-]*)(?<mail>\.mail)?\.onmicrosoft\.com\b') `
        -Test { param($m) -not ($script:PlaceholderTenantLabels -contains $m.Groups['label'].Value.ToLowerInvariant()) } `
        -Replacement '<TENANT>.onmicrosoft.com'

    # 4. SharePoint hosts and personal-site paths.
    $sharePointReplacement = { param($m) '<TENANT>' + $m.Groups['suffix'].Value + '.sharepoint.com' }
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'(?i)(?<![\p{L}\p{N}-])(?<label>[a-z0-9][a-z0-9-]*?)(?<suffix>-my|-admin)?\.sharepoint\.com\b') `
        -Test { param($m) -not ($script:PlaceholderTenantLabels -contains $m.Groups['label'].Value.ToLowerInvariant()) } `
        -Replacement $sharePointReplacement
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'(?i)(?<=/personal/)[^/\s"<>]+') `
        -Test { param($m) -not (Test-IsPlaceholderText $m.Value) } `
        -Replacement '<UPN-PATH>'

    # 5. Directory object ids inside Graph URLs (@odata.bind, @odata.id, navigation links).
    $objectIdReplacement = {
        param($m)
        $kind = $m.Groups['kind'].Value.ToLowerInvariant()
        if ($kind -eq 'groups') {
            if ($Context.Groups.ContainsKey($m.Value)) { return ('<GROUP:' + $Context.Groups[$m.Value] + '>') }
            return '<GROUP-OBJECT-ID>'
        }
        if ($kind -eq 'users') { return '<USER-OBJECT-ID>' }
        if ($kind -eq 'devices') { return '<DEVICE-ID>' }
        if ($kind -eq 'serviceprincipals') { return '<APP-ID>' }
        return '<OBJECT-ID>'
    }
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]('(?i)(?<=/(?<kind>groups|users|directoryObjects|devices|servicePrincipals)/)' + $script:GuidAnywherePattern)) `
        -Test { param($m) $m.Value -ne $script:EmptyGuid } `
        -Replacement $objectIdReplacement

    # 6. MAC addresses.
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b') `
        -Replacement '<MAC-ADDRESS>'

    # 7. UNC hosts.
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'(?<=\\\\)[^\\\s"<>]+') `
        -Test { param($m) -not (Test-IsPlaceholderText $m.Value) } `
        -Replacement '<SERVER>'

    # 8. Internal hostnames.
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'(?i)(?<![\p{L}\p{N}.-])[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:local|corp|internal|lan|intra)\b') `
        -Replacement '<HOSTNAME>'

    # 9. RFC 1918 IPv4 addresses.
    $result = Convert-TextRule -Text $result -Context $Context `
        -Regex ([regex]'\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b') `
        -Replacement '<IP-ADDRESS>'

    return $result
}

function Test-IsBase64Blob {
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowEmptyString()][string]$Value, [int]$MinLength)

    if ($Value.Length -lt $MinLength) { return $false }
    return ($Value -match '^[A-Za-z0-9+/\r\n]+={0,2}$')
}

function ConvertTo-SanitizedString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][string]$Value,
        [AllowEmptyString()][string]$Key,
        [hashtable]$Context,
        [switch]$Secret
    )

    if ([string]::IsNullOrEmpty($Value)) { return $Value }
    if (Test-IsPlaceholderText $Value) { return $Value }

    if ($Key -and $Context.Keep.Contains($Key)) {
        return (ConvertTo-SanitizedText -Value $Value -Context $Context)
    }

    # Secret values: by container (passed in by the caller) or by key name.
    if ($Secret -or ($Key -and ($script:SecretKeys -contains $Key -or $Key -match $script:SecretKeySuffixPattern))) {
        Add-Replacement -Context $Context -Placeholder '<SECRET>'
        return '<SECRET>'
    }

    if ($Key) {
        $bareGuid = $Value.Trim().Trim('{', '}')
        $isGuid = (Test-IsGuidValue $Value) -and $bareGuid -ne $script:EmptyGuid

        if ($isGuid -and $script:GroupIdKeys -contains $Key) {
            $placeholder = '<GROUP-OBJECT-ID>'
            if ($Context.Groups.ContainsKey($bareGuid)) { $placeholder = '<GROUP:' + $Context.Groups[$bareGuid] + '>' }
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
        if ($isGuid -and $script:FilterIdKeys -contains $Key) {
            $placeholder = '<FILTER-ID>'
            if ($Context.Filters.ContainsKey($bareGuid)) { $placeholder = '<FILTER:' + $Context.Filters[$bareGuid] + '>' }
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
        if ($isGuid -and $script:GuidPlaceholderByKey.ContainsKey($Key)) {
            $placeholder = $script:GuidPlaceholderByKey[$Key]
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
        if ($script:ValuePlaceholderByKey.ContainsKey($Key)) {
            $placeholder = $script:ValuePlaceholderByKey[$Key]
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
        if ($script:BlobKeys -contains $Key -and (Test-IsBase64Blob -Value $Value -MinLength 16)) {
            $placeholder = '<BASE64-BLOB-REMOVED:' + $Value.Length + '-CHARS>'
            Add-Replacement -Context $Context -Placeholder '<BASE64-BLOB-REMOVED>'
            return $placeholder
        }
        # Any other key that ends in Id/Ids or names a group, user, device, app or filter and holds a
        # GUID is a tenant object reference unless listed as global.
        if ($isGuid -and $Key -match '(?i)(ids?$|group|user|device|app|filter|owner|principal|member)' -and -not ($script:KeptIdKeys -contains $Key)) {
            $placeholder = Get-TypedGuidPlaceholder -Key $Key
            if ($placeholder -eq '<GROUP-OBJECT-ID>' -and $Context.Groups.ContainsKey($bareGuid)) { $placeholder = '<GROUP:' + $Context.Groups[$bareGuid] + '>' }
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
    }

    if (Test-IsBase64Blob -Value $Value -MinLength $script:BlobMinLength) {
        $placeholder = '<BASE64-BLOB-REMOVED:' + $Value.Length + '-CHARS>'
        Add-Replacement -Context $Context -Placeholder '<BASE64-BLOB-REMOVED>'
        return $placeholder
    }

    return (ConvertTo-SanitizedText -Value $Value -Context $Context)
}

function Get-ObjectPair {
    # Returns @(@{Key=..;Value=..}) for a PSCustomObject or IDictionary, in source order.
    [CmdletBinding()]
    [OutputType([object[]])]
    param([object]$Object)

    $pairs = New-Object System.Collections.Generic.List[object]
    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($k in $Object.Keys) { $pairs.Add(@{ Key = [string]$k; Value = $Object[$k] }) }
    } else {
        foreach ($p in $Object.PSObject.Properties) { $pairs.Add(@{ Key = [string]$p.Name; Value = $p.Value }) }
    }
    return , $pairs.ToArray()
}

function Test-IsObjectLike {
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $false }
    if ($Value -is [System.Collections.IDictionary]) { return $true }
    if ($Value -is [System.Management.Automation.PSCustomObject]) { return $true }
    return $false
}

function Test-IsArrayLike {
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return $false }
    if ($Value -is [System.Collections.IDictionary]) { return $false }
    if ($Value -is [System.Management.Automation.PSCustomObject]) { return $false }
    return ($Value -is [System.Collections.IEnumerable])
}

function ConvertTo-SanitizedValue {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Value,
        [AllowEmptyString()][string]$Key,
        [hashtable]$Context,
        [switch]$Secret
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) { return (ConvertTo-SanitizedString -Value $Value -Key $Key -Context $Context -Secret:$Secret) }
    if (Test-IsObjectLike $Value) { return (ConvertTo-SanitizedObject -Object $Value -Context $Context -ParentKey $Key) }
    if (Test-IsArrayLike $Value) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $Value) {
            $items.Add((ConvertTo-SanitizedValue -Value $item -Key $Key -Context $Context -Secret:$Secret))
        }
        return , $items.ToArray()
    }
    return $Value
}

function ConvertTo-SanitizedObject {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [object]$Object,
        [hashtable]$Context,
        [AllowEmptyString()][string]$ParentKey = ''
    )

    $pairs = Get-ObjectPair -Object $Object
    $byKey = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
    foreach ($pair in $pairs) { $byKey[$pair.Key] = $pair.Value }
    $keys = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in $byKey.Keys) { $keys.Add($k) }
    $keys.Sort([System.StringComparer]::Ordinal)

    # Object-level facts that change how members are treated.
    $odataType = ''
    if ($byKey.ContainsKey('@odata.type') -and $byKey['@odata.type'] -is [string]) { $odataType = $byKey['@odata.type'] }
    $isSecretContainer = ($odataType -match '(?i)SecretSettingValue$')
    if ($byKey.ContainsKey('isEncrypted') -and $byKey['isEncrypted'] -is [bool] -and $byKey['isEncrypted']) { $isSecretContainer = $true }
    $keepsGlobalId = ($script:GlobalIdParentKeys -contains $ParentKey) -or ($odataType -match $script:GlobalIdTypePattern)

    $result = New-Object System.Collections.Specialized.OrderedDictionary ([System.StringComparer]::Ordinal)

    foreach ($key in $keys) {
        $value = $byKey[$key]
        $keep = $Context.Keep.Contains($key)

        if (-not $keep) {
            $drop = $false
            if ($Context.Remove.Contains($key)) { $drop = $true }
            foreach ($suffix in $script:RemovedPropertySuffixes) {
                if ($key.EndsWith($suffix, [System.StringComparison]::OrdinalIgnoreCase)) { $drop = $true }
            }
            if ($key -eq 'id' -and -not $keepsGlobalId -and $value -is [string] -and $value -match $script:GuidAnywherePattern) { $drop = $true }
            if ($key -eq 'id' -and -not $keepsGlobalId -and $value -is [guid]) { $drop = $true }
            if ($Context.RemoveAssignments -and $key -eq 'assignments') { $drop = $true }
            if ($drop) {
                $Context.Stats.PropertiesRemoved++
                continue
            }
        }

        $secretMember = $isSecretContainer -and ($key -eq 'value')
        $outKey = ConvertTo-SanitizedText -Value $key -Context $Context
        # A kept global id must not fall into the key-driven GUID rules either.
        $ruleKey = $key
        if ($keepsGlobalId -and $key -eq 'id') { $ruleKey = '' }
        $result[$outKey] = ConvertTo-SanitizedValue -Value $value -Key $ruleKey -Context $Context -Secret:$secretMember
    }

    return $result
}

function Format-JsonString {
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowEmptyString()][string]$Value)

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
        $code = [int]$ch
        # Branch on the code point. A switch on the char itself compares culture-sensitively and
        # treats soft hyphens, zero-width characters and control characters as equal to "`b".
        if ($code -eq 0x22) { [void]$sb.Append('\"') }
        elseif ($code -eq 0x5C) { [void]$sb.Append('\\') }
        elseif ($code -eq 0x0A) { [void]$sb.Append('\n') }
        elseif ($code -eq 0x0D) { [void]$sb.Append('\r') }
        elseif ($code -eq 0x09) { [void]$sb.Append('\t') }
        elseif ($code -eq 0x08) { [void]$sb.Append('\b') }
        elseif ($code -eq 0x0C) { [void]$sb.Append('\f') }
        elseif ($code -lt 0x20 -or $code -eq 0x7F) { [void]$sb.Append('\u' + $code.ToString('x4')) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Format-JsonDate {
    [CmdletBinding()]
    [OutputType([string])]
    param([datetime]$Value)

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Value.Kind -eq [System.DateTimeKind]::Local) { $Value = $Value.ToUniversalTime() }
    if ($Value.Kind -eq [System.DateTimeKind]::Utc) {
        return $Value.ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFFZ', $inv)
    }
    return $Value.ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFF', $inv)
}

function ConvertTo-StableJson {
    # Deterministic serializer: 2-space indent, keys in the order the OrderedDictionary holds them,
    # identical output on Windows PowerShell 5.1 and PowerShell 7 (ConvertTo-Json differs between them).
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()][object]$Value,
        [int]$Depth = 0
    )

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $pad = '  ' * $Depth
    $padIn = '  ' * ($Depth + 1)

    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string]) { return (Format-JsonString -Value $Value) }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [datetime]) { return ('"' + (Format-JsonDate -Value $Value) + '"') }
    if ($Value -is [System.DateTimeOffset]) { return ('"' + $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFFZ', $inv) + '"') }
    if ($Value -is [guid]) { return ('"' + $Value.ToString() + '"') }
    if ($Value -is [char]) { return (Format-JsonString -Value ([string]$Value)) }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        $d = [double]$Value
        if ($d -eq 0) { return '0' }
        return $d.ToString('R', $inv)
    }
    if ($Value -is [System.ValueType]) { return $Value.ToString($inv) }

    if (Test-IsObjectLike $Value) {
        $pairs = Get-ObjectPair -Object $Value
        if ($pairs.Count -eq 0) { return '{}' }
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($pair in $pairs) {
            $lines.Add($padIn + (Format-JsonString -Value $pair.Key) + ': ' + (ConvertTo-StableJson -Value $pair.Value -Depth ($Depth + 1)))
        }
        return "{`n" + ($lines -join ",`n") + "`n" + $pad + '}'
    }

    if (Test-IsArrayLike $Value) {
        $items = @($Value)
        if ($items.Count -eq 0) { return '[]' }
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($item in $items) {
            $lines.Add($padIn + (ConvertTo-StableJson -Value $item -Depth ($Depth + 1)))
        }
        return "[`n" + ($lines -join ",`n") + "`n" + $pad + ']'
    }

    return (Format-JsonString -Value ([string]$Value))
}

function ConvertFrom-JsonText {
    # ConvertFrom-Json with the same result on every PowerShell version: strings stay strings
    # (PowerShell 7 would turn ISO 8601 dates into DateTime), and a top-level array stays an array.
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Text)

    $params = (Get-Command ConvertFrom-Json).Parameters
    $splat = @{}
    if ($params.ContainsKey('DateKind')) { $splat['DateKind'] = 'String' }
    if ($params.ContainsKey('NoEnumerate')) { $splat['NoEnumerate'] = $true }
    if ($params.ContainsKey('Depth')) { $splat['Depth'] = 100 }
    $parsed = $Text | ConvertFrom-Json @splat
    if ($null -eq $parsed -and $Text.TrimStart().StartsWith('[')) { return , @() }
    return , $parsed
}

function Read-JsonFile {
    [CmdletBinding()]
    param([string]$FilePath)

    $raw = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "File is empty: $FilePath" }
    return , (ConvertFrom-JsonText -Text $raw)
}

function Read-NameMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string]$FilePath)

    $map = @{ Groups = @{}; Filters = @{} }
    if (-not $FilePath) { return $map }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "Name map file not found: $FilePath" }
    $resolved = (Resolve-Path -LiteralPath $FilePath).ProviderPath

    $obj = Read-JsonFile -FilePath $resolved
    if (-not (Test-IsObjectLike $obj)) { throw "Name map must be a JSON object with 'groups' and/or 'filters': $FilePath" }
    foreach ($section in @('groups', 'filters')) {
        $sectionValue = $null
        foreach ($pair in (Get-ObjectPair -Object $obj)) { if ($pair.Key -eq $section) { $sectionValue = $pair.Value } }
        if ($null -eq $sectionValue) { continue }
        if (-not (Test-IsObjectLike $sectionValue)) { throw "Name map section '$section' must be an object of id -> display name." }
        $target = $map.Groups
        if ($section -eq 'filters') { $target = $map.Filters }
        foreach ($pair in (Get-ObjectPair -Object $sectionValue)) {
            $id = ([string]$pair.Key).Trim()
            $name = [string]$pair.Value
            if (-not (Test-IsGuidValue $id)) { throw "Name map '$section' key is not a GUID: '$id'" }
            if ([string]::IsNullOrWhiteSpace($name)) { throw "Name map '$section' entry '$id' has an empty name." }
            if ($name -match '[<>"\r\n\t@]') { throw "Name map '$section' entry '$id' contains a character that is not allowed in a placeholder (< > quote line break @): '$name'" }
            if ($name -match ('(?i)\.onmicrosoft\.com|' + $script:GuidAnywherePattern)) { throw "Name map '$section' entry '$id' looks tenant-specific: '$name'" }
            $target[$id.Trim('{', '}')] = $name.Trim()
        }
    }
    return $map
}

function Get-InputFileList {
    [CmdletBinding()]
    [OutputType([object[]])]
    param([string[]]$Path, [switch]$InPlace)

    $list = New-Object System.Collections.Generic.List[object]
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Path not found: $p" }
        $item = Get-Item -LiteralPath $p
        if ($item.PSIsContainer) {
            $root = $item.FullName
            Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.json' | Sort-Object FullName | ForEach-Object {
                if (-not $InPlace -and $_.Name.EndsWith('.sanitized.json', [System.StringComparison]::OrdinalIgnoreCase)) { return }
                $list.Add(@{ File = $_; Root = $root })
            }
        } else {
            $list.Add(@{ File = $item; Root = $item.DirectoryName })
        }
    }
    return , $list.ToArray()
}

function Get-OutputFilePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [System.IO.FileInfo]$File,
        [string]$Root,
        [string]$OutputPath,
        [switch]$InPlace
    )

    if ($InPlace) { return $File.FullName }
    if ($OutputPath) {
        $relative = $File.FullName.Substring($Root.Length).TrimStart('\', '/')
        return (Join-Path $OutputPath $relative)
    }
    $base = $File.Name.Substring(0, $File.Name.Length - $File.Extension.Length)
    return (Join-Path $File.DirectoryName ($base + '.sanitized.json'))
}

function Get-ReviewHint {
    # Lines of the sanitized output that still contain a GUID or an IPv4 address.
    [CmdletBinding()]
    [OutputType([string[]])]
    param([string]$Json)

    $hints = New-Object System.Collections.Generic.List[string]
    $lines = $Json -split "`n"
    for ($i = 0; $i -lt $lines.Count -and $hints.Count -lt 25; $i++) {
        $line = $lines[$i]
        $why = @()
        if ($line -match $script:GuidAnywherePattern) { $why += 'GUID' }
        if ($line -match '\b(?:\d{1,3}\.){3}\d{1,3}\b') { $why += 'IPv4' }
        if ($why.Count -gt 0) {
            $hints.Add(('line {0} ({1}): {2}' -f ($i + 1), ($why -join ', '), $line.Trim()))
        }
    }
    return $hints.ToArray()
}

#endregion Helpers

#region Main

if ($MyInvocation.InvocationName -ne '.') {

    if (-not $Path -or $Path.Count -eq 0) { throw 'Specify -Path: one or more JSON files or folders.' }
    if ($InPlace -and $OutputPath) { throw '-InPlace and -OutputPath cannot be combined.' }
    if ($TenantId -and -not (Test-IsGuidValue $TenantId)) { throw "-TenantId must be a GUID, got '$TenantId'." }

    # .NET file APIs resolve relative paths against the process directory, not PowerShell's location.
    if ($OutputPath) { $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath) }

    $nameMap = Read-NameMap -FilePath $NameMapPath
    $inputs = Get-InputFileList -Path $Path -InPlace:$InPlace
    if ($inputs.Count -eq 0) { Write-Warning 'No JSON files found.'; return }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    foreach ($entry in $inputs) {
        $file = $entry.File
        $context = Initialize-SanitizeContext -TenantId $TenantId -GroupNames $nameMap.Groups -FilterNames $nameMap.Filters `
            -RemoveProperty $RemoveProperty -KeepProperty $KeepProperty -RemoveAssignments:$RemoveAssignments

        $data = Read-JsonFile -FilePath $file.FullName
        Add-TenantIdFromObject -Value $data -Context $context
        $sanitized = ConvertTo-SanitizedValue -Value $data -Key '' -Context $context
        $json = (ConvertTo-StableJson -Value $sanitized) + "`n"

        $destination = Get-OutputFilePath -File $file -Root $entry.Root -OutputPath $OutputPath -InPlace:$InPlace

        if ($PSCmdlet.ShouldProcess($destination, 'Write sanitized JSON')) {
            $destinationDir = Split-Path -Parent $destination
            if ($destinationDir -and -not (Test-Path -LiteralPath $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }
            [System.IO.File]::WriteAllText($destination, $json, $utf8NoBom)
        }

        if ($PassThru) {
            $sanitized
        } else {
            [pscustomobject]@{
                Source            = $file.FullName
                Destination       = $destination
                PropertiesRemoved = $context.Stats.PropertiesRemoved
                ValuesReplaced    = $context.Stats.ValuesReplaced
                Placeholders      = @($context.Placeholders | Sort-Object)
                ReviewHints       = @(Get-ReviewHint -Json $json)
            }
        }
    }
}

#endregion Main
