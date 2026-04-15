# Codex Cleaning Temporary Processes

[简体中文](./README.zh-CN.md)

Cross-platform Codex skill for safe process hygiene on Windows, macOS, and Linux. It helps Codex inspect and clean temporary development processes after tool-driven work without touching the active Codex shell, ordinary user applications, or ambiguous long-lived services.

## Overview

Long development sessions often leave behind shells, test runners, build helpers, browser-debug processes, and workspace runtimes that have already finished their job. This skill gives Codex a repeatable way to classify those leftovers and reclaim only the ones that are clearly temporary and no longer useful.

This is a public, general-purpose skill. It is not tied to one project, one stack, or one operating system.

## Supported Environments

- Windows
- macOS
- Linux

The implementation uses a shared PowerShell entrypoint plus a shell wrapper for macOS and Linux.

## Runtime Requirements

- Windows: PowerShell is available by default
- macOS or Linux: install PowerShell 7 so `pwsh` is available
- If your checkout does not preserve executable bits, run the Unix wrapper through `bash`
- Thread-aware explicit automation recovery works best when Codex exposes `CODEX_THREAD_ID` and you pass `-Workspace`; on a first confirmed Codex-owned explicit-automation observation, the current thread can seed ownership for a later reclaim pass. If no thread id is available, explicit automation falls back to current-task lineage while generic dev tools keep using workspace and ancestor evidence

## Ecosystem Coverage

The bundled rules are designed around mainstream developer workflows across multiple ecosystems, including:

