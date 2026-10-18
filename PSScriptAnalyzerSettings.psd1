@{
    # PSScriptAnalyzer settings for Intune Atlas.
    # Run locally:  Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
    # CI runs the same command and fails on any Error or Warning.

    Severity            = @('Error', 'Warning')
    IncludeDefaultRules = $true

    ExcludeRules        = @(
        # Intune remediation and platform scripts commonly use Write-Host for the
        # output the Intune Management Extension captures. Microsoft's own sample
        # remediation scripts do the same, so contributions should not fail on it.
        'PSAvoidUsingWriteHost'
    )

    Rules               = @{
        # Everything in this repo must parse on Windows PowerShell 5.1, because the
        # Intune Management Extension runs scripts with 5.1 on endpoints. Flags
        # PowerShell 7-only syntax (ternary, null-coalescing, pipeline chain operators).
        PSUseCompatibleSyntax      = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }

        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace  = @{
            Enable          = $true
            CheckInnerBrace = $true
            CheckOpenBrace  = $true
            CheckOpenParen  = $true
            CheckOperator   = $false
            CheckPipe       = $true
            CheckSeparator  = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $false
            CheckHashtable = $false
        }
    }
}
