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

  It 'does not classify an interactive bash shell without task markers' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 97
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 0
  }

  It 'classifies unowned DevTools MCP node processes as inspect-only candidates' {
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
    $result[0].Killable | Should Be $false
  }

  It 'classifies task-owned DevTools MCP node processes as killable' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 149
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
      [pscustomobject]@{
        ProcessId = 150
        ParentProcessId = 149
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo' | Where-Object { $_.ProcessId -eq 150 })

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'devtools-mcp'
    $result[0].Killable | Should Be $true
  }

  It 'classifies thread-owned DevTools MCP node processes as killable without fresh workspace evidence' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 158
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
      }
    )
    $threadOwnershipEntries = @(
      [pscustomobject]@{
        ProcessId = 158
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
        Category = 'devtools-mcp'
        Workspace = 'C:\Repo'
        ObservedAtUtc = '2026-04-15T14:00:00Z'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -ThreadOwnershipEntries $threadOwnershipEntries)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'devtools-mcp'
    $result[0].Killable | Should Be $true
  }

  It 'classifies unowned DevTools MCP watchdog processes as inspect-only candidates' {
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
    $result[0].Killable | Should Be $false
  }

  It 'classifies task-owned DevTools MCP watchdog processes as killable' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 151
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
      [pscustomobject]@{
        ProcessId = 152
        ParentProcessId = 151
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
      }
      [pscustomobject]@{
        ProcessId = 153
        ParentProcessId = 152
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\telemetry\watchdog\main.js --parent-pid=152'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo' | Where-Object { $_.ProcessId -eq 153 })

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'devtools-watchdog'
    $result[0].Killable | Should Be $true
  }

  It 'classifies unowned DevTools MCP npx launchers as inspect-only candidates' {
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
    $result[0].Killable | Should Be $false
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

  It 'classifies workspace-scoped pnpm install shells as temporary tool shells' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 160
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm install --dir C:\Repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'tool-shell'
    $result[0].Killable | Should Be $true
  }

  It 'classifies task-owned DevTools MCP npx launchers as killable' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 154
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
      [pscustomobject]@{
        ProcessId = 155
        ParentProcessId = 154
        Name = 'node.exe'
        CommandLine = '"C:\Program Files\nodejs\node.exe" "C:\Program Files\nodejs\node_modules\npm\bin\npx-cli.js" -y chrome-devtools-mcp@latest'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo' | Where-Object { $_.ProcessId -eq 155 })

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'devtools-launcher'
    $result[0].Killable | Should Be $true
  }

  It 'classifies unowned DevTools MCP launcher shells as inspect-only candidates' {
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
    $result[0].Killable | Should Be $false
  }

  It 'classifies task-owned DevTools MCP launcher shells as killable' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 156
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
      [pscustomobject]@{
        ProcessId = 157
        ParentProcessId = 156
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /d /s /c npx -y chrome-devtools-mcp@latest'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo' | Where-Object { $_.ProcessId -eq 157 })

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

  It 'does not let thread ownership make a generic runtime killable' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 159
        ParentProcessId = 1
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload'
      }
    )
    $threadOwnershipEntries = @(
      [pscustomobject]@{
        ProcessId = 159
        Name = 'python.exe'
        CommandLine = 'python -m uvicorn app.main:app --reload'
        Category = 'dev-tool'
        Workspace = 'C:\Repo'
        ObservedAtUtc = '2026-04-15T14:05:00Z'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -ThreadOwnershipEntries $threadOwnershipEntries)

    $result.Count | Should Be 0
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

  It 'does not classify vite node processes without workspace evidence' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 143
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node /repo/node_modules/vite/bin/vite.js'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 0
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

  It 'classifies workspace-scoped python3 uvicorn processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 111
        ParentProcessId = 1
        Name = 'python3'
        CommandLine = 'python3 -m uvicorn app.main:app --reload --app-dir /repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

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

  It 'classifies workspace-scoped java dev processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 112
        ParentProcessId = 1
        Name = 'java'
        CommandLine = 'java -jar /repo/build/libs/app.jar --spring.profiles.active=dev'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped bash pytest shells as temporary tool shells' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 113
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "pytest tests/api --rootdir /repo"'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'tool-shell'
    $result[0].Killable | Should Be $true
  }

  It 'does not classify pytest shells without workspace ownership' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 118
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "pytest tests/api"'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 0
  }

  It 'classifies relative pnpm direct processes through a workspace-owned parent shell' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 129
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "cd /repo && pnpm dev"'
      }
      [pscustomobject]@{
        ProcessId = 130
        ParentProcessId = 129
        Name = 'pnpm'
        CommandLine = 'pnpm dev'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')
    $child = @($result | Where-Object { $_.ProcessId -eq 130 })

    $result.Count | Should Be 2
    $child.Count | Should Be 1
    $child[0].Category | Should Be 'dev-tool'
    $child[0].Killable | Should Be $true
  }

  It 'classifies relative direct tools through a workspace-backed Codex shell' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 145
        ParentProcessId = 1
        Name = 'Codex'
        CommandLine = 'Codex.exe'
      }
      [pscustomobject]@{
        ProcessId = 146
        ParentProcessId = 145
        Name = 'powershell.exe'
        CommandLine = 'powershell.exe -NoProfile -Command "Set-Location C:\Repo; pnpm test"'
      }
      [pscustomobject]@{
        ProcessId = 147
        ParentProcessId = 146
        Name = 'pnpm'
        CommandLine = 'pnpm test'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')
    $shell = @($result | Where-Object { $_.ProcessId -eq 146 })
    $child = @($result | Where-Object { $_.ProcessId -eq 147 })

    $shell.Count | Should Be 1
    $shell[0].Category | Should Be 'protected-shell'
    $child.Count | Should Be 1
    $child[0].Category | Should Be 'dev-tool'
    $child[0].Killable | Should Be $true
  }

  It 'classifies relative python runtimes through a workspace-owned parent shell' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 131
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "cd /repo && python -m pytest tests/api"'
      }
      [pscustomobject]@{
        ProcessId = 132
        ParentProcessId = 131
        Name = 'python'
        CommandLine = 'python -m pytest tests/api'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')
    $child = @($result | Where-Object { $_.ProcessId -eq 132 })

    $result.Count | Should Be 2
    $child.Count | Should Be 1
    $child[0].Category | Should Be 'dev-tool'
    $child[0].Killable | Should Be $true
  }

  It 'classifies node launcher descendants through ancestor task ownership' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 133
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
      [pscustomobject]@{
        ProcessId = 134
        ParentProcessId = 133
        Name = 'powershell.exe'
        CommandLine = 'powershell.exe -NoProfile -Command pnpm test'
      }
      [pscustomobject]@{
        ProcessId = 135
        ParentProcessId = 134
        Name = 'node.exe'
        CommandLine = '"C:\Program Files\nodejs\node.exe" "C:\Users\Admin\AppData\Local\pnpm\pnpm.cjs" test'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')
    $descendantShell = @($result | Where-Object { $_.ProcessId -eq 134 })
    $nodeChild = @($result | Where-Object { $_.ProcessId -eq 135 })

    $result.Count | Should Be 3
    $descendantShell.Count | Should Be 1
    $nodeChild.Count | Should Be 1
    $descendantShell[0].Category | Should Be 'tool-shell'
    $nodeChild[0].Category | Should Be 'dev-tool'
    $nodeChild[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped bash tsx watch shells as temporary tool shells' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 115
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "tsx watch src/server.ts --cwd /repo"'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'tool-shell'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped php artisan serve processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 114
        ParentProcessId = 1
        Name = 'php'
        CommandLine = 'php /repo/artisan serve --host=127.0.0.1'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped tsx node processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 116
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node /repo/node_modules/tsx/dist/cli.mjs watch src/server.ts'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped nodemon node processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 117
        ParentProcessId = 1
        Name = 'node'
        CommandLine = 'node /repo/node_modules/nodemon/bin/nodemon.js src/server.ts --watch src'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'does not treat sibling workspace paths as a workspace match' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 119
        ParentProcessId = 1
        Name = 'pnpm'
        CommandLine = 'pnpm dev --dir C:\Repo2'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 0
  }

  It 'classifies workspace-scoped pnpm direct processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 120
        ParentProcessId = 1
        Name = 'pnpm'
        CommandLine = 'pnpm dev --dir /repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'does not classify direct framework commands without dev or test markers' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 121
        ParentProcessId = 1
        Name = 'next'
        CommandLine = 'next telemetry disable --dir /repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 0
  }

  It 'does not classify shell-wrapped framework commands without lifecycle markers' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 144
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "cd /repo && next telemetry disable"'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 0
  }

  It 'does not classify shell wrappers that only mention vitest as an argument' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 148
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "cd /repo && grep vitest package.json"'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 0
  }

  It 'classifies workspace-scoped cargo direct processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 122
        ParentProcessId = 1
        Name = 'cargo'
        CommandLine = 'cargo test --manifest-path /repo/Cargo.toml'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped uvicorn direct processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 123
        ParentProcessId = 1
        Name = 'uvicorn'
        CommandLine = 'uvicorn app.main:app --reload --app-dir /repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped gradle direct processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 124
        ParentProcessId = 1
        Name = 'gradle'
        CommandLine = 'gradle test --project-dir /repo'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'classifies workspace-scoped tauri direct processes as temporary dev tools' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 125
        ParentProcessId = 1
        Name = 'tauri'
        CommandLine = 'tauri dev --config /repo/src-tauri/tauri.conf.json'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'dev-tool'
    $result[0].Killable | Should Be $true
  }

  It 'does not classify a browser just because a devtools page is open' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 126
        ParentProcessId = 1
        Name = 'chrome'
        CommandLine = '"C:\Program Files\Google\Chrome\Application\chrome.exe" devtools://devtools/bundled/inspector.html'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 0
  }

  It 'classifies unowned Google Chrome app bundle remote-debug processes as inspect-only candidates' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 127
        ParentProcessId = 1
        Name = 'Google Chrome'
        CommandLine = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-profile'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'browser-debug'
    $result[0].Killable | Should Be $false
  }

  It 'classifies workspace-scoped Google Chrome app bundle remote-debug processes as killable browser-debug sessions' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 129
        ParentProcessId = 1
        Name = 'Google Chrome'
        CommandLine = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-port=9222 --user-data-dir=/repo/tmp/chrome-profile'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'browser-debug'
    $result[0].Killable | Should Be $true
  }

  It 'classifies unowned google-chrome-stable remote-debug processes as inspect-only candidates' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 128
        ParentProcessId = 1
        Name = 'google-chrome-stable'
        CommandLine = '/usr/bin/google-chrome-stable --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-profile'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes)

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'browser-debug'
    $result[0].Killable | Should Be $false
  }

  It 'classifies workspace-scoped google-chrome-stable remote-debug processes as killable browser-debug sessions' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 130
        ParentProcessId = 1
        Name = 'google-chrome-stable'
        CommandLine = '/usr/bin/google-chrome-stable --remote-debugging-port=9222 --user-data-dir=/repo/tmp/chrome-profile'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'browser-debug'
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

  It 'classifies unowned remote-debug browser processes as inspect-only candidates' {
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
    $result[0].Killable | Should Be $false
  }

  It 'classifies workspace-scoped remote-debug browser processes as killable browser-debug sessions' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 131
        ParentProcessId = 1
        Name = 'msedge.exe'
        CommandLine = '"C:\Program Files\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222 --user-data-dir=C:\Repo\.tmp\edge-profile'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].Category | Should Be 'browser-debug'
    $result[0].Killable | Should Be $true
  }

  It 'does not classify relative dev commands without a workspace-owned ancestor' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 136
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "pnpm dev"'
      }
      [pscustomobject]@{
        ProcessId = 137
        ParentProcessId = 136
        Name = 'pnpm'
        CommandLine = 'pnpm dev'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 0
  }

  It 'does not classify child dev tools from the active Codex shell lineage alone' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 138
        ParentProcessId = 1
        Name = 'Codex'
        CommandLine = 'Codex.exe'
      }
      [pscustomobject]@{
        ProcessId = 139
        ParentProcessId = 138
        Name = 'powershell.exe'
        CommandLine = 'powershell.exe -NoProfile'
      }
      [pscustomobject]@{
        ProcessId = 140
        ParentProcessId = 139
        Name = 'pnpm'
        CommandLine = 'pnpm dev'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')

    $result.Count | Should Be 1
    $result[0].ProcessId | Should Be 139
    $result[0].Category | Should Be 'protected-shell'
  }

  It 'does not classify unrelated node children just because an ancestor is task-owned' {
    . $libraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 141
        ParentProcessId = 1
        Name = 'bash'
        CommandLine = '/bin/bash -lc "cd /repo && pnpm dev"'
      }
      [pscustomobject]@{
        ProcessId = 142
        ParentProcessId = 141
        Name = 'node'
        CommandLine = 'node /tmp/custom-script.js'
      }
    )

    $result = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')

    $result.Count | Should Be 1
    $result[0].ProcessId | Should Be 141
    $result[0].Category | Should Be 'tool-shell'
  }
}
