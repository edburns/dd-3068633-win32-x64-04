[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$N,

    [ValidateSet('fibonacci', 'factorial')]
    [string]$Operation = 'fibonacci'
)

function Get-Fibonacci {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$N
    )

    $previous = [bigint]0
    $current = [bigint]1

    for ($index = 0; $index -lt $N; $index++) {
        $next = $previous + $current
        $previous = $current
        $current = $next
    }

    return $previous
}

function Get-Factorial {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$N
    )

    $result = [bigint]1

    for ($factor = 2; $factor -le $N; $factor++) {
        $result *= $factor
    }

    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($Operation -eq 'fibonacci') {
        $result = Get-Fibonacci -N $N
        $label = 'Fibonacci'
    }
    else {
        $result = Get-Factorial -N $N
        $label = 'Factorial'
    }

    Write-Output "$label($N) = $result"
}
