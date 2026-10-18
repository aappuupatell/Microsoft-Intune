# Pester 5 tests for .github/scripts/Test-RepoSanitized.ps1
#
# Fixture strings are assembled at run time (concatenation, repetition) so that this
# test file never itself contains anything that looks like a secret or identifier.

BeforeAll {
    $script:guard = Join-Path $PSScriptRoot '..' '.github' 'scripts' 'Test-RepoSanitized.ps1'
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:realGuid = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d'

    # Each test gets its own fixture root so files from one test never leak into the next.
    function Write-Fixture {
        param([string]$RelativePath, [string]$Content, [switch]$Bom)
        $full = Join-Path $script:fixtureRoot $RelativePath
        $dir = Split-Path $full -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $encoding = if ($Bom) { New-Object System.Text.UTF8Encoding($true) } else { New-Object System.Text.UTF8Encoding($false) }
        [System.IO.File]::WriteAllText($full, $Content, $encoding)
        return $full
    }

    function Invoke-Guard {
        param([string]$Path = $script:fixtureRoot)
        @(& $script:guard -Path $Path -Quiet)
    }
}

Describe 'Test-RepoSanitized.ps1' {

    BeforeEach {
        $script:fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
    }

    Context 'Clean content' {
        It 'reports nothing for a clean tree with placeholders' {
            Write-Fixture 'docs/clean.md' @'
# Clean doc
Tenant: <TENANT-ID>
Group: <GROUP-OBJECT-ID>
Contact: admin@contoso.com or user@contoso.onmicrosoft.com
'@ | Out-Null
            Write-Fixture 'artifacts/policies/compliance/clean.json' @'
{
  "displayName": "Windows - Baseline compliance",
  "roleScopeTagIds": [ "0" ],
  "assignments": [ { "target": { "groupId": "<GROUP-OBJECT-ID>" } } ],
  "settings": [ { "id": "0", "settingInstance": { "settingDefinitionId": "device_vendor_msft_bitlocker_requiredeviceencryption" } } ]
}
'@ | Out-Null
            Write-Fixture 'scripts/powershell/Clean.ps1' "param([string]`$TenantId = '<TENANT-ID>')`r`nWrite-Output 'ok'`r`n" | Out-Null
            (Invoke-Guard).Count | Should -Be 0
        }

        It 'ignores the empty GUID and $variables in known keys' {
            Write-Fixture 'artifacts/x.json' ('{ "tenantId": "00000000-0000-0000-0000-000000000000", "groupId": "$GroupId" }') | Out-Null
            (Invoke-Guard).Count | Should -Be 0
        }
    }

    Context 'Secrets' {
        It 'flags a GitHub token' {
            Write-Fixture 'docs/leak.md' ('token: ' + 'ghp_' + ('A' * 36)) | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'GitHubToken').Count | Should -Be 1
        }

        It 'flags a private key block' {
            Write-Fixture 'scripts/key.txt' ('-----BEGIN ' + 'RSA PRIVATE KEY-----') | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'PrivateKeyBlock').Count | Should -Be 1
        }

        It 'flags a JWT' {
            $jwt = 'eyJ' + ('a' * 20) + '.' + ('b' * 20) + '.' + ('c' * 20)
            Write-Fixture 'docs/jwt.md' $jwt | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'JwtToken').Count | Should -Be 1
        }

        It 'flags a literal client secret assignment but not a placeholder' {
            Write-Fixture 'scripts/a.ps1' ('$clientSecret = "' + ('Q' * 30) + '"') | Out-Null
            Write-Fixture 'scripts/b.ps1' '$clientSecret = "<CLIENT-SECRET>"' | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'SecretAssignment'
            $r.Count | Should -Be 1
            $r.File | Should -Be 'scripts/a.ps1'
        }

        It 'flags a long base64 blob (hardware hash shape)' {
            Write-Fixture 'examples/hash.txt' ('T0' * 500) | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'HardwareHashOrBinaryBlob').Count | Should -Be 1
        }
    }

    Context 'Identifiers' {
        It 'flags a real tenant domain (also the .mail routing form) and allows placeholders' {
            Write-Fixture 'docs/t.md' 'Real: northwindtraders99.onmicrosoft.com and northwindtraders99.mail.onmicrosoft.com; fake: contoso.onmicrosoft.com and <label>.mail.onmicrosoft.com' | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'TenantDomain'
            $r.Count | Should -Be 2
        }

        It 'flags a real e-mail address and allows placeholder domains' {
            Write-Fixture 'docs/e.md' 'Write to kim.lee@northwindtraders99.example-corp.io or admin@contoso.com' | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'EmailOrUpn'
            $r.Count | Should -Be 1
        }

        It 'flags guest, URL-encoded, non-ASCII and admin@ addresses on real domains' {
            Write-Fixture 'docs/e2.md' ('guest kim_northwind99.com#EXT#@northwind99.onmicrosoft.com ; encoded kim.lee%40northwind99.com ; unicode kim.m' + [char]0x00FC + 'ller@northwind99.com ; admin@northwind99.com') | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'EmailOrUpn'
            $r.Count | Should -Be 4
        }

        It 'does not flag JSON keys that look like addresses (definition@odata.bind, settings@odata.context)' {
            Write-Fixture 'artifacts/admx.json' '{ "definition@odata.bind": "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions(''x'')", "settings@odata.context": "y" }' | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'EmailOrUpn').Count | Should -Be 0
        }

        It 'flags secrets in JSON form and under Wi-Fi / VPN key names' {
            Write-Fixture 'artifacts/secrets.json' ('{ "password": "' + ('P' * 20) + '", "preSharedKey": "' + ('K' * 20) + '", "sharedSecret": "<SECRET>" }') | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'SecretAssignment').Count | Should -Be 2
        }

        It 'flags a GUID in tenantId / groupId keys' {
            Write-Fixture 'docs/ids.json' ('{ "tenantId": "' + $script:realGuid + '", "target": { "groupId": "' + $script:realGuid + '" } }') | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'TenantObjectIdInJson').Count | Should -Be 2
        }

        It 'flags device identifiers in known keys' {
            Write-Fixture 'artifacts/reports/sample.json' '{ "serialNumber": "5CG1234ABC", "userPrincipalName": "<UPN>" }' | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'DeviceOrUserIdentifierInJson'
            $r.Count | Should -Be 1
        }

        It 'flags a CSV of hardware hashes with data rows but not a header-only sample' {
            Write-Fixture 'examples/hashes.csv' "Device Serial Number,Windows Product ID,Hardware Hash`nABC123,00330-00000-00000-AA000,QUJD`n" | Out-Null
            Write-Fixture 'examples/header-only.csv' "Device Serial Number,Windows Product ID,Hardware Hash`n" | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'DeviceIdentifierCsv'
            $r.Count | Should -Be 1
            $r.File | Should -Be 'examples/hashes.csv'
        }
    }

    Context 'Unsanitized exports under artifacts/' {
        It 'flags raw Graph export metadata only inside artifacts/' {
            $raw = '{ "id": "' + $script:realGuid + '", "createdDateTime": "2026-01-01T00:00:00Z", "displayName": "x" }'
            Write-Fixture 'artifacts/policies/configuration/raw.json' $raw | Out-Null
            Write-Fixture 'docs/example-response.json' $raw | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'UnsanitizedExportMetadata'
            $r.Count | Should -Be 2
            ($r.File | Sort-Object -Unique) | Should -Be @('artifacts/policies/configuration/raw.json')
        }

        It 'does not flag non-GUID setting ids' {
            Write-Fixture 'artifacts/policies/configuration/ok.json' '{ "settings": [ { "id": "0" }, { "id": "1" } ] }' | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'UnsanitizedExportMetadata').Count | Should -Be 0
        }
    }

    Context 'Script hygiene' {
        It 'flags a UTF-8 BOM in a script' {
            Write-Fixture 'scripts/bom.ps1' "Write-Output 'hi'`r`n" -Bom | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'ScriptHasBom').Count | Should -Be 1
        }

        It 'flags non-ASCII characters in a script with the right line number' {
            Write-Fixture 'scripts/smart.ps1' ("Write-Output 'line one'`r`nWrite-Output 'caf" + [char]0x00E9 + "'`r`n") | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'NonAsciiInScript'
            $r.Count | Should -Be 1
            $r.Line | Should -Be 2
        }

        It 'does not flag non-ASCII in Markdown' {
            Write-Fixture 'docs/unicode.md' ('Arrows and em dash: ' + [char]0x2192 + ' ' + [char]0x2014) | Out-Null
            (Invoke-Guard).Count | Should -Be 0
        }

        It 'flags Invoke-Expression and iex in scripts/ and remediations/ only' {
            Write-Fixture 'scripts/x.ps1' 'Invoke-Expression $cmd' | Out-Null
            Write-Fixture 'remediations/y/Remediate-Y.ps1' 'iex $cmd' | Out-Null
            Write-Fixture 'docs/z.ps1' 'Invoke-Expression $cmd' | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'InvokeExpression').Count | Should -Be 2
        }

        It 'flags download-and-execute' {
            Write-Fixture 'scripts/dl.ps1' 'Invoke-WebRequest https://example.com/x.ps1 | iex' | Out-Null
            (Invoke-Guard | Where-Object Rule -eq 'DownloadAndExecute').Count | Should -Be 1
        }

        It 'flags PSGallery installs inside remediations/ but not scripts/' {
            Write-Fixture 'remediations/a/Remediate-A.ps1' 'Install-Module Foo -Force' | Out-Null
            Write-Fixture 'scripts/powershell/Setup.ps1' 'Install-Module Microsoft.Graph.Authentication' | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'GalleryInstallInRemediation'
            $r.Count | Should -Be 1
            $r.File | Should -Be 'remediations/a/Remediate-A.ps1'
        }

        It 'flags persistent execution policy weakening but allows process scope' {
            Write-Fixture 'scripts/ep1.ps1' 'Set-ExecutionPolicy Bypass -Force' | Out-Null
            Write-Fixture 'scripts/ep2.ps1' 'Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force' | Out-Null
            $r = Invoke-Guard | Where-Object Rule -eq 'ExecutionPolicyWeakening'
            $r.Count | Should -Be 1
            $r.File | Should -Be 'scripts/ep1.ps1'
        }
    }

    Context 'Suppression and failure mode' {
        It 'skips a line carrying the sanitize-allow marker' {
            Write-Fixture 'docs/allowed.md' ('token ghp_' + ('B' * 36) + '  <!-- sanitize-allow: documented example -->') | Out-Null
            (Invoke-Guard).Count | Should -Be 0
        }

        It 'throws with -FailOnFindings when something is found' {
            Write-Fixture 'docs/leak.md' ('ghp_' + ('C' * 36)) | Out-Null
            { & $script:guard -Path $script:fixtureRoot -Quiet -FailOnFindings } | Should -Throw -ExpectedMessage '*Sanitization guard found 1 issue*'
        }

        It 'does not throw with -FailOnFindings when clean' {
            Write-Fixture 'docs/ok.md' 'nothing here' | Out-Null
            { & $script:guard -Path $script:fixtureRoot -Quiet -FailOnFindings } | Should -Not -Throw
        }
    }

    Context 'This repository' {
        It 'is clean' {
            $r = Invoke-Guard -Path $script:repoRoot
            if ($r.Count -gt 0) { $r | Format-Table Rule, File, Line, Match -AutoSize | Out-String | Write-Host }
            $r.Count | Should -Be 0
        }
    }
}
