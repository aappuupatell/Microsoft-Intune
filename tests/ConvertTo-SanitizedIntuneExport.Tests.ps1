# Pester 5 tests for scripts/powershell/ConvertTo-SanitizedIntuneExport.ps1
#
# The script's functions are loaded by dot-sourcing (its main block only runs when invoked
# directly). File-mode tests call the script with & so the main block runs.
# Identifiers in fixtures are built at run time so this file never contains anything that
# looks like a real tenant, group, or user.

BeforeAll {
    $script:scriptPath = Join-Path $PSScriptRoot '..' 'scripts' 'powershell' 'ConvertTo-SanitizedIntuneExport.ps1'
    $script:guardPath = Join-Path $PSScriptRoot '..' '.github' 'scripts' 'Test-RepoSanitized.ps1'
    . $script:scriptPath

    $script:tenant = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d'
    $script:group1 = '2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e'
    $script:group2 = '3c4d5e6f-7a8b-4c9d-0e1f-2a3b4c5d6e7f'
    $script:filter1 = '4d5e6f7a-8b9c-4d0e-1f2a-3b4c5d6e7f8a'
    $script:objectId = '5e6f7a8b-9c0d-4e1f-2a3b-4c5d6e7f8a9b'
    $script:templateId = '6f7a8b9c-0d1e-4f2a-3b4c-5d6e7f8a9b0c'

    function Get-RawExportJson {
        # A composite fixture that looks like a Graph export of a Settings Catalog policy with
        # assignments, plus compliance-style scheduled actions and some device/user fields.
        $domain = 'northwindtraders99.onmicrosoft.com'
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
    }
  ],
  "assignments": [
    {
      "id": "$($script:objectId)_$($script:group1)",
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
        { "id": "$($script:group1)", "actionType": "block", "gracePeriodHours": 0, "notificationTemplateId": "00000000-0000-0000-0000-000000000000", "notificationMessageCCList": [] }
      ]
    }
  ],
  "ownerDevice": {
    "deviceId": "$($script:group2)",
    "serialNumber": "5CG1234ABC",
    "userPrincipalName": "kim.lee@$domain",
    "enrolledByUserId": "$($script:group1)",
    "wifiMacAddress": "00-11-22-33-44-55",
    "deviceName": "LAPTOP-SAMPLE-01"
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
        $obj = $Json | ConvertFrom-Json -DateKind String -NoEnumerate
        $ctx = Initialize-SanitizeContext @ContextArgs
        $out = ConvertTo-SanitizedValue -Value $obj -Key '' -Context $ctx
        return @{ Object = $out; Context = $ctx; Json = (ConvertTo-StableJson -Value $out) }
    }
}

