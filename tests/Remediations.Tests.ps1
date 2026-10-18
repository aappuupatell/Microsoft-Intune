# Mechanical checks for the remediation contract described in remediations/README.md.
#
# For every remediations/detection/Detect-<Name>.ps1:
#   - remediations/remediation/Remediate-<Name>.ps1 exists, OR <Name> is listed under the
#     "Detection-only packages" heading in remediations/README.md
#   - remediations/docs/<Name>.md exists and has the required headings
#   - the detection script contains both "exit 1" and "exit 0"
#   - no script in the pair uses Write-Host (output must go to stdout via Write-Output)
#   - no script is larger than 200 KB (Intune's platform script limit; remediations are smaller still)
# Orphaned remediation scripts and docs (no matching detection) are also reported.

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:remRoot = Join-Path $script:repoRoot 'remediations'
    $script:detectDir = Join-Path $script:remRoot 'detection'
    $script:remediateDir = Join-Path $script:remRoot 'remediation'
    $script:docsDir = Join-Path $script:remRoot 'docs'

    $script:requiredHeadings = @(
        'What it checks',
        'What it changes',
        'What it does not touch',
        'Run context',
        'Schedule',
        'Rollback'
    )

    $script:detectionOnly = @()
    $contract = Join-Path $script:remRoot 'README.md'
    if (Test-Path $contract) {
        $text = Get-Content $contract -Raw
        $m = [regex]::Match($text, '(?ms)^##+\s*Detection-only packages\s*\n(?<body>.*?)(?=^##\s|\z)')
        if ($m.Success) {
            $script:detectionOnly = [regex]::Matches($m.Groups['body'].Value, '`Detect-(?<name>[A-Za-z0-9]+)\.ps1`') |
                ForEach-Object { $_.Groups['name'].Value }
        }
    }

    $script:pairs = @()
    if (Test-Path $script:detectDir) {
        $script:pairs = Get-ChildItem $script:detectDir -Filter 'Detect-*.ps1' -File | ForEach-Object {
            $name = $_.BaseName.Substring('Detect-'.Length)
            [pscustomobject]@{
                Name      = $name
                Detect    = $_.FullName
                Remediate = Join-Path $script:remediateDir "Remediate-$name.ps1"
                Doc       = Join-Path $script:docsDir "$name.md"
            }
        }
    }
}

Describe 'Remediation pairs' {

    It 'has a remediations/README.md contract' {
        Test-Path (Join-Path $script:remRoot 'README.md') | Should -BeTrue
    }

    Context 'Pair <_.Name>' -ForEach $script:pairs {

        It 'has a remediation script or is declared detection-only' {
            $isDetectionOnly = $script:detectionOnly -contains $_.Name
            if (-not $isDetectionOnly) {
                Test-Path $_.Remediate | Should -BeTrue -Because "Remediate-$($_.Name).ps1 must exist or the pair must be listed under 'Detection-only packages' in remediations/README.md"
            }
        }

        It 'has a doc at remediations/docs/<Name>.md' {
            Test-Path $_.Doc | Should -BeTrue
        }

        It 'doc has every required heading' {
            if (Test-Path $_.Doc) {
                $doc = Get-Content $_.Doc -Raw
                foreach ($h in $script:requiredHeadings) {
                    $doc | Should -Match ("(?m)^##+\s*" + [regex]::Escape($h)) -Because "the doc for $($_.Name) must have a '$h' section"
                }
            }
        }

        It 'detection script exits 1 on found and 0 on not found' {
            $src = Get-Content $_.Detect -Raw
            $src | Should -Match '(?im)^\s*exit\s+1\b'
            $src | Should -Match '(?im)^\s*exit\s+0\b'
        }

        It 'scripts do not use Write-Host' {
            $files = @($_.Detect) + @(if (Test-Path $_.Remediate) { $_.Remediate })
            foreach ($f in $files) {
                (Get-Content $f -Raw) | Should -Not -Match '(?i)\bWrite-Host\b' -Because "$f must write output with Write-Output so the Intune Management Extension captures it"
            }
        }

        It 'scripts are under 200 KB' {
            $files = @($_.Detect) + @(if (Test-Path $_.Remediate) { $_.Remediate })
            foreach ($f in $files) {
                (Get-Item $f).Length | Should -BeLessThan 204800
            }
        }

        It 'scripts declare the Intune run context in comment-based help' {
            $files = @($_.Detect) + @(if (Test-Path $_.Remediate) { $_.Remediate })
            foreach ($f in $files) {
                (Get-Content $f -Raw) | Should -Match '(?i)\.NOTES' -Because "$f needs a .NOTES block stating run context and validation status"
            }
        }
    }

    It 'has no orphaned remediation scripts' {
        if (Test-Path $script:remediateDir) {
            $orphans = Get-ChildItem $script:remediateDir -Filter 'Remediate-*.ps1' -File | Where-Object {
                $name = $_.BaseName.Substring('Remediate-'.Length)
                -not (Test-Path (Join-Path $script:detectDir "Detect-$name.ps1"))
            }
            @($orphans).Count | Should -Be 0 -Because ("every remediation needs a detection: " + (($orphans | ForEach-Object Name) -join ', '))
        }
    }

    It 'has no orphaned remediation docs' {
        if (Test-Path $script:docsDir) {
            $orphans = Get-ChildItem $script:docsDir -Filter '*.md' -File | Where-Object {
                $_.Name -ne 'README.md' -and -not (Test-Path (Join-Path $script:detectDir "Detect-$($_.BaseName).ps1"))
            }
            @($orphans).Count | Should -Be 0 -Because ("every doc needs a detection script: " + (($orphans | ForEach-Object Name) -join ', '))
        }
    }
}
