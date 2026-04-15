$libraryPath = Join-Path $PSScriptRoot 'trigger-runtime-state.ps1'

Describe 'trigger runtime state' {
  BeforeEach {
    $env:CODEX_HOME = $TestDrive
  }

  It 'normalizes workspace scope and isolates state keys by thread plus workspace' {
    . $libraryPath

    $normalizedScope = Resolve-TriggerRuntimeScope -ThreadId 'thread-a' -Workspace '  C:\Repo\  '
    $sameScope = Resolve-TriggerRuntimeScope -ThreadId 'thread-a' -Workspace 'C:\Repo'
    $otherThreadScope = Resolve-TriggerRuntimeScope -ThreadId 'thread-b' -Workspace 'C:\Repo'
    $otherWorkspaceScope = Resolve-TriggerRuntimeScope -ThreadId 'thread-a' -Workspace 'C:\OtherRepo'

    $normalizedScope.ThreadId | Should Be 'thread-a'
    $normalizedScope.Workspace | Should Be 'C:\Repo'
    $normalizedScope.StateKey | Should Be $sameScope.StateKey
    $normalizedScope.StatePath | Should Be $sameScope.StatePath
    $normalizedScope.StateKey | Should Not Be $otherThreadScope.StateKey
    $normalizedScope.StateKey | Should Not Be $otherWorkspaceScope.StateKey
  }

  It 'never turns a blank workspace into a wildcard scope' {
    . $libraryPath

    $now = [datetime]'2026-04-15T15:00:00Z'
    $repoState = New-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo'
    $repoState.LastTriggerAtUtc = $now.ToString('o')

    $savedState = Save-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo' -State $repoState -CurrentTimeUtc $now
    $blankScope = Resolve-TriggerRuntimeScope -ThreadId 'thread-a' -Workspace '   '
    $blankState = Get-TriggerRuntimeState -ThreadId 'thread-a' -Workspace '   '

    $savedState.StateKey | Should Not Be $null
    $blankScope.Workspace | Should Be $null
    $blankScope.StateKey | Should Be $null
    $blankScope.StatePath | Should Be $null
    $blankState.StateKey | Should Be $null
    $blankState.LastTriggerAtUtc | Should Be $null
  }

  It 'round-trips persisted runtime state only for the matching thread and workspace' {
    . $libraryPath

    $now = [datetime]'2026-04-15T15:05:00Z'
    $state = New-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo'
    $state.LastTriggerAtUtc = $now.ToString('o')
    $state.CleanupWindowKey = 'checkpoint:test'
    $state.CleanupWindowOpenedAtUtc = $now.ToString('o')

    $null = Save-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo' -State $state -CurrentTimeUtc $now

    $loadedState = Get-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo\'
    $otherWorkspaceState = Get-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\OtherRepo'
    $otherThreadState = Get-TriggerRuntimeState -ThreadId 'thread-b' -Workspace 'C:\Repo'

    $loadedState.StateKey | Should Be $state.StateKey
    $loadedState.LastTriggerAtUtc | Should Be $now.ToUniversalTime().ToString('o')
    $loadedState.CleanupWindowKey | Should Be 'checkpoint:test'
    $otherWorkspaceState.LastTriggerAtUtc | Should Be $null
    $otherWorkspaceState.StateKey | Should Not Be $loadedState.StateKey
    $otherThreadState.LastTriggerAtUtc | Should Be $null
    $otherThreadState.StateKey | Should Not Be $loadedState.StateKey
  }

  It 'runs the first risky checkpoint and opens a cleanup window' {
    . $libraryPath

    $now = [datetime]'2026-04-15T15:10:00Z'
    $state = New-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo'

    $decision = Get-TriggerRuntimeDecision `
      -State $state `
      -CheckpointKey 'checkpoint:test' `
      -CurrentTimeUtc $now `
      -DebounceWindow ([TimeSpan]::FromMinutes(2)) `
      -CooldownWindow ([TimeSpan]::FromMinutes(5)) `
      -BacklogReliefThreshold 2

    $decision.Decision | Should Be 'run'
    $decision.ShouldTriggerCleanup | Should Be $true
    $decision.State.CleanupWindowKey | Should Be 'checkpoint:test'
    $decision.State.CleanupWindowOpenedAtUtc | Should Be $now.ToUniversalTime().ToString('o')
    $decision.State.LastTriggerAtUtc | Should Be $now.ToUniversalTime().ToString('o')
    $decision.State.DistinctCheckpointBacklog | Should Be 0
  }

  It 'debounces repeated identical risky checkpoints into one cleanup window' {
    . $libraryPath

    $windowOpenedAt = [datetime]'2026-04-15T15:20:00Z'
    $state = New-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo'
    $state.LastTriggerAtUtc = $windowOpenedAt.ToString('o')
    $state.CleanupWindowKey = 'checkpoint:test'
    $state.CleanupWindowOpenedAtUtc = $windowOpenedAt.ToString('o')

    $decision = Get-TriggerRuntimeDecision `
      -State $state `
      -CheckpointKey 'checkpoint:test' `
      -CurrentTimeUtc ([datetime]'2026-04-15T15:21:00Z') `
      -DebounceWindow ([TimeSpan]::FromMinutes(2)) `
      -CooldownWindow ([TimeSpan]::FromMinutes(5)) `
      -BacklogReliefThreshold 2

    $decision.Decision | Should Be 'debounce'
    $decision.ShouldTriggerCleanup | Should Be $false
    $decision.State.CleanupWindowKey | Should Be 'checkpoint:test'
    $decision.State.CleanupWindowOpenedAtUtc | Should Be $windowOpenedAt.ToUniversalTime().ToString('o')
    $decision.State.DistinctCheckpointBacklog | Should Be 0
  }

  It 'tracks distinct checkpoints during cooldown and escalates to backlog relief' {
    . $libraryPath

    $firstRunAt = [datetime]'2026-04-15T15:30:00Z'
    $state = New-TriggerRuntimeState -ThreadId 'thread-a' -Workspace 'C:\Repo'
    $state.LastTriggerAtUtc = $firstRunAt.ToString('o')
    $state.CleanupWindowKey = 'checkpoint:test'
    $state.CleanupWindowOpenedAtUtc = $firstRunAt.ToString('o')

    $cooldownDecision = Get-TriggerRuntimeDecision `
      -State $state `
      -CheckpointKey 'checkpoint:build' `
      -CurrentTimeUtc ([datetime]'2026-04-15T15:31:00Z') `
      -DebounceWindow ([TimeSpan]::FromMinutes(2)) `
      -CooldownWindow ([TimeSpan]::FromMinutes(5)) `
      -BacklogReliefThreshold 2

    $reliefDecision = Get-TriggerRuntimeDecision `
      -State $cooldownDecision.State `
      -CheckpointKey 'checkpoint:browser' `
      -CurrentTimeUtc ([datetime]'2026-04-15T15:32:00Z') `
      -DebounceWindow ([TimeSpan]::FromMinutes(2)) `
      -CooldownWindow ([TimeSpan]::FromMinutes(5)) `
      -BacklogReliefThreshold 2

    $cooldownDecision.Decision | Should Be 'cooldown'
    $cooldownDecision.ShouldTriggerCleanup | Should Be $false
    $cooldownDecision.State.DistinctCheckpointBacklog | Should Be 1

    $reliefDecision.Decision | Should Be 'backlog-relief'
    $reliefDecision.ShouldTriggerCleanup | Should Be $true
    $reliefDecision.State.DistinctCheckpointBacklog | Should Be 0
    $reliefDecision.State.CleanupWindowKey | Should Be 'checkpoint:browser'
    $reliefDecision.State.LastTriggerAtUtc | Should Be ([datetime]'2026-04-15T15:32:00Z').ToUniversalTime().ToString('o')
  }
}
