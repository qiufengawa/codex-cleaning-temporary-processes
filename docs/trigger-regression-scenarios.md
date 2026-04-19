# Trigger Regression Scenarios

These scenarios define the public trigger contract for the pure skill package.

Because this repository ships as a skill rather than a plugin, the checkpoints below describe best-effort implicit invocation targets, not guaranteed host callbacks.

## Positive Contract

### `must reconsider now`

Use this class for:

- a finished one-shot high-risk command such as `npm test`, `vite build`, `vitest`, `cargo test`, `tauri build`, `pytest`, or `dotnet build`
- a failed one-shot high-risk command in the same categories
- a finished DevTools, browser automation, or remote-debug checkpoint
- a finished subagent checkpoint
- a finished same-workspace batch of one-shot high-risk commands
- a user-requested final sweep

Expected decision: prefer `checkpoint-cleanup` when the leftovers are clearly temporary and finished; otherwise fall back to `inspect`.

### `should reconsider soon`

Use this class for:

- backlog relief checkpoints where repeated finished commands may have left temporary helpers behind
- finished checkpoints where some residue risk exists but reuse is still plausible

Expected decision: prefer `inspect` when reuse is plausible or ownership is still ambiguous.

## Negative Contract

### `do not reconsider from this checkpoint alone`

Use this class for:

- low-risk inspection commands such as listing, searching, grepping, or reading files
- long-lived `dev`, `watch`, `serve`, preview, or storybook-style checkpoints where reuse value is still the point
- `session-end alone`
- ambiguous checkpoints with no reliable workspace or task ownership

Expected decision: no stronger cleanup reconsideration from this checkpoint alone.

## Safety Reminder

- Best-effort implicit invocation should stay conservative.
- Stronger trigger wording means stronger reconsideration, not stronger kill authority.
- Current-thread ownership only narrows explicit automation cleanup; it does not widen cleanup for generic runtimes.
- Do not clean plain interactive shells, ordinary user browsers, reusable dev servers, or ambiguous runtimes without strong task-specific evidence.
- Workspace match alone is not enough for explicit automation.

## Action Protocol

- inspect first after a trigger-worthy finished checkpoint
- if `inspect` reports `killable roots`, run `checkpoint-cleanup` next
- use `-ConfirmCurrentThreadExplicitAutomation` on the first follow-up `inspect` only when the just-finished checkpoint really used same-thread explicit automation and the workspace is non-blank
- read the returned ledger path fields when verifying whether same-thread ownership state was recorded
