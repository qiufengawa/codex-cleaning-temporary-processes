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

$processes = @(Get-CimInstance Win32_Process)
$childrenByParent = @{}

foreach ($process in $processes) {
  $parentId = [int]$process.ParentProcessId
  if (-not $childrenByParent.ContainsKey($parentId)) {
    $childrenByParent[$parentId] = New-Object System.Collections.Generic.List[int]
  }

  $null = $childrenByParent[$parentId].Add([int]$process.ProcessId)
}

function Add-ProcessTreeIds {
  param(
    [int]$RootId,
    [System.Collections.Generic.HashSet[int]]$Seen,
    [System.Collections.Generic.List[int]]$OrderedIds
  )

  if ($Seen.Contains($RootId)) {
    return
  }

  $null = $Seen.Add($RootId)

  if ($childrenByParent.ContainsKey($RootId)) {
    foreach ($childId in $childrenByParent[$RootId]) {
      Add-ProcessTreeIds -RootId $childId -Seen $Seen -OrderedIds $OrderedIds
    }
  }

  $null = $OrderedIds.Add($RootId)
}

$classified = Get-TemporaryProcessClassifications -Processes $processes -Workspace $Workspace -CurrentProcessId $PID |
  ForEach-Object {
    $decision = Get-CleanupDecision -Record $_ -Mode $Mode
    $_ | Add-Member -NotePropertyName Decision -NotePropertyValue $decision.Decision -Force
    $_ | Add-Member -NotePropertyName DecisionReason -NotePropertyValue $decision.Reason -Force
    $_
  }

if ($Mode -in @("cleanup", "checkpoint-cleanup")) {
  $killRoots = @($classified | Where-Object { $_.Decision -eq "cleanup-now" })
  $seenIds = New-Object 'System.Collections.Generic.HashSet[int]'
  $killOrder = New-Object 'System.Collections.Generic.List[int]'

  foreach ($killRoot in $killRoots) {
    Add-ProcessTreeIds -RootId ([int]$killRoot.ProcessId) -Seen $seenIds -OrderedIds $killOrder
  }

  $killedIds = New-Object 'System.Collections.Generic.List[int]'
  foreach ($killId in $killOrder) {
    if (Get-Process -Id $killId -ErrorAction SilentlyContinue) {
      try {
        Stop-Process -Id $killId -Force -ErrorAction Stop
        $null = $killedIds.Add($killId)
      } catch {
      }
    }
  }

  $output = [pscustomobject]@{
    mode          = $Mode
    workspace     = $Workspace
    matchedCount  = @($classified).Count
    killableRoots = @($killRoots).Count
    decisionCounts = [pscustomobject]@{
      cleanupNow = @($classified | Where-Object { $_.Decision -eq "cleanup-now" }).Count
      inspectOnly = @($classified | Where-Object { $_.Decision -eq "inspect-only" }).Count
      preserve = @($classified | Where-Object { $_.Decision -eq "preserve" }).Count
    }
    killedCount   = @($killedIds).Count
    killedIds     = @($killedIds)
    processes     = @($classified)
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
