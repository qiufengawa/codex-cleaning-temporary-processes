$policyLibraryPath = Join-Path $PSScriptRoot 'hook-trigger-policy.ps1'
$fixturesRoot = Join-Path $PSScriptRoot 'hook-trigger-fixtures'

function Get-HookTriggerFixture {
  param([string]$Name)

  Get-Content -Raw -Encoding UTF8 (Join-Path $fixturesRoot $Name) | ConvertFrom-Json
}

Describe 'Get-HookTriggerDecision' {
  It 'marks one-shot high-risk shell commands for checkpoint cleanup' {
    . $policyLibraryPath

    $hookInput = Get-HookTriggerFixture -Name 'posttooluse-bash-high-risk.json'
    $decision = Get-HookTriggerDecision -HookInput $hookInput -Workspace '/repo' -ThreadId 'thread-shell'

    $decision.ShouldTrigger | Should Be $true
    $decision.CleanupMode | Should Be 'checkpoint-cleanup'
    $decision.RequireExplicitAutomationConfirmation | Should Be $false
    $decision.TriggerClass | Should Be 'one-shot-shell'
    $decision.Isolation.ThreadId | Should Be 'thread-shell'
    $decision.Isolation.WorkspaceKey | Should Be '/repo'
    $decision.DebounceKey | Should Match 'posttooluse'
    $decision.CooldownKey | Should Match 'one-shot-shell'
    $decision.AuditReason | Should Match 'one-shot'
  }

  It 'does not trigger cleanup for clearly reusable dev servers' {
    . $policyLibraryPath

    $hookInput = Get-HookTriggerFixture -Name 'posttooluse-bash-low-risk.json'
    $decision = Get-HookTriggerDecision -HookInput $hookInput -Workspace '/repo' -ThreadId 'thread-dev'

    $decision.ShouldTrigger | Should Be $false
    ($null -eq $decision.CleanupMode) | Should Be $true
    $decision.RequireExplicitAutomationConfirmation | Should Be $false
    $decision.TriggerClass | Should Be 'long-lived-dev-server'
    $decision.AuditReason | Should Match 'reusable'
  }

  It 'adds explicit automation confirmation for current-thread DevTools follow-up' {
    . $policyLibraryPath

    $hookInput = Get-HookTriggerFixture -Name 'posttooluse-devtools.json'
    $decision = Get-HookTriggerDecision -HookInput $hookInput -Workspace 'C:\Repo' -ThreadId 'thread-devtools'

    $decision.ShouldTrigger | Should Be $true
    $decision.CleanupMode | Should Be 'checkpoint-cleanup'
    $decision.RequireExplicitAutomationConfirmation | Should Be $true
    $decision.TriggerClass | Should Be 'explicit-automation'
    $decision.Isolation.ThreadId | Should Be 'thread-devtools'
    $decision.Isolation.WorkspaceKey | Should Be 'c:\repo'
    $decision.Isolation.RequiresWorkspace | Should Be $true
    $decision.Isolation.WorkspaceWildcard | Should Be $false
    $decision.AuditReason | Should Match 'explicit automation'
  }

  It 'does not request current-thread explicit automation confirmation without a nonblank workspace' {
    . $policyLibraryPath

    $hookInput = Get-HookTriggerFixture -Name 'posttooluse-devtools.json'
    $decision = Get-HookTriggerDecision -HookInput $hookInput -Workspace '   ' -ThreadId 'thread-devtools'

    $decision.ShouldTrigger | Should Be $true
    $decision.CleanupMode | Should Be 'checkpoint-cleanup'
    $decision.RequireExplicitAutomationConfirmation | Should Be $false
    $decision.TriggerClass | Should Be 'explicit-automation'
    $decision.Isolation.ThreadId | Should Be 'thread-devtools'
    ($null -eq $decision.Isolation.WorkspaceKey) | Should Be $true
    $decision.Isolation.RequiresWorkspace | Should Be $true
    $decision.Isolation.WorkspaceWildcard | Should Be $false
    $decision.AuditReason | Should Match 'non-blank workspace'
  }

  It 'requests a final cleanup on SessionEnd' {
    . $policyLibraryPath

    $hookInput = Get-HookTriggerFixture -Name 'session-end.json'
    $decision = Get-HookTriggerDecision -HookInput $hookInput -Workspace 'C:\Repo' -ThreadId 'thread-end'

    $decision.ShouldTrigger | Should Be $true
    $decision.CleanupMode | Should Be 'cleanup'
    $decision.RequireExplicitAutomationConfirmation | Should Be $false
    $decision.TriggerClass | Should Be 'session-end'
    $decision.DebounceKey | Should Match 'session-end'
    $decision.AuditReason | Should Match 'session end'
  }

  It 'treats SubagentStop as a cleanup checkpoint' {
    . $policyLibraryPath

    $hookInput = Get-HookTriggerFixture -Name 'subagent-stop.json'
    $decision = Get-HookTriggerDecision -HookInput $hookInput -Workspace 'C:\Repo' -ThreadId 'thread-parent'

    $decision.ShouldTrigger | Should Be $true
    $decision.CleanupMode | Should Be 'checkpoint-cleanup'
    $decision.RequireExplicitAutomationConfirmation | Should Be $false
    $decision.TriggerClass | Should Be 'subagent-stop'
    $decision.CooldownKey | Should Match 'subagent-stop'
    $decision.AuditReason | Should Match 'subagent'
  }
}
