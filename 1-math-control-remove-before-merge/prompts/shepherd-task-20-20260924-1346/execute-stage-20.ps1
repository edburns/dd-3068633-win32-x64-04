[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repo = 'edburns/dd-3068633-win32-x64-04'
$parentIssue = 1
$expectedCount = 2
$selectedIssueType = ''
$logDirectory = $PSScriptRoot
$bodyDirectory = Join-Path $logDirectory 'issue-bodies'
$ledgerPath = Join-Path $logDirectory 'creation-ledger.json'
$resultPath = Join-Path $logDirectory 'stage-20-result.json'
$validator = 'C:\Users\edburns\.copilot\plugins\shepherd-task\scripts\validate-stage20-drafts.ps1'
$bodyVerifier = 'C:\Users\edburns\.copilot\plugins\shepherd-task\scripts\verify-github-issue-body.ps1'

$drafts = @(
    [ordered]@{
        implementationSubsection = '1. Implement Fibonacci with unit and isolated CLI coverage'
        title = '1. Implement Fibonacci with unit and isolated CLI coverage'
        bodyFile = Join-Path $bodyDirectory '01-1-implement-fibonacci-body.md'
    },
    [ordered]@{
        implementationSubsection = '2. Add factorial and operation dispatch'
        title = '2. Add factorial and operation dispatch'
        bodyFile = Join-Path $bodyDirectory '02-2-add-factorial-dispatch-body.md'
    }
)

function Write-AtomicJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][object]$Value
    )

    $temporaryPath = "$Path.tmp"
    $json = ConvertTo-Json -InputObject $Value -Depth 20
    [IO.File]::WriteAllText(
        $temporaryPath,
        $json + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

function Read-CreationLedger {
    $parsed = [IO.File]::ReadAllText($ledgerPath) |
        ConvertFrom-Json -NoEnumerate
    if ($parsed -isnot [System.Array]) {
        throw 'Creation ledger JSON root must be an array.'
    }

    $ledger = [object[]]$parsed
    if (@($ledger | Where-Object { $_ -is [System.Array] }).Count -ne 0) {
        throw 'Creation ledger must not contain nested array entries.'
    }
    return $ledger
}

function Write-CreationLedger {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Ledger)
    Write-AtomicJson -Path $ledgerPath -Value ([object[]]$Ledger)
}

function Set-LedgerFlag {
    param(
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][ValidateSet('body_verified', 'linked')][string]$Field,
        [Parameter(Mandatory)][bool]$Value
    )

    $ledger = @(Read-CreationLedger)
    $matchingEntries = @($ledger | Where-Object { $_.number -eq $Number })
    if ($matchingEntries.Count -ne 1) {
        throw "Expected exactly one ledger entry for issue #$Number."
    }
    $matchingEntries[0].$Field = $Value
    Write-CreationLedger -Ledger ([object[]]$ledger)
}

function Get-NormalizedChildren {
    $childrenOutput = & gh api "repos/$repo/issues/$parentIssue/sub_issues" --paginate --slurp 2>&1
    $childrenExitCode = $LASTEXITCODE
    if ($childrenExitCode -ne 0) {
        throw "Unable to query parent children: $($childrenOutput | Out-String)"
    }

    $completeJson = $childrenOutput | Out-String
    $normalizedOutput = $completeJson |
        & jq 'if length == 0 then [] elif all(.[]; type == "array") then add else . end' 2>&1
    $jqExitCode = $LASTEXITCODE
    if ($jqExitCode -ne 0) {
        throw "Unable to normalize parent children: $($normalizedOutput | Out-String)"
    }

    $parsed = ($normalizedOutput | Out-String) | ConvertFrom-Json -NoEnumerate
    if ($parsed -isnot [System.Array]) {
        throw 'Normalized child response root must be an array.'
    }
    $children = [object[]]$parsed
    if (@($children | Where-Object { $_ -is [System.Array] }).Count -ne 0) {
        throw 'Normalized child response must be a flat issue array.'
    }
    return $children
}

