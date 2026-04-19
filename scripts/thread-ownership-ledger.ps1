Set-StrictMode -Version Latest

$script:ThreadOwnershipLedgerVersion = 1
$script:ThreadOwnershipMaxAge = [TimeSpan]::FromHours(8)
$script:ExplicitAutomationCategories = @(
  "devtools-launcher",
  "devtools-watchdog",
  "devtools-mcp",
  "browser-automation",
  "browser-debug"
)
$script:ExplicitAutomationShellMarkers = @(
  "chrome-devtools-mcp",
  "remote-debugging-port",
  "playwright"
)

function Get-CurrentCodexThreadId {
  if ([string]::IsNullOrWhiteSpace($env:CODEX_THREAD_ID)) {
    return $null
  }

  return $env:CODEX_THREAD_ID.Trim()
}

function Get-ThreadOwnershipStateRoot {
  if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    $codexHomePath = $env:CODEX_HOME
    try {
      $resolvedPath = Resolve-Path -LiteralPath $env:CODEX_HOME -ErrorAction Stop | Select-Object -First 1
      if ($null -ne $resolvedPath -and -not [string]::IsNullOrWhiteSpace($resolvedPath.ProviderPath)) {
        $codexHomePath = $resolvedPath.ProviderPath
      }
    } catch {
    }

    return Join-Path (Join-Path $codexHomePath 'state') 'codex-cleaning-temporary-processes'
  }

  $installedScriptsPath = $PSScriptRoot
  try {
    $resolvedScriptsPath = Resolve-Path -LiteralPath $PSScriptRoot -ErrorAction Stop | Select-Object -First 1
    if ($null -ne $resolvedScriptsPath -and -not [string]::IsNullOrWhiteSpace($resolvedScriptsPath.ProviderPath)) {
      $installedScriptsPath = $resolvedScriptsPath.ProviderPath
    }
  } catch {
  }

  $skillRoot = Split-Path -Path $installedScriptsPath -Parent
  $skillsRoot = Split-Path -Path $skillRoot -Parent
  if (
    -not [string]::IsNullOrWhiteSpace($skillsRoot) -and
    ([System.IO.Path]::GetFileName($skillsRoot)).Equals('skills', [System.StringComparison]::OrdinalIgnoreCase)
  ) {
    $inferredCodexHome = Split-Path -Path $skillsRoot -Parent
    if (-not [string]::IsNullOrWhiteSpace($inferredCodexHome)) {
      return Join-Path (Join-Path $inferredCodexHome 'state') 'codex-cleaning-temporary-processes'
    }
  }

  return Join-Path ([System.IO.Path]::GetTempPath()) 'codex-cleaning-temporary-processes'
}

function ConvertTo-SafeThreadOwnershipFileName {
  param([string]$ThreadId)

  if ([string]::IsNullOrWhiteSpace($ThreadId)) {
    return $null
  }

  return ($ThreadId -replace '[^A-Za-z0-9._-]', '_')
}

function Get-ThreadOwnershipLedgerPath {
  param([string]$ThreadId)

  if ([string]::IsNullOrWhiteSpace($ThreadId)) {
    return $null
  }

  $directory = Join-Path (Get-ThreadOwnershipStateRoot) 'thread-ownership'
  $safeThreadId = ConvertTo-SafeThreadOwnershipFileName -ThreadId $ThreadId
  return Join-Path $directory ($safeThreadId + '.json')
}

function Test-ExplicitAutomationPatternList {
  param(
    [string]$Value,
    [string[]]$Patterns
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }

  foreach ($pattern in $Patterns) {
    if ($Value -match $pattern) {
      return $true
    }
  }

  return $false
}

function Test-IsExplicitAutomationRecord {
  param([object]$Record)

  if ($null -eq $Record) {
    return $false
  }

  $category = [string]$Record.Category
  if ($category -in $script:ExplicitAutomationCategories) {
    return $true
  }

  if ($category -eq 'tool-shell') {
    return Test-ExplicitAutomationPatternList -Value ([string]$Record.CommandLine) -Patterns $script:ExplicitAutomationShellMarkers
  }

  return $false
}

