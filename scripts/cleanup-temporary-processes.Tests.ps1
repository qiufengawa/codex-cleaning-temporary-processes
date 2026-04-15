$entrypointPath = Join-Path $PSScriptRoot 'cleanup-temporary-processes.ps1'

function New-CleanupEntrypointHarness {
  param(
    [string]$HarnessRoot,
    [object[]]$PreCleanupProcesses,
    [object[]]$LiveProcesses,
    [object[]]$PostCleanupProcesses,
    [int[]]$FailStopIds,
    [object[]]$ThreadOwnershipEntries = @(),
    [int[]]$ThreadOwnedPromotionIds = @()
  )

  $null = New-Item -ItemType Directory -Path $HarnessRoot -Force
  Copy-Item -LiteralPath $entrypointPath -Destination (Join-Path $HarnessRoot 'cleanup-temporary-processes.ps1') -Force

  if ($null -eq $LiveProcesses) {
    $LiveProcesses = @($PreCleanupProcesses)
  }

  $preCleanupJson = $PreCleanupProcesses | ConvertTo-Json -Depth 6 -Compress
  $postCleanupJson = $PostCleanupProcesses | ConvertTo-Json -Depth 6 -Compress
  $presentProcessIdsJson = @($LiveProcesses | ForEach-Object { [int]$_.ProcessId }) | ConvertTo-Json -Compress
  $liveProcessesJson = $LiveProcesses | ConvertTo-Json -Depth 6 -Compress
  $failStopIdsJson = @($FailStopIds) | ConvertTo-Json -Compress
  $threadOwnershipJson = @($ThreadOwnershipEntries) | ConvertTo-Json -Depth 6 -Compress
  $threadOwnedPromotionIdsJson = @($ThreadOwnedPromotionIds) | ConvertTo-Json -Compress

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
`$script:LiveProcesses = @((ConvertFrom-Json @'
$liveProcessesJson
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

function Get-LiveTemporaryProcessRecord {
  param([int]`$ProcessId)

  return @(`$script:LiveProcesses | Where-Object { [int]`$_.ProcessId -eq `$ProcessId }) | Select-Object -First 1
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
    [int]`$CurrentProcessId,
    [object[]]`$ThreadOwnershipEntries
  )

  `$threadOwnedIds = @()
  if (`$null -ne `$ThreadOwnershipEntries) {
    `$threadOwnedIds = @(`$ThreadOwnershipEntries | ForEach-Object { [int]`$_.ProcessId })
  }
  `$promotionIds = @((ConvertFrom-Json @'
$threadOwnedPromotionIdsJson
'@))

  return @(`$Processes | ForEach-Object {
    `$killable = [bool]`$_.Killable
    `$desiredDecision = [string]`$_.DesiredDecision

    if ((`$promotionIds -contains [int]`$_.ProcessId) -and (`$threadOwnedIds -contains [int]`$_.ProcessId)) {
      `$killable = `$true
      `$desiredDecision = 'cleanup-now'
    }

    [pscustomobject]@{
      ProcessId       = [int]`$_.ProcessId
      ParentProcessId = [int]`$_.ParentProcessId
      Name            = [string]`$_.Name
      CommandLine     = [string]`$_.CommandLine
      Killable        = `$killable
      DesiredDecision = `$desiredDecision
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

  $ledgerStub = @"
Set-StrictMode -Version Latest

`$parsedThreadOwnershipEntries = ConvertFrom-Json @'
$threadOwnershipJson
'@
`$script:ThreadOwnershipEntries = @()
if (`$null -ne `$parsedThreadOwnershipEntries) {
  `$script:ThreadOwnershipEntries = @(`$parsedThreadOwnershipEntries | ForEach-Object { `$_ })
}

function Get-CurrentCodexThreadId {
  return 'thread-test'
}

function Get-ActiveThreadOwnershipEntries {
  param(
    [string]`$ThreadId,
    [object[]]`$Processes,
    [datetime]`$CurrentTimeUtc
  )

  return @(`$script:ThreadOwnershipEntries | ForEach-Object { `$_ })
}

function Update-ThreadOwnershipEntries {
  param(
    [string]`$ThreadId,
    [object[]]`$ExistingEntries,
    [object[]]`$Processes,
    [object[]]`$ClassifiedRecords,
    [string]`$Workspace,
    [datetime]`$CurrentTimeUtc
  )

  return @(`$ExistingEntries)
}
"@

  Set-Content -LiteralPath (Join-Path $HarnessRoot 'process-inventory.ps1') -Value $inventoryStub
  Set-Content -LiteralPath (Join-Path $HarnessRoot 'process-classification.ps1') -Value $classificationStub
  Set-Content -LiteralPath (Join-Path $HarnessRoot 'cleanup-policy.ps1') -Value $policyStub
  Set-Content -LiteralPath (Join-Path $HarnessRoot 'thread-ownership-ledger.ps1') -Value $ledgerStub

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

  It 'skips cleanup when a killable pid now resolves to a different live process identity' {
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 501
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-root.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool'
      }
    )

    $postCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 501
        ParentProcessId = 1
        Name = 'pwsh'
        CommandLine = 'pwsh -NoLogo'
        Killable = $false
        DesiredDecision = 'preserve'
        DecisionReason = 'pid reused by active shell'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot (Join-Path $TestDrive 'cleanup-entrypoint-pid-reuse') `
      -PreCleanupProcesses $preCleanupProcesses `
      -LiveProcesses $postCleanupProcesses `
      -PostCleanupProcesses $postCleanupProcesses `
      -FailStopIds @()

    $output = & $scriptUnderTest -Mode cleanup -AsJson | ConvertFrom-Json

    $output.killedCount | Should Be 0
    @($output.killedIds).Count | Should Be 0
    $output.failedCount | Should Be 0
    @($output.failedIds).Count | Should Be 0
    $output.decisionCounts.cleanupNow | Should Be 0
    $output.decisionCounts.preserve | Should Be 1
    $output.processes[0].Name | Should Be 'pwsh'
    $output.processes[0].CommandLine | Should Be 'pwsh -NoLogo'
  }

  It 'passes current-thread ownership entries into classification before counting killable roots' {
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lacks current-task ownership evidence'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot (Join-Path $TestDrive 'cleanup-entrypoint-thread-ownership') `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $preCleanupProcesses `
      -FailStopIds @() `
      -ThreadOwnershipEntries @(
        [pscustomobject]@{
          ProcessId = 401
          Name = 'node'
          CommandLine = 'node temp-devtools.js'
          Category = 'devtools-mcp'
          Workspace = 'C:\Repo'
          ObservedAtUtc = '2026-04-15T14:00:00Z'
        }
      ) `
      -ThreadOwnedPromotionIds @(401)

    $output = & $scriptUnderTest -Mode inspect -AsJson | ConvertFrom-Json

    $output.killableRoots | Should Be 1
  }
}
