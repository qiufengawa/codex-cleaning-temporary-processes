$libraryPath = Join-Path $PSScriptRoot 'process-classification.ps1'

Describe 'Get-TemporaryProcessClassifications' {
  It 'does not classify a normal browser without automation flags' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 99
        ParentProcessId = 1
        Name = 'chrome.exe'
        CommandLine = '"C:\Program Files\Google\Chrome\Application\chrome.exe" --profile-directory=Default'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 0
  }

  It 'does not classify an interactive PowerShell shell without task markers' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 98
        ParentProcessId = 1
        Name = 'powershell.exe'
        CommandLine = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 0
  }

  It 'classifies DevTools MCP node processes without needing a workspace match' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 100
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'devtools-mcp'
    $result[0].Killable | Should Be $true
  }

  It 'classifies DevTools MCP watchdog processes with a specific watchdog category' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 107
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\telemetry\watchdog\main.js --parent-pid=1234'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'devtools-watchdog'
    $result[0].Killable | Should Be $true
  }

  It 'classifies DevTools MCP npx launchers with a specific launcher category' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 108
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = '"C:\Program Files\nodejs\node.exe" "C:\Program Files\nodejs\node_modules\npm\bin\npx-cli.js" -y chrome-devtools-mcp@latest'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'devtools-launcher'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped pnpm dev shells as temporary tool shells' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 101
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm dev --dir C:\Repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'tool-shell'
    $result[0].Killable | Should Be $true
  }

  It 'classifies DevTools MCP launcher shells without needing a workspace match' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 109
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /d /s /c npx -y chrome-devtools-mcp@latest'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'tool-shell'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped cargo tauri dev shells as temporary tool shells' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 110
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c cargo tauri dev --manifest-path C:\Repo\src-tauri\Cargo.toml'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'tool-shell'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped next dev node processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 102
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Repo\node_modules\next\dist\bin\next dev'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped uvicorn python processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 103
        ParentProcessId = 1
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload --app-dir C:\Repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped dotnet watch processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 104
        ParentProcessId = 1
        Name = 'dotnet.exe'
        CommandLine = 'dotnet watch run --project C:\Repo\WebApp.csproj'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'preserves generic runtime processes when the workspace does not match' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 105
        ParentProcessId = 1
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload --app-dir C:\OtherRepo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 0
  }

  It 'classifies remote-debug browser processes as killable browser-debug sessions' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 106
        ParentProcessId = 1
        Name = 'msedge.exe'
        CommandLine = '"C:\Program Files\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222 --user-data-dir=C:\Temp\edge-profile'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'browser-debug'
    $result[0].Killable | Should Be $true
  }
}