function Test-ShouldPersistThreadOwnershipRecord {
  param([object]$Record)

  if (-not (Test-IsExplicitAutomationRecord -Record $Record)) {
    return $false
  }

  if ([bool]$Record.Killable) {
    return $true
  }

  if ($Record.PSObject.Properties['ThreadOwnershipSeedable']) {
    return [bool]$Record.ThreadOwnershipSeedable
  }

  return $false
}

function Normalize-ThreadOwnershipWorkspace {
  param([string]$Workspace)

  if ([string]::IsNullOrWhiteSpace($Workspace)) {
    return $null
  }

  return $Workspace.Trim().TrimEnd('\', '/')
}

function Test-ThreadOwnershipWorkspaceMatch {
  param(
    [string]$EntryWorkspace,
    [string]$Workspace
  )

  $normalizedWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace $Workspace
  if ([string]::IsNullOrWhiteSpace($normalizedWorkspace)) {
    return $false
  }

  $normalizedEntryWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace $EntryWorkspace
  if ([string]::IsNullOrWhiteSpace($normalizedEntryWorkspace)) {
    return $false
  }

  return $normalizedEntryWorkspace.Equals($normalizedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-ThreadOwnershipEntry {
  param(
    [object]$Record,
    [string]$Workspace,
    [datetime]$ObservedAtUtc
  )

  [pscustomobject]@{
    ProcessId     = [int]$Record.ProcessId
    Name          = [string]$Record.Name
    CommandLine   = [string]$Record.CommandLine
    Category      = [string]$Record.Category
    Workspace     = Normalize-ThreadOwnershipWorkspace -Workspace $Workspace
    ObservedAtUtc = $ObservedAtUtc.ToString('o')
  }
}

function Get-ThreadOwnershipProcessMap {
  param([object[]]$Processes)

  $processMap = @{}
  foreach ($process in @($Processes)) {
    $processMap[[int]$process.ProcessId] = $process
  }

  return $processMap
}

function Test-ThreadOwnershipEntryMatchesProcess {
  param(
    [object]$Entry,
    [object]$Process
  )

  if ($null -eq $Entry -or $null -eq $Process) {
    return $false
  }

  return (
    ([int]$Entry.ProcessId -eq [int]$Process.ProcessId) -and
    ([string]$Entry.Name -eq [string]$Process.Name) -and
    ([string]$Entry.CommandLine -eq [string]$Process.CommandLine)
  )
}

function Get-ThreadOwnershipEntriesFromLedgerFile {
  param([string]$ThreadId)

  $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $ThreadId
  if ([string]::IsNullOrWhiteSpace($ledgerPath) -or -not (Test-Path -LiteralPath $ledgerPath)) {
    return @()
  }

  try {
    $ledger = Get-Content -Raw -LiteralPath $ledgerPath | ConvertFrom-Json
    return @($ledger.Entries)
  } catch {
    return @()
  }
}

function Save-ThreadOwnershipLedger {
  param(
    [string]$ThreadId,
    [object[]]$Entries,
    [datetime]$CurrentTimeUtc
  )

  if ([string]::IsNullOrWhiteSpace($ThreadId)) {
    return
  }

  $ledgerPath = Get-ThreadOwnershipLedgerPath -ThreadId $ThreadId
  $ledgerDirectory = Split-Path $ledgerPath -Parent
  $null = New-Item -ItemType Directory -Path $ledgerDirectory -Force

  $ledger = [pscustomobject]@{
    Version      = $script:ThreadOwnershipLedgerVersion
    ThreadId     = $ThreadId
    UpdatedAtUtc = $CurrentTimeUtc.ToString('o')
    Entries      = @($Entries)
  }

  $ledger | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ledgerPath
}

function Get-ActiveThreadOwnershipEntries {
  param(
    [string]$ThreadId,
    [object[]]$Processes,
    [string]$Workspace,
    [datetime]$CurrentTimeUtc = [datetime]::UtcNow
  )

  if ([string]::IsNullOrWhiteSpace($ThreadId)) {
    return @()
  }

  $processMap = Get-ThreadOwnershipProcessMap -Processes $Processes
  $activeEntries = New-Object 'System.Collections.Generic.List[object]'

  foreach ($entry in @(Get-ThreadOwnershipEntriesFromLedgerFile -ThreadId $ThreadId)) {
    if (-not (Test-IsExplicitAutomationRecord -Record $entry)) {
      continue
    }

    if (-not (Test-ThreadOwnershipWorkspaceMatch -EntryWorkspace ([string]$entry.Workspace) -Workspace $Workspace)) {
      continue
    }

    $observedAtUtc = [datetime]::MinValue
    if (-not [datetime]::TryParse([string]$entry.ObservedAtUtc, [ref]$observedAtUtc)) {
      continue
    }

    if (($CurrentTimeUtc.ToUniversalTime() - $observedAtUtc.ToUniversalTime()) -gt $script:ThreadOwnershipMaxAge) {
      continue
    }

    $processId = [int]$entry.ProcessId
    if (-not $processMap.ContainsKey($processId)) {
      continue
    }

    $process = $processMap[$processId]
    if (-not (Test-ThreadOwnershipEntryMatchesProcess -Entry $entry -Process $process)) {
      continue
    }

    $null = $activeEntries.Add($entry)
  }

  $activeEntriesArray = @($activeEntries | ForEach-Object { $_ })
  Save-ThreadOwnershipLedger -ThreadId $ThreadId -Entries $activeEntriesArray -CurrentTimeUtc $CurrentTimeUtc
  return $activeEntriesArray
}

function Update-ThreadOwnershipEntries {
  param(
    [string]$ThreadId,
    [object[]]$ExistingEntries,
    [object[]]$Processes,
    [object[]]$ClassifiedRecords,
    [string]$Workspace,
    [datetime]$CurrentTimeUtc = [datetime]::UtcNow
  )

  if ([string]::IsNullOrWhiteSpace($ThreadId)) {
    return @()
  }

  $processMap = Get-ThreadOwnershipProcessMap -Processes $Processes
  $entriesByKey = @{}
  $normalizedWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace $Workspace

  foreach ($entry in @($ExistingEntries)) {
    if (-not (Test-IsExplicitAutomationRecord -Record $entry)) {
      continue
    }

    $processId = [int]$entry.ProcessId
    if (-not $processMap.ContainsKey($processId)) {
      continue
    }

    if (-not (Test-ThreadOwnershipEntryMatchesProcess -Entry $entry -Process $processMap[$processId])) {
      continue
    }

    if (-not (Test-ThreadOwnershipWorkspaceMatch -EntryWorkspace ([string]$entry.Workspace) -Workspace $normalizedWorkspace)) {
      continue
    }

    $entryWorkspace = Normalize-ThreadOwnershipWorkspace -Workspace ([string]$entry.Workspace)
    $key = '{0}|{1}|{2}|{3}|{4}' -f $processId, [string]$entry.Name, [string]$entry.CommandLine, [string]$entry.Category, [string]$entryWorkspace
    $entriesByKey[$key] = $entry
  }

  if ([string]::IsNullOrWhiteSpace($normalizedWorkspace)) {
    $updatedEntries = @($entriesByKey.Values | Sort-Object Category, Name, ProcessId)
    Save-ThreadOwnershipLedger -ThreadId $ThreadId -Entries $updatedEntries -CurrentTimeUtc $CurrentTimeUtc
    return $updatedEntries
  }

  foreach ($record in @($ClassifiedRecords)) {
    if (-not (Test-ShouldPersistThreadOwnershipRecord -Record $record)) {
      continue
    }

    $processId = [int]$record.ProcessId
    if (-not $processMap.ContainsKey($processId)) {
      continue
    }

    $entry = ConvertTo-ThreadOwnershipEntry -Record $record -Workspace $normalizedWorkspace -ObservedAtUtc $CurrentTimeUtc
    $key = '{0}|{1}|{2}|{3}|{4}' -f $processId, [string]$entry.Name, [string]$entry.CommandLine, [string]$entry.Category, [string]$entry.Workspace
    $entriesByKey[$key] = $entry
  }

  $updatedEntries = @($entriesByKey.Values | Sort-Object Category, Name, ProcessId)
  Save-ThreadOwnershipLedger -ThreadId $ThreadId -Entries $updatedEntries -CurrentTimeUtc $CurrentTimeUtc
  return $updatedEntries
}
