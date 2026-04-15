Set-StrictMode -Version Latest

$script:ProtectedShellNamePatterns = @(
  "^(powershell|pwsh)(\.exe)?$",
  "^(bash|zsh|sh|fish)$"
)
$script:CmdShellNamePatterns = @("^cmd(\.exe)?$")
$script:BrowserNamePatterns = @(
  "^(chrome|chromium|google chrome|google-chrome|google-chrome-stable|msedge|microsoft edge|microsoft-edge)(\.exe)?$"
)
$script:NodeNamePatterns = @("^node(\.exe)?$")
$script:GenericRuntimeNamePatterns = @(
  "^(python(\d+(\.\d+)*)?|py)(\.exe)?$",
  "^(uv|uvx|poetry|pipenv)(\.exe)?$",
  "^(dotnet|go|ruby|php|java|bun|deno|julia|swift|dart|flutter)(\.exe)?$"
)
$script:DirectToolNamePatterns = @(
  "^(npm|npx|pnpm|pnpx|yarn)(\.cmd|\.exe)?$",
  "^(vite|vitest|next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit|tsx|ts-node|ts-node-dev|nodemon|vite-node)(\.cmd|\.exe)?$",
  "^(cargo|tauri|trunk)(\.exe)?$",
  "^(pytest|uvicorn|gunicorn|flask|django-admin|streamlit|hatch)(\.exe)?$",
  "^(jupyter|jupyter-lab|jupyter-notebook)(\.exe)?$",
  "^(gradle(w)?(\.bat)?|mvn(\.cmd)?)$",
  "^(sbt(\.bat)?|scala(-cli)?(\.cmd|\.exe)?|kotlin(\.exe)?)$",
  "^(air|reflex)(\.exe)?$",
  "^(bundle(\.bat)?|rails(\.exe)?|rspec(\.exe)?)$",
  "^(composer(\.bat)?|artisan)$",
  "^(mix|iex|rebar3)$",
  "^(cmake|ctest|meson|ninja|make)$"
)

$script:BrowserAutomationPattern = "playwright|remote-debugging-port|--headless"
$script:BrowserDebugPattern = "--remote-debugging-port|--headless|playwright"
$script:CodexParentNamePattern = "^Codex(\.exe)?$"
$script:CodexAppServerCommandPattern = "\bapp-server\b"

$script:HighConfidenceShellPatterns = @(
  "\bplaywright\b",
  "chrome-devtools-mcp",
  "remote-debugging-port"
)