- JavaScript and TypeScript tools such as `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, `next`, `nuxt`, `astro`, `webpack`, and `storybook`
- Node backend and service tools such as `tsx`, `ts-node`, `ts-node-dev`, `nodemon`, `nest`, `remix`, and `svelte-kit`
- Rust tools such as `cargo`, `cargo test`, and `cargo tauri dev`
- Python tools such as `pytest`, `uvicorn`, `gunicorn`, `flask`, and Django `runserver`
- JVM and .NET tools such as `java`, `gradle`, `mvn`, and `dotnet`
- Go, Ruby, PHP, Elixir, Swift, Dart, Flutter, and common native build tools when command and workspace evidence are strong
- DevTools MCP, Playwright-style automation, and remote-debug browser sessions

The examples are representative, not exhaustive. The skill relies on command-line evidence, process-tree relationships, and workspace matching instead of hard-coding one project layout.

For ordinary build, test, serve, and runtime processes, pass `-Workspace` whenever possible. Without workspace evidence, the implementation stays conservative and only treats explicit automation or remote-debug signatures as high-confidence cleanup targets.

## How It Works

The skill uses a three-mode workflow:

- `inspect`: report classified temporary candidates and any positively identified protected classes without killing anything
- `checkpoint-cleanup`: reclaim only high-confidence leftovers after a risky step has finished
- `cleanup`: do a final sweep for remaining killable temporary process trees

Under the hood, the implementation stays split into two decisions:

- process classification decides what kind of process Codex is looking at
- cleanup policy decides whether the current mode should preserve, inspect only, or clean it now

## Ownership Signals

The classification rules stay intentionally conservative when attributing a process to the current task.

- Prefer passing `-Workspace` so command lines can be matched to the active repo or project path
- Relative child commands can inherit task ownership only when a parent or ancestor already has both workspace evidence and known dev, test, build, serve, or watch markers
- Explicit automation and remote-debug processes stay `inspect-only` unless current-task lineage or current-thread-owned evidence is strong enough; workspace match alone is not enough
- A local current-thread ownership ledger can seed from a first confirmed Codex-owned explicit-automation observation and keep that automation reclaimable on later passes, even if the original launcher shell exits later
- Current-thread ownership never makes generic runtimes or ordinary dev tools killable by itself
- Codex `app-server` ancestry can make explicit automation eligible for current-thread ledger seeding, but it is not immediate cleanup permission by itself
- Codex-owned shell ancestry by itself is never enough to make descendants killable
- If the evidence is weak or ambiguous, the process remains `inspect-only` or is ignored entirely

## Recommended Strategy

Use the skill in short cycles instead of waiting for the very end of a long task:

1. Run `inspect` before cleanup or when process ownership is still unclear.
2. Run `checkpoint-cleanup` after a risky step such as tests, builds, one-shot scripts, browser automation, or DevTools MCP.
3. Re-run `inspect` to verify only the intended leftovers were reclaimed.
4. Use `cleanup` only when the remaining temporary process trees are definitely no longer needed.

## Trigger Cadence

Treat invocation as step-scoped, not only task-scoped:

- Re-evaluate the skill after each finished high-risk step, even while the larger task continues.
- Re-evaluate after DevTools MCP, browser-debug, or Playwright-style work finishes.
- Re-evaluate after a subagent finishes if it may have used shells, runtimes, browser helpers, tests, builds, or dev servers.
- Re-evaluate after a batch of one-shot shell or tool commands when those processes no longer have reuse value.
- If reuse is plausible, prefer `inspect`; if the step is clearly finished, use `checkpoint-cleanup`.

## Safety Model

This skill is intentionally conservative.

- It preserves the active Codex shell and Codex helper shells
- It preserves ordinary browsers that do not carry automation or remote-debug flags
- It preserves DevTools MCP, browser automation, and remote-debug sessions when current-task lineage or current-thread ownership is not proven
- It may continue to reclaim current-thread-owned explicit automation that this Codex conversation already seeded or otherwise proved it owned earlier in the task
- It preserves ambiguous processes when the evidence is not strong enough
- It keeps likely reusable dev servers in `inspect-only` during checkpoint cleanup
- It only cleans high-confidence temporary process trees that no longer provide value to the current step

Checkpoint cleanup is mainly for:

- DevTools MCP services, launchers, and watchdogs
- explicit browser automation or remote-debug sessions
- one-shot shells and runtimes tied to a finished step
- wrapper shells that clearly launched automation helpers such as `chrome-devtools-mcp`, `playwright`, or `--remote-debugging-port`

Incremental `checkpoint-cleanup` is for clearly finished steps. Final `cleanup` is the end-of-task sweep once the remaining temporary process trees are definitely no longer needed.

## Multi-Project Safety

When several Codex conversations, branches, or repositories are active at once, the skill should only clean processes that belong to the current task.

- Workspace-backed dev, test, build, serve, and runtime processes must match the current workspace or a task-owned ancestor.
- Explicit automation such as DevTools MCP, Playwright-style helpers, or remote-debug browsers stays `inspect-only` unless the current task can prove lineage or the same Codex thread has already seeded or proved ownership.
- Current-thread ownership is only a recovery hint for explicit automation that the same Codex conversation already seeded or proved it owned; workspace match alone is not a blanket same-workspace cleanup permission.
- Codex-owned ancestry by itself is not enough to let one project clean another project's process tree.

## What It Will Not Do

- It will not kill the active Codex shell or Codex helper shells
- It will not kill normal user browsers without automation flags
- It will not kill unmatched runtimes just because they are `node`, `python`, `java`, or similar
- It will not kill DevTools MCP, browser automation, or remote-debug sessions from another workspace or Codex conversation when current-task lineage is not established
- It will not use current-thread ownership alone to kill generic dev, test, build, or runtime processes
- It will not treat Codex-owned shell ancestry alone as proof that a descendant belongs to the current task
- It will not force cleanup when evidence is weak; those processes stay in `inspect-only`
- Direct browser-process matching currently targets Chromium and Edge-family remote-debug sessions; non-Chromium automation is mainly identified through helper or wrapper processes

## Output Contract

`inspect` returns the current classified snapshot:

- `matchedCount`
- `killableRoots`
- `decisionCounts`
- `processes`

`checkpoint-cleanup` and `cleanup` return a post-cleanup snapshot plus kill results:

- `matchedCount`
- `killableRoots`
- `decisionCounts`
- `killedCount`
- `killedIds`
- `failedCount`
- `failedIds`
- `processes`

The `processes` array in cleanup modes is re-inspected after kill attempts, so callers see what still remains instead of only the pre-cleanup view.

`inspect` reports classified records, not a full process table dump. Ambiguous or unmatched processes may be preserved silently and omitted from the output.

## Repository Layout

- `SKILL.md`: public skill instructions and operating rules
- `agents/openai.yaml`: default agent metadata and invocation prompt
- `scripts/process-inventory.ps1`: cross-platform process inventory collection
- `scripts/process-classification.ps1`: process classification rules
- `scripts/cleanup-policy.ps1`: cleanup decision policy
- `scripts/cleanup-temporary-processes.ps1`: shared inspect and cleanup entry point
- `scripts/thread-ownership-ledger.ps1`: local current-thread ownership cache for explicit automation recovery
- `scripts/cleanup-temporary-processes.sh`: macOS and Linux shell wrapper
- `scripts/*.Tests.ps1`: Pester coverage for inventory, classification, policy, and entrypoint behavior
- `docs/project-introduction.md`: English project introduction
- `docs/project-introduction.zh-CN.md`: Chinese project introduction
- `docs/trigger-regression-scenarios.md`: English trigger timing scenarios
- `docs/trigger-regression-scenarios.zh-CN.md`: Chinese trigger timing scenarios

Thread-aware ownership state is local runtime data, not part of the public package. When available, it is stored under `$CODEX_HOME/state/codex-cleaning-temporary-processes/thread-ownership/`; otherwise the scripts fall back to the OS temporary directory. If `CODEX_THREAD_ID` is missing, that optimization is disabled and explicit automation stays on current-task lineage while generic dev tools continue using workspace and ancestor evidence.

## Installation

1. Clone or copy this repository into your Codex skills directory.
2. Place it at `$CODEX_HOME/skills/codex-cleaning-temporary-processes` or the equivalent Codex skill path on your machine.
3. Keep the repository folder name aligned with the skill name: `codex-cleaning-temporary-processes`.

## Usage

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode inspect -Workspace "C:\Projects\ExampleApp"
```

macOS or Linux with PowerShell:

```bash
pwsh -NoProfile -File "$CODEX_HOME/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.ps1" -Mode inspect -Workspace "/Users/example/project"
```

macOS or Linux with the shell wrapper:

```bash
bash "$CODEX_HOME/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.sh" -Mode inspect -Workspace "/Users/example/project"
```

Switch `inspect` to `checkpoint-cleanup` after a risky step finishes. Use `cleanup` only when the remaining temporary process trees are definitely no longer needed.

Example incremental cleanup after DevTools MCP, tests, or other finished one-shot steps:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode checkpoint-cleanup -Workspace "C:\Projects\ExampleApp"
```

## Troubleshooting

- If process stacks keep growing, explicitly ask Codex to use `$codex-cleaning-temporary-processes`.
- If a long task stays inside one assistant turn, ask for checkpoint cleanup between finished steps instead of waiting for the final answer.
- If the next step may reuse a process, ask Codex to run `inspect` first rather than forcing cleanup.
- If a process is preserved, that may be intentional because workspace evidence, automation flags, or other strong ownership signals were not present.
- If detached DevTools or browser-debug helpers came from this same Codex conversation, a first confirmed observation can seed current-thread ownership and a later pass may still reclaim them even after the original launcher shell is gone.
- If several Codex conversations or projects are active at once, expect unowned DevTools or browser-debug leftovers to remain `inspect-only` until the current task can prove ownership.

## Testing

Run the focused suites:

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru
```

Or run the full matrix in one shot:

```powershell
Invoke-Pester -Path .\scripts -PassThru
```

## License

This project is released under the [MIT License](./LICENSE).
