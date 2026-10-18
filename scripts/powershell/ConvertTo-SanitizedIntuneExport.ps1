#Requires -Version 5.1
<#
.SYNOPSIS
    Removes tenant-specific data from Intune policy exports so they can be committed to this repo.

.DESCRIPTION
    Takes one or more JSON files (or folders of JSON files) exported from the Intune admin center
    ("Export JSON" on a Settings Catalog profile) or from Microsoft Graph, and writes sanitized copies:

      Removed everywhere      createdDateTime, lastModifiedDateTime, modifiedDateTime, version,
                              supportsScopeTags, settingCount, priorityMetaData, isAssigned, createdBy,
                              lastModifiedBy, @odata.context, *@odata.count, *@odata.nextLink
      Removed when a GUID     id   (object ids are tenant-specific; setting ids like "0" are kept)
      Replaced                groupId / targetGroupId        -> <GROUP:Display Name> or <GROUP-OBJECT-ID>
                              deviceAndAppManagementAssignmentFilterId -> <FILTER:Display Name> or <FILTER-ID>
                              tenantId                        -> <TENANT-ID>
                              userId, enrolledByUserId        -> <USER-OBJECT-ID>
                              deviceId, azureADDeviceId, managedDeviceId, ... -> <DEVICE-ID>
                              userPrincipalName, emailAddress -> <UPN>
                              serialNumber, hardwareIdentifier, imei, meid, MAC addresses, phoneNumber,
                              iccid, udid                     -> <SERIAL>, <HARDWARE-HASH>, <IMEI>, ...
      Replaced inside any string   the tenant GUID given with -TenantId -> <TENANT-ID>
                                   e-mail addresses that are not documentation placeholders -> <UPN>
                                   <label>.onmicrosoft.com that is not a placeholder -> <TENANT>.onmicrosoft.com
      Kept                    displayName, description, settingDefinitionId, templateReference,
                              settingInstanceTemplateReference, roleScopeTagIds, and every setting value

    Keys are sorted recursively and the JSON is written with 2-space indentation, LF line endings and
    UTF-8 without BOM, so two exports of the same policy produce a readable git diff.

    The script works entirely offline. It never connects to Graph. The optional name map file lets
    assignments keep a human-readable group or filter name instead of an opaque placeholder:

        { "groups": { "<GROUP-OBJECT-ID>": "WIN-Ring-R1" }, "filters": { "<FILTER-ID>": "Corporate Windows" } }

    The result is what the CI sanitization guard (.github/scripts/Test-RepoSanitized.ps1) expects to
    find under artifacts/. Run the guard after sanitizing; it catches what this script cannot know
    about, such as an internal hostname in a description.

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
    The source tenant's GUID. Every occurrence inside any string value is replaced with <TENANT-ID>.

.PARAMETER NameMapPath
    JSON file with "groups" and/or "filters" objects that map object ids to display names.

.PARAMETER RemoveProperty
    Additional property names to remove wherever they occur (case-insensitive).

.PARAMETER KeepProperty
    Property names that must be kept even though the default rules would remove them, e.g. 'version'.

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
    Validated: 2026-10 on PowerShell 7.6 with synthetic exports and Pester tests; not yet run against
               a real tenant export.
    Run as:    any user, offline. No Graph connection and no modules required.
    Exit code: none. The script throws on bad input so it can be used from other scripts and tests.
    Known gaps: it cannot recognise an internal hostname or a person's name in free text. Read the
               output before committing, and let the CI guard have the final word.
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
    'settingCount', 'priorityMetaData', 'isAssigned', 'createdBy', 'lastModifiedBy', '@odata.context'
)
$script:RemovedPropertySuffixes = @('@odata.count', '@odata.nextLink', '@odata.deltaLink')

$script:GroupIdKeys = @('groupId', 'targetGroupId')
$script:FilterIdKeys = @('deviceAndAppManagementAssignmentFilterId')

