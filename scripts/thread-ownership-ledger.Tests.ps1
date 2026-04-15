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

    $result = @(Get-ActiveThreadOwnershipEntries -ThreadId $threadId -Processes $liveProcesses -CurrentTimeUtc $now)

    $result.Count | Should Be 1
    $result[0].ProcessId | Should Be 401
    $savedLedger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    @($savedLedger.Entries).Count | Should Be 1
    @($savedLedger.Entries)[0].ProcessId | Should Be 401
  }

  It 'persists only killable explicit automation records for the current thread' {
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
      [pscustomobject]@{
        ProcessId = 502
        ParentProcessId = 1
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload'
      }
      [pscustomobject]@{
        ProcessId = 503
        ParentProcessId = 1
        Name = 'msedge.exe'
        CommandLine = 'msedge.exe --remote-debugging-port=9222'
      }
    )
    $classifiedRecords = @(
      [pscustomobject]@{
        ProcessId = 501
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Killable = $true
      }
      [pscustomobject]@{
        ProcessId = 502
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload'
        Category = 'dev-tool'
        Killable = $true
      }
      [pscustomobject]@{
        ProcessId = 503
        Name = 'msedge.exe'
        CommandLine = 'msedge.exe --remote-debugging-port=9222'
        Category = 'browser-debug'
        Killable = $false
      }
    )

    $result = @(Update-ThreadOwnershipEntries -ThreadId $threadId -ExistingEntries @() -Processes $processes -ClassifiedRecords $classifiedRecords -Workspace 'C:\Repo' -CurrentTimeUtc $now)

    $result.Count | Should Be 1
    $result[0].ProcessId | Should Be 501
    $result[0].Category | Should Be 'devtools-mcp'
    $result[0].Workspace | Should Be 'C:\Repo'
  }
}
