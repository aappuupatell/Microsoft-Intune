# Keeps README.md's "Repo structure" block in sync with reality.
#
# The block is parsed as a tree. Every entry ending in "/" must exist as a directory and
# contain a README.md (git cannot track empty folders, and the README is what tells a
# newcomer what belongs there). Every entry without a trailing "/" must exist as a file.
# Conversely, every top-level directory in the repo (other than the ignored list below)
# must appear in the block, so the README cannot silently fall behind.

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:readme = Get-Content (Join-Path $script:repoRoot 'README.md') -Raw

    # Top-level items that are intentionally not in the tree block.
    $script:ignoredTopLevel = @('.git', 'node_modules', '.vscode')

    # Listed folders that must NOT get a README.md. GitHub surfaces .github/README.md in
    # preference to the root README, which would hide the real one.
    $script:noReadmeDirs = @('.github/')

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

    $script:entries = ConvertFrom-TreeBlock (Get-StructureBlock $script:readme)
}

Describe 'README repo structure block' {

    It 'parses to at least 20 entries' {
        $script:entries.Count | Should -BeGreaterOrEqual 20
    }

    It 'every listed directory exists: <_>' -ForEach ($script:entries | Where-Object { $_.EndsWith('/') }) {
        $dir = Join-Path $script:repoRoot $_
        Test-Path -LiteralPath $dir -PathType Container | Should -BeTrue -Because "README lists $_ as a folder"
    }

    It 'every listed directory has a README.md: <_>' -ForEach ($script:entries | Where-Object { $_.EndsWith('/') -and $script:noReadmeDirs -notcontains $_ }) {
        $readmePath = Join-Path (Join-Path $script:repoRoot $_) 'README.md'
        Test-Path -LiteralPath $readmePath -PathType Leaf | Should -BeTrue -Because "$_ needs a README.md explaining what belongs there"
    }

    It '.github/ has no README.md (it would replace the root README on GitHub)' {
        Test-Path -LiteralPath (Join-Path $script:repoRoot '.github/README.md') | Should -BeFalse
    }

    It 'every listed file exists: <_>' -ForEach ($script:entries | Where-Object { -not $_.EndsWith('/') }) {
        Test-Path -LiteralPath (Join-Path $script:repoRoot $_) -PathType Leaf | Should -BeTrue
    }

    It 'every top-level directory in the repo appears in the block' {
        $listedTop = $script:entries | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique
        $actualTop = Get-ChildItem -LiteralPath $script:repoRoot -Directory -Force |
            Where-Object { $script:ignoredTopLevel -notcontains $_.Name } |
            Select-Object -ExpandProperty Name
        foreach ($d in $actualTop) {
            $listedTop | Should -Contain $d -Because "top-level folder $d/ exists but README's structure block does not mention it"
        }
    }
}
