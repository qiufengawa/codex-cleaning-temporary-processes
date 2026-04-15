Set-StrictMode -Version Latest

$script:TriggerRuntimeStateVersion = 1

function Get-TriggerRuntimeStateRoot {
  if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $codexHomePath = $env:CODEX_HOME
    try {
      $resolvedPath = Resolve-Path -LiteralPath $env:CODEX_HOME -ErrorAction Stop | Select-Object -First 1
      if ($null -ne $resolvedPath -and -not [string]::IsNullOrWhiteSpace($resolvedPath.ProviderPath)) {
        $codexHomePath = $resolvedPath.ProviderPath
      }
    } catch {
    }

    return Join-Path (Join-Path $codexHomePath 'state') 'codex-cleaning-temporary-processes\trigger-runtime'
  }

  return Join-Path ([System.IO.Path]::GetTempPath()) 'codex-cleaning-temporary-processes\trigger-runtime'
}

function Normalize-TriggerRuntimeWorkspace {
  param([string]$Workspace)

  if ([string]::IsNullOrWhiteSpace($Workspace)) {
    return $null
  }

  return $Workspace.Trim().TrimEnd('\', '/')
}

function ConvertTo-SafeTriggerRuntimeFileName {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $null
  }

  return ($Value.Trim() -replace '[^A-Za-z0-9._-]', '_')
}

function Get-TriggerRuntimeWorkspaceHash {
  param([string]$Workspace)

  $normalizedWorkspace = Normalize-TriggerRuntimeWorkspace -Workspace $Workspace
  if ([string]::IsNullOrWhiteSpace($normalizedWorkspace)) {
    return $null
  }

  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalizedWorkspace)
    $hashBytes = $sha256.ComputeHash($bytes)
    return (-join ($hashBytes | ForEach-Object { $_.ToString('x2') }))
  } finally {
    $sha256.Dispose()
  }
}

function Resolve-TriggerRuntimeScope {
  param(
    [string]$ThreadId,
    [string]$Workspace
  )

  $normalizedThreadId = if ([string]::IsNullOrWhiteSpace($ThreadId)) { $null } else { $ThreadId.Trim() }
  $normalizedWorkspace = Normalize-TriggerRuntimeWorkspace -Workspace $Workspace

  if ([string]::IsNullOrWhiteSpace($normalizedThreadId) -or [string]::IsNullOrWhiteSpace($normalizedWorkspace)) {
    return [pscustomobject]@{
      ThreadId      = $normalizedThreadId
      Workspace     = $normalizedWorkspace
      StateKey      = $null
      StatePath     = $null
      WorkspaceHash = $null
      IsPersistable = $false
    }
  }

  $workspaceHash = Get-TriggerRuntimeWorkspaceHash -Workspace $normalizedWorkspace
  $safeThreadId = ConvertTo-SafeTriggerRuntimeFileName -Value $normalizedThreadId
  $stateDirectory = Join-Path (Get-TriggerRuntimeStateRoot) 'scopes'
  $statePath = Join-Path $stateDirectory ('{0}-{1}.json' -f $safeThreadId, $workspaceHash)

  return [pscustomobject]@{
    ThreadId      = $normalizedThreadId
    Workspace     = $normalizedWorkspace
    StateKey      = '{0}|{1}' -f $normalizedThreadId, $normalizedWorkspace
    StatePath     = $statePath
    WorkspaceHash = $workspaceHash
    IsPersistable = $true
  }
}

function New-TriggerRuntimeState {
  param(
    [string]$ThreadId,
    [string]$Workspace
  )

  $scope = Resolve-TriggerRuntimeScope -ThreadId $ThreadId -Workspace $Workspace

  return [pscustomobject]@{
    Version                   = $script:TriggerRuntimeStateVersion
    ThreadId                  = $scope.ThreadId
    Workspace                 = $scope.Workspace
    StateKey                  = $scope.StateKey
    LastCheckpointKey         = $null
    LastCheckpointAtUtc       = $null
    LastTriggerAtUtc          = $null
    CleanupWindowKey          = $null
    CleanupWindowOpenedAtUtc  = $null
    DistinctCheckpointBacklog = 0
    UpdatedAtUtc              = $null
  }
}

