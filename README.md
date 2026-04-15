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
- Codex-owned shell ancestry by itself is never enough to make descendants killable
- If the evidence is weak or ambiguous, the process remains `inspect-only` or is ignored entirely

## Recommended Strategy

Use the skill in short cycles instead of waiting for the very end of a long task:

1. Run `inspect` before cleanup or when process ownership is still unclear.
2. Run `checkpoint-cleanup` after a risky step such as tests, builds, one-shot scripts, browser automation, or DevTools MCP.
3. Re-run `inspect` to verify only the intended leftovers were reclaimed.
4. Use `cleanup` only when the remaining temporary process trees are definitely no longer needed.

## Safety Model

This skill is intentionally conservative.

- It preserves the active Codex shell and Codex helper shells
- It preserves ordinary browsers that do not carry automation or remote-debug flags
- It preserves ambiguous processes when the evidence is not strong enough
- It keeps likely reusable dev servers in `inspect-only` during checkpoint cleanup
- It only cleans high-confidence temporary process trees that no longer provide value to the current step

Checkpoint cleanup is mainly for:

- DevTools MCP services, launchers, and watchdogs
- explicit browser automation or remote-debug sessions
- one-shot shells and runtimes tied to a finished step
- wrapper shells that clearly launched automation helpers such as `chrome-devtools-mcp`, `playwright`, or `--remote-debugging-port`

## What It Will Not Do

- It will not kill the active Codex shell or Codex helper shells
- It will not kill normal user browsers without automation flags
- It will not kill unmatched runtimes just because they are `node`, `python`, `java`, or similar
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
- `scripts/cleanup-temporary-processes.sh`: macOS and Linux shell wrapper
- `scripts/*.Tests.ps1`: Pester coverage for inventory, classification, policy, and entrypoint behavior
- `docs/project-introduction.md`: English project introduction
- `docs/project-introduction.zh-CN.md`: Chinese project introduction

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

## Testing

Run the focused suites:

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
```

Or run the full matrix in one shot:

```powershell
Invoke-Pester -Path .\scripts -PassThru
```

## License

This project is released under the [MIT License](./LICENSE).
