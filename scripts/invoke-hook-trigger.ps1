[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('PostToolUse', 'SubagentStop', 'SessionEnd')]
  [string]$HookName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TrimmedString {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) {
    return $null
  }

  return $text.Trim()
}

function Get-ImmediatePropertyValue {
  param(
    [object]$Node,
    [string[]]$Names
  )

  if ($null -eq $Node -or $null -eq $Names) {
    return $null
  }

  if ($Node -is [System.Collections.IDictionary]) {
    foreach ($name in $Names) {
      foreach ($key in $Node.Keys) {
        if ([string]$key -ieq $name) {
          return $Node[$key]
        }
      }
    }

    return $null
  }

  $propertyBag = $Node.PSObject
  if ($null -eq $propertyBag) {
    return $null
  }

  foreach ($name in $Names) {
    $property = $propertyBag.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($null -ne $property) {
      return $property.Value
    }
  }

  return $null
}

function Find-FirstNestedValue {
  param(
    [object]$Node,
    [string[]]$Names,
    [hashtable]$Visited = $null
  )

  if ($null -eq $Node) {
    return $null
  }

  if ($null -eq $Visited) {
    $Visited = @{}
  }

  if ($Node -isnot [string] -and $Node -isnot [ValueType]) {
    $objectId = [System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($Node)
    if ($Visited.ContainsKey($objectId)) {
      return $null
    }

    $Visited[$objectId] = $true
  }

  $directValue = Get-ImmediatePropertyValue -Node $Node -Names $Names
  $trimmedDirectValue = Get-TrimmedString -Value $directValue
  if ($null -ne $trimmedDirectValue) {
    return $trimmedDirectValue
  }

  if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
    foreach ($item in $Node) {
      $nestedValue = Find-FirstNestedValue -Node $item -Names $Names -Visited $Visited
      if ($null -ne $nestedValue) {
        return $nestedValue
      }
    }

    return $null
  }

  if ($Node -is [System.Collections.IDictionary]) {
    foreach ($value in $Node.Values) {
      $nestedValue = Find-FirstNestedValue -Node $value -Names $Names -Visited $Visited
      if ($null -ne $nestedValue) {
        return $nestedValue
      }
    }

    return $null
  }

  $propertyBag = $Node.PSObject
  if ($null -eq $propertyBag) {
    return $null
  }

  foreach ($property in $propertyBag.Properties) {
    $nestedValue = Find-FirstNestedValue -Node $property.Value -Names $Names -Visited $Visited
    if ($null -ne $nestedValue) {
      return $nestedValue
    }
  }

  return $null
}