function ConvertTo-TriggerRuntimeTimestamp {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  $timestamp = [datetime]::MinValue
  if ([datetime]::TryParse([string]$Value, [ref]$timestamp)) {
    return $timestamp.ToUniversalTime().ToString('o')
  }

  return $null
}

function Get-TriggerRuntimeTimestampValue {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  $timestamp = [datetime]::MinValue
  if ([datetime]::TryParse([string]$Value, [ref]$timestamp)) {
    return $timestamp.ToUniversalTime()
  }

  return $null
}

function ConvertTo-TriggerRuntimeState {
  param(
    [object]$State,
    [object]$Scope
  )

  $normalizedState = New-TriggerRuntimeState -ThreadId ([string]$Scope.ThreadId) -Workspace ([string]$Scope.Workspace)
  if ($null -eq $State) {
    return $normalizedState
  }

  if ($State.PSObject.Properties['LastCheckpointKey']) {
    $normalizedState.LastCheckpointKey = [string]$State.LastCheckpointKey
  }

  if ($State.PSObject.Properties['LastCheckpointAtUtc']) {
    $normalizedState.LastCheckpointAtUtc = ConvertTo-TriggerRuntimeTimestamp -Value $State.LastCheckpointAtUtc
  }

  if ($State.PSObject.Properties['LastTriggerAtUtc']) {
    $normalizedState.LastTriggerAtUtc = ConvertTo-TriggerRuntimeTimestamp -Value $State.LastTriggerAtUtc
  }

  if ($State.PSObject.Properties['CleanupWindowKey']) {
    $normalizedState.CleanupWindowKey = [string]$State.CleanupWindowKey
  }

  if ($State.PSObject.Properties['CleanupWindowOpenedAtUtc']) {
    $normalizedState.CleanupWindowOpenedAtUtc = ConvertTo-TriggerRuntimeTimestamp -Value $State.CleanupWindowOpenedAtUtc
  }

  if ($State.PSObject.Properties['DistinctCheckpointBacklog']) {
    $normalizedState.DistinctCheckpointBacklog = [Math]::Max([int]$State.DistinctCheckpointBacklog, 0)
  }

  if ($State.PSObject.Properties['UpdatedAtUtc']) {
    $normalizedState.UpdatedAtUtc = ConvertTo-TriggerRuntimeTimestamp -Value $State.UpdatedAtUtc
  }

  return $normalizedState
}

function Get-TriggerRuntimeStatePath {
  param(
    [string]$ThreadId,
    [string]$Workspace
  )

  return (Resolve-TriggerRuntimeScope -ThreadId $ThreadId -Workspace $Workspace).StatePath
}

function Get-TriggerRuntimeState {
  param(
    [string]$ThreadId,
    [string]$Workspace
  )

  $scope = Resolve-TriggerRuntimeScope -ThreadId $ThreadId -Workspace $Workspace
  $defaultState = New-TriggerRuntimeState -ThreadId $scope.ThreadId -Workspace $scope.Workspace

  if (-not $scope.IsPersistable -or -not (Test-Path -LiteralPath $scope.StatePath)) {
    return $defaultState
  }

  try {
    $storedState = Get-Content -Raw -LiteralPath $scope.StatePath | ConvertFrom-Json
    return ConvertTo-TriggerRuntimeState -State $storedState -Scope $scope
  } catch {
    return $defaultState
  }
}

function Save-TriggerRuntimeState {
  param(
    [string]$ThreadId,
    [string]$Workspace,
    [object]$State,
    [datetime]$CurrentTimeUtc = [datetime]::UtcNow
  )

  $scope = Resolve-TriggerRuntimeScope -ThreadId $ThreadId -Workspace $Workspace
  $normalizedState = ConvertTo-TriggerRuntimeState -State $State -Scope $scope
  $normalizedState.UpdatedAtUtc = $CurrentTimeUtc.ToUniversalTime().ToString('o')

  if (-not $scope.IsPersistable) {
    return $normalizedState
  }

  $stateDirectory = Split-Path $scope.StatePath -Parent
  $null = New-Item -ItemType Directory -Path $stateDirectory -Force
  $normalizedState | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $scope.StatePath

  return $normalizedState
}

function New-TriggerRuntimeDecisionResult {
  param(
    [string]$Decision,
    [bool]$ShouldTriggerCleanup,
    [string]$Reason,
    [object]$State
  )

  return [pscustomobject]@{
    Decision             = $Decision
    ShouldTriggerCleanup = $ShouldTriggerCleanup
    Reason               = $Reason
    State                = $State
  }
}

