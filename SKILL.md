---
name: codex-cleaning-temporary-processes
description: Use when coding work may leave temporary development processes behind across package managers, runtimes, build tools, test runners, browser automation, or local servers, especially after finished checkpoints where a safe cleanup decision can reduce process pileup without crossing workspace boundaries.
---

# Codex Cleaning Temporary Processes

## What This Skill Is

Codex Cleaning Temporary Processes is a public, cross-platform skill package for safe cleanup of temporary development processes.

This repository is a pure skill package. With `allow_implicit_invocation: true`, Codex may pick it up without being asked, but that behavior is best-effort implicit invocation rather than a host-hook guarantee. The skill can encourage proactive cleanup decisions; it cannot create fixed callbacks inside the Codex app by itself.

## Trigger Model

Re-evaluate cleanup at finished checkpoints instead of waiting for the whole task to end.

Best-effort implicit invocation is most appropriate:

- after a finished high-risk tool step
- after a finished batch of one-shot shell commands
- after browser automation, DevTools, or remote-debug work finishes
- after a subagent finishes and its helpers no longer have reuse value
- when the current branch of work is pausing and a final sweep is clearly safe

If implicit invocation does not happen in your environment, explicitly ask Codex to use `$codex-cleaning-temporary-processes`.

## Toolchain Coverage

This skill is public and language-agnostic. It should reason about temporary processes across mainstream toolchains, not just one project stack.

Common examples include:

- JavaScript and TypeScript: `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, `jest`, `webpack`, `rollup`, `next`, `nuxt`, `turbo`
- Rust and native tooling: `cargo`, `rustc`, `tauri`, `trunk`
- Python: `python`, `uv`, `pip`, `pipenv`, `poetry`, `hatch`, `pytest`, `uvicorn`, `jupyter`, `streamlit`
- JVM and .NET: `java`, `mvn`, `gradle`, `kotlin`, `scala`, `dotnet`
- Other popular stacks: `go`, `ruby`, `bundle`, `rails`, `php`, `composer`, `artisan`, `elixir`, `mix`, `iex`, `rebar3`, `deno`
- Browser automation and debugging: `chrome-devtools-mcp`, Playwright-style tooling, headless browsers, remote-debug launchers

Coverage does not mean aggression. The safety rules still decide whether something is inspect-only, cleanup-now, or preserve.

## Cleanup Modes

- `inspect`: classify and report without killing
- `checkpoint-cleanup`: clean high-confidence leftovers that are no longer useful to the finished checkpoint
- `cleanup`: final sweep for clearly finished temporary process trees

Prefer `inspect` when reuse is still plausible. Prefer `checkpoint-cleanup` when a step is clearly finished. Reserve full `cleanup` for the point where the remaining temporary tree is definitely no longer needed.

## Practical Limits

This package is still a pure skill, not a host-level plugin.

- It can increase the chance that Codex reconsiders cleanup at the right checkpoints
- It cannot install fixed callbacks, timers, or always-on hooks inside the Codex app
- If implicit invocation does not happen in your environment, explicitly ask Codex to use `$codex-cleaning-temporary-processes`
- Broader toolchain coverage never lowers the safety threshold for cleanup

## Safety Model

Kill only processes that are both:

- clearly temporary by command line, process tree, or tool signature
- no longer needed for the active checkpoint

Require strong evidence before cleanup:

- current-workspace match plus dev, test, build, preview, serve, run, or watch markers
- known temporary launcher, watchdog, helper-shell, or wrapper signatures
- explicit automation or remote-debug flags together with current-task lineage or current-thread-owned evidence
- for relative child commands, a parent or ancestor that already carries workspace-backed task evidence

If evidence is weak, inspect and report instead of killing.

Never kill:

- the active Codex session shell
- plain interactive `powershell`, `pwsh`, `bash`, `zsh`, `sh`, or `fish` with no task-specific arguments
- ordinary browsers without automation or remote-debug flags
- reusable dev servers unless the finished checkpoint makes their reuse value clearly zero
- user-owned runtimes outside the current workspace scope
- ambiguous Docker, container, VM, or orchestration daemons that are not clearly task-owned temporary children
- anything you are not highly confident is temporary

## Explicit Automation Follow-up

Use `-ConfirmCurrentThreadExplicitAutomation` only when this same Codex thread really used DevTools MCP, browser automation, or remote debugging in the finished checkpoint that just ended.

Always pair that switch with a non-blank `-Workspace`.

The first confirmed follow-up pass may record current-thread ownership for that workspace. Later passes in the same workspace may reclaim leftover launcher trees that were previously only inspectable.

Current-thread ownership never broadens cleanup for generic runtimes.

## Multi-Project Isolation

This public skill must stay safe when several repositories, worktrees, or Codex conversations are active at once.

- Workspace-backed build, test, serve, watch, and runtime processes must match the current workspace or a task-owned ancestor
- Explicit automation from another workspace or another conversation stays `inspect-only` unless current-task lineage or confirmed current-thread ownership proves it belongs here
- Workspace match alone is never enough for explicit automation
- Generic runtimes do not become killable just because same-thread automation evidence exists

## Local Runtime State

Same-thread explicit automation recovery uses sanitized thread identifiers and normalized workspace values in local runtime state.

- Prefer `CODEX_HOME/state/codex-cleaning-temporary-processes/...`
- Fall back to the OS temporary directory if `CODEX_HOME` is unavailable
- Treat this state as runtime support data only, not as permission to widen cleanup scope

## Commands

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

## Common Mistakes

- expecting pure skill packaging to provide plugin-like host hooks
- waiting until the entire task ends even though several finished checkpoints already left process residue behind
- using a blank or wrong `-Workspace`
- treating workspace match alone as enough evidence for explicit automation cleanup
- assuming Codex-owned ancestry alone makes a process safe to kill
- forgetting that best-effort implicit invocation may still need an explicit prompt in some environments
