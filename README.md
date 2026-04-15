# Codex Cleaning Temporary Processes

[Chinese](./README.zh-CN.md)

Safety-first Codex skill for Windows process hygiene. It helps inspect and clean temporary development processes after tool-driven work without killing the active Codex shell, ordinary user apps, or ambiguous long-lived services.

## Purpose

Long Codex sessions can leave behind temporary shells, package-manager commands, browser-debug helpers, DevTools MCP services, test runners, and workspace-owned runtimes. Waiting until the very end of a large task can cause unnecessary buildup.

This skill exists to give Codex a safe, reusable workflow for Windows process hygiene:

- prevent long tasks from accumulating already-finished temporary processes
- reclaim high-confidence leftovers earlier, not only at final task completion
- preserve reusable dev servers, interactive shells, and normal user applications

## Risks

Process cleanup is useful, but it becomes dangerous when the rules are too broad. The main risks are:

- killing the active Codex shell or Codex helper shells
- killing ordinary browsers or user-owned runtimes that happen to be open
- killing long-lived dev services that the next step still needs
- overfitting cleanup rules to one private project and leaking private names or paths

Because this repository is public, the design is intentionally conservative and the examples are sanitized.

## Solution

This skill adds a checkpoint cleanup workflow:

- `inspect` to classify candidates and protected processes
- `checkpoint-cleanup` to reclaim only high-confidence leftovers after a risky step finishes
- `cleanup` to perform a final sweep for remaining killable temporary process trees

The solution uses two layers:

- classification decides what kind of process Codex is looking at
- cleanup policy decides whether the current mode should preserve, inspect, or clean it now

## Safety Model

This repository is intended for public use and keeps the cleanup policy intentionally conservative.

- Never kill the active Codex shell or Codex helper shells
- Never kill ordinary browsers without automation or remote-debug flags
- Never kill unrelated user runtimes that do not match current task evidence
- Never kill ambiguous processes during checkpoint cleanup
- Prefer `inspect` first when the next step may still reuse a process

Checkpoint cleanup only targets:

- DevTools MCP services, launchers, and watchdogs
- explicit browser automation or remote-debug sessions
- one-shot shells and runtimes that clearly belong to the finished step
- high-confidence wrapper shells that explicitly launched automation helpers such as `chrome-devtools-mcp`, `playwright`, or `--remote-debugging-port`

Long-lived dev servers such as `dev`, `serve`, `preview`, `watch`, `runserver`, or `start` remain `inspect-only` during checkpoint cleanup.

## Coverage

The included classification rules already cover representative patterns across multiple ecosystems. The examples are not exhaustive, but the current rules include:

- JavaScript and TypeScript tooling such as `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, and framework dev commands
- Rust and Tauri shell workflows such as `cargo` and `cargo tauri dev`
- Python dev and test commands such as `pytest`, `uvicorn`, `flask`, and Django `runserver`
- .NET, Go, Ruby, PHP, and Java dev or test workflows when the workspace match is strong
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

## Privacy and Sanitization

This public package should contain only sanitized skill sources.

- Use neutral placeholders such as `C:\Projects\ExampleApp`
- Do not commit private workspace paths, project names, or machine-specific data
- Do not publish captured process output that contains user-specific information

## License

This project is released under the [MIT License](./LICENSE).