function Get-TriggerRuntimeDecision {
  param(
    [object]$State,
    [string]$CheckpointKey,
    [datetime]$CurrentTimeUtc,
    [TimeSpan]$DebounceWindow = ([TimeSpan]::FromMinutes(2)),
    [TimeSpan]$CooldownWindow = ([TimeSpan]::FromMinutes(5)),
    [int]$BacklogReliefThreshold = 2
  )

  if ($null -eq $State) {
    $State = New-TriggerRuntimeState
  }

  $scope = Resolve-TriggerRuntimeScope -ThreadId ([string]$State.ThreadId) -Workspace ([string]$State.Workspace)
  $updatedState = ConvertTo-TriggerRuntimeState -State $State -Scope $scope
  $checkpointKeyValue = if ([string]::IsNullOrWhiteSpace($CheckpointKey)) { $null } else { $CheckpointKey.Trim() }
  $nowUtcString = $CurrentTimeUtc.ToUniversalTime().ToString('o')
  $updatedState.LastCheckpointKey = $checkpointKeyValue
  $updatedState.LastCheckpointAtUtc = $nowUtcString
  $updatedState.UpdatedAtUtc = $nowUtcString

  $cleanupWindowOpenedAt = Get-TriggerRuntimeTimestampValue -Value $updatedState.CleanupWindowOpenedAtUtc
  $lastTriggerAt = Get-TriggerRuntimeTimestampValue -Value $updatedState.LastTriggerAtUtc
  $backlogThreshold = [Math]::Max($BacklogReliefThreshold, 1)
  $sameCheckpointWindow = (
    -not [string]::IsNullOrWhiteSpace($checkpointKeyValue) -and
    -not [string]::IsNullOrWhiteSpace([string]$updatedState.CleanupWindowKey) -and
    $checkpointKeyValue.Equals([string]$updatedState.CleanupWindowKey, [System.StringComparison]::Ordinal)
  )

  if ($sameCheckpointWindow -and $null -ne $cleanupWindowOpenedAt) {
    if (($CurrentTimeUtc.ToUniversalTime() - $cleanupWindowOpenedAt) -lt $DebounceWindow) {
      return New-TriggerRuntimeDecisionResult `
        -Decision 'debounce' `
        -ShouldTriggerCleanup $false `
        -Reason 'Repeated risky checkpoint is already inside the active cleanup window.' `
        -State $updatedState
    }
  }

  $withinCooldown = $false
  if ($null -ne $lastTriggerAt) {
    $withinCooldown = (($CurrentTimeUtc.ToUniversalTime() - $lastTriggerAt) -lt $CooldownWindow)
  }

  if ($withinCooldown) {
    if (-not $sameCheckpointWindow) {
      $updatedState.DistinctCheckpointBacklog = [Math]::Max([int]$updatedState.DistinctCheckpointBacklog, 0) + 1
    }

    if ($updatedState.DistinctCheckpointBacklog -ge $backlogThreshold) {
      $updatedState.LastTriggerAtUtc = $nowUtcString
      $updatedState.CleanupWindowKey = $checkpointKeyValue
      $updatedState.CleanupWindowOpenedAtUtc = $nowUtcString
      $updatedState.DistinctCheckpointBacklog = 0

      return New-TriggerRuntimeDecisionResult `
        -Decision 'backlog-relief' `
        -ShouldTriggerCleanup $true `
        -Reason 'Distinct risky checkpoints accumulated during cooldown.' `
        -State $updatedState
    }

    return New-TriggerRuntimeDecisionResult `
      -Decision 'cooldown' `
      -ShouldTriggerCleanup $false `
      -Reason 'A recent cleanup already ran for this thread and workspace scope.' `
      -State $updatedState
  }

  $updatedState.LastTriggerAtUtc = $nowUtcString
  $updatedState.CleanupWindowKey = $checkpointKeyValue
  $updatedState.CleanupWindowOpenedAtUtc = $nowUtcString
  $updatedState.DistinctCheckpointBacklog = 0

  return New-TriggerRuntimeDecisionResult `
    -Decision 'run' `
    -ShouldTriggerCleanup $true `
    -Reason 'A new cleanup window should start for this risky checkpoint.' `
    -State $updatedState
}
