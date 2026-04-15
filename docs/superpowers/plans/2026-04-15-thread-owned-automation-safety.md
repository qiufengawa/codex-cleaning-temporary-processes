# Thread-Owned Automation Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a thread-owned automation ledger that helps the current Codex conversation reclaim its own explicit automation leftovers without broadening cleanup for generic dev processes.

**Architecture:** Keep workspace and ancestor ownership as the primary signal. Add a local runtime ledger keyed by `CODEX_THREAD_ID`, seed it only from already-proven explicit automation records, and consult it only for explicit automation categories. Prune stale entries on every run.

**Tech Stack:** PowerShell, Pester, Codex skill metadata, Markdown docs

---

### Task 1: Lock The Desired Safety Contract In Tests

**Files:**
- Modify: `scripts/process-classification.Tests.ps1`
- Modify: `scripts/cleanup-temporary-processes.Tests.ps1`

- [ ] **Step 1: Write failing classification tests for thread-owned explicit automation**

```powershell
It 'classifies thread-owned DevTools MCP services as killable without fresh workspace evidence' {
  # arrange thread-owned fingerprint input
  # assert category stays devtools-mcp and Killable becomes $true
}

It 'does not let thread ownership make a generic runtime killable' {
  # arrange a python or node runtime plus thread-owned fingerprint input
  # assert result stays unclassified or non-killable
}

It 'keeps mismatched or stale thread-owned browser-debug sessions as inspect-only' {
  # arrange a browser-debug process with non-matching or expired ownership data
  # assert Killable stays $false
}
```

- [ ] **Step 2: Run the focused classification suite and watch the new tests fail**

Run: `Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru`

Expected: new thread-ownership tests fail because the classifier cannot consume thread-owned evidence yet.

- [ ] **Step 3: Write failing entrypoint tests for ledger persistence and pruning**

```powershell
It 'persists current-thread ownership only for killable explicit automation records' {
  # arrange a harness run with killable devtools + non-automation dev-tool
  # assert ledger output stores only the automation record
}

It 'prunes dead or stale thread-owned entries before returning output' {
  # arrange old ownership data and a post-run inventory without those processes
  # assert the ledger is reduced
}
```

- [ ] **Step 4: Run the entrypoint suite and watch the new tests fail**

Run: `Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru`

Expected: new ledger tests fail because no ledger helper is wired yet.

### Task 2: Implement Thread-Owned Explicit Automation Support

**Files:**
- Create: `scripts/thread-ownership-ledger.ps1`
- Modify: `scripts/process-classification.ps1`
- Modify: `scripts/cleanup-temporary-processes.ps1`

- [ ] **Step 1: Add a ledger helper with read, match, update, and prune functions**

```powershell
function Get-CodexThreadOwnershipLedger { }
function Test-ThreadOwnedAutomationMatch { }
function Update-CodexThreadOwnershipLedger { }
```

- [ ] **Step 2: Extend classification to accept thread-owned evidence for explicit automation only**

```powershell
Get-TemporaryProcessClassifications -Processes $processes -Workspace $workspace -ThreadOwnershipEntries $entries
```

- [ ] **Step 3: Wire the entrypoint so each run loads the current thread id, prunes stale ownership, classifies with ledger input, and persists fresh explicit automation ownership**

```powershell
. (Join-Path $PSScriptRoot "thread-ownership-ledger.ps1")

$threadId = Get-CurrentCodexThreadId
$entries = Get-CodexThreadOwnershipLedger -ThreadId $threadId
# classify
# persist killable explicit automation entries
```

- [ ] **Step 4: Re-run the focused suites until they pass**

Run:

```powershell
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
```

Expected: all focused tests pass with the new ledger logic.

### Task 3: Document The New Safety Boundary

**Files:**
- Modify: `SKILL.md`
- Modify: `agents/openai.yaml`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/project-introduction.md`
- Modify: `docs/project-introduction.zh-CN.md`

- [ ] **Step 1: Update the public docs to explain thread-owned automation as an optimization, not a permission broadening**

```markdown
- explicit automation may be reclaimed by the current Codex thread after prior strong ownership evidence
- generic runtimes still require workspace-backed evidence
- missing thread ownership still falls back to inspect-only
```

- [ ] **Step 2: Add or adjust trigger-contract language if needed**

Run: `Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru`

Expected: documentation contract remains green after wording changes.

### Task 4: Full Verification And Release Prep

**Files:**
- Modify: installed skill copy under `$CODEX_HOME\skills\codex-cleaning-temporary-processes\...` after repo verification

- [ ] **Step 1: Run the full test matrix**

Run: `Invoke-Pester -Path .\scripts -PassThru`

Expected: full suite passes with no regressions.

- [ ] **Step 2: Sync the installed skill copy only after the repo version is verified**

Run:

```powershell
Copy-Item -LiteralPath .\SKILL.md -Destination "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\SKILL.md" -Force
```

- [ ] **Step 3: Re-run the high-value installed-skill subset**

Run:

```powershell
Invoke-Pester -Path "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\process-classification.Tests.ps1" -PassThru
Invoke-Pester -Path "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\cleanup-policy.Tests.ps1" -PassThru
Invoke-Pester -Path "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\skill-trigger-contract.Tests.ps1" -PassThru
```

- [ ] **Step 4: Commit and push once verification is green**

Run:

```powershell
git add .
git commit -m "feat: add thread-owned automation safety ledger"
git push origin main
```
