[CmdletBinding()]
param(
  [ValidateSet("inspect", "cleanup", "checkpoint-cleanup")]
  [string]$Mode = "inspect",
  [string]$Workspace,
  [switch]$ConfirmCurrentThreadExplicitAutomation,
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "process-classification.ps1")
. (Join-Path $PSScriptRoot "cleanup-policy.ps1")
. (Join-Path $PSScriptRoot "process-inventory.ps1")
. (Join-Path $PSScriptRoot "thread-ownership-ledger.ps1")

function Get-ClassifiedTemporaryProcessSnapshot {
  param(
    [string]$Workspace,
    [string]$ThreadId,
    [bool]$AllowCurrentThreadExplicitAutomationSeed = $false,
    [datetime]$CurrentTimeUtc = [datetime]::UtcNow,
    [int]$CurrentProcessId = $PID
  )

  $processes = @(Get-TemporaryProcessInventory)
  $threadOwnershipEntries = @(Get-ActiveThreadOwnershipEntries -ThreadId $ThreadId -Processes $processes -Workspace $Workspace -CurrentTimeUtc $CurrentTimeUtc)
  $childrenByParent = @{}

  foreach ($process in $processes) {
    $parentId = [int]$process.ParentProcessId
    if (-not $childrenByParent.ContainsKey($parentId)) {
      $childrenByParent[$parentId] = New-Object 'System.Collections.Generic.List[int]'
    }

    $null = $childrenByParent[$parentId].Add([int]$process.ProcessId)
  }

  $classified = Get-TemporaryProcessClassifications -Processes $processes -Workspace $Workspace -ThreadOwnershipEntries $threadOwnershipEntries -AllowCurrentThreadExplicitAutomationSeed:$AllowCurrentThreadExplicitAutomationSeed -CurrentProcessId $CurrentProcessId |
    ForEach-Object {
      $decision = Get-CleanupDecision -Record $_ -Mode $Mode
      $_ | Add-Member -NotePropertyName Decision -NotePropertyValue $decision.Decision -Force
      $_ | Add-Member -NotePropertyName DecisionReason -NotePropertyValue $decision.Reason -Force
      $_
    }

  [pscustomobject]@{
    Processes        = @($processes)
    ChildrenByParent = $childrenByParent
    ThreadOwnership  = @($threadOwnershipEntries)
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

function Get-RootRecordCount {
  param(
    [object[]]$Records
  )

  $recordIds = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($record in $Records) {
    $null = $recordIds.Add([int]$record.ProcessId)
  }

  return @(
    $Records | Where-Object {
      -not $recordIds.Contains([int]$_.ParentProcessId)
    }
  ).Count
}

function Test-InventoryProcessIdentityMatch {
  param(
    [object]$ExpectedProcess,
    [object]$ActualProcess
  )

  if ($null -eq $ExpectedProcess -or $null -eq $ActualProcess) {
    return $false
  }

  return (
    ([int]$ExpectedProcess.ProcessId -eq [int]$ActualProcess.ProcessId) -and
    ([int]$ExpectedProcess.ParentProcessId -eq [int]$ActualProcess.ParentProcessId) -and
    ([string]$ExpectedProcess.Name -eq [string]$ActualProcess.Name) -and
    ([string]$ExpectedProcess.CommandLine -eq [string]$ActualProcess.CommandLine)
  )
}

$threadId = Get-CurrentCodexThreadId
$snapshotTimeUtc = [datetime]::UtcNow
$allowCurrentThreadExplicitAutomationSeed = $ConfirmCurrentThreadExplicitAutomation -and -not [string]::IsNullOrWhiteSpace($Workspace)
$snapshot = Get-ClassifiedTemporaryProcessSnapshot -Workspace $Workspace -ThreadId $threadId -AllowCurrentThreadExplicitAutomationSeed:$allowCurrentThreadExplicitAutomationSeed -CurrentTimeUtc $snapshotTimeUtc -CurrentProcessId $PID
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
  $snapshotProcessById = @{}
  foreach ($process in $snapshot.Processes) {
    $snapshotProcessById[[int]$process.ProcessId] = $process
  }

  foreach ($killId in $killOrder) {
    if (-not $snapshotProcessById.ContainsKey($killId)) {
      continue
    }

    $expectedProcess = $snapshotProcessById[$killId]
    $liveProcess = Get-LiveTemporaryProcessRecord -ProcessId $killId
    if (-not (Test-InventoryProcessIdentityMatch -ExpectedProcess $expectedProcess -ActualProcess $liveProcess)) {
      continue
    }

    $null = $attemptedKillIds.Add($killId)
    try {
      Stop-Process -Id $killId -Force -ErrorAction Stop
    } catch {
    }
  }

  $postSnapshot = Get-ClassifiedTemporaryProcessSnapshot -Workspace $Workspace -ThreadId $threadId -AllowCurrentThreadExplicitAutomationSeed:$allowCurrentThreadExplicitAutomationSeed -CurrentTimeUtc ([datetime]::UtcNow) -CurrentProcessId $PID
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
    killableRoots = Get-RootRecordCount -Records @($postClassified | Where-Object { $_.Decision -eq "cleanup-now" })
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

  $null = Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries @($postSnapshot.ThreadOwnership) -Processes @($postSnapshot.Processes) -ClassifiedRecords @($postClassified) -Workspace $Workspace -CurrentTimeUtc ([datetime]::UtcNow)
} else {
  $output = [pscustomobject]@{
    mode          = $Mode
    workspace     = $Workspace
    matchedCount  = @($classified).Count
    killableRoots = Get-RootRecordCount -Records @($classified | Where-Object { $_.Killable })
    decisionCounts = [pscustomobject]@{
      cleanupNow = @($classified | Where-Object { $_.Decision -eq "cleanup-now" }).Count
      inspectOnly = @($classified | Where-Object { $_.Decision -eq "inspect-only" }).Count
      preserve = @($classified | Where-Object { $_.Decision -eq "preserve" }).Count
    }
    processes     = @($classified)
  }

  $null = Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries @($snapshot.ThreadOwnership) -Processes @($snapshot.Processes) -ClassifiedRecords @($classified) -Workspace $Workspace -CurrentTimeUtc ([datetime]::UtcNow)
}

if ($AsJson) {
  $output | ConvertTo-Json -Depth 6
} else {
  $output
}
