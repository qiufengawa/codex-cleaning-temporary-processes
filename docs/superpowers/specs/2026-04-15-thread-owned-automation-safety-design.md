# Thread-Owned Automation Safety Design

## Goal

Let the current Codex conversation reclaim its own explicit automation leftovers more reliably, without broadening cleanup for generic workspace runtimes or weakening the existing multi-project safety posture.

## Current Problem

The current public skill already does two important things well:

- it re-checks cleanup at step checkpoints instead of waiting only for task end
- it keeps unowned DevTools MCP, browser automation, and remote-debug sessions in `inspect-only`

That safety posture avoids cross-project kills, but it leaves one gap: a current Codex thread can lose ownership evidence for its own explicit automation once the original workspace-backed launcher exits. When that happens, later cleanup passes become conservative again and leave stackable automation helpers behind.

## Requirements

- Keep the default fallback unchanged: no ownership evidence means `inspect-only`.
- Do not make generic `dev-tool` or non-automation `tool-shell` records thread-owned.
- Only use thread ownership as a conservative recovery path for explicit automation classes:
  - `devtools-mcp`
  - `devtools-launcher`
  - `devtools-watchdog`
  - `browser-automation`
  - `browser-debug`
  - explicit automation wrapper shells
- Only persist thread ownership after a process was already proven killable by existing strong evidence in the current thread.
- Store runtime ownership state outside the public repo so the published source stays clean.
- Prune stale ownership entries so dead processes do not accumulate.
- Preserve current behavior when `CODEX_THREAD_ID` is absent.

## Approaches Considered

### Option A: Read per-process environment and match `CODEX_THREAD_ID`

Pros:

- strong attribution in theory

Cons:

- cross-platform process environment inspection is inconsistent
- adds platform-specific complexity and permission risk
- harder to validate in tests

### Option B: Thread ownership ledger seeded from already-proven ownership

Pros:

- keeps the current conservative model
- works as an additive optimization
- simple to test
- does not require unsafe process-environment scraping

Cons:

- only helps after the current thread has seen the process once with strong evidence
- needs stale-entry pruning

### Option C: Require thread ownership for all cleanup

Pros:

- strongest isolation

Cons:

- too disruptive
- would break existing workspace-scoped cleanup behavior
- would under-clean common one-shot build and test leftovers

## Recommended Design

Choose Option B.

### Ownership Model

- Existing workspace and ancestor evidence remain the primary attribution path.
- A local thread ownership ledger adds a secondary attribution path for explicit automation only.
- The current thread can mark a process as thread-owned only when that process is already killable through strong existing evidence in the current pass.
- Later passes may treat the same explicit automation process as current-task-owned if it still matches the stored fingerprint for the same thread.

### Scope Boundary

Thread ownership is allowed for:

- DevTools MCP services, launchers, and watchdogs
- remote-debug browsers
- explicit browser automation helpers
- wrapper shells whose command line explicitly launches automation helpers

Thread ownership is not allowed for:

- plain workspace runtimes such as `python`, `node`, `java`, `dotnet`, `go`, `ruby`, `php`
- generic build/test shells without explicit automation markers
- interactive shells
- current Codex shells

### Ledger Storage

- Use a local state directory outside the repo, preferring a `CODEX_HOME`-scoped runtime path.
- Keep one ledger file per Codex thread id.
- Persist only non-sensitive process fingerprints already visible from local process metadata:
  - `ProcessId`
  - `Name`
  - `CommandLine`
  - `Category`
  - `Workspace`
  - `ObservedAt`

### Matching Rules

A live process may reuse thread ownership only when all of the following are true:

- current `CODEX_THREAD_ID` is available
- the live process matches a stored entry for the same thread
- the category is one of the explicit automation categories
- the stored entry is still fresh

If any of those checks fail, fall back to the existing workspace and ancestor logic.

### Pruning Rules

- remove entries for processes that are no longer present
- remove entries older than the freshness window
- overwrite entries when the same process id is observed again by the same thread

## Testing Strategy

- add RED tests for thread-owned explicit automation becoming killable without fresh workspace evidence
- add RED tests proving generic runtimes do not inherit thread ownership
- add RED tests for stale or mismatched ledger entries staying `inspect-only`
- add entrypoint tests proving ledger update and pruning happen around inspect and cleanup passes
- update docs only after code and tests agree on the final behavior

## Out of Scope

- process-environment scraping
- thread ownership for generic build or runtime processes
- background daemons or OS-specific services
- changing the published skill name or packaging structure
