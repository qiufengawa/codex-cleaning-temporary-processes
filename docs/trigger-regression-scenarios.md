# Trigger Regression Scenarios

These scenarios are the public trigger contract for plugin-style installation.

Automatic strong triggering requires the repo-root plugin files such as `.codex-plugin/plugin.json`, `hooks.json`, and `hooks/`. Skill-style installation under `CODEX_HOME/skills` is the manual fallback path and does not auto-run these checkpoints by itself.

Automatic strong triggering is fixed-checkpoint based. It should not depend on Codex vaguely remembering cleanup when the task ends. If automatic hooks are unavailable, the manual fallback is to ask Codex to use `$codex-cleaning-temporary-processes` or run the scripts directly.

## Scenario 1: Finished one-shot tool checkpoint

- What happened: a finished step ran a one-shot build, test, install, preview, or runtime command such as `pnpm test`, `cargo test`, `pytest`, or `dotnet build`.
- Should the plugin-style installation trigger automatically: yes.
- When to trigger: immediately after the checkpoint is clearly finished, even if the larger task continues.
- Expected mode: prefer `checkpoint-cleanup`; fall back to `inspect` first if the next step may reuse the process.

## Scenario 2: Finished DevTools or browser automation checkpoint

- What happened: the session used `mcp__chrome_devtools__*`, `chrome-devtools-mcp`, Playwright-style tooling, or a browser launched with `--remote-debugging-port` or `--headless`.
- Should the plugin-style installation trigger automatically: yes.
- When to trigger: after the DevTools or browser-debug checkpoint finishes, not only at session end.
- Expected mode: prefer `checkpoint-cleanup` for obvious launcher, watchdog, helper-shell, and remote-debug leftovers; use `inspect` first if reuse is still plausible. The first follow-up pass may record current-thread ownership only when this same thread explicitly confirms real explicit-automation use with `-ConfirmCurrentThreadExplicitAutomation` and a non-blank workspace.

## Scenario 3: Helper backlog relief checkpoint

- What happened: repeated shell or tool commands finished and may have left temporary helpers, wrappers, or runtimes behind.
- Should the plugin-style installation trigger automatically: yes.
- When to trigger: after the finished batch, before process stacks grow further.
- Expected mode: prefer `inspect` when ownership is still ambiguous; use `checkpoint-cleanup` when the finished-step evidence is strong.

## Scenario 4: Finished subagent checkpoint

- What happened: a subagent finished work and may have launched shells, runtimes, tests, builds, browser helpers, or dev servers.
- Should the plugin-style installation trigger automatically: yes, if those processes are no longer needed for the active checkpoint.
- When to trigger: when the subagent result arrives and the spawned tooling is clearly step-finished.
- Expected mode: prefer `inspect` when reuse is plausible; use `checkpoint-cleanup` when the leftovers are clearly temporary and finished.

## Scenario 5: Session end checkpoint

- What happened: the session is ending and the remaining temporary process trees are no longer needed.
- Should the plugin-style installation trigger automatically: yes.
- When to trigger: at session end as the final fixed checkpoint.
- Expected mode: use full `cleanup` for the final sweep after the checkpoint-safe passes have already handled earlier finished steps.

## Safety Reminder

- Automatic strong triggering should stay conservative.
- Current-thread ownership only narrows explicit automation cleanup; it does not widen cleanup for generic runtimes.
- Do not clean plain interactive shells, ordinary user browsers, reusable dev servers, or ambiguous runtimes without strong task-specific evidence.
- Workspace match alone is not enough for explicit automation.
- Manual fallback should preserve the same fixed checkpoints and safety rules as plugin-style installation.
