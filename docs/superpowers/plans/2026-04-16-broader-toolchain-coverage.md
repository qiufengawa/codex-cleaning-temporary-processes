# Broader Toolchain Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the public skill's explicit classifier coverage across more mainstream language ecosystems while preserving the existing safety model and multi-project isolation.

**Architecture:** Add RED tests for the missing ecosystems first, then extend the PowerShell classifier pattern tables so shell-wrapped tools, direct tools, and runtime-style invocations are recognized only when workspace-backed task ownership exists. Finally, update the public docs so the broader coverage claims match the tested implementation.

**Tech Stack:** PowerShell, Pester, Markdown, YAML

---

### Task 1: Add RED Coverage Tests

**Files:**
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\process-classification.Tests.ps1`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\skill-trigger-contract.Tests.ps1`

- [ ] **Step 1: Add failing classification tests for new mainstream ecosystems**

```powershell
It 'classifies broader mainstream toolchains as temporary dev tools' -TestCases @(
  @{ Name = 'clj'; ProcessName = 'clj'; CommandLine = 'clj -M:dev -m app.core --project-dir /repo' },
  @{ Name = 'cabal'; ProcessName = 'cabal'; CommandLine = 'cabal test all --project-dir=/repo' },
  @{ Name = 'Rscript'; ProcessName = 'Rscript'; CommandLine = 'Rscript /repo/scripts/dev.R' }
)
```

- [ ] **Step 2: Add at least one negative safety test for missing workspace evidence**

```powershell
$result = @(Get-TemporaryProcessClassifications -Processes $processes)
$result.Count | Should Be 0
```

- [ ] **Step 3: Add failing documentation expectations for the new ecosystems**

```powershell
$readmeEnglish | Should Match 'clj'
$readmeEnglish | Should Match 'cabal'
$projectIntroEnglish | Should Match 'zig'
```

- [ ] **Step 4: Run focused suites and confirm they fail before implementation**

Run:

```powershell
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru
```

Expected: new toolchain cases fail because the current classifier and docs do not yet cover them.

### Task 2: Extend The Classifier

**Files:**
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\scripts\process-classification.ps1`

- [ ] **Step 1: Extend direct tool and runtime name tables**

```powershell
"^(clj|lein|ghci|runghc|cabal|stack|dune|prove|cpanm|luarocks|zig)(\.exe)?$"
```

- [ ] **Step 2: Add workspace-scoped shell and direct-tool patterns**

```powershell
"\b(clj|lein)\b.*\b(run|test|repl|-m|-X|-T)\b"
"\b(cabal|stack)\b.*\b(run|test|build|repl)\b"
"\b(dune|zig)\b.*\b(exec|test|build|run)\b"
```

- [ ] **Step 3: Add runtime-style patterns for ecosystems launched through interpreters**

```powershell
"\b(Rscript|perl|lua|ocaml)\b.*(/repo|C:\\Repo)"
```

- [ ] **Step 4: Run the focused classification suite and confirm the new tests pass**

Run: `Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru`

Expected: new ecosystem tests pass while the negative safety test remains green.

### Task 3: Update Public Coverage Documentation

**Files:**
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\SKILL.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\README.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\README.zh-CN.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\docs\project-introduction.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\docs\project-introduction.zh-CN.md`
- Modify: `C:\Users\Admin\Desktop\Task\codex-cleaning-temporary-processes-public\agents\openai.yaml`

- [ ] **Step 1: Update public coverage lists to include the new ecosystems**

```markdown
- Additional mainstream ecosystems: `clj`, `lein`, `cabal`, `stack`, `dune`, `Rscript`, `perl`, `lua`, `zig`
```

- [ ] **Step 2: Preserve the honesty boundary in every doc**

```markdown
Coverage is broad across mainstream ecosystems, not exhaustive across every language or command.
```

- [ ] **Step 3: Run the focused documentation contract suite**

Run: `Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru`

Expected: documentation expectations pass without reintroducing plugin claims or "all languages" wording.

### Task 4: Run Full Verification

**Files:**
- Modify: repo files from Tasks 1-3 only

- [ ] **Step 1: Run the full Pester matrix**

Run: `Invoke-Pester -Path .\scripts -PassThru`

Expected: all suites pass.

- [ ] **Step 2: Review the diff**

Run: `git diff --stat`

Expected: only classifier, tests, docs, and metadata changed.

- [ ] **Step 3: Commit the broadened public-coverage revision**

Run:

```powershell
git add .
git commit -m "feat: broaden mainstream toolchain coverage"
```

- [ ] **Step 4: Push the revision**

Run: `git push origin main`

Expected: the verified broader-coverage revision is published once network connectivity permits.
