---
name: codex-cleaning-temporary-processes
description: Use when work on Windows, macOS, or Linux may spawn temporary shells, package-manager commands, language runtimes, browser-debug sessions, DevTools MCP helpers, dev servers, test runners, build watchers, or subagent-owned tooling that should be inspected and cleaned without touching the active Codex shell or unrelated user apps.
---

# Codex Cleaning Temporary Processes

## Overview

Treat process hygiene as part of task completion across Windows, macOS, and Linux. After tool-driven work that may spawn temporary PowerShell, bash, zsh, cmd, Node, browser-debug, or other language-runtime processes, inspect for leftovers, clean only clearly temporary processes, then re-check what remains.

Examples in this skill are representative, not exhaustive. The rule is about temporary dev processes by role and evidence, not one hard-coded command list.

Use this skill proactively. Do not wait for the user to complain about memory pressure if the current turn used shells, builds, tests, browser debugging, language runtimes, or subagents that may leave temporary processes behind.

Do not wait for the entire task to finish if a long task contains multiple risky tool steps. Reclaim temporary processes in smaller checkpoints whenever a high-risk step has clearly finished and those processes no longer have reuse value.

## Trigger Checklist

Run this skill automatically when any of these happened in the current turn:

- Ran package-manager, dev-server, test-runner, watcher, or build commands such as `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, `tsx`, `nodemon`, `cargo`, `tauri`, `pytest`, `uvicorn`, `dotnet`, `go test`, `rails`, `php artisan`, `gradle`, `mvn`, `mix`, `swift`, `dart`, `cmake`, or similar tooling
- Opened browser automation, DevTools MCP, remote debugging, headless Chrome or Edge, or Playwright-style workflows
- Spawned or waited on subagents that may have used browser or dev tooling
- Executed repeated shell commands and may have left helper shells behind
- The user mentioned memory pressure, many background runtime processes, lingering shells, or unexpected browser-debug processes

## Safety Model

Kill only processes that are both:

- clearly temporary by command line, process tree, or tool signature
- no longer needed for the active task

Require strong evidence before cleanup:

- explicit automation or remote-debug flags
- clear DevTools MCP markers
- current-workspace match plus dev, test, build, preview, serve, run, or watch markers

If only one weak signal is present, inspect and report instead of killing.

Checkpoint cleanup rule:

- after a high-risk step ends, clean only `cleanup-now` processes
- keep likely reusable dev servers and ambiguous processes in `inspect-only`
- reserve full `cleanup` for the final sweep when the task is ending or those temporary processes are definitely no longer needed

Never kill:

- the active Codex session shell
- plain interactive `powershell`, `pwsh`, `bash`, `zsh`, `sh`, or `fish` with no task-specific arguments
- normal user browsers without automation or remote-debug flags
- user-owned runtimes such as Node, Python, Java, Ruby, PHP, Go, or .NET when they do not match current task work
- anything you are not highly confident is temporary

When in doubt, inspect first and report instead of killing.

## What To Clean

- DevTools MCP services, launchers, and watchdogs that are no longer needed
- shells clearly running temporary tool commands for the current task
- wrapper shells that explicitly launched DevTools MCP, Playwright, or browser remote-debug sessions for a finished step
- browser automation or remote-debug sessions with explicit debug flags
- language runtimes tied to the current workspace and clearly running dev, test, build, or serve workflows

## Coverage

This skill is meant for mainstream development workflows across multiple ecosystems, including:

- JavaScript and TypeScript toolchains such as `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, `next`, `nuxt`, `astro`, `webpack`, and `storybook`
- Node backend and service tools such as `tsx`, `ts-node`, `ts-node-dev`, `nodemon`, `nest`, `remix`, and `svelte-kit`
- Rust workflows such as `cargo`, `cargo test`, and `cargo tauri dev`
- Python workflows such as `pytest`, `uvicorn`, `gunicorn`, `flask`, and Django `runserver`
- JVM and .NET workflows such as `java`, `gradle`, `mvn`, and `dotnet`
- Go, Ruby, PHP, Elixir, Swift, Dart, Flutter, and common native build tools when the workspace match and command evidence are strong
- DevTools MCP, Playwright-style automation, and remote-debug browser sessions