# Keys whose GUID values become a typed placeholder.
$script:GuidPlaceholderByKey = @{
    'tenantId'         = '<TENANT-ID>'
    'userId'           = '<USER-OBJECT-ID>'
    'enrolledByUserId' = '<USER-OBJECT-ID>'
    'deviceId'         = '<DEVICE-ID>'
    'azureADDeviceId'  = '<DEVICE-ID>'
    'aadDeviceId'      = '<DEVICE-ID>'
    'managedDeviceId'  = '<DEVICE-ID>'
    'intuneDeviceId'   = '<DEVICE-ID>'
    'entraDeviceId'    = '<DEVICE-ID>'
}

# Keys whose non-empty values become a typed placeholder regardless of shape.
$script:ValuePlaceholderByKey = @{
    'userPrincipalName'           = '<UPN>'
    'emailAddress'                = '<UPN>'
    'enrolledByUserPrincipalName' = '<UPN>'
    'serialNumber'                = '<SERIAL>'
    'hardwareIdentifier'          = '<HARDWARE-HASH>'
    'hardwareHash'                = '<HARDWARE-HASH>'
    'imei'                        = '<IMEI>'
    'meid'                        = '<MEID>'
    'wifiMacAddress'              = '<MAC-ADDRESS>'
    'ethernetMacAddress'          = '<MAC-ADDRESS>'
    'macAddress'                  = '<MAC-ADDRESS>'
    'phoneNumber'                 = '<PHONE-NUMBER>'
    'iccid'                       = '<ICCID>'
    'udid'                        = '<UDID>'
}

$script:GuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
$script:EmptyGuid = '00000000-0000-0000-0000-000000000000'

