$entrypointPath = Join-Path $PSScriptRoot 'cleanup-temporary-processes.ps1'

function New-CleanupEntrypointHarness {
  param(
    [string]$HarnessRoot,
    [object[]]$PreCleanupProcesses,
    [object[]]$PostCleanupProcesses,
    [int[]]$FailStopIds
  )

  $null = New-Item -ItemType Directory -Path $HarnessRoot -Force
  Copy-Item -LiteralPath $entrypointPath -Destination (Join-Path $HarnessRoot 'cleanup-temporary-processes.ps1') -Force

  $preCleanupJson = $PreCleanupProcesses | ConvertTo-Json -Depth 6 -Compress
  $postCleanupJson = $PostCleanupProcesses | ConvertTo-Json -Depth 6 -Compress
  $presentProcessIdsJson = @($PreCleanupProcesses | ForEach-Object { [int]$_.ProcessId }) | ConvertTo-Json -Compress
  $failStopIdsJson = @($FailStopIds) | ConvertTo-Json -Compress

  $inventoryStub = @"
Set-StrictMode -Version Latest

`$script:InventorySnapshots = @(
  @((ConvertFrom-Json @'
$preCleanupJson
'@)),
  @((ConvertFrom-Json @'
$postCleanupJson
'@))
)
`$script:InventoryCallCount = 0
`$script:PresentProcessIds = @((ConvertFrom-Json @'
$presentProcessIdsJson
'@))
`$script:FailStopIds = @((ConvertFrom-Json @'
$failStopIdsJson
'@))

function Get-TemporaryProcessInventory {
  `$index = [Math]::Min(`$script:InventoryCallCount, `$script:InventorySnapshots.Count - 1)
  `$snapshot = `$script:InventorySnapshots[`$index]
  `$script:InventoryCallCount += 1
  return @(`$snapshot)
}

function Get-Process {
  param(
    [int]`$Id,
    [string]`$ErrorAction
  )

  if (`$script:PresentProcessIds -contains `$Id) {
    return [pscustomobject]@{ Id = `$Id }
  }

  return `$null
}

function Stop-Process {
  param(
    [int]`$Id,
    [switch]`$Force,
    [string]`$ErrorAction
  )

  if (`$script:FailStopIds -contains `$Id) {
    throw "Stop failed for process `$Id"
  }

  `$script:PresentProcessIds = @(`$script:PresentProcessIds | Where-Object { `$_ -ne `$Id })
}
"@

  $classificationStub = @"
Set-StrictMode -Version Latest

function Get-TemporaryProcessClassifications {
  param(
    [object[]]`$Processes,
    [string]`$Workspace,
    [int]`$CurrentProcessId
  )

  return @(`$Processes | ForEach-Object {
    [pscustomobject]@{
      ProcessId       = [int]`$_.ProcessId
      ParentProcessId = [int]`$_.ParentProcessId
      Name            = [string]`$_.Name
      CommandLine     = [string]`$_.CommandLine
      Killable        = [bool]`$_.Killable
      DesiredDecision = [string]`$_.DesiredDecision
      DecisionReason  = [string]`$_.DecisionReason
    }
  })
}
"@

  $policyStub = @"
Set-StrictMode -Version Latest

function Get-CleanupDecision {
  param(
    [object]`$Record,
    [string]`$Mode
  )

  return [pscustomobject]@{
    Decision = [string]`$Record.DesiredDecision
    Reason   = [string]`$Record.DecisionReason
  }
}
"@

  Set-Content -LiteralPath (Join-Path $HarnessRoot 'process-inventory.ps1') -Value $inventoryStub
  Set-Content -LiteralPath (Join-Path $HarnessRoot 'process-classification.ps1') -Value $classificationStub
  Set-Content -LiteralPath (Join-Path $HarnessRoot 'cleanup-policy.ps1') -Value $policyStub

  return Join-Path $HarnessRoot 'cleanup-temporary-processes.ps1'
}

Describe 'cleanup-temporary-processes entrypoint' {
  It 'reports deduped killableRoots in inspect mode' {
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 101
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-root.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool'
      },
      [pscustomobject]@{
        ProcessId = 102
        ParentProcessId = 101
        Name = 'node'
        CommandLine = 'node temp-child.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool child'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot (Join-Path $TestDrive 'cleanup-entrypoint-inspect-roots') `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $preCleanupProcesses `
      -FailStopIds @()

    $output = & $scriptUnderTest -Mode inspect -AsJson | ConvertFrom-Json

    $output.matchedCount | Should Be 2
    $output.killableRoots | Should Be 1
  }

  It 'reports post-cleanup state and failed kill ids for <Mode>' -TestCases @(
    @{ Mode = 'cleanup' },
    @{ Mode = 'checkpoint-cleanup' }
  ) {
    param($Mode)

    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 101
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-success.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool'
      },
      [pscustomobject]@{
        ProcessId = 102
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-failure.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool'
      },
      [pscustomobject]@{
        ProcessId = 201
        ParentProcessId = 1
        Name = 'pwsh'
        CommandLine = 'pwsh.exe'
        Killable = $false
        DesiredDecision = 'preserve'
        DecisionReason = 'active shell'
      }
    )

    $postCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 102
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-failure.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool'
      },
      [pscustomobject]@{
        ProcessId = 201
        ParentProcessId = 1
        Name = 'pwsh'
        CommandLine = 'pwsh.exe'
        Killable = $false
        DesiredDecision = 'preserve'
        DecisionReason = 'active shell'
      },
      [pscustomobject]@{
        ProcessId = 202
        ParentProcessId = 1
        Name = 'pwsh'
        CommandLine = 'pwsh.exe helper'
        Killable = $false
        DesiredDecision = 'preserve'
        DecisionReason = 'helper shell'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot (Join-Path $TestDrive "cleanup-entrypoint-$Mode") `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $postCleanupProcesses `
      -FailStopIds @(102)

    $output = & $scriptUnderTest -Mode $Mode -AsJson | ConvertFrom-Json

    $output.mode | Should Be $Mode
    $output.matchedCount | Should Be 3
    $output.killableRoots | Should Be 1
    $output.decisionCounts.cleanupNow | Should Be 1
    $output.decisionCounts.inspectOnly | Should Be 0
    $output.decisionCounts.preserve | Should Be 2
    $output.killedCount | Should Be 1
    @($output.killedIds) | Should Be @(101)
    $output.failedCount | Should Be 1
    @($output.failedIds) | Should Be @(102)
    @($output.processes | ForEach-Object { [int]$_.ProcessId }) | Should Be @(102, 201, 202)
  }

  It 'does not kill descendants that are not classified for cleanup' {
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 101
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-root.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool'
      },
      [pscustomobject]@{
        ProcessId = 301
        ParentProcessId = 101
        Name = 'node'
        CommandLine = 'node keep-child.js'
        Killable = $false
        DesiredDecision = 'preserve'
        DecisionReason = 'not classified for cleanup'
      }
    )

    $postCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 301
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node keep-child.js'
        Killable = $false
        DesiredDecision = 'preserve'
        DecisionReason = 'not classified for cleanup'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot (Join-Path $TestDrive 'cleanup-entrypoint-safe-descendants') `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $postCleanupProcesses `
      -FailStopIds @()

    $output = & $scriptUnderTest -Mode cleanup -AsJson | ConvertFrom-Json

    $output.killedCount | Should Be 1
    @($output.killedIds) | Should Be @(101)
    $output.failedCount | Should Be 0
    @($output.processes | ForEach-Object { [int]$_.ProcessId }) | Should Be @(301)
  }
}
