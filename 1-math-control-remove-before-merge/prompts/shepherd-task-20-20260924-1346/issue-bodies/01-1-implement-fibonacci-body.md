## Campaign context and required reading

**On the `experiment/shepherd-control` branch, the directory `1-math-control-remove-before-merge` contains the plan (`math-tool-ignorance-reduction-plan.md`) and supporting resources (diagrams, decision records). Spike subdirectories are research artifacts — read the plan's Resolution sections for findings, not the spike source code.**

Before changing code, read the entire `1-math-control-remove-before-merge/math-tool-ignorance-reduction-plan.md` plan. Then carefully re-read these exact sections:

- `## Ignorance reduction`
- `### Repository-owned validation`
- `### Output and ordering contracts`
- `## Implementation`
- `### 1. Implement Fibonacci with unit and isolated CLI coverage`

Carry these resolved decisions into the implementation:

- Repository-owned acceptance is `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1`. The existing `.github/workflows/shepherd-task-math-tool.yml` workflow pins Pester 5.7.1 and invokes that runner; do not replace, bypass, or duplicate the runner.
- Direct CLI execution writes exactly one result line to stdout in the form `Fibonacci(N) = value`.
- Functions return their numeric value without incidental output.
- Inputs are non-negative integers.
- Production and test changes belong in the repository-root files `math-tool.ps1` and `math-tool.Tests.ps1`.
- The tasks are serial: this first task must be merged before task 2 starts.

The plan records no separate spike-derived implementation finding for this task. The concrete research outcomes are the resolution values above; implement production behavior from those outcomes rather than reading or adapting research code.

## Branch and execution order

Target `experiment/shepherd-control` as the PR base branch. Do not start work until this issue is assigned to the coding agent.

The two implementation issues are assigned, completed, and merged serially in plan order. This is implementation subsection 1 and has no task prerequisite. Complete and merge it before work begins on subsection 2.

## Implement

Create repository-root `math-tool.ps1` with:

- A script parameter named `N` that accepts the required non-negative integer input.
- A pure `Get-Fibonacci` function that returns the Fibonacci number as a numeric value and emits no incidental pipeline or console output.
- Direct-execution behavior that invokes the function and writes exactly one stdout line formatted as `Fibonacci(N) = value`.

Use the conventional sequence values `Fibonacci(0) = 0` and `Fibonacci(1) = 1`. Ensure a small representative input is computed correctly without adding unrelated abstractions.

Create repository-root `math-tool.Tests.ps1` with:

- Dot-sourced unit coverage for `Get-Fibonacci`.
- Unit cases for `N=0`, `N=1`, and at least one small representative value such as `N=5`.
- Isolated direct-CLI coverage that launches a child `pwsh` process rather than relying on the dot-sourced test process.
- Assertions that direct execution exits successfully and emits exactly the required single result line, with no extra stdout.
- A check that the function result is numeric and is not accompanied by incidental output.

Follow the repository's existing PowerShell and Pester conventions. Keep implementation and tests deterministic and small.

## Completion gates

- `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1` exits zero.
- The pinned pull-request workflow using Pester 5.7.1 passes without changes to its dependency pin or acceptance command.
- Unit tests prove the `0`, `1`, and representative Fibonacci cases.
- Child-process tests distinguish direct script execution from dot-sourcing and prove exact stdout cardinality and formatting.
- `Get-Fibonacci` returns only the numeric result.
- The PR targets `experiment/shepherd-control` and contains only the scoped math-tool implementation and tests.

## Out of scope

- Do not implement factorial or operation dispatch; those belong to implementation subsection 2.
- Do not modify the workflow, Pester version, repository-owned test runner, campaign metadata, plan, or supporting resources.
- Do not introduce unrelated modules, packaging, commands, or refactors.
- Do not copy or adapt spike source code or spike-only test infrastructure.
