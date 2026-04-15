# Trigger Regression Scenarios

These scenarios define the public trigger contract for the pure skill package.

Because this repository ships as a skill rather than a plugin, the checkpoints below describe best-effort implicit invocation targets, not guaranteed host callbacks.

## Scenario 1: Finished one-shot tool checkpoint

- What happened: a finished step ran a one-shot command such as `npm test`, `vite build`, `vitest`, `cargo test`, `tauri build`, `pytest`, or `dotnet build`.
- Should the skill consider itself: yes, best-effort.
- When to trigger: as soon as the finished checkpoint is clear, even if the larger task continues.
- Expected mode: prefer `checkpoint-cleanup`; use `inspect` first if reuse is still plausible.

## Scenario 2: Finished DevTools or browser automation checkpoint

- What happened: the session used `mcp__chrome_devtools__*`, `chrome-devtools-mcp`, Playwright-style tooling, or a browser launched with remote-debug or headless markers.
- Should the skill consider itself: yes, best-effort.
- When to trigger: after the explicit automation checkpoint finishes, not only when the whole task ends.
- Expected mode: prefer `checkpoint-cleanup` for obvious launcher, watchdog, helper-shell, and remote-debug leftovers; use `inspect` first if reuse is still plausible. The first follow-up pass may record current-thread ownership only when this same thread explicitly confirms real explicit-automation use with `-ConfirmCurrentThreadExplicitAutomation` and a non-blank workspace.

## Scenario 3: Helper backlog relief checkpoint

- What happened: repeated shell or tool commands finished and may have left temporary helpers, wrappers, or runtimes behind.
- Should the skill consider itself: yes, best-effort.
- When to trigger: after the finished batch, before process stacks grow further.
- Expected mode: prefer `inspect` when ownership is still ambiguous; use `checkpoint-cleanup` when finished-step evidence is strong.

## Scenario 4: Finished subagent checkpoint

- What happened: a subagent finished work and may have launched shells, runtimes, tests, builds, browser helpers, or dev servers.
- Should the skill consider itself: yes, best-effort.
- When to trigger: when the subagent result arrives and the spawned tooling is clearly step-finished.
- Expected mode: prefer `inspect` when reuse is plausible; use `checkpoint-cleanup` when the leftovers are clearly temporary and finished.

## Scenario 5: Final sweep checkpoint

- What happened: the current branch of work is pausing, or the user explicitly asks for a final sweep, and the remaining temporary process trees are no longer needed.
- Should the skill consider itself: yes, best-effort.
- When to trigger: at the point where a final sweep is clearly safe.
- Expected mode: use full `cleanup` after checkpoint-safe passes have already handled earlier leftovers.

## Safety Reminder

- Best-effort implicit invocation should stay conservative.
- Current-thread ownership only narrows explicit automation cleanup; it does not widen cleanup for generic runtimes.
- Do not clean plain interactive shells, ordinary user browsers, reusable dev servers, or ambiguous runtimes without strong task-specific evidence.
- Workspace match alone is not enough for explicit automation.
