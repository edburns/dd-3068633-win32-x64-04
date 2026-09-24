## Campaign context and required reading

**On the `experiment/shepherd-control` branch, the directory `1-math-control-remove-before-merge` contains the plan (`math-tool-ignorance-reduction-plan.md`) and supporting resources (diagrams, decision records). Spike subdirectories are research artifacts — read the plan's Resolution sections for findings, not the spike source code.**

Before changing code, read the entire `1-math-control-remove-before-merge/math-tool-ignorance-reduction-plan.md` plan. Then carefully re-read these exact sections:

- `## Ignorance reduction`
- `### Repository-owned validation`
- `### Output and ordering contracts`
- `## Implementation`
- `### 1. Implement Fibonacci with unit and isolated CLI coverage`
- `### 2. Add factorial and operation dispatch`

Carry these resolved decisions into the implementation:

- Repository-owned acceptance is `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1`. The existing `.github/workflows/shepherd-task-math-tool.yml` workflow pins Pester 5.7.1 and invokes that runner; do not replace, bypass, or duplicate the runner.
- Direct CLI execution writes exactly one result line to stdout: `Fibonacci(N) = value` or `Factorial(N) = value`, according to the selected operation.
- Functions return their numeric value without incidental output.
- Inputs are non-negative integers.
- Production and test changes remain in the repository-root files `math-tool.ps1` and `math-tool.Tests.ps1`.
- This task starts only after implementation subsection 1 has been merged, and existing Fibonacci behavior must remain intact.

The plan records no separate spike-derived implementation finding for this task. The concrete research outcomes are the resolution values above; implement production behavior from those outcomes rather than reading or adapting research code.

## Branch and execution order

Target `experiment/shepherd-control` as the PR base branch. Do not start work until this issue is assigned to the coding agent.

The two implementation issues are assigned, completed, and merged serially in plan order. This is implementation subsection 2. Its prerequisite is the merged implementation from `### 1. Implement Fibonacci with unit and isolated CLI coverage`; begin from that merged base-branch state rather than reimplementing task 1.

## Implement

Extend repository-root `math-tool.ps1` while preserving its Fibonacci contract:

- Add a pure `Get-Factorial` function that returns the factorial as a numeric value and emits no incidental pipeline or console output.
- Add an `Operation` parameter that dispatches between `fibonacci` and `factorial`, retaining the existing `N` parameter.
- Keep Fibonacci calculation and direct-execution output behavior compatible with task 1.
- For factorial direct execution, write exactly one stdout line formatted as `Factorial(N) = value`.
- Implement the conventional edge cases `Factorial(0) = 1` and `Factorial(1) = 1`, plus correct calculation for a small representative input.
- Keep accepted inputs constrained to the resolved non-negative integer contract and reject unsupported operation values through clear PowerShell parameter/validation behavior.

Extend repository-root `math-tool.Tests.ps1` with objective combined coverage:

- Dot-sourced unit cases for factorial `N=0`, `N=1`, and at least one small representative value such as `N=5`.
- Assertions that `Get-Factorial` returns only a numeric result without incidental output.
- Isolated child-`pwsh` process coverage for factorial dispatch, successful exit, and exact single-line stdout.
- Full regression coverage for the Fibonacci unit and isolated CLI contracts delivered by task 1.
- A dispatch discrimination check proving that the same representative `N` selects the requested operation and produces the corresponding label and value.
- A negative gating case proving unsupported operation values are not silently treated as a valid operation.

Follow the repository's existing PowerShell and Pester conventions. Keep the public interface, implementation, and tests deterministic and small.

## Completion gates

- `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1` exits zero for the combined regression suite.
- The pinned pull-request workflow using Pester 5.7.1 passes without changes to its dependency pin or acceptance command.
- Unit tests prove factorial `0`, `1`, and representative cases, while all Fibonacci tests continue to pass.
- Child-process tests prove operation dispatch and exact stdout cardinality and formatting for both operations.
- Both calculation functions return only numeric results.
- Unsupported operation values fail clearly instead of falling through to a valid result.
- The PR targets `experiment/shepherd-control` and contains only the scoped math-tool and test extensions.

## Out of scope

- Do not redesign or rename the task-1 Fibonacci API or alter its observable result contract.
- Do not add operations beyond `fibonacci` and `factorial`.
- Do not modify the workflow, Pester version, repository-owned test runner, campaign metadata, plan, or supporting resources.
- Do not introduce unrelated modules, packaging, commands, or refactors.
- Do not copy or adapt spike source code or spike-only test infrastructure.