$script:PlaceholderTenantLabels = @(
    'contoso', 'fabrikam', 'tenant', 'tenantname', 'yourtenant', 'your-tenant', 'mytenant',
    'example', 'yourorg', 'org', 'company', 'yourcompany', 'tenant-name'
)
$script:PlaceholderEmailDomains = @(
    'example.com', 'example.org', 'example.net', 'contoso.com', 'fabrikam.com', 'domain.com',
    'yourdomain.com', 'yourcompany.com', 'company.com', 'tenant.com', 'microsoft.com'
)
$script:PlaceholderLocalParts = @(
    'user', 'username', 'admin', 'someone', 'name', 'upn', 'firstname.lastname', 'first.last',
    'john.doe', 'jane.doe', 'noreply', 'no-reply'
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
    return ($Value -match $script:GuidPattern)
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

function Test-IsPlaceholderEmail {
    [CmdletBinding()]
    [OutputType([bool])]
    param([string]$LocalPart, [string]$Domain)

    $d = $Domain.ToLowerInvariant()
    if ($script:PlaceholderEmailDomains -contains $d) { return $true }
    foreach ($p in $script:PlaceholderEmailDomains) {
        if ($d.EndsWith('.' + $p)) { return $true }
    }
    if ($d -match '^(?<label>[a-z0-9-]+)\.onmicrosoft\.com$') {
        if ($script:PlaceholderTenantLabels -contains $Matches['label']) { return $true }
    }
    if ($script:PlaceholderLocalParts -contains $LocalPart.ToLowerInvariant()) { return $true }
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

    return @{
        TenantId          = $TenantId
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

function ConvertTo-SanitizedString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][string]$Value,
        [AllowEmptyString()][string]$Key,
        [hashtable]$Context
    )

    if ([string]::IsNullOrEmpty($Value)) { return $Value }

    # 1. Key-driven placeholders.
    if ($Key) {
        if ($script:GroupIdKeys -contains $Key -and (Test-IsGuidValue $Value) -and $Value -ne $script:EmptyGuid) {
            $placeholder = '<GROUP-OBJECT-ID>'
            if ($Context.Groups.ContainsKey($Value)) { $placeholder = '<GROUP:' + $Context.Groups[$Value] + '>' }
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
        if ($script:FilterIdKeys -contains $Key -and (Test-IsGuidValue $Value) -and $Value -ne $script:EmptyGuid) {
            $placeholder = '<FILTER-ID>'
            if ($Context.Filters.ContainsKey($Value)) { $placeholder = '<FILTER:' + $Context.Filters[$Value] + '>' }
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
        if ($script:GuidPlaceholderByKey.ContainsKey($Key) -and (Test-IsGuidValue $Value) -and $Value -ne $script:EmptyGuid) {
            $placeholder = $script:GuidPlaceholderByKey[$Key]
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
        if ($script:ValuePlaceholderByKey.ContainsKey($Key) -and -not (Test-IsPlaceholderText $Value)) {
            $placeholder = $script:ValuePlaceholderByKey[$Key]
            Add-Replacement -Context $Context -Placeholder $placeholder
            return $placeholder
        }
    }

    $result = $Value

    # 2. The source tenant's GUID anywhere inside the string.
    if ($Context.TenantId -and $result.IndexOf($Context.TenantId, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $result = [regex]::Replace($result, [regex]::Escape($Context.TenantId), '<TENANT-ID>', 'IgnoreCase')
        Add-Replacement -Context $Context -Placeholder '<TENANT-ID>'
    }

    # 3. E-mail addresses / UPNs that are not documentation placeholders. Done before the domain
    #    rule so that user@tenant.onmicrosoft.com is replaced as a whole.
    $emailRegex = [regex]'\b(?<local>[A-Za-z0-9._%+-]+)@(?<domain>[A-Za-z0-9.-]+\.[A-Za-z]{2,})\b'
    $emailMatches = $emailRegex.Matches($result)
    if ($emailMatches.Count -gt 0) {
        $builder = New-Object System.Text.StringBuilder
        $last = 0
        foreach ($m in $emailMatches) {
            [void]$builder.Append($result.Substring($last, $m.Index - $last))
            if (Test-IsPlaceholderEmail -LocalPart $m.Groups['local'].Value -Domain $m.Groups['domain'].Value) {
                [void]$builder.Append($m.Value)
            } else {
                [void]$builder.Append('<UPN>')
                Add-Replacement -Context $Context -Placeholder '<UPN>'
            }
            $last = $m.Index + $m.Length
        }
        [void]$builder.Append($result.Substring($last))
        $result = $builder.ToString()
    }

    # 4. Tenant domains that are not placeholders.
    $domainRegex = [regex]'(?i)\b(?<label>[a-z0-9-]+)\.onmicrosoft\.com\b'
    $domainMatches = $domainRegex.Matches($result)
    if ($domainMatches.Count -gt 0) {
        $builder = New-Object System.Text.StringBuilder
        $last = 0
        foreach ($m in $domainMatches) {
            [void]$builder.Append($result.Substring($last, $m.Index - $last))
            if ($script:PlaceholderTenantLabels -contains $m.Groups['label'].Value.ToLowerInvariant()) {
                [void]$builder.Append($m.Value)
            } else {
                [void]$builder.Append('<TENANT>.onmicrosoft.com')
                Add-Replacement -Context $Context -Placeholder '<TENANT>.onmicrosoft.com'
            }
            $last = $m.Index + $m.Length
        }
        [void]$builder.Append($result.Substring($last))
        $result = $builder.ToString()
    }

    return $result
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
        [hashtable]$Context
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) { return (ConvertTo-SanitizedString -Value $Value -Key $Key -Context $Context) }
    if (Test-IsObjectLike $Value) { return (ConvertTo-SanitizedObject -Object $Value -Context $Context) }
    if (Test-IsArrayLike $Value) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $Value) {
            $items.Add((ConvertTo-SanitizedValue -Value $item -Key $Key -Context $Context))
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
        [hashtable]$Context
    )

    $pairs = Get-ObjectPair -Object $Object
    $byKey = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::Ordinal)
    foreach ($pair in $pairs) { $byKey[$pair.Key] = $pair.Value }
    $keys = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in $byKey.Keys) { $keys.Add($k) }
    $keys.Sort([System.StringComparer]::Ordinal)
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
            if ($key -eq 'id' -and (Test-IsGuidValue $value)) { $drop = $true }
            if ($Context.RemoveAssignments -and $key -eq 'assignments') { $drop = $true }
            if ($drop) {
                $Context.Stats.PropertiesRemoved++
                continue
            }
        }

        $result[$key] = ConvertTo-SanitizedValue -Value $value -Key $key -Context $Context
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
        switch ($ch) {
            '"' { [void]$sb.Append('\"'); continue }
            '\' { [void]$sb.Append('\\'); continue }
            "`n" { [void]$sb.Append('\n'); continue }
            "`r" { [void]$sb.Append('\r'); continue }
            "`t" { [void]$sb.Append('\t'); continue }
            "`b" { [void]$sb.Append('\b'); continue }
            "`f" { [void]$sb.Append('\f'); continue }
            default {
                if ($code -lt 0x20) {
                    [void]$sb.Append('\u' + $code.ToString('x4'))
                } else {
                    [void]$sb.Append($ch)
                }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Format-JsonDate {
    [CmdletBinding()]
    [OutputType([string])]
    param([datetime]$Value)

    if ($Value.Kind -eq [System.DateTimeKind]::Utc) {
        return $Value.ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFFZ', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $Value.ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFFK', [System.Globalization.CultureInfo]::InvariantCulture)
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
    if ($Value -is [System.DateTimeOffset]) { return ('"' + $Value.ToString('yyyy-MM-ddTHH:mm:ss.FFFFFFFK', $inv) + '"') }
    if ($Value -is [guid]) { return ('"' + $Value.ToString() + '"') }
    if ($Value -is [char]) { return (Format-JsonString -Value ([string]$Value)) }
    if ($Value -is [double] -or $Value -is [single]) { return $Value.ToString('R', $inv) }
    if ($Value -is [decimal]) { return $Value.ToString($inv) }
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

function Read-JsonFile {
    [CmdletBinding()]
    param([string]$FilePath)

    $raw = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "File is empty: $FilePath" }

    # PowerShell 7 turns ISO 8601 strings into DateTime objects and unrolls top-level arrays unless told
    # otherwise; Windows PowerShell 5.1 has neither parameter. Use what is available.
    $params = (Get-Command ConvertFrom-Json).Parameters
    $splat = @{}
    if ($params.ContainsKey('DateKind')) { $splat['DateKind'] = 'String' }
    if ($params.ContainsKey('NoEnumerate')) { $splat['NoEnumerate'] = $true }
    if ($params.ContainsKey('Depth')) { $splat['Depth'] = 100 }
    return ($raw | ConvertFrom-Json @splat)
}

function Read-NameMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string]$FilePath)

    $map = @{ Groups = @{}; Filters = @{} }
    if (-not $FilePath) { return $map }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "Name map file not found: $FilePath" }

    $obj = Read-JsonFile -FilePath $FilePath
    foreach ($section in @('groups', 'filters')) {
        $prop = $obj.PSObject.Properties[$section]
        if ($null -eq $prop -or $null -eq $prop.Value) { continue }
        $target = $map.Groups
        if ($section -eq 'filters') { $target = $map.Filters }
        foreach ($pair in (Get-ObjectPair -Object $prop.Value)) {
            $target[[string]$pair.Key] = [string]$pair.Value
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

#endregion Helpers

#region Main

if ($MyInvocation.InvocationName -ne '.') {

    if (-not $Path -or $Path.Count -eq 0) { throw 'Specify -Path: one or more JSON files or folders.' }
    if ($InPlace -and $OutputPath) { throw '-InPlace and -OutputPath cannot be combined.' }
    if ($TenantId -and -not (Test-IsGuidValue $TenantId)) { throw "-TenantId must be a GUID, got '$TenantId'." }

    $nameMap = Read-NameMap -FilePath $NameMapPath
    $inputs = Get-InputFileList -Path $Path -InPlace:$InPlace
    if ($inputs.Count -eq 0) { Write-Warning 'No JSON files found.'; return }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    foreach ($entry in $inputs) {
        $file = $entry.File
        $context = Initialize-SanitizeContext -TenantId $TenantId -GroupNames $nameMap.Groups -FilterNames $nameMap.Filters `
            -RemoveProperty $RemoveProperty -KeepProperty $KeepProperty -RemoveAssignments:$RemoveAssignments

        $data = Read-JsonFile -FilePath $file.FullName
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
            }
        }
    }
}

#endregion Main
