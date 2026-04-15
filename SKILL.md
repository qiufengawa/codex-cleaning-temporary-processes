---
name: codex-cleaning-temporary-processes
description: Fallback/manual guidance for checkpoint-safe cleanup of stacked temporary dev processes; automatic strong triggering requires plugin-style installation with the bundled plugin manifest and hooks.
---

# Codex Cleaning Temporary Processes

## Packaging Model

This repository is a public, cross-platform cleanup package for Codex. It supports two user-facing installation modes:

- Plugin-style installation keeps the repo root intact, including `.codex-plugin/plugin.json`, `hooks.json`, and `hooks/`. That installation mode enables automatic strong triggering at fixed checkpoints.
- Skill-style installation under `CODEX_HOME/skills/codex-cleaning-temporary-processes` exposes the skill text, metadata, and scripts, but it does not activate plugin hook behavior by itself.

This standalone `SKILL.md` file is therefore the fallback/manual guide. Use it when you installed the package in skill-style mode, when plugin hooks are unavailable, or when you want to request cleanup explicitly even though the plugin-style install exists.

## Automatic Strong Triggering

When the package is installed in plugin-style mode, automatic strong triggering should re-check cleanup at fixed checkpoints such as:

- after each finished high-risk tool step
- after DevTools MCP, browser automation, or remote-debug work finishes
- after a completed batch of one-shot helpers that no longer have reuse value
- after a subagent finishes
- at session end for the final sweep

Automatic strong triggering should not depend on vaguely remembering cleanup when a task ends. The installed plugin package should react to concrete finished checkpoints before process stacks build up.

## Manual Fallback Workflow

Use the standalone guidance when:

- the package is only installed in skill-style mode under `CODEX_HOME/skills`
- plugin hooks from `.codex-plugin/plugin.json` and `hooks/` are unavailable in the current Codex environment
- you want an explicit `inspect` pass before cleanup
- you want to explain why a process was preserved

Manual fallback is still fixed-checkpoint based:

- do not wait for the entire task to finish if several finished checkpoints already left temporary processes behind
- re-run after each finished checkpoint instead of relying on end-of-task memory

## Fixed Checkpoints

Re-evaluate this package as soon as any of these finished checkpoints becomes true:

- A build, test, install, preview, serve, watch, or one-shot runtime command finished and its helpers no longer have reuse value
- A DevTools MCP, browser automation, Playwright-style, headless-browser, or remote-debug checkpoint finished
- A subagent finished and may have left shells, runtimes, browser helpers, or dev servers behind
- A batch of one-shot shell or tool commands finished and backlog relief is useful before process stacks grow
- The session is ending and a final sweep is appropriate

Prefer `checkpoint-cleanup` for finished-step cleanup. Use `inspect` first if the next step may reuse the process. Reserve full `cleanup` for the final sweep when the remaining temporary process trees are definitely no longer needed.

## Safety Model

Kill only processes that are both:

- clearly temporary by command line, process tree, or tool signature
- no longer needed for the active checkpoint

Require strong evidence before cleanup:

- explicit automation or remote-debug flags
- clear DevTools MCP markers
- current-workspace match plus dev, test, build, preview, serve, run, or watch markers
- for relative child commands, a parent or ancestor that already has both workspace evidence and known dev, test, build, serve, or watch markers
- for multiple active projects or conversations, explicit automation still needs current-task lineage or current-thread-owned explicit automation evidence; workspace match alone is not enough
- only pass `-ConfirmCurrentThreadExplicitAutomation` when this same Codex thread actually used DevTools MCP, browser automation, or remote debugging in the finished checkpoint that just completed
- pair that switch with a non-blank `-Workspace`; the first confirmed pass seeds current-thread-owned explicit automation for that workspace, later same-workspace passes may reclaim it, and blank workspace is never a wildcard
- current-thread-owned explicit automation never broadens cleanup for generic runtimes

If only one weak signal is present, inspect and report instead of killing.

Never kill:

