# Pester 5 tests for scripts/powershell/ConvertTo-SanitizedIntuneExport.ps1
#
# The script's functions are loaded by dot-sourcing (its main block only runs when invoked
# directly). File-mode tests call the script with & so the main block runs.
# Identifiers in fixtures are built at run time so this file never contains anything that
# looks like a real tenant, group, or user. Join-Path is used with two arguments only so the
# file also runs on Windows PowerShell 5.1.

BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot '..'
    $script:scriptPath = Join-Path (Join-Path (Join-Path $repoRoot 'scripts') 'powershell') 'ConvertTo-SanitizedIntuneExport.ps1'
    $script:guardPath = Join-Path (Join-Path (Join-Path $repoRoot '.github') 'scripts') 'Test-RepoSanitized.ps1'
    . $script:scriptPath

    $script:tenant = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d'
    $script:group1 = '2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e'
    $script:group2 = '3c4d5e6f-7a8b-4c9d-0e1f-2a3b4c5d6e7f'
    $script:filter1 = '4d5e6f7a-8b9c-4d0e-1f2a-3b4c5d6e7f8a'
    $script:objectId = '5e6f7a8b-9c0d-4e1f-2a3b-4c5d6e7f8a9b'
    $script:templateId = '6f7a8b9c-0d1e-4f2a-3b4c-5d6e7f8a9b0c'
    $script:definitionId = '7a8b9c0d-1e2f-4a3b-4c5d-6e7f8a9b0c1d'
    $script:realDomain = 'northwindtraders99'

    function Get-RawExportJson {
        # A composite fixture that looks like a Graph export of a Settings Catalog policy with
        # assignments, plus compliance-style scheduled actions, ADMX bindings, secrets and some
        # device/user fields.
        $domain = $script:realDomain + '.onmicrosoft.com'
        return @"
{
  "@odata.context": "https://graph.microsoft.com/beta/`$metadata#deviceManagement/configurationPolicies/`$entity",
  "id": "$($script:objectId)",
  "name": "WIN-Cfg-BitLocker-R1",
  "description": "Owned by kim.lee@$domain for tenant $($script:tenant). Contact admin@contoso.com.",
  "platforms": "windows10",
  "technologies": "mdm",
  "createdDateTime": "2026-01-02T03:04:05Z",
  "lastModifiedDateTime": "2026-02-03T04:05:06Z",
  "settingCount": 2,
  "isAssigned": true,
  "priorityMetaData": null,
  "roleScopeTagIds": [ "0" ],
  "templateReference": { "templateId": "$($script:templateId)_1", "templateFamily": "endpointSecurityDiskEncryption", "templateDisplayName": "BitLocker", "templateDisplayVersion": "Version 1" },
  "settings@odata.context": "https://graph.microsoft.com/beta/`$metadata#deviceManagement/configurationPolicies('$($script:objectId)')/settings",
  "settings": [
    {
      "id": "0",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "settingDefinitionId": "device_vendor_msft_bitlocker_requiredeviceencryption",
        "settingInstanceTemplateReference": { "settingInstanceTemplateId": "$($script:templateId)" },
        "choiceSettingValue": { "value": "device_vendor_msft_bitlocker_requiredeviceencryption_1", "children": [] }
      }
    },
    {
      "id": "1",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
        "settingDefinitionId": "device_vendor_msft_bitlocker_encryptionmethodbydrivetype",
        "simpleSettingValue": { "@odata.type": "#microsoft.graph.deviceManagementConfigurationIntegerSettingValue", "value": 7 }
      }
    },
    {
      "id": "2",
      "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
        "settingDefinitionId": "device_vendor_msft_accounts_localadmin_password",
        "simpleSettingValue": { "@odata.type": "#microsoft.graph.deviceManagementConfigurationSecretSettingValue", "valueState": "notEncrypted", "value": "Sup3rS3cretLocalAdmin!2026" }
      }
    }
  ],
  "assignments": [
    {
      "id": "$($script:objectId)_$($script:group1)",
      "sourceId": "$($script:objectId)",
      "target": {
        "@odata.type": "#microsoft.graph.groupAssignmentTarget",
        "groupId": "$($script:group1)",
        "deviceAndAppManagementAssignmentFilterId": "$($script:filter1)",
        "deviceAndAppManagementAssignmentFilterType": "include"
      }
    },
    {
      "id": "$($script:objectId)_$($script:group2)",
      "target": { "@odata.type": "#microsoft.graph.exclusionGroupAssignmentTarget", "groupId": "$($script:group2)" }
    }
  ],
  "scheduledActionsForRule": [
    {
      "id": "$($script:objectId)",
      "ruleName": "PasswordRequired",
      "scheduledActionConfigurations": [
        { "id": "$($script:group1)", "actionType": "notification", "gracePeriodHours": 0, "notificationTemplateId": "$($script:templateId)", "notificationMessageCCList": [ "$($script:group2)" ] },
        { "id": "$($script:group2)", "actionType": "block", "gracePeriodHours": 0, "notificationTemplateId": "00000000-0000-0000-0000-000000000000", "notificationMessageCCList": [] }
      ]
    }
  ],
  "definitionValues": [
    {
      "id": "$($script:objectId)",
      "enabled": true,
      "definition@odata.bind": "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($script:definitionId)')",
      "definition": { "id": "$($script:definitionId)", "@odata.type": "#microsoft.graph.groupPolicyDefinition", "displayName": "Turn off Autoplay" }
    }
  ],
  "omaSettings": [
    { "@odata.type": "#microsoft.graph.omaSettingString", "omaUri": "./Device/Vendor/MSFT/Accounts/Users/localadmin/Password", "displayName": "Local admin password", "value": "PlainTextP@ss2026", "isEncrypted": true, "secretReferenceValueId": "$($script:objectId)_$($script:group1)" }
  ],
  "ownerDevice": {
    "deviceId": "$($script:group2)",
    "azureActiveDirectoryDeviceId": "$($script:group1)",
    "serialNumber": "5CG1234ABC",
    "userPrincipalName": "kim.lee@$domain",
    "enrolledByUserId": "$($script:group1)",
    "wifiMacAddress": "00-11-22-33-44-55",
    "deviceName": "NW-LT-KLEE-01",
    "ownerId": "$($script:group1)",
    "targetedMobileApps": [ "$($script:group2)" ],
    "group@odata.bind": "https://graph.microsoft.com/v1.0/groups/$($script:group1)",
    "preSharedKey": "CorpWifi2026!Secret",
    "intranet": "https://intranet.$($script:realDomain).local/ and \\\\nwfs01.corp.$($script:realDomain).local\\software and proxy 10.20.30.40:8080",
    "sharepoint": "https://$($script:realDomain)-my.sharepoint.com/personal/kim_lee_$($script:realDomain)_com/Documents",
    "routing": "$($script:realDomain).mail.onmicrosoft.com",
    "guest": "kim.lee_$($script:realDomain).com#EXT#@$domain",
    "encoded": "https://graph.microsoft.com/v1.0/users/kim.lee%40$($script:realDomain).com/managedDevices",
    "payload": "UEsDBBQAAAAIAHSmaFkAAAAAAAAAAAAAAAAIAAAAbW9iaWxlY29uZmlnUEsFBgAAAAABAAEANgAAAAAAAAAAAA=="
  },
  "version": 3,
  "supportsScopeTags": true,
  "assignments@odata.count": 2,
  "unicodeName": "Z$([char]0x00FC)rich $([char]0x2192) B$([char]0x00E4)ren",
  "quoted": "He said \"hi\"\nnew line\ttab \\ backslash",
  "emptyObject": {},
  "emptyArray": [],
  "nullValue": null,
  "flag": false,
  "ratio": 1.5
}
"@
    }

    function Invoke-Sanitize {
        param([string]$Json, [hashtable]$ContextArgs = @{})
        $obj = ConvertFrom-JsonText -Text $Json
        $ctx = Initialize-SanitizeContext @ContextArgs
        Add-TenantIdFromObject -Value $obj -Context $ctx
        $out = ConvertTo-SanitizedValue -Value $obj -Key '' -Context $ctx
        return @{ Object = $out; Context = $ctx; Json = (ConvertTo-StableJson -Value $out) }
    }
}

