#  Pester v5 tests for the WslCompact module.
#  Run with:  Invoke-Pester -Path ./Tests   (Pester 5.x required)
#
#  Compatible with Windows PowerShell 5.1 and PowerShell 7+ pwsh
#  (no ternary operator, no ?? operator).
#
#  Culture caveat: Format-Size uses the culture-sensitive 'N0'/'N1' format
#  specifiers, so group and decimal separators follow $PSCulture. Assertions
#  like '^12,34[56] MB$' or '15.0 GB' assume en-US-style separators; on other
#  cultures those specific assertions may need loosening.
#
#  Platform caveat: the locked-file Test-VhdxFree case relies on the runtime
#  honoring FileShare::None across handles. .NET Framework (Windows PS 5.1)
#  and .NET 6+ enforce it everywhere; older .NET Core runtimes on Linux may
#  not, in which case that single test could report $true.

BeforeAll {
    Import-Module "$PSScriptRoot/../WslCompact/WslCompact.psm1" -Force
}

# Format-Size, Test-VhdxFree and Test-SpaceOk are module-internal helpers,
# not exported, so everything below runs through InModuleScope.
InModuleScope WslCompact {

    Describe 'Format-Size' {
        It 'formats values below the GB threshold as whole MB' {
            Format-Size 512 | Should -Be '512 MB'
        }

        It 'rounds fractional MB input to whole MB' {
            # [math]::Round(12345.67890625) -> 12346; grouping separator is
            # culture-dependent (see file header caveat).
            Format-Size 12345.67890625 | Should -Match '^12,34[56](\.\d)? MB$'
        }

        It 'formats values at or above the GB threshold with one decimal' {
            Format-Size 15360 | Should -Be '15.0 GB'
        }

        It 'treats 10239 MB (just below threshold) as MB' {
            $out = Format-Size 10239
            ($out -match 'MB$') | Should -BeTrue
            ($out -notmatch 'GB') | Should -BeTrue
        }

        It 'treats 10240 MB (exactly at threshold) as GB' {
            Format-Size 10240 | Should -Match 'GB$'
        }
    }

    Describe 'Test-VhdxFree' {
        It 'returns true when the file is not locked' {
            $path = Join-Path ([IO.Path]::GetTempPath()) ("wslcompact-test-$([guid]::NewGuid()).vhdx")
            New-Item -Path $path -ItemType File -Force | Out-Null
            try {
                Test-VhdxFree -Path $path | Should -BeTrue
            }
            finally {
                Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
            }
        }

        It 'returns false while another handle holds the file open exclusively' {
            $path = Join-Path ([IO.Path]::GetTempPath()) ("wslcompact-test-$([guid]::NewGuid()).vhdx")
            New-Item -Path $path -ItemType File -Force | Out-Null
            $fs = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                Test-VhdxFree -Path $path | Should -BeFalse
            }
            finally {
                if ($fs) { $fs.Close() }
                Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
            }
        }

        It 'returns false for a nonexistent path' {
            $missing = Join-Path ([IO.Path]::GetTempPath()) ("wslcompact-missing-$([guid]::NewGuid()).vhdx")
            Test-VhdxFree -Path $missing | Should -BeFalse
        }
    }

    Describe 'Test-SpaceOk' {
        It 'returns true when free space exceeds what is needed' {
            Test-SpaceOk -Path ([IO.Path]::GetTempPath()) -NeededBytes 1KB | Should -BeTrue
        }

        It 'returns false when more space is needed than exists' {
            Test-SpaceOk -Path ([IO.Path]::GetTempPath()) -NeededBytes ([int64]::MaxValue) | Should -BeFalse
        }
    }

    Describe 'WslCompact parameter validation' {
        It 'rejects unknown options' {
            { WslCompact -BadFlag } | Should -Throw
        }

        It 'rejects targets starting with a dash' {
            { WslCompact '-' } | Should -Throw
        }

        It 'rejects whitespace-only targets' {
            { WslCompact ' ' } | Should -Throw
        }
    }

    Describe 'WslCompact help and version output' {
        It '-h prints usage without invoking wsl.exe' {
            $out = WslCompact -h *>&1 | Out-String
            ($out -match 'Usage:') | Should -BeTrue
        }

        It '-v prints the version banner' {
            $out = WslCompact -v *>&1 | Out-String
            ($out -match 'WslCompact v') | Should -BeTrue
        }
    }

    Describe 'ConvertTo-WslArg quoting (MSVCRT argv rules)' {
        It 'leaves plain tokens bare' {
            InModuleScope WslCompact { ConvertTo-WslArg 'abc' } | Should -Be 'abc'
        }
        It 'wraps tokens containing spaces' {
            InModuleScope WslCompact { ConvertTo-WslArg 'a b' } | Should -Be '"a b"'
        }
        It 'doubles trailing backslashes' {
            InModuleScope WslCompact { ConvertTo-WslArg 'C:\path\' } | Should -Be 'C:\path\\'
        }
        It 'escapes and wraps tokens containing quotes' {
            InModuleScope WslCompact { ConvertTo-WslArg 'a"b' } | Should -Be '"a\"b"'
        }
        It 'escapes quotes inside wrapped tokens' {
            InModuleScope WslCompact { ConvertTo-WslArg 'say "hi"' } | Should -Be '"say \"hi\""'
        }
    }
}