Describe 'ConvertTo-SanitizedIntuneExport' {

    Context 'Removal rules' {
        BeforeAll { $script:r = Invoke-Sanitize -Json (Get-RawExportJson) -ContextArgs @{ TenantId = $script:tenant } }

        It 'removes export metadata at the top level' {
            foreach ($k in @('@odata.context', 'createdDateTime', 'lastModifiedDateTime', 'settingCount', 'isAssigned', 'priorityMetaData', 'version', 'supportsScopeTags', 'assignments@odata.count')) {
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

        It 'removes assignment ids composed of GUIDs only when they are exact GUIDs' {
            # "<policyId>_<groupId>" is not a bare GUID, so it is kept and the tenant GUIDs inside
            # it are not touched by the id rule. The guard would still accept it because the key is id
            # with a non-GUID value; the test documents the behavior.
            $script:r.Object['assignments'][0].Contains('id') | Should -BeTrue
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
                TenantId   = $script:tenant
                GroupNames = @{ $script:group1 = 'WIN-Ring-R1' }
                FilterNames = @{ $script:filter1 = 'Corporate Windows' }
            }
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
            $d = $script:r.Object['ownerDevice']
            $d['deviceId'] | Should -Be '<DEVICE-ID>'
            $d['enrolledByUserId'] | Should -Be '<USER-OBJECT-ID>'
            $d['serialNumber'] | Should -Be '<SERIAL>'
            $d['userPrincipalName'] | Should -Be '<UPN>'
            $d['wifiMacAddress'] | Should -Be '<MAC-ADDRESS>'
            $d['deviceName'] | Should -Be 'LAPTOP-SAMPLE-01'
        }

        It 'leaves the empty GUID alone' {
            $script:r.Object['scheduledActionsForRule'][0]['scheduledActionConfigurations'][0]['notificationTemplateId'] | Should -Be '00000000-0000-0000-0000-000000000000'
        }

        It 'records the placeholders it used' {
            $script:r.Context.Placeholders | Should -Contain '<TENANT-ID>'
            $script:r.Context.Placeholders | Should -Contain '<GROUP:WIN-Ring-R1>'
            $script:r.Context.Placeholders | Should -Contain '<UPN>'
            $script:r.Context.Stats.ValuesReplaced | Should -BeGreaterThan 5
        }

        It 'replaces a bare tenant domain with a placeholder domain' {
            $r2 = Invoke-Sanitize -Json '{ "x": "Sync to northwindtraders99.onmicrosoft.com and contoso.onmicrosoft.com" }'
            $r2.Object['x'] | Should -Be 'Sync to <TENANT>.onmicrosoft.com and contoso.onmicrosoft.com'
        }

        It 'does not replace a tenant domain or e-mail that is already a placeholder' {
            $r2 = Invoke-Sanitize -Json '{ "a": "<UPN>", "userPrincipalName": "<UPN>", "b": "user@contoso.com" }'
            $r2.Object['a'] | Should -Be '<UPN>'
            $r2.Object['userPrincipalName'] | Should -Be '<UPN>'
            $r2.Object['b'] | Should -Be 'user@contoso.com'
            $r2.Context.Stats.ValuesReplaced | Should -Be 0
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

        It 'serializes empty containers, numbers, booleans and null' {
            $r = Invoke-Sanitize -Json '{ "o": {}, "a": [], "n": null, "f": false, "d": 1.5, "i": 42, "big": 12345678901234 }'
            $r.Json | Should -Be ('{' + "`n" + '  "a": [],' + "`n" + '  "big": 12345678901234,' + "`n" + '  "d": 1.5,' + "`n" + '  "f": false,' + "`n" + '  "i": 42,' + "`n" + '  "n": null,' + "`n" + '  "o": {}' + "`n" + '}')
        }

        It 'escapes quotes, backslashes and control characters, and keeps non-ASCII text' {
            $r = Invoke-Sanitize -Json (Get-RawExportJson)
            $r.Json | Should -Match '"quoted": "He said \\"hi\\"\\nnew line\\ttab \\\\ backslash"'
            $r.Json | Should -Match ('"unicodeName": "Z' + [char]0x00FC + 'rich ' + [char]0x2192 + ' B' + [char]0x00E4 + 'ren"')
            $r.Json | Should -Not -Match '\\u003c'
        }

        It 'writes DateTime values as ISO 8601 strings' {
            $utc = [datetime]::new(2026, 3, 4, 5, 6, 7, [System.DateTimeKind]::Utc)
            ConvertTo-StableJson -Value $utc | Should -Be '"2026-03-04T05:06:07Z"'
            $unspecified = [datetime]::new(2026, 3, 4, 5, 6, 7, [System.DateTimeKind]::Unspecified)
            ConvertTo-StableJson -Value $unspecified | Should -Be '"2026-03-04T05:06:07"'
        }

        It 'round-trips as valid JSON and is idempotent' {
            $first = Invoke-Sanitize -Json (Get-RawExportJson) -ContextArgs @{ TenantId = $script:tenant }
            { $first.Json | ConvertFrom-Json } | Should -Not -Throw
            $second = Invoke-Sanitize -Json $first.Json -ContextArgs @{ TenantId = $script:tenant }
            $second.Json | Should -Be $first.Json
            $second.Context.Stats.PropertiesRemoved | Should -Be 0
            $second.Context.Stats.ValuesReplaced | Should -Be 0
        }

        It 'handles a top-level array' {
            $r = Invoke-Sanitize -Json ('[ { "id": "' + $script:objectId + '", "name": "a" }, { "name": "b" } ]')
            $r.Json | Should -Be ('[' + "`n" + '  {' + "`n" + '    "name": "a"' + "`n" + '  },' + "`n" + '  {' + "`n" + '    "name": "b"' + "`n" + '  }' + "`n" + ']')
        }
    }

    Context 'File mode' {
        BeforeEach {
            $script:work = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path (Join-Path $script:work 'exports' 'sub') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:work 'exports' 'policy-a.json') -Value (Get-RawExportJson) -Encoding UTF8 -NoNewline
            Set-Content -LiteralPath (Join-Path $script:work 'exports' 'sub' 'policy-b.json') -Value (Get-RawExportJson) -Encoding UTF8 -NoNewline
        }

        It 'writes a sibling .sanitized.json by default and returns a summary' {
            $file = Join-Path $script:work 'exports' 'policy-a.json'
            $summary = & $script:scriptPath -Path $file -TenantId $script:tenant
            $summary.Destination | Should -Be (Join-Path $script:work 'exports' 'policy-a.sanitized.json')
            Test-Path $summary.Destination | Should -BeTrue
            $summary.PropertiesRemoved | Should -BeGreaterThan 0
            $summary.ValuesReplaced | Should -BeGreaterThan 0
            $summary.Placeholders | Should -Contain '<TENANT-ID>'
        }

        It 'mirrors folder structure under -OutputPath and skips .sanitized.json files' {
            $out = Join-Path $script:work 'artifacts' 'policies' 'configuration'
            Set-Content -LiteralPath (Join-Path $script:work 'exports' 'old.sanitized.json') -Value '{ "a": 1 }' -Encoding UTF8
            $summaries = @(& $script:scriptPath -Path (Join-Path $script:work 'exports') -OutputPath $out -TenantId $script:tenant)
            $summaries.Count | Should -Be 2
            Test-Path (Join-Path $out 'policy-a.json') | Should -BeTrue
            Test-Path (Join-Path $out 'sub' 'policy-b.json') | Should -BeTrue
        }

        It 'writes UTF-8 without BOM and LF line endings' {
            $file = Join-Path $script:work 'exports' 'policy-a.json'
            $summary = & $script:scriptPath -Path $file
            $bytes = [System.IO.File]::ReadAllBytes($summary.Destination)
            $bytes[0] | Should -Be ([byte][char]'{')
            ($bytes -contains 13) | Should -BeFalse
            $bytes[-1] | Should -Be 10
        }

        It '-InPlace overwrites the input' {
            $file = Join-Path $script:work 'exports' 'policy-a.json'
            $before = Get-Content $file -Raw
            $summary = & $script:scriptPath -Path $file -InPlace
            $summary.Destination | Should -Be $file
            (Get-Content $file -Raw) | Should -Not -Be $before
            (Get-Content $file -Raw) | Should -Not -Match 'createdDateTime'
        }

        It '-WhatIf writes nothing' {
            $file = Join-Path $script:work 'exports' 'policy-a.json'
            & $script:scriptPath -Path $file -WhatIf | Out-Null
            Test-Path (Join-Path $script:work 'exports' 'policy-a.sanitized.json') | Should -BeFalse
        }

        It 'rejects -InPlace together with -OutputPath, a non-GUID tenant id, and a missing path' {
            $file = Join-Path $script:work 'exports' 'policy-a.json'
            { & $script:scriptPath -Path $file -InPlace -OutputPath $script:work } | Should -Throw '*cannot be combined*'
            { & $script:scriptPath -Path $file -TenantId 'not-a-guid' } | Should -Throw '*must be a GUID*'
            { & $script:scriptPath -Path (Join-Path $script:work 'nope.json') } | Should -Throw '*not found*'
            { & $script:scriptPath } | Should -Throw '*Specify -Path*'
        }

        It 'reads a name map file' {
            $map = Join-Path $script:work 'names.json'
            Set-Content -LiteralPath $map -Value ('{ "groups": { "' + $script:group1 + '": "WIN-Ring-R1" }, "filters": { "' + $script:filter1 + '": "Corporate Windows" } }') -Encoding UTF8
            $file = Join-Path $script:work 'exports' 'policy-a.json'
            $obj = & $script:scriptPath -Path $file -NameMapPath $map -PassThru
            $obj['assignments'][0]['target']['groupId'] | Should -Be '<GROUP:WIN-Ring-R1>'
            $obj['assignments'][0]['target']['deviceAndAppManagementAssignmentFilterId'] | Should -Be '<FILTER:Corporate Windows>'
        }

        It 'produces output that passes the sanitization guard, from input that fails it' {
            $out = Join-Path $script:work 'artifacts' 'policies' 'configuration'
            & $script:scriptPath -Path (Join-Path $script:work 'exports') -OutputPath $out -TenantId $script:tenant | Out-Null

            $rawFindings = @(& $script:guardPath -Path (Join-Path $script:work 'exports') -Quiet)
            $rawFindings.Count | Should -BeGreaterThan 0

            $cleanFindings = @(& $script:guardPath -Path (Join-Path $script:work 'artifacts') -Quiet)
            if ($cleanFindings.Count -gt 0) { $cleanFindings | Format-Table Rule, File, Line, Match -AutoSize | Out-String | Write-Host }
            $cleanFindings.Count | Should -Be 0
        }
    }
}
