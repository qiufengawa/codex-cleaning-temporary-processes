# Stronger Trigger Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strengthen the pure-skill trigger contract so Codex must reconsider cleanup at clearer fixed checkpoints, while keeping the package honest about not having host hooks or broader kill authority.

**Architecture:** Update the public trigger model in `SKILL.md`, README files, trigger scenario docs, and `agents/openai.yaml` so they distinguish "must reconsider now" from later cleanup decisions. Lock that contract in `skill-trigger-contract.Tests.ps1` and rename public sample fixtures from hook-shaped names to neutral checkpoint-trigger fixtures.

**Tech Stack:** Markdown, YAML, JSON fixtures, PowerShell, Pester

---

### Task 1: Lock The Stronger Trigger Contract In Failing Tests

**Files:**
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\skill-trigger-contract.Tests.ps1`

- [ ] **Step 1: Add failing expectations for the stronger trigger classes**

```powershell
$skillMarkdown | Should Match 'must reconsider now'
$skillMarkdown | Should Match 'should reconsider soon'
$skillMarkdown | Should Match 'do not reconsider from this checkpoint alone'
```

- [ ] **Step 2: Add failing expectations for high-risk failure checkpoints and negative trigger cases**

```powershell
$readmeEnglish | Should Match 'failed one-shot high-risk'
$triggerScenariosEnglish | Should Match 'long-lived'
$triggerScenariosEnglish | Should Match 'session-end alone'
$triggerScenariosChinese | Should Match '失败'
```

- [ ] **Step 3: Add failing expectations for neutral trigger-fixture packaging**

```powershell
Test-Path (Join-Path $repoRoot 'scripts\trigger-fixtures') | Should Be $true
Test-Path (Join-Path $repoRoot 'scripts\hook-trigger-fixtures') | Should Be $false
```

- [ ] **Step 4: Run the focused contract suite and confirm the new checks fail**

Run: `Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru`

Expected: the suite fails because the docs do not yet expose the stronger trigger classes and the old fixture directory still exists.

### Task 2: Rename Public Trigger Fixtures And Normalize Their Meaning

**Files:**
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-one-shot-success.json`
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-one-shot-failure.json`
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-explicit-automation.json`
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-subagent-complete.json`
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-batch-finished.json`
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-low-risk.json`
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-long-running-dev.json`
- Create: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\trigger-fixtures\checkpoint-session-end.json`
- Delete or rename: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\hook-trigger-fixtures\*`

- [ ] **Step 1: Create the neutral fixture directory and copy the existing positive samples into new checkpoint names**

```powershell
Rename-Item -LiteralPath .\scripts\hook-trigger-fixtures -NewName trigger-fixtures
```

- [ ] **Step 2: Add a dedicated failure fixture and a batch-finished fixture**

```json
{
  "checkpoint_type": "one-shot-high-risk",
  "result": "failure",
  "workspace": "/repo"
}
```

- [ ] **Step 3: Rename the low-risk, long-running-dev, and session-end samples so their meaning is explicit**

```json
{
  "checkpoint_type": "low-risk-inspection",
  "result": "success"
}
```

- [ ] **Step 4: Re-run the focused contract suite and confirm the fixture-path checks now pass while wording checks still drive failures**

Run: `Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru`

Expected: fixture-path assertions pass, but stronger wording assertions still fail until docs are updated.

### Task 3: Strengthen Skill Metadata And Public Trigger Docs

**Files:**
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\SKILL.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\agents\openai.yaml`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\README.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\README.zh-CN.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\docs\trigger-regression-scenarios.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\docs\trigger-regression-scenarios.zh-CN.md`

- [ ] **Step 1: Update `SKILL.md` so the trigger section exposes the three public classes**

```markdown
## Trigger Model

- `must reconsider now`
- `should reconsider soon`
- `do not reconsider from this checkpoint alone`
```

- [ ] **Step 2: Update `agents/openai.yaml` to bias toward high-risk finished checkpoints, including failed one-shot steps**

```yaml
default_prompt: "When a finished high-risk one-shot step succeeds or fails, or when explicit automation, a subagent, or a same-workspace batch finishes, must reconsider cleanup now ..."
```

- [ ] **Step 3: Rewrite the English trigger docs to include positive examples, negative examples, and the honesty boundary**

```markdown
- stronger trigger means stronger reconsideration, not stronger kill authority
- failed one-shot high-risk steps still count
- session-end alone does not count
```

- [ ] **Step 4: Mirror the same trigger contract in Chinese**

```markdown
- 更强触发表示更强的重新评估义务，不表示更强的 kill 权限
- 一次性高风险步骤即使失败也要重新评估
- 仅有 session end 不单独构成强触发
```

- [ ] **Step 5: Re-run the focused contract suite and confirm it passes**

Run: `Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru`

Expected: the stronger trigger wording and fixture contract pass without reintroducing plugin claims.

### Task 4: Run Full Verification And Prepare The Publishable Revision

**Files:**
- Modify: repo files from Tasks 1-3 only

- [ ] **Step 1: Run the full test matrix**

Run: `Invoke-Pester -Path .\scripts -PassThru`

Expected: all suites pass, including classification, cleanup policy, entrypoint, ledger, and trigger-contract coverage.

- [ ] **Step 2: Review the diff to confirm the package still looks like a pure skill**

Run: `git diff --stat`

Expected: only docs, metadata, fixtures, and contract tests changed; no plugin manifests or hook entrypoints were reintroduced.

- [ ] **Step 3: Commit the stronger-trigger revision**

Run:

```powershell
git add .
git commit -m "feat: strengthen pure-skill trigger contract"
```

Expected: commit succeeds with only the intended stronger-trigger changes staged.

- [ ] **Step 4: Push the revision**

Run: `git push origin main`

Expected: `origin/main` advances to the stronger-trigger revision after verification stays green.
