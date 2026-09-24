BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot 'math-tool.ps1'
    . $scriptPath -N 0
}

Describe 'Get-Fibonacci' {
    It 'returns 0 for N=0' {
        Get-Fibonacci -N 0 | Should -Be 0
    }

    It 'returns 1 for N=1' {
        Get-Fibonacci -N 1 | Should -Be 1
    }

    It 'returns 5 for N=5 without incidental output' {
        $result = @(Get-Fibonacci -N 5)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType ([bigint])
        $result[0] | Should -Be 5
    }
}

Describe 'math-tool direct execution' {
    It 'writes exactly one formatted Fibonacci result line' {
        $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
        $output = @(& $pwsh -NoLogo -NoProfile -File $scriptPath -N 5)

        $LASTEXITCODE | Should -Be 0
        $output | Should -HaveCount 1
        $output[0] | Should -BeExactly 'Fibonacci(5) = 5'
    }
}
