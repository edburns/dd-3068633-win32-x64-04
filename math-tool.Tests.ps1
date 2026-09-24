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

Describe 'Get-Factorial' {
    It 'returns 1 for N=0' {
        Get-Factorial -N 0 | Should -Be 1
    }

    It 'returns 1 for N=1' {
        Get-Factorial -N 1 | Should -Be 1
    }

    It 'returns 120 for N=5 without incidental output' {
        $result = @(Get-Factorial -N 5)

        $result | Should -HaveCount 1
        $result[0] | Should -BeOfType ([bigint])
        $result[0] | Should -Be 120
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

    It 'writes exactly one formatted Factorial result line' {
        $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
        $output = @(& $pwsh -NoLogo -NoProfile -File $scriptPath -N 5 -Operation factorial)

        $LASTEXITCODE | Should -Be 0
        $output | Should -HaveCount 1
        $output[0] | Should -BeExactly 'Factorial(5) = 120'
    }

    It 'dispatches the same N to the requested operation' {
        $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
        $fibonacciOutput = @(& $pwsh -NoLogo -NoProfile -File $scriptPath -N 5 -Operation fibonacci)
        $factorialOutput = @(& $pwsh -NoLogo -NoProfile -File $scriptPath -N 5 -Operation factorial)

        $fibonacciOutput | Should -BeExactly 'Fibonacci(5) = 5'
        $factorialOutput | Should -BeExactly 'Factorial(5) = 120'
    }

    It 'rejects an unsupported operation' {
        $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
        $null = & $pwsh -NoLogo -NoProfile -File $scriptPath -N 5 -Operation unsupported 2>&1

        $LASTEXITCODE | Should -Not -Be 0
    }
}