$script:WorkspaceScopedShellPatterns = @(
  "\b(npm|npx|pnpm|pnpx|yarn|bun|bunx)(\.cmd|\.exe)?\b.*\b(run|exec|dev|build|preview|test|start|serve|watch|install|ci)\b",
  "(?:^|[\s;&|`"])(?:vite|vitest)(?:\s+(dev|preview|test|run|watch)\b|\s+--[A-Za-z0-9-]+(?:[=\s][^\s`"]+)?|\s*(?:`"|$))",
  "\b(next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit)\b.*\b(dev|build|preview|test|start|serve|watch|run|open)\b",
  "\b(tsx|ts-node|ts-node-dev|nodemon|vite-node)\b.*\b(watch|dev|start|serve|run)\b",
  "\bcargo(\.exe)?\b.*\b(test|run|check|build|tauri|clippy)\b",
  "\btrunk(\.exe)?\b.*\b(serve|watch|build|test)\b",
  "\b(py(thon)?|uv|uvx|poetry|pipenv)(\.exe)?\b.*\b(pytest|uvicorn|gunicorn|flask|django|runserver|serve|watch|test|dev)\b",
  "\b(pytest|uvicorn|gunicorn)\b",
  "\bflask(\.exe)?\b.*\brun\b",
  "\bdjango-admin(\.exe)?\b.*\brunserver\b",
  "manage\.py\b.*\b(runserver|test)\b",
  "\bhatch(\.exe)?\b.*\b(run|test)\b",
  "\bstreamlit(\.exe)?\b.*\brun\b",
  "\bjupyter(?:-lab|-notebook)?(\.exe)?\b.*(?:\b(lab|notebook)\b|--notebook-dir)\b",
  "\b(gradle(w)?(\.bat)?|mvn(\.cmd)?|java(\.exe)?)\b.*\b(test|bootrun|spring-boot:run|quarkus:dev|dev|run|serve)\b",
  "\b(sbt(\.bat)?|scala(-cli)?(\.cmd|\.exe)?)\b.*(\b(run|test|compile|console)\b|\.scala\b)",
  "\bkotlin(\.exe)?\b.*(\.kts\b|\b(run|test)\b)",
  "\bdotnet(\.exe)?\b.*\b(watch|run|test|build|publish)\b",
  "\b(go(\.exe)?)\b.*\b(run|test)\b",
  "\b(air|reflex)(\.exe)?\b",
  "\b(bundle(\.bat)?|rails(\.exe)?|rspec(\.exe)?|ruby(\.exe)?)\b.*\b(server|test|spec|dev)\b",
  "\b(php(\.exe)?|composer(\.bat)?|artisan)\b.*\b(serve|test)\b",
  "\bartisan\b.*\b(serve|test)\b",
  "\b(mix|iex|rebar3)\b.*\b(phx\.server|test|dev|serve|run)\b",
  "\b(cmake|ctest|meson|ninja|make)\b.*\b(test|build|check|run)\b",
  "\b(swift|dart|flutter)\b.*\b(run|test|build|serve)\b"
)

$script:WorkspaceScopedNodePatterns = @(
  "\bnpm(\.cmd)?\b.*\b(run|exec)\b.*\b(dev|build|preview|test)\b",
  "\b(pnpm|pnpx|yarn|bun|bunx)(\.cmd|\.exe)?\b.*\b(dev|build|preview|test|start|serve|watch)\b",
  "\b(next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit)\b.*\b(dev|build|preview|test|start|serve|watch|run|open)\b",
  "\b(tsx|ts-node|ts-node-dev|nodemon|vite-node)\b.*\b(watch|dev|start|serve|run)\b",
  "node_modules[/\\](vite|vitest)[/\\]",
  "node_modules[/\\](next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit|tsx|ts-node|ts-node-dev|nodemon|vite-node)[/\\].*\b(dev|build|preview|test|start|serve|watch|run|open)\b"
)

$script:WorkspaceScopedRuntimePatterns = @(
  "\b(py(thon)?|uv|uvx|poetry|pipenv)(\.exe)?\b.*\b(pytest|uvicorn|gunicorn|flask|django|runserver|serve|watch|test|dev)\b",
  "\b(pytest|uvicorn|gunicorn)\b",
  "\bflask(\.exe)?\b.*\brun\b",
  "\bdjango-admin(\.exe)?\b.*\brunserver\b",
  "manage\.py\b.*\b(runserver|test)\b",
  "\bhatch(\.exe)?\b.*\b(run|test)\b",
  "\bstreamlit(\.exe)?\b.*\brun\b",
  "\bjupyter(?:-lab|-notebook)?(\.exe)?\b.*(?:\b(lab|notebook)\b|--notebook-dir)\b",
  "\bdotnet(\.exe)?\b.*\b(watch|run|test|build|publish)\b",
  "\btrunk(\.exe)?\b.*\b(serve|watch|build|test)\b",
  "\b(sbt(\.bat)?|scala(-cli)?(\.cmd|\.exe)?)\b.*(\b(run|test|compile|console)\b|\.scala\b)",
  "\bkotlin(\.exe)?\b.*(\.kts\b|\b(run|test)\b)",
  "\b(go(\.exe)?)\b.*\b(run|test)\b",
  "\b(air|reflex)(\.exe)?\b",
  "\b(bundle(\.bat)?|rails(\.exe)?|rspec(\.exe)?|ruby(\.exe)?)\b.*\b(server|test|spec|dev)\b",
  "\b(php(\.exe)?|composer(\.bat)?|artisan)\b.*\b(serve|test)\b",
  "\bartisan\b.*\b(serve|test)\b",
  "\b(gradle(w)?(\.bat)?|mvn(\.cmd)?|java(\.exe)?)\b.*\b(test|bootrun|spring-boot:run|quarkus:dev|dev|run|serve)\b",
  "\b(bun|bunx)(\.exe)?\b.*\b(dev|build|preview|test|start|serve|watch)\b",
  "\b(deno(\.exe)?)\b.*\b(run|test|task)\b",
  "\b(mix|iex|rebar3)\b.*\b(phx\.server|test|dev|serve|run)\b",
  "\b(swift|dart|flutter)\b.*\b(run|test|build|serve)\b",
  "\b(cmake|ctest|meson|ninja|make)\b.*\b(test|build|check|run)\b"
)
$script:WorkspaceScopedDirectToolPatterns = @(
  "\bnpm(\.cmd)?\b.*\b(run|exec|dev|build|preview|test|start|serve|watch|install|ci)\b",
  "\b(npx|pnpm|pnpx|yarn|bun|bunx)(\.cmd|\.exe)?\b.*\b(run|exec|dev|build|preview|test|start|serve|watch|install|ci)\b",
  "\b(vite|vitest)\b(?:\s|$)",
  "\b(next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit)\b.*\b(dev|build|preview|test|start|serve|watch|run|open)\b",
  "\b(tsx|ts-node|ts-node-dev|nodemon|vite-node)\b.*\b(watch|dev|start|serve|run)\b",
  "\bcargo(\.exe)?\b.*\b(test|run|check|build|tauri|clippy)\b",
  "\btauri(\.exe)?\b.*\b(dev|build|android|ios)\b",
  "\b(pytest|uvicorn|gunicorn)\b",
  "\bflask(\.exe)?\b.*\brun\b",
  "\bdjango-admin(\.exe)?\b.*\brunserver\b",
  "manage\.py\b.*\b(runserver|test)\b",
  "\bhatch(\.exe)?\b.*\b(run|test)\b",
  "\bstreamlit(\.exe)?\b.*\brun\b",
  "\bjupyter(?:-lab|-notebook)?(\.exe)?\b.*(?:\b(lab|notebook)\b|--notebook-dir)\b",
  "\b(gradle(w)?(\.bat)?|mvn(\.cmd)?)\b.*\b(test|build|bootrun|spring-boot:run|quarkus:dev|dev|run|serve|package|install|verify)\b",
  "\btrunk(\.exe)?\b.*\b(serve|watch|build|test)\b",
  "\b(sbt(\.bat)?|scala(-cli)?(\.cmd|\.exe)?)\b.*(\b(run|test|compile|console)\b|\.scala\b)",
  "\bkotlin(\.exe)?\b.*(\.kts\b|\b(run|test)\b)",
  "\b(air|reflex)(\.exe)?\b",
  "\b(bundle(\.bat)?|rails(\.exe)?|rspec(\.exe)?)\b.*\b(server|test|spec|dev)\b",
  "\b(composer(\.bat)?|artisan)\b.*\b(serve|test)\b",
  "\b(mix|iex|rebar3)\b.*\b(phx\.server|test|dev|serve|run)\b",
  "\b(cmake|ctest|meson|ninja|make)\b.*\b(test|build|check|run)\b"
)

function New-ProcessRecord {
  param(
    [object]$Process,
    [string]$Category,
    [bool]$Killable,
    [string]$Reason,
    [bool]$ThreadOwnershipSeedable = $false
  )

  [pscustomobject]@{
    ProcessId       = [int]$Process.ProcessId
    ParentProcessId = [int]$Process.ParentProcessId
    Name            = [string]$Process.Name
    Category        = $Category
    Killable        = $Killable
    Reason          = $Reason
    ThreadOwnershipSeedable = $ThreadOwnershipSeedable
    CommandLine     = [string]$Process.CommandLine
  }
}

function Get-WorkspacePattern {
  param([string]$Workspace)

  if ([string]::IsNullOrWhiteSpace($Workspace)) {
    return $null
  }

  $trimmedWorkspace = $Workspace.Trim().TrimEnd('\', '/')
  if ([string]::IsNullOrWhiteSpace($trimmedWorkspace)) {
    return $null
  }

  $segments = @($trimmedWorkspace -split '[\\/]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($segments.Count -eq 0) {
    return $null
  }

  $pathPattern = [string]::Join('[\\/]', @($segments | ForEach-Object { [regex]::Escape($_) }))
  if ($trimmedWorkspace.StartsWith('\') -or $trimmedWorkspace.StartsWith('/')) {
    $pathPattern = '[\\/]' + $pathPattern
  }

  return '(?i)(?<![A-Za-z0-9_.-])' + $pathPattern + '(?=$|[\\/''"\s;&|])'
}

function Get-NormalizedWorkspaceValue {
  param([string]$Workspace)

  if ([string]::IsNullOrWhiteSpace($Workspace)) {
    return $null
  }

  return $Workspace.Trim().TrimEnd('\', '/').ToLowerInvariant()
}

function Test-PatternList {
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

function Test-NamePatternList {
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

function Test-WorkspaceMatch {
  param(
    [string]$CommandLine,
    [string]$WorkspacePattern
  )

  if ([string]::IsNullOrWhiteSpace($WorkspacePattern)) {
    return $false
  }

  return $CommandLine -match $WorkspacePattern
}

function Get-ParentProcessName {
  param(
    [int]$ParentProcessId,
    [hashtable]$ProcessById
  )

  if ($ProcessById.ContainsKey($ParentProcessId)) {
    return [string]$ProcessById[$ParentProcessId].Name
  }

  return $null
}

function Test-CodexAppServerProcess {
  param([object]$Process)

  if ($null -eq $Process) {
    return $false
  }

  $name = [string]$Process.Name
  $commandLine = [string]$Process.CommandLine

  return (
    (Test-NamePatternList -Value $name -Patterns @($script:CodexParentNamePattern)) -and
    ($commandLine -match $script:CodexAppServerCommandPattern)
  )
}

function Get-CodexAppServerAncestorId {
  param(
    [int]$ProcessId,
    [hashtable]$ProcessById
  )

  $visited = @{}
  $ancestorId = $ProcessId

  while ($ancestorId -gt 0 -and $ProcessById.ContainsKey($ancestorId) -and -not $visited.ContainsKey($ancestorId)) {
    $visited[$ancestorId] = $true

    $ancestor = $ProcessById[$ancestorId]
    if (Test-CodexAppServerProcess -Process $ancestor) {
      return $ancestorId
    }

    $ancestorId = [int]$ancestor.ParentProcessId
  }

  return 0
}

function Test-CurrentThreadCodexAppServerExplicitAutomationAncestry {
  param(
    [object]$Process,
    [hashtable]$ProcessById,
    [int]$CurrentCodexAppServerId
  )

  if ($null -eq $Process -or $CurrentCodexAppServerId -le 0) {
    return $false
  }

  return (Get-CodexAppServerAncestorId -ProcessId ([int]$Process.ProcessId) -ProcessById $ProcessById) -eq $CurrentCodexAppServerId
}

function Test-ProcessAnchorsTaskOwnership {
  param(
    [object]$Process,
    [hashtable]$ProcessById,
    [string]$WorkspacePattern
  )

  if ($null -eq $Process) {
    return $false
  }

  $name = ([string]$Process.Name).ToLowerInvariant()
  $commandLine = [string]$Process.CommandLine
  $workspaceMatch = Test-WorkspaceMatch -CommandLine $commandLine -WorkspacePattern $WorkspacePattern

  if (-not $workspaceMatch) {
    return $false
  }

  if (Test-NamePatternList -Value $name -Patterns $script:ProtectedShellNamePatterns) {
    if ($commandLine -match "Long-lived PowerShell AST parser|ConvertFrom-Json") {
      return $false
    }

    return Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedShellPatterns
  }

  if (Test-NamePatternList -Value $name -Patterns $script:CmdShellNamePatterns) {
    return Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedShellPatterns
  }

  if (Test-NamePatternList -Value $name -Patterns $script:NodeNamePatterns) {
    return Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedNodePatterns
  }

  if (Test-NamePatternList -Value $name -Patterns $script:DirectToolNamePatterns) {
    return Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedDirectToolPatterns
  }

  if (Test-NamePatternList -Value $name -Patterns $script:GenericRuntimeNamePatterns) {
    return Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedRuntimePatterns
  }

  return $false
}

function Test-TaskOwnedAncestor {
  param(
    [int]$ParentProcessId,
    [hashtable]$ProcessById,
    [string]$WorkspacePattern
  )

  $visited = @{}
  $ancestorId = $ParentProcessId

  while ($ancestorId -gt 0 -and $ProcessById.ContainsKey($ancestorId) -and -not $visited.ContainsKey($ancestorId)) {
    $visited[$ancestorId] = $true

    $ancestor = $ProcessById[$ancestorId]
    if (Test-ProcessAnchorsTaskOwnership -Process $ancestor -ProcessById $ProcessById -WorkspacePattern $WorkspacePattern) {
      return $true
    }

    $ancestorId = [int]$ancestor.ParentProcessId
  }

  return $false
}

function Test-TemporaryShellCommandLine {
  param(
    [string]$CommandLine,
    [bool]$WorkspaceMatch,
    [bool]$TaskOwnedAncestor = $false
  )

  if ([string]::IsNullOrWhiteSpace($CommandLine)) {
    return $false
  }

  return ($WorkspaceMatch -or $TaskOwnedAncestor) -and (Test-PatternList -Value $CommandLine -Patterns $script:WorkspaceScopedShellPatterns)
}

function Test-ExplicitAutomationShellCommandLine {
  param([string]$CommandLine)

  if ([string]::IsNullOrWhiteSpace($CommandLine)) {
    return $false
  }

  if ($CommandLine -match "chrome-devtools-mcp|remote-debugging-port") {
    return $true
  }

  return Test-PatternList -Value $CommandLine -Patterns $script:HighConfidenceShellPatterns
}

function Test-TaskOwnershipEvidence {
  param(
    [bool]$WorkspaceMatch,
    [bool]$TaskOwnedAncestor
  )

  return $WorkspaceMatch -or $TaskOwnedAncestor
}

function Test-ExplicitAutomationOwnershipEvidence {
  param(
    [bool]$TaskOwnedAncestor,
    [bool]$ThreadOwned
  )

  return $TaskOwnedAncestor -or $ThreadOwned
}

function Get-ThreadOwnershipIndex {
  param([object[]]$ThreadOwnershipEntries)

  $index = @{}
  foreach ($entry in @($ThreadOwnershipEntries)) {
    $processId = [int]$entry.ProcessId
    if (-not $index.ContainsKey($processId)) {
      $index[$processId] = New-Object 'System.Collections.Generic.List[object]'
    }

    $null = $index[$processId].Add($entry)
  }

  return $index
}

function Test-ThreadOwnedExplicitAutomation {
  param(
    [object]$Process,
    [string]$Category,
    [hashtable]$ThreadOwnershipIndex,
    [string]$CurrentWorkspace = $null
  )

  if ($null -eq $Process -or $null -eq $ThreadOwnershipIndex) {
    return $false
  }

  $processId = [int]$Process.ProcessId
  if (-not $ThreadOwnershipIndex.ContainsKey($processId)) {
    return $false
  }

  $normalizedWorkspace = Get-NormalizedWorkspaceValue -Workspace $CurrentWorkspace
  if ([string]::IsNullOrWhiteSpace($normalizedWorkspace)) {
    return $false
  }

  foreach ($entry in $ThreadOwnershipIndex[$processId]) {
    $entryWorkspace = Get-NormalizedWorkspaceValue -Workspace ([string]$entry.Workspace)
    if (
      ([string]$entry.Category -eq $Category) -and
      ([string]$entry.Name -eq [string]$Process.Name) -and
      ([string]$entry.CommandLine -eq [string]$Process.CommandLine) -and
      (
        -not [string]::IsNullOrWhiteSpace($entryWorkspace) -and
        $entryWorkspace -eq $normalizedWorkspace
      )
    ) {
      return $true
    }
  }

  return $false
}

function New-ExplicitAutomationRecord {
  param(
    [object]$Process,
    [string]$Category,
    [bool]$TaskOwned,
    [string]$OwnedReason,
    [bool]$ThreadOwnershipSeedable = $false
  )

  if ($TaskOwned) {
    return New-ProcessRecord -Process $Process -Category $Category -Killable:$true -Reason $OwnedReason -ThreadOwnershipSeedable:$ThreadOwnershipSeedable
  }

  $reason = if ($ThreadOwnershipSeedable) {
    "Explicit automation shares the current Codex app-server lineage and is eligible for current-thread ledger seeding"
  } else {
    "Explicit automation without current-task lineage or current-thread ownership evidence"
  }

  return New-ProcessRecord -Process $Process -Category $Category -Killable:$false -Reason $reason -ThreadOwnershipSeedable:$ThreadOwnershipSeedable
}

function Classify-TemporaryProcess {
  param(
    [object]$Process,
    [hashtable]$ProcessById,
    [string]$WorkspacePattern,
    [string]$Workspace = $null,
    [hashtable]$ThreadOwnershipIndex = $null,
    [bool]$AllowCurrentThreadExplicitAutomationSeed = $false,
    [int]$CurrentCodexAppServerId = 0,
    [int]$CurrentProcessId = $PID
  )

  $name = ([string]$Process.Name).ToLowerInvariant()
  $commandLine = [string]$Process.CommandLine
  $parentName = Get-ParentProcessName -ParentProcessId ([int]$Process.ParentProcessId) -ProcessById $ProcessById
  $workspaceMatch = Test-WorkspaceMatch -CommandLine $commandLine -WorkspacePattern $WorkspacePattern
  $taskOwnedAncestor = Test-TaskOwnedAncestor -ParentProcessId ([int]$Process.ParentProcessId) -ProcessById $ProcessById -WorkspacePattern $WorkspacePattern
  $taskOwned = Test-TaskOwnershipEvidence -WorkspaceMatch $workspaceMatch -TaskOwnedAncestor $taskOwnedAncestor

  if ([int]$Process.ProcessId -eq $CurrentProcessId) {
    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:ProtectedShellNamePatterns) {
    if ($parentName -match $script:CodexParentNamePattern) {
      return New-ProcessRecord -Process $Process -Category "protected-shell" -Killable:$false -Reason "Active Codex session shell"
    }

    if ($commandLine -match "Long-lived PowerShell AST parser|ConvertFrom-Json") {
      return New-ProcessRecord -Process $Process -Category "protected-shell" -Killable:$false -Reason "Codex harness helper shell"
    }

    if ((Test-ExplicitAutomationShellCommandLine -CommandLine $commandLine) -and $commandLine -notmatch "ConvertFrom-Json") {
      $threadOwned = Test-ThreadOwnedExplicitAutomation -Process $Process -Category "tool-shell" -ThreadOwnershipIndex $ThreadOwnershipIndex -CurrentWorkspace $Workspace
      $threadOwnershipSeedable = $AllowCurrentThreadExplicitAutomationSeed -and (Test-CurrentThreadCodexAppServerExplicitAutomationAncestry -Process $Process -ProcessById $ProcessById -CurrentCodexAppServerId $CurrentCodexAppServerId)
      $explicitAutomationOwned = Test-ExplicitAutomationOwnershipEvidence -TaskOwnedAncestor $taskOwnedAncestor -ThreadOwned $threadOwned
      $ownedReason = if ($threadOwned -and -not $taskOwnedAncestor) {
        "Current-thread shell for explicit automation work"
      } else {
        "Current-task lineage for explicit automation work"
      }

      return New-ExplicitAutomationRecord -Process $Process -Category "tool-shell" -TaskOwned $explicitAutomationOwned -OwnedReason $ownedReason -ThreadOwnershipSeedable:$threadOwnershipSeedable
    }

    if (
      (Test-TemporaryShellCommandLine -CommandLine $commandLine -WorkspaceMatch $workspaceMatch -TaskOwnedAncestor $taskOwnedAncestor) -and
      $commandLine -notmatch "ConvertFrom-Json"
    ) {
      return New-ProcessRecord -Process $Process -Category "tool-shell" -Killable:$true -Reason "Task-owned shell for temporary tool work"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:CmdShellNamePatterns) {
    if (Test-ExplicitAutomationShellCommandLine -CommandLine $commandLine) {
      $threadOwned = Test-ThreadOwnedExplicitAutomation -Process $Process -Category "tool-shell" -ThreadOwnershipIndex $ThreadOwnershipIndex -CurrentWorkspace $Workspace
      $threadOwnershipSeedable = $AllowCurrentThreadExplicitAutomationSeed -and (Test-CurrentThreadCodexAppServerExplicitAutomationAncestry -Process $Process -ProcessById $ProcessById -CurrentCodexAppServerId $CurrentCodexAppServerId)
      $explicitAutomationOwned = Test-ExplicitAutomationOwnershipEvidence -TaskOwnedAncestor $taskOwnedAncestor -ThreadOwned $threadOwned
      $ownedReason = if ($threadOwned -and -not $taskOwnedAncestor) {
        "Current-thread shell for explicit automation work"
      } else {
        "Current-task lineage for explicit automation work"
      }

      return New-ExplicitAutomationRecord -Process $Process -Category "tool-shell" -TaskOwned $explicitAutomationOwned -OwnedReason $ownedReason -ThreadOwnershipSeedable:$threadOwnershipSeedable
    }

    if (Test-TemporaryShellCommandLine -CommandLine $commandLine -WorkspaceMatch $workspaceMatch -TaskOwnedAncestor $taskOwnedAncestor) {
      return New-ProcessRecord -Process $Process -Category "tool-shell" -Killable:$true -Reason "Task-owned shell for temporary tool work"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:NodeNamePatterns) {
    if ($commandLine -match "telemetry\\watchdog\\main\.js") {
      $threadOwned = Test-ThreadOwnedExplicitAutomation -Process $Process -Category "devtools-watchdog" -ThreadOwnershipIndex $ThreadOwnershipIndex -CurrentWorkspace $Workspace
      $threadOwnershipSeedable = $AllowCurrentThreadExplicitAutomationSeed -and (Test-CurrentThreadCodexAppServerExplicitAutomationAncestry -Process $Process -ProcessById $ProcessById -CurrentCodexAppServerId $CurrentCodexAppServerId)
      $explicitAutomationOwned = Test-ExplicitAutomationOwnershipEvidence -TaskOwnedAncestor $taskOwnedAncestor -ThreadOwned $threadOwned
      $ownedReason = if ($threadOwned -and -not $taskOwnedAncestor) {
        "Current-thread DevTools MCP watchdog"
      } else {
        "Current-task lineage for DevTools MCP watchdog"
      }

      return New-ExplicitAutomationRecord -Process $Process -Category "devtools-watchdog" -TaskOwned $explicitAutomationOwned -OwnedReason $ownedReason -ThreadOwnershipSeedable:$threadOwnershipSeedable
    }

    if ($commandLine -match "npx-cli\.js.*chrome-devtools-mcp@latest") {
      $threadOwned = Test-ThreadOwnedExplicitAutomation -Process $Process -Category "devtools-launcher" -ThreadOwnershipIndex $ThreadOwnershipIndex -CurrentWorkspace $Workspace
      $threadOwnershipSeedable = $AllowCurrentThreadExplicitAutomationSeed -and (Test-CurrentThreadCodexAppServerExplicitAutomationAncestry -Process $Process -ProcessById $ProcessById -CurrentCodexAppServerId $CurrentCodexAppServerId)
      $explicitAutomationOwned = Test-ExplicitAutomationOwnershipEvidence -TaskOwnedAncestor $taskOwnedAncestor -ThreadOwned $threadOwned
      $ownedReason = if ($threadOwned -and -not $taskOwnedAncestor) {
        "Current-thread DevTools MCP launcher"
      } else {
        "Current-task lineage for DevTools MCP launcher"
      }

      return New-ExplicitAutomationRecord -Process $Process -Category "devtools-launcher" -TaskOwned $explicitAutomationOwned -OwnedReason $ownedReason -ThreadOwnershipSeedable:$threadOwnershipSeedable
    }

    if ($commandLine -match "chrome-devtools-mcp") {
      $threadOwned = Test-ThreadOwnedExplicitAutomation -Process $Process -Category "devtools-mcp" -ThreadOwnershipIndex $ThreadOwnershipIndex -CurrentWorkspace $Workspace
      $threadOwnershipSeedable = $AllowCurrentThreadExplicitAutomationSeed -and (Test-CurrentThreadCodexAppServerExplicitAutomationAncestry -Process $Process -ProcessById $ProcessById -CurrentCodexAppServerId $CurrentCodexAppServerId)
      $explicitAutomationOwned = Test-ExplicitAutomationOwnershipEvidence -TaskOwnedAncestor $taskOwnedAncestor -ThreadOwned $threadOwned
      $ownedReason = if ($threadOwned -and -not $taskOwnedAncestor) {
        "Current-thread DevTools MCP service"
      } else {
        "Current-task lineage for DevTools MCP service"
      }

      return New-ExplicitAutomationRecord -Process $Process -Category "devtools-mcp" -TaskOwned $explicitAutomationOwned -OwnedReason $ownedReason -ThreadOwnershipSeedable:$threadOwnershipSeedable
    }

    if ($taskOwned -and (Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedNodePatterns)) {
      return New-ProcessRecord -Process $Process -Category "dev-tool" -Killable:$true -Reason "Current-task JavaScript dev process"
    }

    if ($commandLine -match $script:BrowserAutomationPattern) {
      $threadOwned = Test-ThreadOwnedExplicitAutomation -Process $Process -Category "browser-automation" -ThreadOwnershipIndex $ThreadOwnershipIndex -CurrentWorkspace $Workspace
      $threadOwnershipSeedable = $AllowCurrentThreadExplicitAutomationSeed -and (Test-CurrentThreadCodexAppServerExplicitAutomationAncestry -Process $Process -ProcessById $ProcessById -CurrentCodexAppServerId $CurrentCodexAppServerId)
      $explicitAutomationOwned = Test-ExplicitAutomationOwnershipEvidence -TaskOwnedAncestor $taskOwnedAncestor -ThreadOwned $threadOwned
      $ownedReason = if ($threadOwned -and -not $taskOwnedAncestor) {
        "Current-thread browser automation helper"
      } else {
        "Current-task lineage for browser automation helper"
      }

      return New-ExplicitAutomationRecord -Process $Process -Category "browser-automation" -TaskOwned $explicitAutomationOwned -OwnedReason $ownedReason -ThreadOwnershipSeedable:$threadOwnershipSeedable
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:DirectToolNamePatterns) {
    if ($taskOwned -and (Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedDirectToolPatterns)) {
      return New-ProcessRecord -Process $Process -Category "dev-tool" -Killable:$true -Reason "Current-task developer tool process"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:GenericRuntimeNamePatterns) {
    if ($taskOwned -and (Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedRuntimePatterns)) {
      return New-ProcessRecord -Process $Process -Category "dev-tool" -Killable:$true -Reason "Current-task dev or test runtime"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:BrowserNamePatterns) {
    if ($commandLine -match $script:BrowserDebugPattern) {
      $threadOwned = Test-ThreadOwnedExplicitAutomation -Process $Process -Category "browser-debug" -ThreadOwnershipIndex $ThreadOwnershipIndex -CurrentWorkspace $Workspace
      $threadOwnershipSeedable = $AllowCurrentThreadExplicitAutomationSeed -and (Test-CurrentThreadCodexAppServerExplicitAutomationAncestry -Process $Process -ProcessById $ProcessById -CurrentCodexAppServerId $CurrentCodexAppServerId)
      $explicitAutomationOwned = Test-ExplicitAutomationOwnershipEvidence -TaskOwnedAncestor $taskOwnedAncestor -ThreadOwned $threadOwned
      $ownedReason = if ($threadOwned -and -not $taskOwnedAncestor) {
        "Current-thread browser automation or remote-debug session"
      } else {
        "Current-task lineage for browser automation or remote-debug session"
      }

      return New-ExplicitAutomationRecord -Process $Process -Category "browser-debug" -TaskOwned $explicitAutomationOwned -OwnedReason $ownedReason -ThreadOwnershipSeedable:$threadOwnershipSeedable
    }

    return $null
  }

  return $null
}

function Get-TemporaryProcessClassifications {
  param(
    [object[]]$Processes,
    [string]$Workspace,
    [object[]]$ThreadOwnershipEntries = @(),
    [bool]$AllowCurrentThreadExplicitAutomationSeed = $false,
    [int]$CurrentProcessId = $PID
  )

  $processById = @{}
  foreach ($process in $Processes) {
    $processById[[int]$process.ProcessId] = $process
  }

  $workspacePattern = Get-WorkspacePattern -Workspace $Workspace
  $threadOwnershipIndex = Get-ThreadOwnershipIndex -ThreadOwnershipEntries $ThreadOwnershipEntries
  $currentCodexAppServerId = Get-CodexAppServerAncestorId -ProcessId $CurrentProcessId -ProcessById $processById
  $allowCurrentThreadExplicitAutomationSeedWithWorkspace = (
    $AllowCurrentThreadExplicitAutomationSeed -and
    -not [string]::IsNullOrWhiteSpace((Get-NormalizedWorkspaceValue -Workspace $Workspace))
  )

  $classified = foreach ($process in $Processes) {
    $record = Classify-TemporaryProcess -Process $process -ProcessById $processById -WorkspacePattern $workspacePattern -Workspace $Workspace -ThreadOwnershipIndex $threadOwnershipIndex -AllowCurrentThreadExplicitAutomationSeed:$allowCurrentThreadExplicitAutomationSeedWithWorkspace -CurrentCodexAppServerId $currentCodexAppServerId -CurrentProcessId $CurrentProcessId
    if ($null -ne $record) {
      $record
    }
  }

  return @($classified | Sort-Object Category, Name, ProcessId)
}
