$entrypointPath = Join-Path $PSScriptRoot 'cleanup-temporary-processes.ps1'

function New-CleanupEntrypointHarness {
  param(
    [string]$HarnessRoot,
    [object[]]$PreCleanupProcesses,
    [object[]]$LiveProcesses,
    [object[]]$PostCleanupProcesses,
    [int[]]$FailStopIds,
    [object[]]$ThreadOwnershipEntries = @(),
    [int[]]$ThreadOwnedPromotionIds = @(),
    [bool]$PersistUpdatedThreadOwnership = $false
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
  $classificationTracePath = Join-Path $HarnessRoot 'classification-thread-ownership-trace.txt'
  $classificationTracePathLiteral = $classificationTracePath -replace "'", "''"
  $ledgerWorkspaceTracePath = Join-Path $HarnessRoot 'ledger-workspace-trace.txt'
  $ledgerWorkspaceTracePathLiteral = $ledgerWorkspaceTracePath -replace "'", "''"
  $threadOwnershipStatePath = Join-Path $HarnessRoot 'thread-ownership-state.json'
  $threadOwnershipStatePathLiteral = $threadOwnershipStatePath -replace "'", "''"
  $persistUpdatedThreadOwnershipLiteral = if ($PersistUpdatedThreadOwnership) { '$true' } else { '$false' }

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
    [object[]]`$ThreadOwnershipEntries,
    [bool]`$AllowCurrentThreadExplicitAutomationSeed = `$false
  )

  `$threadOwnedIds = @()
  if (`$null -ne `$ThreadOwnershipEntries) {
    `$threadOwnedIds = @(`$ThreadOwnershipEntries | ForEach-Object { [int]`$_.ProcessId })
  }
  `$traceValue = if (`$threadOwnedIds.Count -gt 0) {
    ((`$threadOwnedIds | Sort-Object) -join ',')
  } else {
    '<none>'
  }
  Add-Content -LiteralPath '$classificationTracePathLiteral' -Value `$traceValue
  `$promotionIds = @((ConvertFrom-Json @'
$threadOwnedPromotionIdsJson
'@))

  return @(`$Processes | ForEach-Object {
    `$killable = [bool]`$_.Killable
    `$desiredDecision = [string]`$_.DesiredDecision
    `$category = ''
    `$threadOwnershipSeedable = `$false
    if (`$_.PSObject.Properties['Category']) {
      `$category = [string]`$_.Category
    }
    if (`$_.PSObject.Properties['ThreadOwnershipSeedable']) {
      `$threadOwnershipSeedable = (
        [bool]`$_.ThreadOwnershipSeedable -and
        `$AllowCurrentThreadExplicitAutomationSeed -and
        (-not [string]::IsNullOrWhiteSpace(`$Workspace))
      )
    }

    if ((`$promotionIds -contains [int]`$_.ProcessId) -and (`$threadOwnedIds -contains [int]`$_.ProcessId)) {
      `$killable = `$true
      `$desiredDecision = 'cleanup-now'
    }

    [pscustomobject]@{
      ProcessId       = [int]`$_.ProcessId
      ParentProcessId = [int]`$_.ParentProcessId
      Name            = [string]`$_.Name
      Category        = `$category
      CommandLine     = [string]`$_.CommandLine
      ThreadOwnershipSeedable = `$threadOwnershipSeedable
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
`$script:InitialThreadOwnershipEntries = @()
if (`$null -ne `$parsedThreadOwnershipEntries) {
  `$script:InitialThreadOwnershipEntries = @(`$parsedThreadOwnershipEntries | ForEach-Object { `$_ })
}
`$script:ThreadOwnershipStatePath = '$threadOwnershipStatePathLiteral'
`$script:PersistUpdatedThreadOwnership = $persistUpdatedThreadOwnershipLiteral

@(`$script:InitialThreadOwnershipEntries) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath `$script:ThreadOwnershipStatePath

function Get-StoredThreadOwnershipEntries {
  if (-not (Test-Path -LiteralPath `$script:ThreadOwnershipStatePath)) {
    return @()
  }

  `$storedEntries = Get-Content -Raw -LiteralPath `$script:ThreadOwnershipStatePath | ConvertFrom-Json
  if (`$null -eq `$storedEntries) {
    return @()
  }

  return @(`$storedEntries | ForEach-Object { `$_ })
}

