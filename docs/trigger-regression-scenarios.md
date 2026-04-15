# Trigger Regression Scenarios

These scenarios are the public trigger contract for when Codex should remember this skill before process stacks build up.

## Scenario 1: One-shot tool command finished

- What happened: a finished step ran a one-shot build, test, install, preview, or runtime command such as `pnpm test`, `cargo test`, `pytest`, or `dotnet build`.
- Should the skill trigger automatically: yes.
- When to trigger: immediately after the step is clearly finished, even if the larger task continues.
- Expected mode: prefer `checkpoint-cleanup`; fall back to `inspect` first if the next step may reuse the process.

## Scenario 2: DevTools MCP or browser-debug work finished

- What happened: the session used `mcp__chrome_devtools__*`, `chrome-devtools-mcp`, Playwright-style tooling, or a browser launched with `--remote-debugging-port` or `--headless`.
- Should the skill trigger automatically: yes.
- When to trigger: after the DevTools or browser-debug step finishes, not only at end-of-task.
- Expected mode: prefer `checkpoint-cleanup` for obvious launcher, watchdog, helper-shell, and remote-debug leftovers; use `inspect` first if reuse is still plausible. The first follow-up pass may record current-thread ownership only when this same thread explicitly confirms real explicit-automation use with `-ConfirmCurrentThreadExplicitAutomation` and a non-blank workspace; later same-workspace passes may still reclaim that automation after the original launcher exits, but workspace match alone still does not make those leftovers killable and Codex `app-server` ancestry alone is not immediate cleanup permission.

## Scenario 3: Repeated shell or tool helpers accumulated

- What happened: several shell or tool commands ran in a batch and may have left temporary helpers, wrappers, or runtimes behind.
- Should the skill trigger automatically: yes, once the batch has produced its value and those helpers no longer have reuse value.
- When to trigger: after the batch of one-shot commands, even inside the same long assistant turn.
- Expected mode: prefer `inspect` when ownership is still ambiguous; use `checkpoint-cleanup` when the finished-step evidence is strong.

## Scenario 4: Subagent-owned tooling finished

- What happened: a subagent finished work and may have launched shells, runtimes, tests, builds, browser helpers, or dev servers.
- Should the skill trigger automatically: yes, if those processes are no longer needed for the active step.
- When to trigger: when the subagent result arrives and the spawned tooling is clearly step-finished.
- Expected mode: prefer `inspect` when reuse is plausible; use `checkpoint-cleanup` when the subagent-owned leftovers are clearly temporary and finished.

## Safety Reminder

- Automatic triggering should stay conservative.
- Current-thread ownership only narrows explicit automation cleanup; it does not widen cleanup for generic runtimes.
- Do not clean plain interactive shells, ordinary user browsers, reusable dev servers, or ambiguous runtimes without strong task-specific evidence.
- Final `cleanup` remains the end-of-task sweep, not the default response to every trigger.
