# Codex Cleaning Temporary Processes

[简体中文](./README.zh-CN.md)

Codex Cleaning Temporary Processes is a public, cross-platform package for safe cleanup of temporary development processes on Windows, macOS, and Linux.

## Public Package Model

This repository supports two user-facing installation modes:

- Plugin-style installation keeps the repo root intact with `.codex-plugin/plugin.json`, `hooks.json`, and `hooks/`. That is the install-and-run path that enables automatic strong triggering.
- Skill-style installation under `CODEX_HOME/skills/codex-cleaning-temporary-processes` exposes `SKILL.md`, `agents/openai.yaml`, and the scripts, but it does not activate automatic plugin hook behavior by itself.

The installed plugin package provides automatic checkpoints. The standalone [`SKILL.md`](./SKILL.md) file remains the manual fallback. Automatic triggering changes when Codex re-checks cleanup, not what it is allowed to kill.

## Automatic Strong Triggering

When the package is installed in plugin-style mode, it should re-check cleanup at fixed checkpoints such as:

- after each finished high-risk tool step
- after DevTools MCP, browser automation, or remote-debug work finishes
- after a completed batch of one-shot helpers that no longer have reuse value
- after a subagent finishes
- at session end for the final sweep

This fixed-checkpoint model is intentional. The automatic path should not depend on "remembering when the task ends." It should react to concrete finished checkpoints before process stacks build up.

## Manual Fallback

`SKILL.md` is the fallback/manual guide for environments where the package is only installed in skill-style mode or where plugin hooks are unavailable.

Use the manual path to:

- ask Codex to run `inspect`, `checkpoint-cleanup`, or `cleanup`
- explain why a process is considered `cleanup-now`, `inspect-only`, or `preserve`
- force an explicit review pass before cleanup

The manual path should still follow the same fixed checkpoints. If several risky steps have already finished, do not wait for the overall task to end before inspecting leftovers.

## Trigger Cadence

Treat cleanup as checkpoint-scoped:

- Re-evaluate after each finished high-risk step
- Re-evaluate after DevTools MCP or browser-debug checkpoints finish
- Re-evaluate after a subagent result arrives if its tooling is no longer needed
- Re-evaluate after a batch of one-shot commands when backlog relief is useful
- Re-evaluate at session end for the final sweep

Prefer `checkpoint-cleanup` when the step is clearly finished. Use `inspect` when reuse is still plausible.

## Safety Model

This package is intentionally conservative.

- It preserves the active Codex shell and Codex helper shells
- It preserves ordinary browsers that do not carry automation or remote-debug flags
- It preserves ambiguous runtimes when strong ownership evidence is missing
- It preserves likely reusable dev servers during checkpoint cleanup
- It only cleans high-confidence temporary process trees that no longer provide value to the current checkpoint

Explicit automation has extra safeguards:

- current-task lineage or current-thread-owned explicit automation evidence is required
- workspace match alone is not enough
- `Codex.exe app-server` ancestry can make explicit automation seedable, but not immediately killable
- `-ConfirmCurrentThreadExplicitAutomation` only applies to a first follow-up pass that explicitly confirms real same-thread use with a non-blank workspace
- current-thread ownership never broadens cleanup for generic runtimes

## Multi-Project Isolation

The package must stay safe when several projects or Codex conversations are active at once.

- Workspace-backed build, test, serve, watch, and runtime processes must match the current workspace or a task-owned ancestor
- Explicit automation from another workspace or another Codex conversation stays `inspect-only` unless current-task lineage or confirmed current-thread ownership proves it belongs to this checkpoint
- Current-thread ownership is only a recovery hint for explicit automation that the same conversation already confirmed with the same workspace
- Generic runtimes do not become killable just because a same-thread automation claim exists

## Sanitization And Local State

Same-thread explicit automation recovery uses sanitized thread identifiers and normalized workspace values in local runtime state.

- The state lives under `CODEX_HOME/state/codex-cleaning-temporary-processes/...` when available
- Otherwise the scripts fall back to the OS temporary directory
- This sanitized local state is runtime support data only; it is not a reason to widen cleanup scope

## Cross-Platform Packaging

This public package includes:

- [`SKILL.md`](./SKILL.md) for manual fallback guidance
- [`agents/openai.yaml`](./agents/openai.yaml) for install-time metadata and the default automatic prompt
- `.codex-plugin/plugin.json`, `hooks.json`, and `hooks/` for plugin-style automatic checkpoints
- PowerShell scripts for inventory, classification, policy, ledger handling, and cleanup
- a shell wrapper for macOS and Linux
- English-first docs plus a Chinese companion
- Pester tests for trigger, classification, policy, and entrypoint behavior

The packaging is cross-platform by design:

- Windows uses PowerShell directly
- macOS and Linux can use `pwsh`
- macOS and Linux can also use the provided `bash` wrapper

## Runtime Requirements

- Windows: PowerShell is available by default
- macOS or Linux: install PowerShell 7 so `pwsh` is available
- If your checkout does not preserve executable bits, run the Unix wrapper through `bash`

## Installation

### Plugin-style installation

Use this mode when you want automatic strong triggering.

1. Keep the repo root intact so `.codex-plugin/plugin.json`, `hooks.json`, `hooks/`, `agents/openai.yaml`, and `scripts/` stay together.
2. Install or enable the package through your Codex plugin workflow.
3. Verify that the environment supports plugin hooks so the automatic checkpoints can run.

### Skill-style installation

Use this mode when you only need the manual skill text and scripts.

1. Place the package under `CODEX_HOME/skills/codex-cleaning-temporary-processes`.
2. Use the standalone `SKILL.md` guidance or invoke the scripts directly.
3. Do not expect automatic hook behavior from skill-style installation alone.

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

If a finished checkpoint really used DevTools MCP, Playwright-style automation, or a remote-debug browser in this same thread, add `-ConfirmCurrentThreadExplicitAutomation` on the first follow-up pass together with the workspace. That first confirmed pass records same-thread ownership for that workspace; later same-workspace passes may reclaim leftovers that remain after their launcher exits.

## Troubleshooting

- If the package is only installed in skill-style mode, explicitly ask Codex to use `$codex-cleaning-temporary-processes`.
- If automatic hooks are unavailable, check the plugin-style installation files: `.codex-plugin/plugin.json`, `hooks.json`, and `hooks/`.
- If process stacks keep growing, check whether a fixed checkpoint was skipped after a finished high-risk step or subagent result.
- If the next step may reuse a process, ask Codex to run `inspect` first rather than forcing cleanup.
- If a process is preserved, that may be intentional because workspace evidence, automation flags, or other strong ownership signals were not present.
- If `-Workspace` is blank, missing, or points at a different repo, same-thread confirmation will not seed or promote ownership.
- If a process only traces back to `Codex.exe app-server`, that is still not enough to clean it.
- If several projects are active at once, expect unowned DevTools or browser-debug leftovers to remain `inspect-only` until the current task can prove ownership.

## Testing

Run the focused suites:

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru
```

Or run the full matrix:

```powershell
Invoke-Pester -Path .\scripts -PassThru
```

## License

This project is released under the [MIT License](./LICENSE).