function Write-StageResult {
    param(
        [Parameter(Mandatory)][ValidateSet('in_progress', 'failed', 'complete')][string]$Status,
        [AllowNull()][AllowEmptyString()][object]$OperationError
    )

    $result = [ordered]@{
        schemaVersion = 1
        status = $Status
        ledgerFile = 'creation-ledger.json'
        operationError = $OperationError
    }
    Write-AtomicJson -Path $resultPath -Value $result
}

function Reconcile-Failure {
    param([Parameter(Mandatory)][string]$ErrorMessage)

    $ledger = @(Read-CreationLedger)
    $reconciliationError = $null
    try {
        $serverChildren = @(Get-NormalizedChildren)
        $linkedIds = @($serverChildren | ForEach-Object { [Int64]$_.id })
        foreach ($entry in $ledger) {
            $entry.linked = $linkedIds -contains [Int64]$entry.id
        }
        Write-CreationLedger -Ledger ([object[]]$ledger)
    }
    catch {
        $reconciliationError = $_.Exception.Message
    }

    $finalError = if ($null -eq $reconciliationError) {
        $ErrorMessage
    }
    else {
        "$ErrorMessage Reconciliation also failed: $reconciliationError"
    }
    Write-StageResult -Status failed -OperationError $finalError

    if ($ledger.Count -eq 0) {
        Write-Host 'No issues were created; no cleanup is required.'
    }
    else {
        Write-Host 'Reconciled creation ledger:'
        $ledger |
            Select-Object number, title, url, bodyFile, body_verified, linked |
            Format-Table -AutoSize |
            Out-String |
            Write-Host
        Write-Host 'Cleanup commands:'
        foreach ($entry in $ledger) {
            Write-Host "gh issue delete $($entry.number) --repo `"$repo`" --yes"
        }
    }
    Write-Host 'The operation did not complete and no automatic rollback was performed. Delete every issue in the ledger before invoking this skill again.'
}

& $validator `
    -BodyDirectory $bodyDirectory `
    -ExpectedCount $expectedCount `
    -LessonPropagation off |
    Out-Null

$baselineChildren = @(Get-NormalizedChildren)
Write-CreationLedger -Ledger ([object[]]@())
Write-StageResult -Status in_progress -OperationError $null

$operation = 'initialize stage'
try {
    foreach ($draft in $drafts) {
        $operation = "create issue for $($draft.implementationSubsection)"
        $createArguments = @(
            'api',
            "repos/$repo/issues",
            '-X', 'POST',
            '-f', "title=$($draft.title)",
            '-F', "body=@$($draft.bodyFile)"
        )
        if (-not [string]::IsNullOrEmpty($selectedIssueType)) {
            $createArguments += @('-f', "type=$selectedIssueType")
        }
        $createOutput = & gh @createArguments 2>&1
        $createExitCode = $LASTEXITCODE
        if ($createExitCode -ne 0) {
            throw "Issue creation failed: $($createOutput | Out-String)"
        }
        $createdIssue = ($createOutput | Out-String) | ConvertFrom-Json
        if ($null -eq $createdIssue.id -or $null -eq $createdIssue.number) {
            throw 'Issue creation response did not contain id and number.'
        }

        $ledger = @(Read-CreationLedger)
        $relativeBodyFile = [IO.Path]::GetRelativePath($logDirectory, $draft.bodyFile)
        $ledger += [pscustomobject][ordered]@{
            implementationSubsection = $draft.implementationSubsection
            bodyFile = $relativeBodyFile
            id = [Int64]$createdIssue.id
            number = [int]$createdIssue.number
            title = [string]$createdIssue.title
            url = [string]$createdIssue.html_url
            body_verified = $false
            linked = $false
        }
        Write-CreationLedger -Ledger ([object[]]$ledger)

        $operation = "verify body for issue #$($createdIssue.number)"
        $verifiedIssue = & $bodyVerifier `
            -Repository $repo `
            -IssueNumber ([int]$createdIssue.number) `
            -ExpectedBodyPath $draft.bodyFile `
            -MaxAttempts 6 `
            -DelaySeconds 5 `
            -DiagnosticPath (Join-Path $logDirectory "issue-$($createdIssue.number)-body-verification-failure.json")
        if ($null -eq $verifiedIssue -or [int]$verifiedIssue.number -ne [int]$createdIssue.number) {
            throw "Body verifier returned an unexpected result for issue #$($createdIssue.number)."
        }
        Set-LedgerFlag -Number ([int]$createdIssue.number) -Field body_verified -Value $true

        $operation = "link issue #$($createdIssue.number) to parent #$parentIssue"
        $linkSucceeded = $false
        $lastLinkError = ''
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $linkInputPath = Join-Path $logDirectory "issue-$($createdIssue.number)-link-input.json"
            [IO.File]::WriteAllText(
                $linkInputPath,
                "{`"sub_issue_id`": $([Int64]$createdIssue.id)}",
                [Text.UTF8Encoding]::new($false)
            )
            $linkOutput = & gh api "repos/$repo/issues/$parentIssue/sub_issues" -X POST --input $linkInputPath 2>&1
            $linkExitCode = $LASTEXITCODE
            Remove-Item -LiteralPath $linkInputPath -Force
            if ($linkExitCode -eq 0) {
                $linkSucceeded = $true
                break
            }
            $lastLinkError = $linkOutput | Out-String
            if ($attempt -lt 3) {
                Start-Sleep -Seconds 2
            }
        }
        if (-not $linkSucceeded) {
            throw "Issue linking failed after 3 attempts: $lastLinkError"
        }
        Set-LedgerFlag -Number ([int]$createdIssue.number) -Field linked -Value $true
    }

    $operation = 'verify final child count and order'
    $ledger = @(Read-CreationLedger)
    $finalChildren = @(Get-NormalizedChildren)
    if ($finalChildren.Count -ne $baselineChildren.Count + $ledger.Count) {
        throw "Parent child count changed from $($baselineChildren.Count) to $($finalChildren.Count); expected $($baselineChildren.Count + $ledger.Count)."
    }

    $baselineIds = @($baselineChildren | ForEach-Object { [Int64]$_.id })
    $newChildren = @($finalChildren | Where-Object { $baselineIds -notcontains [Int64]$_.id })
    $expectedIds = @($ledger | ForEach-Object { [Int64]$_.id })
    $actualIds = @($newChildren | ForEach-Object { [Int64]$_.id })
    if ($actualIds.Count -ne $expectedIds.Count -or
        (Compare-Object -ReferenceObject $expectedIds -DifferenceObject $actualIds -SyncWindow 0)) {
        throw 'Newly linked child order does not match implementation plan order.'
    }
    foreach ($entry in $ledger) {
        if (@($finalChildren | Where-Object { [Int64]$_.id -eq [Int64]$entry.id }).Count -ne 1) {
            throw "Issue #$($entry.number) is not linked exactly once."
        }
    }

    foreach ($entry in $ledger) {
        $operation = "verify final postconditions for issue #$($entry.number)"
        $absoluteBodyFile = Join-Path $logDirectory $entry.bodyFile
        $issue = & $bodyVerifier `
            -Repository $repo `
            -IssueNumber ([int]$entry.number) `
            -ExpectedBodyPath $absoluteBodyFile `
            -MaxAttempts 6 `
            -DelaySeconds 5 `
            -DiagnosticPath (Join-Path $logDirectory "issue-$($entry.number)-body-verification-failure.json")
        if ($issue.state -ne 'open') {
            throw "Issue #$($entry.number) is not open."
        }
        if (@($issue.assignees).Count -ne 0) {
            throw "Issue #$($entry.number) is assigned."
        }
        if (-not [string]::IsNullOrEmpty($selectedIssueType) -and
            ([string]$issue.type.name -cne $selectedIssueType)) {
            throw "Issue #$($entry.number) does not have type $selectedIssueType."
        }
    }

    Write-StageResult -Status complete -OperationError $null
    [ordered]@{
        selectedIssueType = if ([string]::IsNullOrEmpty($selectedIssueType)) { $null } else { $selectedIssueType }
        baselineChildCount = $baselineChildren.Count
        finalChildCount = $finalChildren.Count
        ledger = @(Read-CreationLedger)
    } | ConvertTo-Json -Depth 10
}
catch {
    $failureMessage = "$operation`: $($_.Exception.Message)"
    Reconcile-Failure -ErrorMessage $failureMessage
    throw $failureMessage
}