Describe 'ConvertTo-SanitizedIntuneExport' {

    Context 'Removal rules' {
        BeforeAll { $script:r = Invoke-Sanitize -Json (Get-RawExportJson) -ContextArgs @{ TenantId = $script:tenant } }

        It 'removes export metadata at the top level' {
            foreach ($k in @('@odata.context', 'createdDateTime', 'lastModifiedDateTime', 'settingCount', 'isAssigned', 'priorityMetaData', 'version', 'supportsScopeTags', 'assignments@odata.count', 'settings@odata.context')) {
                $script:r.Object.Contains($k) | Should -BeFalse -Because "$k is tenant-specific metadata"
            }
        }

        It 'removes GUID ids but keeps non-GUID ids' {
            $script:r.Object.Contains('id') | Should -BeFalse
            $script:r.Object['settings'][0]['id'] | Should -Be '0'
            $script:r.Object['settings'][1]['id'] | Should -Be '1'
            $script:r.Object['scheduledActionsForRule'][0].Contains('id') | Should -BeFalse
            $script:r.Object['scheduledActionsForRule'][0]['scheduledActionConfigurations'][0].Contains('id') | Should -BeFalse
        }

        It 'removes composite assignment ids and sourceId' {
            $script:r.Object['assignments'][0].Contains('id') | Should -BeFalse
            $script:r.Object['assignments'][0].Contains('sourceId') | Should -BeFalse
        }

        It 'keeps the id of ADMX definitions and the definition@odata.bind reference' {
            $dv = $script:r.Object['definitionValues'][0]
            $dv.Contains('id') | Should -BeFalse
            $dv['definition']['id'] | Should -Be $script:definitionId
            $dv['definition@odata.bind'] | Should -Be ("https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('" + $script:definitionId + "')")
        }

        It 'keeps settings, template references and scope tags' {
            $script:r.Object['settings'][0]['settingInstance']['settingDefinitionId'] | Should -Be 'device_vendor_msft_bitlocker_requiredeviceencryption'
            $script:r.Object['settings'][0]['settingInstance']['settingInstanceTemplateReference']['settingInstanceTemplateId'] | Should -Be $script:templateId
            $script:r.Object['templateReference']['templateId'] | Should -Be ($script:templateId + '_1')
            $script:r.Object['roleScopeTagIds'] | Should -Be @('0')
            $script:r.Object['settings'][1]['settingInstance']['simpleSettingValue']['value'] | Should -Be 7
        }

        It 'counts removed properties' {
            $script:r.Context.Stats.PropertiesRemoved | Should -BeGreaterThan 10
        }
    }

    Context 'Replacement rules' {
        BeforeAll {
            $script:r = Invoke-Sanitize -Json (Get-RawExportJson) -ContextArgs @{
                TenantId    = $script:tenant
                GroupNames  = @{ $script:group1 = 'WIN-Ring-R1' }
                FilterNames = @{ $script:filter1 = 'Corporate Windows' }
            }
            $script:d = $script:r.Object['ownerDevice']
        }

        It 'maps known group and filter ids to names and unknown ones to generic placeholders' {
            $script:r.Object['assignments'][0]['target']['groupId'] | Should -Be '<GROUP:WIN-Ring-R1>'
            $script:r.Object['assignments'][0]['target']['deviceAndAppManagementAssignmentFilterId'] | Should -Be '<FILTER:Corporate Windows>'
            $script:r.Object['assignments'][1]['target']['groupId'] | Should -Be '<GROUP-OBJECT-ID>'
        }

        It 'replaces the tenant id, real e-mail and real tenant domain inside free text, keeping placeholders' {
            $script:r.Object['description'] | Should -Be 'Owned by <UPN> for tenant <TENANT-ID>. Contact admin@contoso.com.'
        }

        It 'replaces device and user identifiers by key' {
            $script:d['deviceId'] | Should -Be '<DEVICE-ID>'
            $script:d['azureActiveDirectoryDeviceId'] | Should -Be '<DEVICE-ID>'
            $script:d['enrolledByUserId'] | Should -Be '<USER-OBJECT-ID>'
            $script:d['ownerId'] | Should -Be '<USER-OBJECT-ID>'
            $script:d['serialNumber'] | Should -Be '<SERIAL>'
            $script:d['userPrincipalName'] | Should -Be '<UPN>'
            $script:d['wifiMacAddress'] | Should -Be '<MAC-ADDRESS>'
            $script:d['deviceName'] | Should -Be '<DEVICE-NAME>'
        }

        It 'replaces GUIDs under unknown *Id keys with a typed placeholder' {
            $script:d['targetedMobileApps'] | Should -Be @('<APP-ID>')
        }

        It 'replaces secrets: secret setting values, encrypted OMA-URI values, and secret-looking keys' {
            $script:r.Object['settings'][2]['settingInstance']['simpleSettingValue']['value'] | Should -Be '<SECRET>'
            $script:r.Object['settings'][2]['settingInstance']['simpleSettingValue']['valueState'] | Should -Be 'notEncrypted'
            $script:r.Object['omaSettings'][0]['value'] | Should -Be '<SECRET>'
            $script:r.Object['omaSettings'][0]['secretReferenceValueId'] | Should -Be '<SECRET-REFERENCE-ID>'
            $script:d['preSharedKey'] | Should -Be '<SECRET>'
        }

        It 'replaces group ids in notification CC lists and notification template ids' {
            $cfg = $script:r.Object['scheduledActionsForRule'][0]['scheduledActionConfigurations']
            $cfg[0]['notificationMessageCCList'] | Should -Be @('<GROUP-OBJECT-ID>')
            $cfg[0]['notificationTemplateId'] | Should -Be '<NOTIFICATION-TEMPLATE-ID>'
            $cfg[1]['notificationTemplateId'] | Should -Be '00000000-0000-0000-0000-000000000000'
        }

        It 'replaces directory object ids inside @odata.bind URLs' {
            $script:d['group@odata.bind'] | Should -Be 'https://graph.microsoft.com/v1.0/groups/<GROUP:WIN-Ring-R1>'
        }

        It 'replaces internal hostnames, UNC hosts and private IP addresses' {
            $script:d['intranet'] | Should -Be 'https://<HOSTNAME>/ and \\<SERVER>\software and proxy <IP-ADDRESS>:8080'
        }

        It 'replaces SharePoint hosts, personal-site paths and routing domains' {
            $script:d['sharepoint'] | Should -Be 'https://<TENANT>-my.sharepoint.com/personal/<UPN-PATH>/Documents'
            $script:d['routing'] | Should -Be '<TENANT>.onmicrosoft.com'
        }

        It 'replaces guest and URL-encoded UPNs as a whole' {
            $script:d['guest'] | Should -Be '<UPN>'
            $script:d['encoded'] | Should -Be 'https://graph.microsoft.com/v1.0/users/<UPN>/managedDevices'
        }

        It 'removes base64 payloads' {
            $script:d['payload'] | Should -Match '^<BASE64-BLOB-REMOVED:\d+-CHARS>$'
        }

        It 'records the placeholders it used' {
            $script:r.Context.Placeholders | Should -Contain '<TENANT-ID>'
            $script:r.Context.Placeholders | Should -Contain '<GROUP:WIN-Ring-R1>'
            $script:r.Context.Placeholders | Should -Contain '<UPN>'
            $script:r.Context.Placeholders | Should -Contain '<SECRET>'
            $script:r.Context.Stats.ValuesReplaced | Should -BeGreaterThan 15
        }

        It 'learns the tenant id from a tenantId key when -TenantId is not given, including the dash-less form' {
            $json = '{ "tenantId": "' + $script:tenant.ToUpperInvariant() + '", "url": "https://login.microsoftonline.com/' + $script:tenant + '/oauth2", "tid": "tid=' + $script:tenant.Replace('-', '') + '" }'
            $r2 = Invoke-Sanitize -Json $json
            $r2.Object['tenantId'] | Should -Be '<TENANT-ID>'
            $r2.Object['url'] | Should -Be 'https://login.microsoftonline.com/<TENANT-ID>/oauth2'
            $r2.Object['tid'] | Should -Be 'tid=<TENANT-ID>'
        }

        It 'replaces a non-ASCII e-mail address and keeps placeholder domains' {
            $json = '{ "a": "kim.m' + [char]0x00FC + 'ller@' + $script:realDomain + '.com and user@contoso.com" }'
            $r2 = Invoke-Sanitize -Json $json
            $r2.Object['a'] | Should -Be '<UPN> and user@contoso.com'
        }

        It 'does not replace values that are already placeholders' {
            $r2 = Invoke-Sanitize -Json '{ "a": "<UPN>", "userPrincipalName": "<UPN>", "b": "user@contoso.com", "password": "<SECRET>" }'
            $r2.Object['a'] | Should -Be '<UPN>'
            $r2.Object['userPrincipalName'] | Should -Be '<UPN>'
            $r2.Object['b'] | Should -Be 'user@contoso.com'
            $r2.Object['password'] | Should -Be '<SECRET>'
            $r2.Context.Stats.ValuesReplaced | Should -Be 0
        }

        It 'sanitizes object keys that carry identifiers' {
            $r2 = Invoke-Sanitize -Json ('{ "kim.lee@' + $script:realDomain + '.com": 1, "definition@odata.bind": "x" }')
            $r2.Object.Contains('<UPN>') | Should -BeTrue
            $r2.Object.Contains('definition@odata.bind') | Should -BeTrue
        }

        It 'keeps global catalog ids under *Id keys' {
            $r2 = Invoke-Sanitize -Json ('{ "settingDefinitionId": "x", "settingInstanceTemplateId": "' + $script:templateId + '", "clientId": "' + $script:templateId + '" }')
            $r2.Object['settingInstanceTemplateId'] | Should -Be $script:templateId
            $r2.Object['clientId'] | Should -Be $script:templateId
        }
    }

    Context 'Keep, remove and assignment options' {
        It '-KeepProperty keeps a property the defaults would remove' {
            $r = Invoke-Sanitize -Json '{ "version": 3, "x": 1 }' -ContextArgs @{ KeepProperty = @('version') }
            $r.Object['version'] | Should -Be 3
        }

        It '-RemoveProperty removes an extra property everywhere' {
            $r = Invoke-Sanitize -Json '{ "description": "a", "nested": { "description": "b" } }' -ContextArgs @{ RemoveProperty = @('description') }
            $r.Object.Contains('description') | Should -BeFalse
            $r.Object['nested'].Contains('description') | Should -BeFalse
        }

        It '-RemoveAssignments drops the assignments array' {
            $r = Invoke-Sanitize -Json (Get-RawExportJson) -ContextArgs @{ RemoveAssignments = $true }
            $r.Object.Contains('assignments') | Should -BeFalse
        }
    }

    Context 'Stable JSON output' {
        It 'sorts keys ordinally with @odata.type first and nests with 2-space indentation' {
            $r = Invoke-Sanitize -Json '{ "zeta": 1, "alpha": { "y": true, "x": null }, "@odata.type": "#t", "List": [ "b", "a" ], "Beta": 2 }'
            $expected = @(
                '{',
                '  "@odata.type": "#t",',
                '  "Beta": 2,',
                '  "List": [',
                '    "b",',
                '    "a"',
                '  ],',
                '  "alpha": {',
                '    "x": null,',
                '    "y": true',
                '  },',
                '  "zeta": 1',
                '}'
            ) -join "`n"
            $r.Json | Should -Be $expected
        }

        It 'serializes empty containers, numbers, booleans and null, normalizing fractional numbers' {
            $r = Invoke-Sanitize -Json '{ "o": {}, "a": [], "n": null, "f": false, "d": 1.5, "i": 42, "big": 12345678901234, "one": 1.0, "negzero": -0.0 }'
            $r.Json | Should -Be ('{' + "`n" + '  "a": [],' + "`n" + '  "big": 12345678901234,' + "`n" + '  "d": 1.5,' + "`n" + '  "f": false,' + "`n" + '  "i": 42,' + "`n" + '  "n": null,' + "`n" + '  "negzero": 0,' + "`n" + '  "o": {},' + "`n" + '  "one": 1' + "`n" + '}')
        }

        It 'normalizes decimal values the way PowerShell 7 parses them' {
            ConvertTo-StableJson -Value ([decimal]'2.50') | Should -Be '2.5'
            ConvertTo-StableJson -Value ([decimal]'1.0') | Should -Be '1'
        }

        It 'escapes quotes, backslashes and control characters, and keeps non-ASCII text' {
            $r = Invoke-Sanitize -Json (Get-RawExportJson)
            $r.Json | Should -Match '"quoted": "He said \\"hi\\"\\nnew line\\ttab \\\\ backslash"'
            $r.Json | Should -Match ('"unicodeName": "Z' + [char]0x00FC + 'rich ' + [char]0x2192 + ' B' + [char]0x00E4 + 'ren"')
            $r.Json | Should -Not -Match '\\u003c'
        }

        It 'escapes control characters by code point and leaves soft hyphens and zero-width characters alone' {
            $s = 'a' + [char]0x01 + 'b' + [char]0x1F + 'c' + [char]0x7F + 'd' + [char]0xAD + 'e' + [char]0x200B + 'f' + [char]0x08 + 'g'
            $expected = '"a\u0001b\u001fc\u007fd' + [char]0xAD + 'e' + [char]0x200B + 'f\bg"'
            Format-JsonString -Value $s | Should -Be $expected
        }

        It 'writes DateTime values as ISO 8601 strings in UTC' {
            $utc = [datetime]::new(2026, 3, 4, 5, 6, 7, [System.DateTimeKind]::Utc)
            ConvertTo-StableJson -Value $utc | Should -Be '"2026-03-04T05:06:07Z"'
            $unspecified = [datetime]::new(2026, 3, 4, 5, 6, 7, [System.DateTimeKind]::Unspecified)
            ConvertTo-StableJson -Value $unspecified | Should -Be '"2026-03-04T05:06:07"'
            $local = [datetime]::new(2026, 3, 4, 5, 6, 7, [System.DateTimeKind]::Local)
            ConvertTo-StableJson -Value $local | Should -Be ('"' + $local.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss') + 'Z"')
        }

        It 'round-trips as valid JSON and is idempotent' {
            $first = Invoke-Sanitize -Json (Get-RawExportJson) -ContextArgs @{ TenantId = $script:tenant }
            { $first.Json | ConvertFrom-Json } | Should -Not -Throw
            $second = Invoke-Sanitize -Json $first.Json -ContextArgs @{ TenantId = $script:tenant }
            $second.Json | Should -Be $first.Json
            $second.Context.Stats.PropertiesRemoved | Should -Be 0
            $second.Context.Stats.ValuesReplaced | Should -Be 0
        }

        It 'handles top-level arrays of any length' {
            $r = Invoke-Sanitize -Json ('[ { "id": "' + $script:objectId + '", "name": "a" }, { "name": "b" } ]')
            $r.Json | Should -Be ('[' + "`n" + '  {' + "`n" + '    "name": "a"' + "`n" + '  },' + "`n" + '  {' + "`n" + '    "name": "b"' + "`n" + '  }' + "`n" + ']')
            (Invoke-Sanitize -Json '[ { "name": "only" } ]').Json | Should -Be ('[' + "`n" + '  {' + "`n" + '    "name": "only"' + "`n" + '  }' + "`n" + ']')
            (Invoke-Sanitize -Json '[]').Json | Should -Be '[]'
            (Invoke-Sanitize -Json '[ "x" ]').Json | Should -Be ('[' + "`n" + '  "x"' + "`n" + ']')
        }
    }

    Context 'File mode' {
        BeforeEach {
            $script:work = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $script:exports = Join-Path $script:work 'exports'
            New-Item -ItemType Directory -Path (Join-Path $script:exports 'sub') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:exports 'policy-a.json') -Value (Get-RawExportJson) -Encoding UTF8 -NoNewline
            Set-Content -LiteralPath (Join-Path (Join-Path $script:exports 'sub') 'policy-b.json') -Value (Get-RawExportJson) -Encoding UTF8 -NoNewline
            $script:fileA = Join-Path $script:exports 'policy-a.json'
        }

        It 'writes a sibling .sanitized.json by default and returns a summary with review hints' {
            $summary = & $script:scriptPath -Path $script:fileA -TenantId $script:tenant
            $summary.Destination | Should -Be (Join-Path $script:exports 'policy-a.sanitized.json')
            Test-Path $summary.Destination | Should -BeTrue
            $summary.PropertiesRemoved | Should -BeGreaterThan 0
            $summary.ValuesReplaced | Should -BeGreaterThan 0
            $summary.Placeholders | Should -Contain '<TENANT-ID>'
            @($summary.ReviewHints).Count | Should -BeGreaterThan 0
            ($summary.ReviewHints -join "`n") | Should -Match 'templateId'
        }

        It 'mirrors folder structure under -OutputPath and skips .sanitized.json files' {
            $out = Join-Path $script:work 'artifacts'
            Set-Content -LiteralPath (Join-Path $script:exports 'old.sanitized.json') -Value '{ "a": 1 }' -Encoding UTF8
            $summaries = @(& $script:scriptPath -Path $script:exports -OutputPath $out -TenantId $script:tenant)
            $summaries.Count | Should -Be 2
            Test-Path (Join-Path $out 'policy-a.json') | Should -BeTrue
            Test-Path (Join-Path (Join-Path $out 'sub') 'policy-b.json') | Should -BeTrue
        }

        It 'resolves relative -OutputPath and -NameMapPath against the PowerShell location' {
            $map = Join-Path $script:work 'names.json'
            Set-Content -LiteralPath $map -Value ('{ "groups": { "' + $script:group1 + '": "WIN-Ring-R1" } }') -Encoding UTF8
            Push-Location $script:work
            try {
                $summary = & $script:scriptPath -Path 'exports/policy-a.json' -OutputPath 'out/relative' -NameMapPath 'names.json'
                $summary.Destination | Should -Be (Join-Path (Join-Path $script:work 'out') (Join-Path 'relative' 'policy-a.json'))
                Test-Path $summary.Destination | Should -BeTrue
                (Get-Content $summary.Destination -Raw) | Should -Match '<GROUP:WIN-Ring-R1>'
            } finally {
                Pop-Location
            }
        }

        It 'keeps a one-element top-level array an array and an empty array empty' {
            Set-Content -LiteralPath (Join-Path $script:exports 'one.json') -Value ('[ { "id": "' + $script:objectId + '", "name": "only" } ]') -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $script:exports 'none.json') -Value '[]' -Encoding UTF8
            & $script:scriptPath -Path (Join-Path $script:exports 'one.json'), (Join-Path $script:exports 'none.json') | Out-Null
            (Get-Content (Join-Path $script:exports 'one.sanitized.json') -Raw) | Should -Be ('[' + "`n" + '  {' + "`n" + '    "name": "only"' + "`n" + '  }' + "`n" + ']' + "`n")
            (Get-Content (Join-Path $script:exports 'none.sanitized.json') -Raw) | Should -Be ('[]' + "`n")
        }

        It 'writes UTF-8 without BOM and LF line endings' {
            $summary = & $script:scriptPath -Path $script:fileA
            $bytes = [System.IO.File]::ReadAllBytes($summary.Destination)
            $bytes[0] | Should -Be ([byte][char]'{')
            ($bytes -contains 13) | Should -BeFalse
            $bytes[-1] | Should -Be 10
        }

        It '-InPlace overwrites the input' {
            $before = Get-Content $script:fileA -Raw
            $summary = & $script:scriptPath -Path $script:fileA -InPlace
            $summary.Destination | Should -Be $script:fileA
            (Get-Content $script:fileA -Raw) | Should -Not -Be $before
            (Get-Content $script:fileA -Raw) | Should -Not -Match 'createdDateTime'
        }

        It '-WhatIf writes nothing' {
            & $script:scriptPath -Path $script:fileA -WhatIf | Out-Null
            Test-Path (Join-Path $script:exports 'policy-a.sanitized.json') | Should -BeFalse
        }

        It 'rejects -InPlace together with -OutputPath, a non-GUID tenant id, and a missing path' {
            { & $script:scriptPath -Path $script:fileA -InPlace -OutputPath $script:work } | Should -Throw '*cannot be combined*'
            { & $script:scriptPath -Path $script:fileA -TenantId 'not-a-guid' } | Should -Throw '*must be a GUID*'
            { & $script:scriptPath -Path (Join-Path $script:work 'nope.json') } | Should -Throw '*not found*'
            { & $script:scriptPath } | Should -Throw '*Specify -Path*'
        }

        It 'reads a name map file and rejects names that would break a placeholder' {
            $map = Join-Path $script:work 'names.json'
            Set-Content -LiteralPath $map -Value ('{ "groups": { "' + $script:group1 + '": "WIN-Ring-R1" }, "filters": { "' + $script:filter1 + '": "Corporate Windows" } }') -Encoding UTF8
            $obj = & $script:scriptPath -Path $script:fileA -NameMapPath $map -PassThru
            $obj['assignments'][0]['target']['groupId'] | Should -Be '<GROUP:WIN-Ring-R1>'
            $obj['assignments'][0]['target']['deviceAndAppManagementAssignmentFilterId'] | Should -Be '<FILTER:Corporate Windows>'

            $bad = Join-Path $script:work 'bad.json'
            Set-Content -LiteralPath $bad -Value ('{ "groups": { "' + $script:group1 + '": "Ring>1" } }') -Encoding UTF8
            { & $script:scriptPath -Path $script:fileA -NameMapPath $bad -WhatIf } | Should -Throw '*not allowed in a placeholder*'
            Set-Content -LiteralPath $bad -Value ('{ "groups": { "not-a-guid": "x" } }') -Encoding UTF8
            { & $script:scriptPath -Path $script:fileA -NameMapPath $bad -WhatIf } | Should -Throw '*not a GUID*'
            Set-Content -LiteralPath $bad -Value ('{ "groups": { "' + $script:group1 + '": "owner kim@' + $script:realDomain + '.com" } }') -Encoding UTF8
            { & $script:scriptPath -Path $script:fileA -NameMapPath $bad -WhatIf } | Should -Throw '*not allowed in a placeholder*'
        }

        It 'produces output that passes the sanitization guard, from input that fails it' {
            $out = Join-Path (Join-Path (Join-Path $script:work 'artifacts') 'policies') 'configuration'
            & $script:scriptPath -Path $script:exports -OutputPath $out -TenantId $script:tenant | Out-Null

            $rawFindings = @(& $script:guardPath -Path $script:exports -Quiet)
            $rawFindings.Count | Should -BeGreaterThan 0

            $cleanFindings = @(& $script:guardPath -Path (Join-Path $script:work 'artifacts') -Quiet)
            if ($cleanFindings.Count -gt 0) { $cleanFindings | Format-Table Rule, File, Line, Match -AutoSize | Out-String | Write-Host }
            $cleanFindings.Count | Should -Be 0
        }
    }
}
