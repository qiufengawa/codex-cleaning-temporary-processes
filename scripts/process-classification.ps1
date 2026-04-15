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
  "^(cargo|tauri)(\.exe)?$",
  "^(pytest|uvicorn|gunicorn|flask|django-admin)(\.exe)?$",
  "^(gradle(w)?(\.bat)?|mvn(\.cmd)?)$",
  "^(air|reflex)(\.exe)?$",
  "^(bundle(\.bat)?|rails(\.exe)?|rspec(\.exe)?)$",
  "^(composer(\.bat)?|artisan)$",
  "^(mix|iex|rebar3)$",
  "^(cmake|ctest|meson|ninja|make)$"
)

$script:BrowserAutomationPattern = "playwright|remote-debugging-port|--headless"
$script:BrowserDebugPattern = "--remote-debugging-port|--headless|playwright"
$script:CodexParentNamePattern = "^Codex(\.exe)?$"

$script:HighConfidenceShellPatterns = @(
  "\bplaywright\b",
  "chrome-devtools-mcp",
  "remote-debugging-port"
)

$script:WorkspaceScopedShellPatterns = @(
  "\b(npm|npx|pnpm|pnpx|yarn|bun|bunx)(\.cmd|\.exe)?\b.*\b(run|exec|dev|build|preview|test|start|serve|watch)\b",
  "\b(next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit)\b",
  "\b(tsx|ts-node|ts-node-dev|nodemon|vite-node)\b.*\b(watch|dev|start|serve|run)\b",
  "\bcargo(\.exe)?\b.*\b(test|run|check|build|tauri|clippy)\b",
  "\b(py(thon)?|uv|uvx|poetry|pipenv)(\.exe)?\b.*\b(pytest|uvicorn|gunicorn|flask|django|runserver|serve|watch|test|dev)\b",
  "\b(pytest|uvicorn|gunicorn)\b",
  "\bflask(\.exe)?\b.*\brun\b",
  "\bdjango-admin(\.exe)?\b.*\brunserver\b",
  "manage\.py\b.*\b(runserver|test)\b",
  "\b(gradle(w)?(\.bat)?|mvn(\.cmd)?|java(\.exe)?)\b.*\b(test|bootrun|spring-boot:run|quarkus:dev|dev|run|serve)\b",
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

$script:HighConfidenceNodePatterns = @(
  "\b(vite|vitest)\b",
  "node_modules[/\\](vite|vitest)[/\\]"
)

$script:WorkspaceScopedNodePatterns = @(
  "\bnpm(\.cmd)?\b.*\b(run|exec)\b.*\b(dev|build|preview|test)\b",
  "\b(pnpm|pnpx|yarn|bun|bunx)(\.cmd|\.exe)?\b.*\b(dev|build|preview|test|start|serve|watch)\b",
  "\b(next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit)\b",
  "\b(tsx|ts-node|ts-node-dev|nodemon|vite-node)\b.*\b(watch|dev|start|serve|run)\b",
  "node_modules[/\\](next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit|tsx|ts-node|ts-node-dev|nodemon|vite-node)[/\\]"
)

$script:WorkspaceScopedRuntimePatterns = @(
  "\b(py(thon)?|uv|uvx|poetry|pipenv)(\.exe)?\b.*\b(pytest|uvicorn|gunicorn|flask|django|runserver|serve|watch|test|dev)\b",
  "\b(pytest|uvicorn|gunicorn)\b",
  "\bflask(\.exe)?\b.*\brun\b",
  "\bdjango-admin(\.exe)?\b.*\brunserver\b",
  "manage\.py\b.*\b(runserver|test)\b",
  "\bdotnet(\.exe)?\b.*\b(watch|run|test|build|publish)\b",
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
  "\bnpm(\.cmd)?\b.*\b(run|exec|dev|build|preview|test|start|serve|watch)\b",
  "\b(npx|pnpm|pnpx|yarn|bun|bunx)(\.cmd|\.exe)?\b.*\b(run|exec|dev|build|preview|test|start|serve|watch)\b",
  "\b(vite|vitest)\b(?:\s|$)",
  "\b(next|nuxt|astro|webpack|rollup|parcel|storybook|cypress|jest|turbo|nx|nest|remix|svelte-kit)\b.*\b(dev|build|preview|test|start|serve|watch|run|open)\b",
  "\b(tsx|ts-node|ts-node-dev|nodemon|vite-node)\b.*\b(watch|dev|start|serve|run)\b",
  "\bcargo(\.exe)?\b.*\b(test|run|check|build|tauri|clippy)\b",
  "\btauri(\.exe)?\b.*\b(dev|build|android|ios)\b",
  "\b(pytest|uvicorn|gunicorn)\b",
  "\bflask(\.exe)?\b.*\brun\b",
  "\bdjango-admin(\.exe)?\b.*\brunserver\b",
  "manage\.py\b.*\b(runserver|test)\b",
  "\b(gradle(w)?(\.bat)?|mvn(\.cmd)?)\b.*\b(test|build|bootrun|spring-boot:run|quarkus:dev|dev|run|serve|package|install|verify)\b",
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
    [string]$Reason
  )

  [pscustomobject]@{
    ProcessId       = [int]$Process.ProcessId
    ParentProcessId = [int]$Process.ParentProcessId
    Name            = [string]$Process.Name
    Category        = $Category
    Killable        = $Killable
    Reason          = $Reason
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

  return '(?i)(?<![A-Za-z0-9_.-])' + $pathPattern + '(?=$|[\\/''"\s])'
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

function Test-TemporaryShellCommandLine {
  param(
    [string]$CommandLine,
    [bool]$WorkspaceMatch
  )

  if ([string]::IsNullOrWhiteSpace($CommandLine)) {
    return $false
  }

  if ($CommandLine -match "chrome-devtools-mcp|remote-debugging-port") {
    return $true
  }

  if (Test-PatternList -Value $CommandLine -Patterns $script:HighConfidenceShellPatterns) {
    return $true
  }

  return $WorkspaceMatch -and (Test-PatternList -Value $CommandLine -Patterns $script:WorkspaceScopedShellPatterns)
}

function Classify-TemporaryProcess {
  param(
    [object]$Process,
    [hashtable]$ProcessById,
    [string]$WorkspacePattern,
    [int]$CurrentProcessId = $PID
  )

  $name = ([string]$Process.Name).ToLowerInvariant()
  $commandLine = [string]$Process.CommandLine
  $parentName = Get-ParentProcessName -ParentProcessId ([int]$Process.ParentProcessId) -ProcessById $ProcessById
  $workspaceMatch = Test-WorkspaceMatch -CommandLine $commandLine -WorkspacePattern $WorkspacePattern

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

    if (
      (Test-TemporaryShellCommandLine -CommandLine $commandLine -WorkspaceMatch $workspaceMatch) -and
      $commandLine -notmatch "ConvertFrom-Json"
    ) {
      return New-ProcessRecord -Process $Process -Category "tool-shell" -Killable:$true -Reason "Task-owned shell for temporary tool work"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:CmdShellNamePatterns) {
    if (Test-TemporaryShellCommandLine -CommandLine $commandLine -WorkspaceMatch $workspaceMatch) {
      return New-ProcessRecord -Process $Process -Category "tool-shell" -Killable:$true -Reason "Task-owned shell for temporary tool work"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:NodeNamePatterns) {
    if ($commandLine -match "telemetry\\watchdog\\main\.js") {
      return New-ProcessRecord -Process $Process -Category "devtools-watchdog" -Killable:$true -Reason "DevTools MCP watchdog"
    }

    if ($commandLine -match "npx-cli\.js.*chrome-devtools-mcp@latest") {
      return New-ProcessRecord -Process $Process -Category "devtools-launcher" -Killable:$true -Reason "DevTools MCP launcher"
    }

    if ($commandLine -match "chrome-devtools-mcp") {
      return New-ProcessRecord -Process $Process -Category "devtools-mcp" -Killable:$true -Reason "DevTools MCP service"
    }

    if (Test-PatternList -Value $commandLine -Patterns $script:HighConfidenceNodePatterns) {
      return New-ProcessRecord -Process $Process -Category "dev-tool" -Killable:$true -Reason "Temporary frontend dev or test process"
    }

    if ($workspaceMatch -and (Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedNodePatterns)) {
      return New-ProcessRecord -Process $Process -Category "dev-tool" -Killable:$true -Reason "Workspace-owned JavaScript dev process"
    }

    if ($commandLine -match $script:BrowserAutomationPattern) {
      return New-ProcessRecord -Process $Process -Category "browser-automation" -Killable:$true -Reason "Browser automation helper"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:DirectToolNamePatterns) {
    if ($workspaceMatch -and (Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedDirectToolPatterns)) {
      return New-ProcessRecord -Process $Process -Category "dev-tool" -Killable:$true -Reason "Workspace-owned developer tool process"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:GenericRuntimeNamePatterns) {
    if ($workspaceMatch -and (Test-PatternList -Value $commandLine -Patterns $script:WorkspaceScopedRuntimePatterns)) {
      return New-ProcessRecord -Process $Process -Category "dev-tool" -Killable:$true -Reason "Workspace-owned dev or test runtime"
    }

    return $null
  }

  if (Test-NamePatternList -Value $name -Patterns $script:BrowserNamePatterns) {
    if ($commandLine -match $script:BrowserDebugPattern) {
      return New-ProcessRecord -Process $Process -Category "browser-debug" -Killable:$true -Reason "Browser automation or remote-debug session"
    }

    return $null
  }

  return $null
}

function Get-TemporaryProcessClassifications {
  param(
    [object[]]$Processes,
    [string]$Workspace,
    [int]$CurrentProcessId = $PID
  )

  $processById = @{}
  foreach ($process in $Processes) {
    $processById[[int]$process.ProcessId] = $process
  }

  $workspacePattern = Get-WorkspacePattern -Workspace $Workspace

  $classified = foreach ($process in $Processes) {
    $record = Classify-TemporaryProcess -Process $process -ProcessById $processById -WorkspacePattern $workspacePattern -CurrentProcessId $CurrentProcessId
    if ($null -ne $record) {
      $record
    }
  }

  return @($classified | Sort-Object Category, Name, ProcessId)
}