- the active Codex session shell
- plain interactive `powershell`, `pwsh`, `bash`, `zsh`, `sh`, or `fish` with no task-specific arguments
- normal user browsers without automation or remote-debug flags
- user-owned runtimes such as Node, Python, Java, Ruby, PHP, Go, or .NET when they do not match current task work
- DevTools MCP, browser automation, or remote-debug browser sessions that lack current-task lineage or current-thread-owned explicit automation evidence
- Codex `app-server` ancestry by itself; it can make explicit automation ledger-seedable, but not immediately killable
- explicit automation follow-up guesses when this thread did not actually use that automation in the finished checkpoint or when `-Workspace` is blank
- descendants that only trace back to Codex shell ancestry without real workspace-backed task evidence
- anything you are not highly confident is temporary

## Multi-Project Isolation

This public package must stay safe when multiple repositories, branches, or Codex conversations are active at once.

- Workspace-backed dev, test, build, serve, and runtime processes must match the current workspace or a task-owned ancestor
- Explicit automation stays `inspect-only` unless current-task lineage or the current thread's confirmed ownership proves it belongs to this checkpoint
- Current-thread ownership is only a recovery hint for explicit automation that this same conversation explicitly confirmed with the same workspace
- Workspace match alone is never enough for explicit automation
- Generic runtimes do not become killable just because a same-thread automation claim exists

## Sanitization And Local State

Current-thread explicit automation recovery uses sanitized thread identifiers and normalized workspace values in local runtime state.

- When available, state is stored under `CODEX_HOME/state/codex-cleaning-temporary-processes/...`
- If `CODEX_HOME` is unavailable, the scripts fall back to the OS temporary directory
- The sanitization step is local implementation detail for safe filenames and lookup keys; it does not authorize broader cleanup
- This state is runtime-only support data for the installed package and should not be committed back into projects

## Cross-Platform Package Contents

The public package includes:

- `SKILL.md` for manual fallback guidance
- `agents/openai.yaml` for install-time metadata and the default automatic prompt
- `.codex-plugin/plugin.json`, `hooks.json`, and `hooks/` for plugin-style automatic strong triggering
- `scripts/process-inventory.ps1`
- `scripts/process-classification.ps1`
- `scripts/cleanup-policy.ps1`
- `scripts/thread-ownership-ledger.ps1`
- `scripts/cleanup-temporary-processes.ps1`
- `scripts/cleanup-temporary-processes.sh`

The shared PowerShell entrypoint works on Windows, macOS, and Linux. The shell wrapper is provided for macOS and Linux environments that prefer `bash`.

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

For explicit automation follow-up, add `-ConfirmCurrentThreadExplicitAutomation` only on the first follow-up pass where this same thread is confirming real use from the finished checkpoint, and always pair it with a non-blank `-Workspace`.

## Quick Reference

| Situation | Action |
| --- | --- |
| Package is installed in plugin-style mode | Let automatic strong triggering re-check at fixed checkpoints |
| Package is only installed in skill-style mode under `CODEX_HOME/skills` | Use `SKILL.md` as manual fallback guidance and run `inspect` or `checkpoint-cleanup` yourself |
| A high-risk step just finished | Prefer `checkpoint-cleanup` |
| Reuse is still plausible | Run `inspect` first |
| The session is ending | Use `cleanup` for the final sweep if the remaining temporary process trees are no longer needed |

## Common Mistakes

- Treating standalone `SKILL.md` or a plain skill-style install as the source of automatic triggering
- Ignoring the distinction between plugin-style installation and skill-style installation
- Waiting until the whole task ends even though several finished checkpoints already left dead temporary processes behind
- Treating workspace match alone as enough evidence for explicit automation cleanup
- Using `-ConfirmCurrentThreadExplicitAutomation` for automation this thread did not actually use in the finished checkpoint
- Treating a blank `-Workspace` as a wildcard for same-thread explicit automation follow-up
- Assuming current-thread ownership can make generic runtimes or ordinary dev tools killable by itself
- Treating Codex-owned ancestry alone as immediate cleanup permission
- Reporting "all clear" without checking the remaining classified process list