function Get-NormalizedWorkspaceValue {
  param([object]$WorkspaceValue)

  $trimmedWorkspace = Get-TrimmedString -Value $WorkspaceValue
  if ($null -eq $trimmedWorkspace) {
    return ''
  }

  $candidatePath = $trimmedWorkspace
  try {
    $candidatePath = [System.IO.Path]::GetFullPath($trimmedWorkspace)
  } catch {
  }

  try {
    if (Test-Path -LiteralPath $candidatePath) {
      $resolvedPath = Resolve-Path -LiteralPath $candidatePath -ErrorAction Stop | Select-Object -First 1
      if ($null -ne $resolvedPath -and -not [string]::IsNullOrWhiteSpace($resolvedPath.ProviderPath)) {
        $candidatePath = $resolvedPath.ProviderPath
      }
    }
  } catch {
  }

  if ($candidatePath -match '^[A-Za-z]:[\\/]$') {
    return ($candidatePath.Substring(0, 2) + '\')
  }

  return $candidatePath.TrimEnd('\', '/')
}

function Get-ResolvedThreadId {
  param([object]$HookInput)

  $threadValue = Find-FirstNestedValue -Node $HookInput -Names @(
    'thread_id',
    'threadId',
    'conversation_id',
    'conversationId'
  )
  if ($null -ne $threadValue) {
    return $threadValue
  }

  $threadValue = Get-TrimmedString -Value $env:CODEX_THREAD_ID
  if ($null -ne $threadValue) {
    return $threadValue
  }

  return (Find-FirstNestedValue -Node $HookInput -Names @('session_id', 'sessionId'))
}

function Get-ResolvedWorkspace {
  param([object]$HookInput)

  $workspaceValue = Find-FirstNestedValue -Node $HookInput -Names @(
    'workspace',
    'cwd',
    'working_directory',
    'workingDirectory',
    'repo_path',
    'repoPath'
  )
  if ($null -eq $workspaceValue) {
    $workspaceValue = Get-TrimmedString -Value $env:CODEX_WORKSPACE
  }
  if ($null -eq $workspaceValue) {
    $workspaceValue = Get-TrimmedString -Value $env:CODEX_PROJECT_ROOT
  }

  return (Get-NormalizedWorkspaceValue -WorkspaceValue $workspaceValue)
}

function ConvertFrom-HookInputJson {
  param([string]$JsonText)

  $trimmedJson = Get-TrimmedString -Value $JsonText
  if ($null -eq $trimmedJson) {
    return [pscustomobject]@{}
  }

  return ($trimmedJson | ConvertFrom-Json)
}

function Get-DecisionPropertyValue {
  param(
    [object]$Decision,
    [string[]]$Names
  )

  return (Get-ImmediatePropertyValue -Node $Decision -Names $Names)
}

function Get-DecisionBoolean {
  param(
    [object]$Decision,
    [bool]$DefaultValue,
    [string[]]$Names
  )

  $value = Get-DecisionPropertyValue -Decision $Decision -Names $Names
  if ($null -eq $value) {
    return $DefaultValue
  }

  if ($value -is [bool]) {
    return [bool]$value
  }

  $text = Get-TrimmedString -Value $value
  if ($null -eq $text) {
    return $DefaultValue
  }

  if ($text -match '^(true|1|yes)$') {
    return $true
  }

  if ($text -match '^(false|0|no)$') {
    return $false
  }

  return $DefaultValue
}

function Get-DecisionString {
  param(
    [object]$Decision,
    [string]$DefaultValue,
    [string[]]$Names
  )

  $value = Get-DecisionPropertyValue -Decision $Decision -Names $Names
  $text = Get-TrimmedString -Value $value
  if ($null -eq $text) {
    return $DefaultValue
  }

  return $text
}

function Get-DecisionInteger {
  param(
    [object]$Decision,
    [int]$DefaultValue,
    [string[]]$Names
  )

  $value = Get-DecisionPropertyValue -Decision $Decision -Names $Names
  if ($null -eq $value) {
    return $DefaultValue
  }

  if ($value -is [int]) {
    return [int]$value
  }

  $parsedValue = 0
  if ([int]::TryParse(([string]$value), [ref]$parsedValue)) {
    return $parsedValue
  }

  return $DefaultValue
}

function Get-CheckpointKey {
  param(
    [object]$PolicyDecision,
    [string]$HookName,
    [string]$ThreadId,
    [string]$Workspace
  )

  $checkpointKey = Get-DecisionString -Decision $PolicyDecision -DefaultValue $null -Names @('DebounceKey')
  if ($null -ne $checkpointKey) {
    return $checkpointKey
  }

  $parts = @(
    $HookName.ToLowerInvariant(),
    (Get-TrimmedString -Value $ThreadId),
    (Get-TrimmedString -Value $Workspace)
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  if ($parts.Count -eq 0) {
    return 'unknown-checkpoint'
  }

  return ($parts -join '|')
}

function Invoke-CleanupEntrypoint {
  param(
    [string]$CleanupScriptPath,
    [string]$Mode,
    [string]$Workspace,
    [bool]$ConfirmCurrentThreadExplicitAutomation
  )

  $arguments = @{
    Mode = $Mode
    Workspace = $Workspace
    AsJson = $true
  }

  if ($ConfirmCurrentThreadExplicitAutomation) {
    $arguments['ConfirmCurrentThreadExplicitAutomation'] = $true
  }

  $rawOutput = & $CleanupScriptPath @arguments
  $rawText = (@($rawOutput | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
  $trimmedText = Get-TrimmedString -Value $rawText
  if ($null -eq $trimmedText) {
    return [pscustomobject]@{}
  }

  return ($trimmedText | ConvertFrom-Json)
}

function Write-AuditRecord {
  param(
    [string]$HookName,
    [string]$Action,
    [string]$Mode,
    [string]$Workspace,
    [string]$ThreadId,
    [string]$Reason,
    [bool]$ConfirmCurrentThreadExplicitAutomation,
    [object]$CleanupResult = $null
  )

  $audit = [ordered]@{
    hook = $HookName
    action = $Action
    mode = $Mode
    workspace = $Workspace
    threadId = $ThreadId
    reason = $Reason
    confirmCurrentThreadExplicitAutomation = $ConfirmCurrentThreadExplicitAutomation
  }

  if ($null -ne $CleanupResult) {
    $audit['matchedCount'] = Get-DecisionPropertyValue -Decision $CleanupResult -Names @('matchedCount')
    $audit['killedCount'] = Get-DecisionPropertyValue -Decision $CleanupResult -Names @('killedCount')
    $audit['failedCount'] = Get-DecisionPropertyValue -Decision $CleanupResult -Names @('failedCount')
  }

  Write-Output ([pscustomobject]$audit | ConvertTo-Json -Depth 10 -Compress)
}

$hookTriggerPolicyPath = Join-Path $PSScriptRoot 'hook-trigger-policy.ps1'
if (-not (Test-Path -LiteralPath $hookTriggerPolicyPath)) {
  throw "Required support script 'hook-trigger-policy.ps1' was not found."
}
. $hookTriggerPolicyPath

$triggerRuntimeStatePath = Join-Path $PSScriptRoot 'trigger-runtime-state.ps1'
if (-not (Test-Path -LiteralPath $triggerRuntimeStatePath)) {
  throw "Required support script 'trigger-runtime-state.ps1' was not found."
}
. $triggerRuntimeStatePath

try {
  $rawHookInput = [Console]::In.ReadToEnd()
  $hookInput = ConvertFrom-HookInputJson -JsonText $rawHookInput
  $workspace = Get-ResolvedWorkspace -HookInput $hookInput
  $threadId = Get-ResolvedThreadId -HookInput $hookInput
  $currentTimeUtc = [datetime]::UtcNow

  $policyDecision = Get-HookTriggerDecision -HookInput $hookInput -Workspace $workspace -ThreadId $threadId
  $shouldTrigger = Get-DecisionBoolean -Decision $policyDecision -DefaultValue:$false -Names @('ShouldTrigger')
  $cleanupMode = Get-DecisionString -Decision $policyDecision -DefaultValue $null -Names @('CleanupMode')
  $policyReason = Get-DecisionString -Decision $policyDecision -DefaultValue 'no strong trigger matched' -Names @('AuditReason')
  $confirmRequested = Get-DecisionBoolean -Decision $policyDecision -DefaultValue:$false -Names @('RequireExplicitAutomationConfirmation')

  $cleanupResult = $null
  $outcome = 'noop'
  $reason = $policyReason
  $confirmCurrentThreadExplicitAutomation = $false

  if ($shouldTrigger) {
    $checkpointKey = Get-CheckpointKey -PolicyDecision $policyDecision -HookName $HookName -ThreadId $threadId -Workspace $workspace
    $debounceWindowSeconds = Get-DecisionInteger -Decision $policyDecision -DefaultValue 12 -Names @('DebounceWindowSeconds')
    $cooldownSeconds = Get-DecisionInteger -Decision $policyDecision -DefaultValue 45 -Names @('CooldownSeconds')

    $runtimeState = Get-TriggerRuntimeState -ThreadId $threadId -Workspace $workspace
    $runtimeDecision = Get-TriggerRuntimeDecision `
      -State $runtimeState `
      -CheckpointKey $checkpointKey `
      -CurrentTimeUtc $currentTimeUtc `
      -DebounceWindow ([TimeSpan]::FromSeconds($debounceWindowSeconds)) `
      -CooldownWindow ([TimeSpan]::FromSeconds($cooldownSeconds)) `
      -BacklogReliefThreshold 2

    $runtimeShouldTrigger = Get-DecisionBoolean -Decision $runtimeDecision -DefaultValue:$false -Names @('ShouldTriggerCleanup')
    $runtimeReason = Get-DecisionString -Decision $runtimeDecision -DefaultValue $null -Names @('Reason')
    $runtimeStateToSave = Get-DecisionPropertyValue -Decision $runtimeDecision -Names @('State')

    if ($null -ne $runtimeReason) {
      $reason = '{0} Runtime: {1}' -f $policyReason, $runtimeReason
    }

    $confirmCurrentThreadExplicitAutomation = (
      $confirmRequested -and
      -not [string]::IsNullOrWhiteSpace($workspace) -and
      -not [string]::IsNullOrWhiteSpace($threadId)
    )

    if ($runtimeShouldTrigger -and -not [string]::IsNullOrWhiteSpace($cleanupMode)) {
      $cleanupScriptPath = Join-Path $PSScriptRoot 'cleanup-temporary-processes.ps1'
      if (-not (Test-Path -LiteralPath $cleanupScriptPath)) {
        throw "cleanup-temporary-processes.ps1 was not found at '$cleanupScriptPath'."
      }

      $cleanupResult = Invoke-CleanupEntrypoint `
        -CleanupScriptPath $cleanupScriptPath `
        -Mode $cleanupMode `
        -Workspace $workspace `
        -ConfirmCurrentThreadExplicitAutomation:$confirmCurrentThreadExplicitAutomation
      $outcome = 'cleanup'
    }

    if ($null -ne $runtimeStateToSave) {
      Save-TriggerRuntimeState -ThreadId $threadId -Workspace $workspace -State $runtimeStateToSave -CurrentTimeUtc $currentTimeUtc | Out-Null
    }
  }

  Write-AuditRecord `
    -HookName $HookName `
    -Action $outcome `
    -Mode $cleanupMode `
    -Workspace $workspace `
    -ThreadId $threadId `
    -Reason $reason `
    -ConfirmCurrentThreadExplicitAutomation:$confirmCurrentThreadExplicitAutomation `
    -CleanupResult $cleanupResult
} catch {
  Write-AuditRecord `
    -HookName $HookName `
    -Action 'error' `
    -Mode $null `
    -Workspace '' `
    -ThreadId (Get-TrimmedString -Value $env:CODEX_THREAD_ID) `
    -Reason $_.Exception.Message `
    -ConfirmCurrentThreadExplicitAutomation:$false
  exit 1
}
