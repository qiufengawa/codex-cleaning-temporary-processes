$libraryPath = Join-Path $PSScriptRoot 'thread-ownership-ledger.ps1'

Describe 'thread ownership ledger' {
  BeforeEach {
    $env:CODEX_HOME = $TestDrive
  }

  It 'prunes stale or inactive ownership entries when loading the current thread ledger' {
    . $libraryPath

    $threadId = 'thread-a'
    $now = [datetime]'2026-04-15T15:00:00Z'
    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId

    $entries = @(
      [pscustomobject]@{
        ProcessId = 401
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Workspace = 'C:\Repo'
        ObservedAtUtc = '2026-04-15T14:55:00Z'
      }
      [pscustomobject]@{
        ProcessId = 402
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Workspace = 'C:\Repo'
        ObservedAtUtc = '2026-04-14T10:00:00Z'
      }
      [pscustomobject]@{
        ProcessId = 403
        Name = 'msedge.exe'
        CommandLine = 'msedge.exe --remote-debugging-port=9222'
        Category = 'browser-debug'
        Workspace = 'C:\Repo'
        ObservedAtUtc = '2026-04-15T14:58:00Z'
      }
    )
    $ledger = [pscustomobject]@{
      Version = 1
      ThreadId = $threadId
      Entries = $entries
    }
    $null = New-Item -ItemType Directory -Path (Split-Path $ledgerPath -Parent) -Force
    $ledger | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ledgerPath

    $liveProcesses = @(
      [pscustomobject]@{
        ProcessId = 401
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
      [pscustomobject]@{
        ProcessId = 402
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
    )

    $result = @(Get-ActiveThreadOwnershipEntries -ThreadId $threadId -Processes $liveProcesses -Workspace 'C:\Repo' -CurrentTimeUtc $now)

    $result.Count | Should Be 1
    $result[0].ProcessId | Should Be 401
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 1
    @($savedLedger.Entries)[0].ProcessId | Should Be 401
  }

  It 'does not load explicit automation claims when the current workspace is blank' {
    . $libraryPath

    $threadId = 'thread-blank-load'
    $now = [datetime]'2026-04-15T15:05:00Z'
    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId

    $entries = @(
      [pscustomobject]@{
        ProcessId = 451
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Workspace = 'C:\Repo'
        ObservedAtUtc = '2026-04-15T15:00:00Z'
      }
    )
    $ledger = [pscustomobject]@{
      Version = 1
      ThreadId = $threadId
      Entries = $entries
    }
    $null = New-Item -ItemType Directory -Path (Split-Path $ledgerPath -Parent) -Force
    $ledger | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ledgerPath

    $liveProcesses = @(
      [pscustomobject]@{
        ProcessId = 451
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
    )

    $result = @(Get-ActiveThreadOwnershipEntries -ThreadId $threadId -Processes $liveProcesses -Workspace '   ' -CurrentTimeUtc $now)

    $result.Count | Should Be 0
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 0
  }

  It 'persists non-killable explicit automation records for the current thread on first observation when the workspace is set' {
    . $libraryPath

    $threadId = 'thread-b'
    $now = [datetime]'2026-04-15T15:10:00Z'
    $processes = @(
      [pscustomobject]@{
        ProcessId = 501
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
    )
    $classifiedRecords = @(
      [pscustomobject]@{
        ProcessId = 501
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Killable = $false
        ThreadOwnershipSeedable = $true
      }
    )

    $result = @(Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries @() -Processes $processes -ClassifiedRecords $classifiedRecords -Workspace 'C:\Repo' -CurrentTimeUtc $now)

    $result.Count | Should Be 1
    $result[0].ProcessId | Should Be 501
    $result[0].Category | Should Be 'devtools-mcp'
    $result[0].Workspace | Should Be 'C:\Repo'

    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 1
    @($savedLedger.Entries)[0].ProcessId | Should Be 501
  }

  It 'does not persist explicit automation records when the workspace is blank' {
    . $libraryPath

    $threadId = 'thread-blank-persist'
    $now = [datetime]'2026-04-15T15:15:00Z'
    $processes = @(
      [pscustomobject]@{
        ProcessId = 551
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
    )
    $classifiedRecords = @(
      [pscustomobject]@{
        ProcessId = 551
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Killable = $false
        ThreadOwnershipSeedable = $true
      }
    )

    $result = @(Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries @() -Processes $processes -ClassifiedRecords $classifiedRecords -Workspace '   ' -CurrentTimeUtc $now)

    $result.Count | Should Be 0

    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 0
  }

  It 'does not persist generic dev-tool records into the current thread ledger' {
    . $libraryPath

    $threadId = 'thread-c'
    $now = [datetime]'2026-04-15T15:20:00Z'
    $processes = @(
      [pscustomobject]@{
        ProcessId = 601
        ParentProcessId = 1
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload'
      }
    )
    $classifiedRecords = @(
      [pscustomobject]@{
        ProcessId = 601
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload'
        Category = 'dev-tool'
        Killable = $true
      }
    )

    $result = @(Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries @() -Processes $processes -ClassifiedRecords $classifiedRecords -Workspace 'C:\Repo' -CurrentTimeUtc $now)

    $result.Count | Should Be 0

    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 0
  }

  It 'does not persist non-killable explicit automation without a seedable ownership signal' {
    . $libraryPath

    $threadId = 'thread-seed-required'
    $now = [datetime]'2026-04-15T15:25:00Z'
    $processes = @(
      [pscustomobject]@{
        ProcessId = 650
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
    )
    $classifiedRecords = @(
      [pscustomobject]@{
        ProcessId = 650
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Killable = $false
      }
    )

    $result = @(Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries @() -Processes $processes -ClassifiedRecords $classifiedRecords -Workspace 'C:\Repo' -CurrentTimeUtc $now)

    $result.Count | Should Be 0

    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 0
  }

  It 'drops existing explicit automation claims when the current workspace changes' {
    . $libraryPath

    $threadId = 'thread-d'
    $now = [datetime]'2026-04-15T15:30:00Z'
    $processes = @(
      [pscustomobject]@{
        ProcessId = 701
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
    )
    $existingEntries = @(
      [pscustomobject]@{
        ProcessId = 701
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Workspace = 'C:\OtherRepo'
        ObservedAtUtc = '2026-04-15T15:25:00Z'
      }
    )

    $result = @(Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries $existingEntries -Processes $processes -ClassifiedRecords @() -Workspace 'C:\Repo' -CurrentTimeUtc $now)

    $result.Count | Should Be 0

    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 0
  }

  It 'does not reuse existing explicit automation claims when the current workspace is blank' {
    . $libraryPath

    $threadId = 'thread-blank-reuse'
    $now = [datetime]'2026-04-15T15:35:00Z'
    $processes = @(
      [pscustomobject]@{
        ProcessId = 751
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
      }
    )
    $existingEntries = @(
      [pscustomobject]@{
        ProcessId = 751
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Workspace = 'C:\Repo'
        ObservedAtUtc = '2026-04-15T15:34:00Z'
      }
    )

    $result = @(Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries $existingEntries -Processes $processes -ClassifiedRecords @() -Workspace '' -CurrentTimeUtc $now)

    $result.Count | Should Be 0

    $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $threadId
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 0
  }
}