## Cleanup Timing

- run `checkpoint-cleanup` after each high-risk step such as tests, builds, DevTools MCP, browser automation, or one-shot tool invocations
- use `inspect` first if the next step may reuse a process and you are not yet confident
- use full `cleanup` only when ending the task or intentionally shutting down all remaining temporary process trees

## What To Preserve

- the Codex session shell and Codex helper shells
- ordinary browsers opened for normal user activity
- standalone runtimes with no current-workspace match
- interactive shells with no task-specific command markers
- anything still producing output for the active task

## High-Confidence Kill Targets

- Node processes with `chrome-devtools-mcp`
- watchdog processes with `telemetry/watchdog/main.js`
- launchers with `npx-cli.js -y chrome-devtools-mcp@latest`
- wrapper shells whose command lines explicitly include `chrome-devtools-mcp`, `playwright`, or `--remote-debugging-port`
- temporary shells or runtime processes that clearly show dev, build, preview, test, serve, runserver, or watch modes for the current workspace
- browser processes only when command lines clearly include automation flags such as `--remote-debugging-port`, `--headless`, or `playwright`

For generic runtimes, prefer passing `-Workspace` so the script can distinguish current-task processes from unrelated user apps.

For ordinary build, test, serve, and runtime processes, omit cleanup when you do not have workspace evidence. Without `-Workspace`, only explicit automation or remote-debug signatures should be treated as high-confidence cleanup targets.

## Protected Process Classes

- shells directly owned by Codex
- ordinary user browsers with no automation flags
- plain interactive shells that do not show current-task command lines
- runtimes with no workspace, devtool, browser-debug, or MCP markers
- helper shells that are still actively needed for the current command sequence

## Workflow

1. After a high-risk step finishes, run `inspect` or `checkpoint-cleanup`.
2. Review the decision fields and confirm which records are `cleanup-now`, `inspect-only`, or `preserve`.
3. Clean only the temporary leftovers the current step no longer needs.
4. Re-inspect and confirm the process tree is gone or reduced as expected.
5. At true task end, optionally run full `cleanup` for the final sweep.
6. Report what was killed and what was intentionally preserved.

Use the bundled scripts:

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

Pass `-Workspace` whenever a repo path helps distinguish current task-owned shells and runtimes from unrelated user processes.

## Quick Reference

| Situation | Action |
| --- | --- |
| After frontend, backend, mobile, or systems tooling that launched a one-shot command | Run `checkpoint-cleanup` after the step if those processes are no longer needed |
| After Python, JVM, .NET, Go, Ruby, PHP, Elixir, Swift, Dart, or Node backend tooling | Inspect with `-Workspace`, then use `checkpoint-cleanup` only for non-reusable leftovers |
| After DevTools MCP or browser-debug workflows | Use `checkpoint-cleanup` promptly to reclaim high-confidence MCP, watchdog, launcher, and automation trees |
| User reports many runtime or shell processes | Inspect matching shell, runtime, and browser-debug processes first |
| Only the Codex session shell or reusable dev servers remain | Stop and preserve them |

## Common Mistakes

- Killing all runtime processes blindly instead of classifying by command line and workspace evidence
- Killing plain interactive shells that belong to the active Codex session
- Killing every tool wrapper shell instead of limiting checkpoint cleanup to one-shot commands or explicit automation wrappers
- Killing normal browsers without remote-debug or headless flags
- Cleaning before test or build output is finished
- Waiting until the whole task ends even though several finished tool steps already left dead temporary processes behind
- Forgetting the second inspection pass after cleanup
- Reporting "all clear" without checking the remaining process list

## Script

- `scripts/process-inventory.ps1`
- `scripts/process-classification.ps1`
- `scripts/cleanup-policy.ps1`
- `scripts/cleanup-temporary-processes.ps1`
- `scripts/cleanup-temporary-processes.sh`
- `inspect` mode lists temporary candidates and protected process classes
- `checkpoint-cleanup` mode kills only high-confidence step-finished leftovers
- `cleanup` mode kills only high-confidence temporary targets and their descendants
