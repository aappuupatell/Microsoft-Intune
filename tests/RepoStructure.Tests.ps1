# Keeps README.md's "Repo structure" block in sync with reality.
#
# The block is parsed as a tree. Every entry ending in "/" must exist as a directory and
# contain a README.md (git cannot track empty folders, and the README is what tells a
# newcomer what belongs there). Every entry without a trailing "/" must exist as a file.
# Conversely, every top-level directory in the repo (other than the ignored list below)
# must appear in the block, so the README cannot silently fall behind.
#
# Pester 5 runs this file's top level during discovery only, and -ForEach data is built
# then. Everything a test needs at run time is therefore passed in through -ForEach.

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw

# Top-level items that are intentionally not in the tree block.
$ignoredTopLevel = @('.git', 'node_modules', '.vscode')

# Listed folders that must NOT get a README.md. GitHub surfaces .github/README.md in
# preference to the root README, which would hide the real one.
$noReadmeDirs = @('.github/')

function Get-StructureBlock {
    param([string]$Markdown)
    $m = [regex]::Match($Markdown, '(?ms)^## Repo structure\s*\n.*?```[a-z]*\s*\n(?<block>.*?)\n```')
    if (-not $m.Success) { throw 'README.md has no fenced code block under "## Repo structure".' }
    return $m.Groups['block'].Value -split "`r?`n"
}

function ConvertFrom-TreeBlock {
    param([string[]]$Lines)
    $entries = New-Object System.Collections.Generic.List[string]
    $stack = @{}
    foreach ($line in $Lines) {
        $m = [regex]::Match($line, '^(?<prefix>[\u2502\s]*)(?<branch>[\u251C\u2514])\u2500\u2500\s(?<name>[^\s#]+)')
        if (-not $m.Success) { continue }
        $depth = [int]([math]::Floor($m.Groups['prefix'].Value.Length / 4))
        $name = $m.Groups['name'].Value
        $parts = @()
        for ($d = 0; $d -lt $depth; $d++) { $parts += $stack[$d] }
        $stack[$depth] = $name.TrimEnd('/')
        foreach ($k in @($stack.Keys)) { if ($k -gt $depth) { $stack.Remove($k) } }
        $entries.Add((($parts + $name) -join '/').Replace('//', '/'))
    }
    return $entries
}

$entries = @(ConvertFrom-TreeBlock (Get-StructureBlock $readme))

$dirCases = @($entries | Where-Object { $_.EndsWith('/') } | ForEach-Object {
        @{ Path = $_; Root = $repoRoot; NeedsReadme = ($noReadmeDirs -notcontains $_) }
    })
$fileCases = @($entries | Where-Object { -not $_.EndsWith('/') } | ForEach-Object {
        @{ Path = $_; Root = $repoRoot }
    })
$summaryCase = @(@{ Entries = $entries; Root = $repoRoot; Ignored = $ignoredTopLevel })

Describe 'README repo structure block' {

    It 'parses to at least 20 entries' -ForEach $summaryCase {
        $Entries.Count | Should -BeGreaterOrEqual 20
    }

    It 'every listed directory exists: <Path>' -ForEach $dirCases {
        Test-Path -LiteralPath (Join-Path $Root $Path) -PathType Container | Should -BeTrue -Because "README lists $Path as a folder"
    }

    It 'every listed directory has a README.md: <Path>' -ForEach ($dirCases | Where-Object { $_.NeedsReadme }) {
        $readmePath = Join-Path (Join-Path $Root $Path) 'README.md'
        Test-Path -LiteralPath $readmePath -PathType Leaf | Should -BeTrue -Because "$Path needs a README.md explaining what belongs there"
    }

    It '.github/ has no README.md (it would replace the root README on GitHub)' -ForEach $summaryCase {
        Test-Path -LiteralPath (Join-Path $Root '.github/README.md') | Should -BeFalse
    }

    It 'every listed file exists: <Path>' -ForEach $fileCases {
        Test-Path -LiteralPath (Join-Path $Root $Path) -PathType Leaf | Should -BeTrue
    }

    It 'every top-level directory in the repo appears in the block' -ForEach $summaryCase {
        $listedTop = $Entries | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique
        $actualTop = Get-ChildItem -LiteralPath $Root -Directory -Force |
            Where-Object { $Ignored -notcontains $_.Name } |
            Select-Object -ExpandProperty Name
        foreach ($d in $actualTop) {
            $listedTop | Should -Contain $d -Because "top-level folder $d/ exists but README's structure block does not mention it"
        }
    }
}
