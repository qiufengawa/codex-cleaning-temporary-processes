[CmdletBinding()]
param(
  [ValidateSet("inspect", "cleanup", "checkpoint-cleanup")]
  [string]$Mode = "inspect",
  [string]$Workspace,
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "process-classification.ps1")
. (Join-Path $PSScriptRoot "cleanup-policy.ps1")
. (Join-Path $PSScriptRoot "process-inventory.ps1")

function Get-ClassifiedTemporaryProcessSnapshot {
  param(
    [string]$Workspace,
    [int]$CurrentProcessId = $PID
  )

  $processes = @(Get-TemporaryProcessInventory)
  $childrenByParent = @{}

  foreach ($process in $processes) {
    $parentId = [int]$process.ParentProcessId
    if (-not $childrenByParent.ContainsKey($parentId)) {
      $childrenByParent[$parentId] = New-Object 'System.Collections.Generic.List[int]'
    }

    $null = $childrenByParent[$parentId].Add([int]$process.ProcessId)
  }

  $classified = Get-TemporaryProcessClassifications -Processes $processes -Workspace $Workspace -CurrentProcessId $CurrentProcessId |
    ForEach-Object {
      $decision = Get-CleanupDecision -Record $_ -Mode $Mode
      $_ | Add-Member -NotePropertyName Decision -NotePropertyValue $decision.Decision -Force
      $_ | Add-Member -NotePropertyName DecisionReason -NotePropertyValue $decision.Reason -Force
      $_
    }

  [pscustomobject]@{
    Processes        = @($processes)
    ChildrenByParent = $childrenByParent
    Classified       = @($classified)
  }
}

function Add-ProcessTreeIds {
  param(
    [int]$RootId,
    [hashtable]$ChildrenByParent,
    [System.Collections.Generic.HashSet[int]]$CleanupNowIds,
    [System.Collections.Generic.HashSet[int]]$Seen,
    [System.Collections.Generic.List[int]]$OrderedIds
  )

  if (-not $CleanupNowIds.Contains($RootId)) {
    return
  }

  if ($Seen.Contains($RootId)) {
    return
  }

  $null = $Seen.Add($RootId)

  if ($ChildrenByParent.ContainsKey($RootId)) {
    foreach ($childId in $ChildrenByParent[$RootId]) {
      if ($CleanupNowIds.Contains($childId)) {
        Add-ProcessTreeIds -RootId $childId -ChildrenByParent $ChildrenByParent -CleanupNowIds $CleanupNowIds -Seen $Seen -OrderedIds $OrderedIds
      }
    }
  }

  $null = $OrderedIds.Add($RootId)
}

$snapshot = Get-ClassifiedTemporaryProcessSnapshot -Workspace $Workspace -CurrentProcessId $PID
$classified = @($snapshot.Classified)

if ($Mode -in @("cleanup", "checkpoint-cleanup")) {
  $killRoots = @($classified | Where-Object { $_.Decision -eq "cleanup-now" })
  $cleanupNowIds = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($killRoot in $killRoots) {
    $null = $cleanupNowIds.Add([int]$killRoot.ProcessId)
  }

  $seenIds = New-Object 'System.Collections.Generic.HashSet[int]'
  $killOrder = New-Object 'System.Collections.Generic.List[int]'

  foreach ($killRoot in $killRoots) {
    Add-ProcessTreeIds -RootId ([int]$killRoot.ProcessId) -ChildrenByParent $snapshot.ChildrenByParent -CleanupNowIds $cleanupNowIds -Seen $seenIds -OrderedIds $killOrder
  }

  $attemptedKillIds = New-Object 'System.Collections.Generic.List[int]'
  foreach ($killId in $killOrder) {
    if (Get-Process -Id $killId -ErrorAction SilentlyContinue) {
      $null = $attemptedKillIds.Add($killId)
      try {
        Stop-Process -Id $killId -Force -ErrorAction Stop
      } catch {
      }
    }
  }

  $postSnapshot = Get-ClassifiedTemporaryProcessSnapshot -Workspace $Workspace -CurrentProcessId $PID
  $postClassified = @($postSnapshot.Classified)
  $postProcessIds = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($process in $postSnapshot.Processes) {
    $null = $postProcessIds.Add([int]$process.ProcessId)
  }

  $killedIds = New-Object 'System.Collections.Generic.List[int]'
  $failedIds = New-Object 'System.Collections.Generic.List[int]'
  foreach ($killId in $attemptedKillIds) {
    if ($postProcessIds.Contains($killId)) {
      $null = $failedIds.Add($killId)
    } else {
      $null = $killedIds.Add($killId)
    }
  }

  $output = [pscustomobject]@{
    mode          = $Mode
    workspace     = $Workspace
    matchedCount  = @($postClassified).Count
    killableRoots = @($postClassified | Where-Object { $_.Decision -eq "cleanup-now" }).Count
    decisionCounts = [pscustomobject]@{
      cleanupNow = @($postClassified | Where-Object { $_.Decision -eq "cleanup-now" }).Count
      inspectOnly = @($postClassified | Where-Object { $_.Decision -eq "inspect-only" }).Count
      preserve = @($postClassified | Where-Object { $_.Decision -eq "preserve" }).Count
    }
    killedCount   = @($killedIds).Count
    killedIds     = @($killedIds)
    failedCount   = @($failedIds).Count
    failedIds     = @($failedIds)
    processes     = @($postClassified)
  }
} else {
  $output = [pscustomobject]@{
    mode          = $Mode
    workspace     = $Workspace
    matchedCount  = @($classified).Count
    killableRoots = @(($classified | Where-Object { $_.Killable })).Count
    decisionCounts = [pscustomobject]@{
      cleanupNow = @($classified | Where-Object { $_.Decision -eq "cleanup-now" }).Count
      inspectOnly = @($classified | Where-Object { $_.Decision -eq "inspect-only" }).Count
      preserve = @($classified | Where-Object { $_.Decision -eq "preserve" }).Count
    }
    processes     = @($classified)
  }
}

if ($AsJson) {
  $output | ConvertTo-Json -Depth 6
} else {
  $output
}