function Get-CurrentCodexThreadId {
  return 'thread-test'
}

function Get-ThreadOwnershipStateRoot {
  return (Split-Path -Parent `$script:ThreadOwnershipStatePath)
}

function Get-ThreadOwnershipLedgerPath {
  param([string]`$ThreadId)

  return `$script:ThreadOwnershipStatePath
}

function Normalize-ThreadOwnershipWorkspace {
  param([string]`$Workspace)

  if ([string]::IsNullOrWhiteSpace(`$Workspace)) {
    return `$null
  }

  return `$Workspace.Trim().TrimEnd('\', '/')
}

function Test-ThreadOwnershipWorkspaceMatch {
  param(
    [string]`$EntryWorkspace,
    [string]`$Workspace
  )

  `$normalizedWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace `$Workspace
  if ([string]::IsNullOrWhiteSpace(`$normalizedWorkspace)) {
    return `$false
  }

  `$normalizedEntryWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace `$EntryWorkspace
  if ([string]::IsNullOrWhiteSpace(`$normalizedEntryWorkspace)) {
    return `$false
  }

  return `$normalizedEntryWorkspace.Equals(`$normalizedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ActiveThreadOwnershipEntries {
  param(
    [string]`$ThreadId,
    [object[]]`$Processes,
    [string]`$Workspace,
    [datetime]`$CurrentTimeUtc
  )

  `$traceValue = if ([string]::IsNullOrWhiteSpace(`$Workspace)) { '<none>' } else { `$Workspace }
  Add-Content -LiteralPath '$ledgerWorkspaceTracePathLiteral' -Value `$traceValue
  if ([string]::IsNullOrWhiteSpace(`$Workspace)) {
    return @()
  }

  return @(
    Get-StoredThreadOwnershipEntries |
      Where-Object {
        Test-ThreadOwnershipWorkspaceMatch -EntryWorkspace ([string]`$_.Workspace) -Workspace `$Workspace
      } |
      ForEach-Object { `$_ }
  )
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

  if (-not `$script:PersistUpdatedThreadOwnership) {
    return @(`$ExistingEntries)
  }

  `$normalizedWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace `$Workspace
  if ([string]::IsNullOrWhiteSpace(`$normalizedWorkspace)) {
    @() | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath `$script:ThreadOwnershipStatePath
    return @()
  }

  `$processMap = @{}
  foreach (`$process in @(`$Processes)) {
    `$processMap[[int]`$process.ProcessId] = `$process
  }

  `$entriesByKey = @{}
  foreach (`$entry in @(`$ExistingEntries)) {
    `$processId = [int]`$entry.ProcessId
    if (-not `$processMap.ContainsKey(`$processId)) {
      continue
    }

    if (
      ([string]`$entry.Name -ne [string]`$processMap[`$processId].Name) -or
      ([string]`$entry.CommandLine -ne [string]`$processMap[`$processId].CommandLine)
    ) {
      continue
    }

    if (-not (Test-ThreadOwnershipWorkspaceMatch -EntryWorkspace ([string]`$entry.Workspace) -Workspace `$normalizedWorkspace)) {
      continue
    }

    `$entryWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace ([string]`$entry.Workspace)
    `$key = '{0}|{1}|{2}|{3}|{4}' -f `$processId, [string]`$entry.Name, [string]`$entry.CommandLine, [string]`$entry.Category, [string]`$entryWorkspace
    `$entriesByKey[`$key] = `$entry
  }

  foreach (`$record in @(`$ClassifiedRecords)) {
    `$category = [string]`$record.Category
    `$commandLine = [string]`$record.CommandLine
    `$threadOwnershipSeedable = `$false
    if (`$record.PSObject.Properties['ThreadOwnershipSeedable']) {
      `$threadOwnershipSeedable = [bool]`$record.ThreadOwnershipSeedable
    }
    `$isExplicitAutomation = (
      (`$category -in @('devtools-launcher', 'devtools-watchdog', 'devtools-mcp', 'browser-automation', 'browser-debug')) -or
      ((`$category -eq 'tool-shell') -and (`$commandLine -match 'chrome-devtools-mcp|remote-debugging-port|playwright'))
    )

    if ((-not `$isExplicitAutomation) -or ((-not [bool]`$record.Killable) -and (-not `$threadOwnershipSeedable))) {
      continue
    }

    `$processId = [int]`$record.ProcessId
    if (-not `$processMap.ContainsKey(`$processId)) {
      continue
    }

    `$entry = [pscustomobject]@{
      ProcessId     = `$processId
      Name          = [string]`$record.Name
      CommandLine   = `$commandLine
      Category      = `$category
      Workspace     = `$normalizedWorkspace
      ObservedAtUtc = `$CurrentTimeUtc.ToString('o')
    }
    `$key = '{0}|{1}|{2}|{3}|{4}' -f `$processId, [string]`$entry.Name, [string]`$entry.CommandLine, [string]`$entry.Category, [string]`$entry.Workspace
    `$entriesByKey[`$key] = `$entry
  }

  `$updatedEntries = @(`$entriesByKey.Values | Sort-Object Category, Name, ProcessId)
  @(`$updatedEntries) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath `$script:ThreadOwnershipStatePath
  return `$updatedEntries
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
    $harnessRoot = Join-Path $TestDrive 'cleanup-entrypoint-thread-ownership'
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Category = 'devtools-mcp'
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lacks current-task ownership evidence'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot $harnessRoot `
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

    $output = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -AsJson | ConvertFrom-Json
    $classificationTrace = Get-Content -LiteralPath (Join-Path $harnessRoot 'classification-thread-ownership-trace.txt')
    $ledgerWorkspaceTrace = Get-Content -LiteralPath (Join-Path $harnessRoot 'ledger-workspace-trace.txt')

    $output.killableRoots | Should Be 1
    @($classificationTrace) | Should Be @('401')
    @($ledgerWorkspaceTrace) | Should Be @('C:\Repo')
  }

  It 'seeds current-thread ownership on the first inspect pass only when explicitly confirmed with a workspace' {
    $harnessRoot = Join-Path $TestDrive 'cleanup-entrypoint-seeded-thread-ownership'
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Category = 'devtools-mcp'
        ThreadOwnershipSeedable = $true
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lacks current-task ownership evidence'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $preCleanupProcesses `
      -FailStopIds @() `
      -ThreadOwnershipEntries @() `
      -ThreadOwnedPromotionIds @(401) `
      -PersistUpdatedThreadOwnership $true

    $firstOutput = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -ConfirmCurrentThreadExplicitAutomation -AsJson | ConvertFrom-Json
    $secondOutput = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -AsJson | ConvertFrom-Json
    $classificationTrace = Get-Content -LiteralPath (Join-Path $harnessRoot 'classification-thread-ownership-trace.txt')
    $firstOutput.killableRoots | Should Be 0
    $secondOutput.killableRoots | Should Be 1
    @($classificationTrace) | Should Be @('<none>', '401')
  }

  It 'reports thread ownership metadata in inspect output after a confirmed seed pass' {
    $harnessRoot = Join-Path $TestDrive 'cleanup-entrypoint-thread-ownership-metadata'
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Category = 'devtools-mcp'
        ThreadOwnershipSeedable = $true
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lacks current-task ownership evidence'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $preCleanupProcesses `
      -FailStopIds @() `
      -ThreadOwnershipEntries @() `
      -PersistUpdatedThreadOwnership $true

    $output = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -ConfirmCurrentThreadExplicitAutomation -AsJson | ConvertFrom-Json

    $output.threadId | Should Be 'thread-test'
    $output.threadOwnershipStateRoot | Should Be $harnessRoot
    $output.threadOwnershipLedgerPath | Should Be (Join-Path $harnessRoot 'thread-ownership-state.json')
    $output.threadOwnershipEntryCount | Should Be 1
  }

  It 'persists first-pass thread ownership before checkpoint cleanup changes the explicit automation snapshot' {
    $harnessRoot = Join-Path $TestDrive 'cleanup-entrypoint-checkpoint-seeded-thread-ownership'
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Category = 'devtools-mcp'
        ThreadOwnershipSeedable = $true
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lacks current-task ownership evidence'
      }
      [pscustomobject]@{
        ProcessId = 501
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-cleanup-root.js'
        Killable = $true
        DesiredDecision = 'cleanup-now'
        DecisionReason = 'temporary tool'
      }
    )
    $postCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Category = 'devtools-mcp'
        ThreadOwnershipSeedable = $false
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lost first-pass seed signal after cleanup'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $postCleanupProcesses `
      -FailStopIds @() `
      -ThreadOwnershipEntries @() `
      -ThreadOwnedPromotionIds @(401) `
      -PersistUpdatedThreadOwnership $true

    $firstOutput = & $scriptUnderTest -Mode checkpoint-cleanup -Workspace 'C:\Repo' -ConfirmCurrentThreadExplicitAutomation -AsJson | ConvertFrom-Json
    $secondOutput = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -AsJson | ConvertFrom-Json
    $secondRecord = @($secondOutput.processes | Where-Object { [int]$_.ProcessId -eq 401 }) | Select-Object -First 1
    $classificationTrace = Get-Content -LiteralPath (Join-Path $harnessRoot 'classification-thread-ownership-trace.txt')

    $firstOutput.killedCount | Should Be 1
    $secondRecord.Killable | Should Be $true
    @($classificationTrace) | Should Be @('<none>', '401')
  }

  It 'does not seed or promote explicit automation without current-thread confirmation' {
    $harnessRoot = Join-Path $TestDrive 'cleanup-entrypoint-unconfirmed-thread-ownership'
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Category = 'devtools-mcp'
        ThreadOwnershipSeedable = $true
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lacks current-task ownership evidence'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $preCleanupProcesses `
      -FailStopIds @() `
      -ThreadOwnershipEntries @() `
      -ThreadOwnedPromotionIds @(401) `
      -PersistUpdatedThreadOwnership $true

    $firstOutput = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -AsJson | ConvertFrom-Json
    $secondOutput = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -AsJson | ConvertFrom-Json
    $classificationTrace = Get-Content -LiteralPath (Join-Path $harnessRoot 'classification-thread-ownership-trace.txt')
    $statePath = Join-Path $harnessRoot 'thread-ownership-state.json'
    $storedEntries = if (Test-Path -LiteralPath $statePath) {
      @((Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json))
    } else {
      @()
    }

    $firstOutput.killableRoots | Should Be 0
    $secondOutput.killableRoots | Should Be 0
    @($classificationTrace) | Should Be @('<none>', '<none>')
    $storedEntries.Count | Should Be 0
  }

  It 'does not seed or promote explicit automation when confirmation is used without a workspace' {
    $harnessRoot = Join-Path $TestDrive 'cleanup-entrypoint-blank-workspace-thread-ownership'
    $preCleanupProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node temp-devtools.js'
        Category = 'devtools-mcp'
        ThreadOwnershipSeedable = $true
        Killable = $false
        DesiredDecision = 'inspect-only'
        DecisionReason = 'explicit automation lacks current-task ownership evidence'
      }
    )

    $scriptUnderTest = New-CleanupEntrypointHarness `
      -HarnessRoot $harnessRoot `
      -PreCleanupProcesses $preCleanupProcesses `
      -PostCleanupProcesses $preCleanupProcesses `
      -FailStopIds @() `
      -ThreadOwnershipEntries @() `
      -ThreadOwnedPromotionIds @(401) `
      -PersistUpdatedThreadOwnership $true

    $firstOutput = & $scriptUnderTest -Mode inspect -Workspace '   ' -ConfirmCurrentThreadExplicitAutomation -AsJson | ConvertFrom-Json
    $secondOutput = & $scriptUnderTest -Mode inspect -Workspace 'C:\Repo' -AsJson | ConvertFrom-Json
    $classificationTrace = Get-Content -LiteralPath (Join-Path $harnessRoot 'classification-thread-ownership-trace.txt')
    $ledgerWorkspaceTrace = Get-Content -LiteralPath (Join-Path $harnessRoot 'ledger-workspace-trace.txt')
    $statePath = Join-Path $harnessRoot 'thread-ownership-state.json'
    $storedEntries = if (Test-Path -LiteralPath $statePath) {
      @((Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json))
    } else {
      @()
    }

    $firstOutput.killableRoots | Should Be 0
    $secondOutput.killableRoots | Should Be 0
    @($classificationTrace) | Should Be @('<none>', '<none>')
    @($ledgerWorkspaceTrace) | Should Be @('<none>', 'C:\Repo')
    $storedEntries.Count | Should Be 0
  }
}
