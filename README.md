# Codex Cleaning Temporary Processes

[简体中文](./README.zh-CN.md)

Safety-first Codex skill for Windows process hygiene. It helps Codex inspect and clean temporary development processes after tool-driven work without touching the active Codex shell, ordinary user applications, or ambiguous long-lived services.

## Overview

Windows development sessions often leave behind extra shells, test runners, build helpers, browser-debug processes, and workspace runtimes. This skill gives Codex a structured way to identify those leftovers and clean only the ones that are clearly finished.

It is especially useful during long multi-step tasks where one-shot commands keep accumulating even though the next step no longer needs them.

## What It Solves

- lingering temporary shells after `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, `cargo`, `tauri`, and similar commands
- extra DevTools MCP, remote-debug, or browser automation helpers after a tool step finishes
- process buildup during long tasks where cleanup should happen between steps, not only at the very end
- accidental over-cleaning caused by treating every runtime or shell as disposable

## How It Works

The skill uses a three-mode workflow:

- `inspect`: classify temporary candidates and protected processes without killing anything
- `checkpoint-cleanup`: reclaim only high-confidence leftovers after a risky step has finished
- `cleanup`: do a final sweep for remaining killable temporary process trees

Under the hood, the implementation stays split into two decisions:

- process classification determines what kind of process Codex is looking at
- cleanup policy determines whether that process should be preserved, inspected only, or cleaned now

## Safety Boundaries

This skill is intentionally conservative.

- It preserves the active Codex shell and Codex helper shells
- It preserves ordinary browsers that do not carry automation or remote-debug flags
- It preserves ambiguous processes when the evidence is not strong enough
- It keeps likely reusable dev servers in `inspect-only` during checkpoint cleanup
- It only cleans high-confidence temporary process trees that no longer provide value to the current step

Checkpoint cleanup is mainly for things like:

- DevTools MCP services, launchers, and watchdogs
- explicit browser automation or remote-debug sessions
- one-shot shells and runtimes tied to a finished step
- wrapper shells that clearly launched automation helpers such as `chrome-devtools-mcp`, `playwright`, or `--remote-debugging-port`

## Coverage

The bundled rules already recognize representative patterns across multiple ecosystems, including:

- JavaScript and TypeScript workflows such as `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, and common framework dev commands
- Rust and Tauri workflows such as `cargo` and `cargo tauri dev`
- Python commands such as `pytest`, `uvicorn`, `flask`, and Django `runserver`
- .NET, Go, Ruby, PHP, and Java dev or test workflows when workspace evidence is strong
- DevTools MCP, Playwright-style automation, and remote-debug browser sessions

## Repository Layout

- `SKILL.md`: public skill instructions and operating rules
- `agents/openai.yaml`: default agent metadata and invocation prompt
- `scripts/process-classification.ps1`: process classification rules
- `scripts/cleanup-policy.ps1`: cleanup decision policy
- `scripts/cleanup-temporary-processes.ps1`: inspect and cleanup entry point
- `scripts/*.Tests.ps1`: Pester coverage for classification and policy behavior
- `docs/project-introduction.md`: English project introduction
- `docs/project-introduction.zh-CN.md`: Chinese project introduction

## Installation

1. Clone or copy this repository into your Codex skills directory.
2. Place it at `$CODEX_HOME/skills/codex-cleaning-temporary-processes` or the equivalent Codex skill path on your machine.
3. Keep the repository folder name aligned with the skill name: `codex-cleaning-temporary-processes`.

## Usage

Inspect first:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode inspect -Workspace "C:\Projects\ExampleApp"
```

Run checkpoint cleanup after a risky step finishes:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode checkpoint-cleanup -Workspace "C:\Projects\ExampleApp"
```

Run a final sweep only when the task is ending or the remaining temporary process trees are definitely no longer needed:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode cleanup -Workspace "C:\Projects\ExampleApp"
```

## Testing

Run the shipped Pester suites:

```powershell
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
```

## License

This project is released under the [MIT License](./LICENSE).
