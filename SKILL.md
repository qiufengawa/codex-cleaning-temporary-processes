---
name: codex-cleaning-temporary-processes
description: Use when tool-heavy work on Windows, macOS, or Linux may leave stacked temporary shells, package-manager commands, language runtimes, browser-debug sessions, DevTools MCP helpers, dev servers, test runners, build watchers, or subagent-owned tooling that should be inspected and cleaned at checkpoints without touching the active Codex shell or unrelated user apps.
---

# Codex Cleaning Temporary Processes

## Overview

Treat process hygiene as part of task completion across Windows, macOS, and Linux. After tool-driven work that may spawn temporary PowerShell, bash, zsh, cmd, Node, browser-debug, or other language-runtime processes, inspect for leftovers, clean only clearly temporary processes, then re-check what remains.

Examples in this skill are representative, not exhaustive. The rule is about temporary dev processes by role and evidence, not one hard-coded command list.

`inspect` reports classified records rather than a full dump of every running process. Weak-signal or unmatched processes may be preserved silently and omitted from the output.

Use this skill proactively. Do not wait for the user to complain about memory pressure if the current turn used shells, builds, tests, browser debugging, language runtimes, or subagents that may leave temporary processes behind.

Do not wait for the entire task to finish if a long task contains multiple risky tool steps. Reclaim temporary processes in smaller checkpoints whenever a high-risk step has clearly finished and those processes no longer have reuse value.

## Trigger Checklist

Re-evaluate this skill after every relevant tool call, DevTools or browser-debug step, and subagent result. Invoke it as soon as any item below becomes true, even mid-turn during a long tool-heavy session.

- Finished build, test, serve, watch, package-manager, install, preview, or one-shot runtime commands such as `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, `tsx`, `nodemon`, `cargo`, `tauri`, `pytest`, `uvicorn`, `dotnet`, `go test`, `rails`, `php artisan`, `gradle`, `mvn`, `mix`, `swift`, `dart`, `cmake`, or similar tooling
- Used any `mcp__chrome_devtools__*` tool, `chrome-devtools-mcp`, browser automation, remote debugging, headless Chrome or Edge, or Playwright-style workflows
- A subagent finished or reported results after using shells, builds, tests, browser tooling, dev servers, or runtimes that may have left temporary helpers behind
- Completed a batch of one-shot shell or tool commands and those helpers or runtimes no longer have reuse value
- The user mentioned memory pressure, many background runtime processes, lingering shells, or unexpected browser-debug processes

## Trigger Cadence

- Re-evaluate after each finished high-risk step, even while the overall task continues.
- Re-evaluate after a subagent finishes if its shells, runtimes, or browser helpers no longer have reuse value.
- Re-evaluate after a batch of one-shot shell or tool commands instead of waiting for final task end.
- You may invoke this skill multiple times in the same task. After one cleanup pass, trigger it again if later steps create new temporary processes.

## Safety Model

Kill only processes that are both:

- clearly temporary by command line, process tree, or tool signature
- no longer needed for the active task

Require strong evidence before cleanup:

- explicit automation or remote-debug flags
- clear DevTools MCP markers
- current-workspace match plus dev, test, build, preview, serve, run, or watch markers
- for relative child commands, a parent or ancestor that already has both workspace evidence and known dev, test, build, serve, or watch markers
- if multiple Codex tasks or workspaces may be active, explicit automation still needs current-task lineage or current-thread-owned explicit automation evidence; current-workspace match alone is not enough, and a current-thread-owned automation ledger may preserve that proof after the original launcher exits, but it never broadens cleanup for generic runtimes

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
- DevTools MCP, browser automation, or remote-debug browser sessions that lack current-task lineage or current-thread-owned explicit automation evidence
- descendants that only trace back to Codex shell ancestry without real workspace-backed task evidence
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

- run `checkpoint-cleanup` after each finished high-risk step such as tests, builds, DevTools MCP, browser automation, or one-shot tool invocations
- run `checkpoint-cleanup` after a subagent finishes if its spawned tooling no longer has reuse value
- run `checkpoint-cleanup` after a batch of one-shot shell or tool commands when those helpers are no longer needed
- use `inspect` first if the next step may reuse a process and you are not yet confident
- use full `cleanup` only when ending the task or intentionally shutting down all remaining temporary process trees

## What To Preserve

- the Codex session shell and Codex helper shells
- ordinary browsers opened for normal user activity
- standalone runtimes with no current-workspace match
- explicit automation from another workspace or Codex conversation when current-task lineage is not proven and the current Codex thread has not already claimed that automation
- interactive shells with no task-specific command markers
- anything still producing output for the active task

## High-Confidence Kill Targets

- Node processes with `chrome-devtools-mcp`
- watchdog processes with `telemetry/watchdog/main.js`
- launchers with `npx-cli.js -y chrome-devtools-mcp@latest`
- wrapper shells whose command lines explicitly include `chrome-devtools-mcp`, `playwright`, or `--remote-debugging-port`
- current-thread-owned explicit automation that this Codex conversation already proved it owned earlier in the task
- temporary shells or runtime processes that clearly show dev, build, preview, test, serve, runserver, or watch modes for the current workspace
- relative child processes only when a parent or ancestor is already workspace-backed and matches known dev, test, build, serve, or watch markers
- browser processes only when command lines clearly include automation flags such as `--remote-debugging-port`, `--headless`, or `playwright`
- direct browser-process matching currently targets Chromium and Edge-family browser names; non-Chromium automation is mainly surfaced through helper or wrapper processes

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
6. Report what was killed, what failed to stop, and what was intentionally preserved.

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
| Multiple Codex conversations or workspaces are active | Preserve explicit automation unless current-task lineage is strong or the current Codex thread already proved ownership of that same explicit automation; workspace match alone is not enough |
| User reports many runtime or shell processes | Inspect matching shell, runtime, and browser-debug processes first |
| Only the Codex session shell or reusable dev servers remain | Stop and preserve them |

## Common Mistakes

- Killing all runtime processes blindly instead of classifying by command line and workspace evidence
- Killing plain interactive shells that belong to the active Codex session
- Killing every tool wrapper shell instead of limiting checkpoint cleanup to one-shot commands or explicit automation wrappers
- Killing normal browsers without remote-debug or headless flags
- Letting one project or Codex conversation clean another project's explicit automation without current-task lineage or current-thread-owned evidence
- Assuming current-thread ownership can make generic runtimes or ordinary dev tools killable by itself
- Treating Codex-owned ancestry alone as sufficient proof that a relative child process belongs to the current task
- Cleaning before test or build output is finished
- Waiting until the whole task ends even though several finished tool steps already left dead temporary processes behind
- Forgetting the second inspection pass after cleanup
- Reporting "all clear" without checking the remaining process list

## Script

- `scripts/process-inventory.ps1`
- `scripts/process-classification.ps1`
- `scripts/cleanup-policy.ps1`
- `scripts/cleanup-temporary-processes.ps1`
- `scripts/thread-ownership-ledger.ps1`
- `scripts/cleanup-temporary-processes.sh`
- `inspect` mode lists temporary candidates and protected process classes
- `checkpoint-cleanup` mode kills only high-confidence step-finished leftovers
- `cleanup` mode kills only high-confidence temporary targets and any separately classified `cleanup-now` descendants, then reports the post-cleanup snapshot plus any failed kill ids
- thread-owned explicit automation recovery uses local runtime state under `CODEX_HOME/state/...` or the OS temp directory when `CODEX_THREAD_ID` is available; otherwise explicit automation falls back to current-task lineage while generic dev tools continue using workspace and ancestor evidence
