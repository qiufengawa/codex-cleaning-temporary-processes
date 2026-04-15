$entrypointPath = Join-Path $PSScriptRoot 'invoke-hook-trigger.ps1'

function Get-TestPowerShellExecutable {
  $pwsh = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
  if ($null -ne $pwsh) {
    return $pwsh.Source
  }

  $powershell = Get-Command -Name 'powershell' -ErrorAction Stop
  return $powershell.Source
}

function ConvertTo-CompressedTestJson {
  param([object]$Value)

  if ($null -eq $Value) {
    return 'null'
  }

  return ($Value | ConvertTo-Json -Depth 12 -Compress)
}

function New-HookEntrypointHarness {
  param(
    [string]$HarnessRoot,
    [object]$PolicyDecision,
    [object]$RuntimeDecision,
    [object]$CleanupResult = $null,
    [object]$InitialState = $null
)

  $null = New-Item -ItemType Directory -Path $HarnessRoot -Force
  $resolvedHarnessRoot = (Resolve-Path -LiteralPath $HarnessRoot).ProviderPath
  Copy-Item -LiteralPath $entrypointPath -Destination (Join-Path $resolvedHarnessRoot 'invoke-hook-trigger.ps1') -Force

  $policyDecisionJson = ConvertTo-CompressedTestJson -Value $PolicyDecision
  $runtimeDecisionJson = ConvertTo-CompressedTestJson -Value $RuntimeDecision
  $initialStateJson = ConvertTo-CompressedTestJson -Value $InitialState
  $cleanupResultJson = ConvertTo-CompressedTestJson -Value $CleanupResult

  $policyStub = @"
Set-StrictMode -Version Latest

function Get-HookTriggerDecision {
  param(
    [pscustomobject]`$HookInput,
    [string]`$Workspace,
    [string]`$ThreadId
  )

  [pscustomobject]@{
    Workspace = `$Workspace
    ThreadId = `$ThreadId
    HookInput = `$HookInput
  } | ConvertTo-Json -Depth 12 -Compress | Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'policy-call.json')

  return (ConvertFrom-Json @'
$policyDecisionJson
'@)
}
"@

  $runtimeStub = @"
Set-StrictMode -Version Latest

function Get-TriggerRuntimeState {
  param(
    [string]`$ThreadId,
    [string]`$Workspace
  )

  [pscustomobject]@{
    ThreadId = `$ThreadId
    Workspace = `$Workspace
  } | ConvertTo-Json -Depth 8 -Compress | Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'state-get.json')

  return (ConvertFrom-Json @'
$initialStateJson
'@)
}

function Get-TriggerRuntimeDecision {
  param(
    [object]`$State,
    [string]`$CheckpointKey,
    [datetime]`$CurrentTimeUtc,
    [timespan]`$DebounceWindow,
    [timespan]`$CooldownWindow,
    [int]`$BacklogReliefThreshold
  )

  [pscustomobject]@{
    State = `$State
    CheckpointKey = `$CheckpointKey
    CurrentTimeUtc = `$CurrentTimeUtc.ToString('o')
    DebounceWindowSeconds = [int]`$DebounceWindow.TotalSeconds
    CooldownWindowSeconds = [int]`$CooldownWindow.TotalSeconds
    BacklogReliefThreshold = `$BacklogReliefThreshold
  } | ConvertTo-Json -Depth 12 -Compress | Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'state-decision.json')

  return (ConvertFrom-Json @'
$runtimeDecisionJson
'@)
}

function Save-TriggerRuntimeState {
  param(
    [string]`$ThreadId,
    [string]`$Workspace,
    [object]`$State,
    [datetime]`$CurrentTimeUtc
  )

  [pscustomobject]@{
    ThreadId = `$ThreadId
    Workspace = `$Workspace
    State = `$State
    CurrentTimeUtc = `$CurrentTimeUtc.ToString('o')
  } | ConvertTo-Json -Depth 12 -Compress | Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'state-save.json')

  return `$State
}
"@

  $cleanupStub = @"
[CmdletBinding()]
param(
  [ValidateSet('inspect', 'cleanup', 'checkpoint-cleanup')]
  [string]`$Mode = 'inspect',
  [string]`$Workspace,
  [switch]`$ConfirmCurrentThreadExplicitAutomation,
  [switch]`$AsJson
)

Set-StrictMode -Version Latest

[pscustomobject]@{
  Mode = `$Mode
  Workspace = `$Workspace
  ConfirmCurrentThreadExplicitAutomation = [bool]`$ConfirmCurrentThreadExplicitAutomation
  AsJson = [bool]`$AsJson
} | ConvertTo-Json -Depth 6 -Compress | Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'cleanup-call.json')

`$result = ConvertFrom-Json @'
$cleanupResultJson
'@

if (`$AsJson) {
  `$result | ConvertTo-Json -Depth 12 -Compress
} else {
  `$result
}
"@

  Set-Content -LiteralPath (Join-Path $resolvedHarnessRoot 'hook-trigger-policy.ps1') -Value $policyStub
  Set-Content -LiteralPath (Join-Path $resolvedHarnessRoot 'trigger-runtime-state.ps1') -Value $runtimeStub
  Set-Content -LiteralPath (Join-Path $resolvedHarnessRoot 'cleanup-temporary-processes.ps1') -Value $cleanupStub

  return Join-Path $resolvedHarnessRoot 'invoke-hook-trigger.ps1'
}

function Invoke-HookEntrypoint {
  param(
    [string]$ScriptPath,
    [string]$HookName,
    [object]$InputObject,
    [hashtable]$Environment = @{}
  )

  $shell = Get-TestPowerShellExecutable
  $inputJson = ConvertTo-CompressedTestJson -Value $InputObject
  $savedEnvironment = @{}

  foreach ($key in $Environment.Keys) {
    $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    [Environment]::SetEnvironmentVariable($key, [string]$Environment[$key], 'Process')
  }

  try {
    $lines = @($inputJson | & $shell -NoProfile -File $ScriptPath -HookName $HookName 2>&1)
    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Lines = @($lines | ForEach-Object { [string]$_ })
    }
  } finally {
    foreach ($key in $Environment.Keys) {
      [Environment]::SetEnvironmentVariable($key, $savedEnvironment[$key], 'Process')
    }
  }
}

Describe 'invoke-hook-trigger entrypoint' {
  It 'runs checkpoint cleanup for risky PostToolUse shell payloads' {
    $harnessRoot = Join-Path $TestDrive 'hook-trigger-posttooluse-shell'
    $scriptUnderTest = New-HookEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PolicyDecision ([pscustomobject]@{
        ShouldTrigger = $true
        CleanupMode = 'checkpoint-cleanup'
        RequireExplicitAutomationConfirmation = $false
        DebounceKey = 'posttooluse|one-shot-shell|thread-shell|c:\repo|shell'
        DebounceWindowSeconds = 10
        CooldownSeconds = 30
        AuditReason = 'finished risky shell command'
      }) `
      -RuntimeDecision ([pscustomobject]@{
        Decision = 'run'
        ShouldTriggerCleanup = $true
        Reason = 'A new cleanup window should start for this risky checkpoint.'
        State = [pscustomobject]@{
          StateKey = 'thread-shell|C:\Repo'
          CleanupWindowKey = 'posttooluse|one-shot-shell|thread-shell|c:\repo|shell'
        }
      }) `
      -CleanupResult ([pscustomobject]@{
        mode = 'checkpoint-cleanup'
        workspace = 'C:\Repo'
        matchedCount = 3
        killedCount = 1
        failedCount = 0
      }) `
      -InitialState ([pscustomobject]@{
        StateKey = 'thread-shell|C:\Repo'
      })

    $result = Invoke-HookEntrypoint `
      -ScriptPath $scriptUnderTest `
      -HookName 'PostToolUse' `
      -InputObject ([pscustomobject]@{
        workspace = 'C:\Repo\'
        thread_id = 'thread-shell'
        tool_name = 'shell'
        command = 'npm test'
      })

    $result.ExitCode | Should Be 0
    $result.Lines.Count | Should Be 1

    $audit = $result.Lines[0] | ConvertFrom-Json
    $cleanupCall = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'cleanup-call.json') | ConvertFrom-Json
    $policyCall = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'policy-call.json') | ConvertFrom-Json
    $stateDecision = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'state-decision.json') | ConvertFrom-Json
    $stateSave = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'state-save.json') | ConvertFrom-Json

    $audit.hook | Should Be 'PostToolUse'
    $audit.action | Should Be 'cleanup'
    $audit.mode | Should Be 'checkpoint-cleanup'
    $audit.workspace | Should Be 'C:\Repo'
    $audit.reason | Should Match 'finished risky shell command'
    $audit.reason | Should Match 'cleanup window'
    $audit.confirmCurrentThreadExplicitAutomation | Should Be $false
    $cleanupCall.Mode | Should Be 'checkpoint-cleanup'
    $cleanupCall.Workspace | Should Be 'C:\Repo'
    $cleanupCall.ConfirmCurrentThreadExplicitAutomation | Should Be $false
    $policyCall.Workspace | Should Be 'C:\Repo'
    $policyCall.ThreadId | Should Be 'thread-shell'
    $stateDecision.CheckpointKey | Should Be 'posttooluse|one-shot-shell|thread-shell|c:\repo|shell'
    $stateDecision.DebounceWindowSeconds | Should Be 10
    $stateDecision.CooldownWindowSeconds | Should Be 30
    $stateSave.ThreadId | Should Be 'thread-shell'
    $stateSave.Workspace | Should Be 'C:\Repo'
  }

  It 'adds conservative automation confirmation for DevTools follow-up' {
    $harnessRoot = Join-Path $TestDrive 'hook-trigger-posttooluse-devtools'
    $scriptUnderTest = New-HookEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PolicyDecision ([pscustomobject]@{
        ShouldTrigger = $true
        CleanupMode = 'checkpoint-cleanup'
        RequireExplicitAutomationConfirmation = $true
        DebounceKey = 'posttooluse|explicit-automation|thread-from-env|c:\repo|chrome-devtools'
        DebounceWindowSeconds = 8
        CooldownSeconds = 20
        AuditReason = 'seed same-thread explicit automation'
      }) `
      -RuntimeDecision ([pscustomobject]@{
        Decision = 'run'
        ShouldTriggerCleanup = $true
        Reason = 'A new cleanup window should start for this risky checkpoint.'
        State = [pscustomobject]@{
          StateKey = 'thread-from-env|C:\Repo'
        }
      }) `
      -CleanupResult ([pscustomobject]@{
        mode = 'checkpoint-cleanup'
        workspace = 'C:\Repo'
        matchedCount = 2
        killedCount = 0
        failedCount = 0
      })

    $result = Invoke-HookEntrypoint `
      -ScriptPath $scriptUnderTest `
      -HookName 'PostToolUse' `
      -InputObject ([pscustomobject]@{
        workspace = 'C:\Repo'
        tool_name = 'chrome-devtools'
        command = 'chrome-devtools-mcp'
      }) `
      -Environment @{ CODEX_THREAD_ID = 'thread-from-env' }

    $result.ExitCode | Should Be 0

    $audit = $result.Lines[0] | ConvertFrom-Json
    $cleanupCall = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'cleanup-call.json') | ConvertFrom-Json
    $policyCall = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'policy-call.json') | ConvertFrom-Json

    $audit.action | Should Be 'cleanup'
    $audit.confirmCurrentThreadExplicitAutomation | Should Be $true
    $audit.threadId | Should Be 'thread-from-env'
    $cleanupCall.Mode | Should Be 'checkpoint-cleanup'
    $cleanupCall.ConfirmCurrentThreadExplicitAutomation | Should Be $true
    $policyCall.ThreadId | Should Be 'thread-from-env'
  }

  It 'does not pass automation confirmation without a nonblank workspace' {
    $harnessRoot = Join-Path $TestDrive 'hook-trigger-no-workspace-confirm'
    $scriptUnderTest = New-HookEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PolicyDecision ([pscustomobject]@{
        ShouldTrigger = $true
        CleanupMode = 'checkpoint-cleanup'
        RequireExplicitAutomationConfirmation = $true
        DebounceKey = 'posttooluse|explicit-automation|thread-empty|no-workspace|chrome-devtools'
        DebounceWindowSeconds = 8
        CooldownSeconds = 20
        AuditReason = 'workspace required before confirmation'
      }) `
      -RuntimeDecision ([pscustomobject]@{
        Decision = 'run'
        ShouldTriggerCleanup = $true
        Reason = 'A new cleanup window should start for this risky checkpoint.'
        State = [pscustomobject]@{
          StateKey = $null
        }
      }) `
      -CleanupResult ([pscustomobject]@{
        mode = 'checkpoint-cleanup'
        workspace = ''
        matchedCount = 1
        killedCount = 0
        failedCount = 0
      })

    $result = Invoke-HookEntrypoint `
      -ScriptPath $scriptUnderTest `
      -HookName 'PostToolUse' `
      -InputObject ([pscustomobject]@{
        workspace = '   '
        thread_id = 'thread-empty'
        tool_name = 'chrome-devtools'
        command = 'chrome-devtools-mcp'
      })

    $result.ExitCode | Should Be 0

    $audit = $result.Lines[0] | ConvertFrom-Json
    $cleanupCall = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'cleanup-call.json') | ConvertFrom-Json

    $audit.confirmCurrentThreadExplicitAutomation | Should Be $false
    $cleanupCall.ConfirmCurrentThreadExplicitAutomation | Should Be $false
    $cleanupCall.Workspace | Should Be ''
  }

  It 'runs final cleanup on SessionEnd with nested session values' {
    $harnessRoot = Join-Path $TestDrive 'hook-trigger-session-end'
    $scriptUnderTest = New-HookEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PolicyDecision ([pscustomobject]@{
        ShouldTrigger = $true
        CleanupMode = 'cleanup'
        RequireExplicitAutomationConfirmation = $false
        DebounceKey = 'sessionend|session-end|thread-session|c:\repo|no-tool'
        DebounceWindowSeconds = 5
        CooldownSeconds = 5
        AuditReason = 'session ending'
      }) `
      -RuntimeDecision ([pscustomobject]@{
        Decision = 'run'
        ShouldTriggerCleanup = $true
        Reason = 'A new cleanup window should start for this risky checkpoint.'
        State = [pscustomobject]@{
          StateKey = 'thread-session|C:\Repo'
        }
      }) `
      -CleanupResult ([pscustomobject]@{
        mode = 'cleanup'
        workspace = 'C:\Repo'
        matchedCount = 4
        killedCount = 2
        failedCount = 0
      })

    $result = Invoke-HookEntrypoint `
      -ScriptPath $scriptUnderTest `
      -HookName 'SessionEnd' `
      -InputObject ([pscustomobject]@{
        session = [pscustomobject]@{
          cwd = 'C:\Repo\'
          thread_id = 'thread-session'
        }
      })

    $result.ExitCode | Should Be 0

    $audit = $result.Lines[0] | ConvertFrom-Json
    $cleanupCall = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'cleanup-call.json') | ConvertFrom-Json

    $audit.hook | Should Be 'SessionEnd'
    $audit.mode | Should Be 'cleanup'
    $cleanupCall.Mode | Should Be 'cleanup'
    $cleanupCall.Workspace | Should Be 'C:\Repo'
  }

  It 'does not invoke cleanup for policy no-op events' {
    $harnessRoot = Join-Path $TestDrive 'hook-trigger-policy-noop'
    $scriptUnderTest = New-HookEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PolicyDecision ([pscustomobject]@{
        ShouldTrigger = $false
        CleanupMode = $null
        RequireExplicitAutomationConfirmation = $false
        DebounceKey = 'posttooluse|non-risk-tool|thread-noop|c:\repo|shell'
        DebounceWindowSeconds = 15
        CooldownSeconds = 30
        AuditReason = 'no strong trigger matched'
      }) `
      -RuntimeDecision ([pscustomobject]@{
        Decision = 'run'
        ShouldTriggerCleanup = $true
        Reason = 'should not be used'
        State = [pscustomobject]@{}
      })

    $result = Invoke-HookEntrypoint `
      -ScriptPath $scriptUnderTest `
      -HookName 'PostToolUse' `
      -InputObject ([pscustomobject]@{
        workspace = 'C:\Repo'
        thread_id = 'thread-noop'
        tool_name = 'shell'
        command = 'echo hello'
      })

    $result.ExitCode | Should Be 0
    $result.Lines.Count | Should Be 1

    $audit = $result.Lines[0] | ConvertFrom-Json

    $audit.action | Should Be 'noop'
    $audit.reason | Should Be 'no strong trigger matched'
    (Test-Path -LiteralPath (Join-Path $harnessRoot 'cleanup-call.json')) | Should Be $false
    (Test-Path -LiteralPath (Join-Path $harnessRoot 'state-decision.json')) | Should Be $false
    (Test-Path -LiteralPath (Join-Path $harnessRoot 'state-save.json')) | Should Be $false
  }

  It 'skips cleanup when runtime cooldown blocks an otherwise risky event' {
    $harnessRoot = Join-Path $TestDrive 'hook-trigger-runtime-cooldown'
    $scriptUnderTest = New-HookEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PolicyDecision ([pscustomobject]@{
        ShouldTrigger = $true
        CleanupMode = 'checkpoint-cleanup'
        RequireExplicitAutomationConfirmation = $false
        DebounceKey = 'posttooluse|one-shot-shell|thread-cooldown|c:\repo|shell'
        DebounceWindowSeconds = 10
        CooldownSeconds = 30
        AuditReason = 'finished risky shell command'
      }) `
      -RuntimeDecision ([pscustomobject]@{
        Decision = 'cooldown'
        ShouldTriggerCleanup = $false
        Reason = 'A recent cleanup already ran for this thread and workspace scope.'
        State = [pscustomobject]@{
          StateKey = 'thread-cooldown|C:\Repo'
        }
      })

    $result = Invoke-HookEntrypoint `
      -ScriptPath $scriptUnderTest `
      -HookName 'PostToolUse' `
      -InputObject ([pscustomobject]@{
        workspace = 'C:\Repo'
        thread_id = 'thread-cooldown'
        tool_name = 'shell'
        command = 'pnpm test'
      })

    $result.ExitCode | Should Be 0

    $audit = $result.Lines[0] | ConvertFrom-Json
    $stateSave = Get-Content -Raw -LiteralPath (Join-Path $harnessRoot 'state-save.json') | ConvertFrom-Json

    $audit.action | Should Be 'noop'
    $audit.reason | Should Match 'recent cleanup'
    (Test-Path -LiteralPath (Join-Path $harnessRoot 'cleanup-call.json')) | Should Be $false
    $stateSave.ThreadId | Should Be 'thread-cooldown'
  }
}
