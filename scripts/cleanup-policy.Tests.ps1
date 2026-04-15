$classificationLibraryPath = Join-Path $PSScriptRoot 'process-classification.ps1'
$policyLibraryPath = Join-Path $PSScriptRoot 'cleanup-policy.ps1'

Describe 'Get-CleanupDecision' {
  It 'keeps unowned DevTools MCP services as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 201
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes)[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
  }

  It 'marks task-owned DevTools MCP services for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 250
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
      [pscustomobject]@{
        ProcessId = 251
        ParentProcessId = 250
        Name = 'node.exe'
        CommandLine = 'node C:\Temp\npm-cache\_npx\pkg\chrome-devtools-mcp\build\src\bin\chrome-devtools-mcp.js'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo' | Where-Object { $_.ProcessId -eq 251 })[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
  }

  It 'keeps dev servers as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 202
        ParentProcessId = 1
        Name = 'node.exe'
        CommandLine = 'node C:\Repo\node_modules\next\dist\bin\next dev'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
  }

  It 'marks one-shot test shells for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 203
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
  }

  It 'marks pnpm install shells for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 255
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm install --dir C:\Repo'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
    $decision.Reason | Should Be 'One-shot build or test command finished for this step'
  }

  It 'keeps unowned DevTools MCP launcher shells as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 206
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /d /s /c npx -y chrome-devtools-mcp@latest'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes)[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
  }

  It 'marks task-owned DevTools MCP launcher shells for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 252
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c pnpm test --dir C:\Repo'
      }
      [pscustomobject]@{
        ProcessId = 253
        ParentProcessId = 252
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /d /s /c npx -y chrome-devtools-mcp@latest'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo' | Where-Object { $_.ProcessId -eq 253 })[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
  }

  It 'keeps cargo tauri dev shells as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 207
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c cargo tauri dev --manifest-path C:\Repo\src-tauri\Cargo.toml'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
  }

  It 'marks direct cargo test processes for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 208
        ParentProcessId = 1
        Name = 'cargo'
        CommandLine = 'cargo test --manifest-path /repo/Cargo.toml'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
  }

  It 'keeps direct pnpm dev processes as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 209
        ParentProcessId = 1
        Name = 'pnpm'
        CommandLine = 'pnpm dev --dir /repo'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
  }

  It 'marks pytest runtimes for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 210
        ParentProcessId = 1
        Name = 'python'
        CommandLine = 'python -m pytest /repo/tests -q'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
    $decision.Reason | Should Be 'One-shot build or test command finished for this step'
  }

  It 'keeps pytest-watch runtimes as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 211
        ParentProcessId = 1
        Name = 'python'
        CommandLine = 'python -m pytest-watch /repo/tests'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
    $decision.Reason | Should Be 'Potentially reusable long-lived dev process'
  }

  It 'marks vitest run processes for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 212
        ParentProcessId = 1
        Name = 'vitest'
        CommandLine = 'vitest run --config /repo/vitest.config.ts'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
    $decision.Reason | Should Be 'One-shot build or test command finished for this step'
  }

  It 'keeps npm storybook shells as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 213
        ParentProcessId = 1
        Name = 'cmd.exe'
        CommandLine = 'cmd.exe /c npm run storybook -- --config-dir C:\Repo\.storybook'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
    $decision.Reason | Should Be 'Potentially reusable long-lived dev process'
  }

  It 'marks cargo clippy processes for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 214
        ParentProcessId = 1
        Name = 'cargo'
        CommandLine = 'cargo clippy --manifest-path /repo/Cargo.toml --all-targets'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
    $decision.Reason | Should Be 'One-shot build or test command finished for this step'
  }

  It 'keeps Spring Boot run processes as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 215
        ParentProcessId = 1
        Name = 'mvn'
        CommandLine = 'mvn spring-boot:run -f /repo/pom.xml'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
    $decision.Reason | Should Be 'Potentially reusable long-lived dev process'
  }

  It 'marks Maven verify processes for cleanup during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 216
        ParentProcessId = 1
        Name = 'mvn'
        CommandLine = 'mvn verify -f /repo/pom.xml'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'cleanup-now'
    $decision.Reason | Should Be 'One-shot build or test command finished for this step'
  }

  It 'keeps uvicorn runtimes as inspect-only during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 217
        ParentProcessId = 1
        Name = 'uvicorn'
        CommandLine = 'uvicorn app.main:app --reload --app-dir /repo'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace '/repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'inspect-only'
    $decision.Reason | Should Be 'Potentially reusable long-lived dev process'
  }

  It 'preserves protected shells during checkpoint cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 204
        ParentProcessId = 999
        Name = 'powershell.exe'
        CommandLine = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
      },
      [pscustomobject]@{
        ProcessId = 999
        ParentProcessId = 1
        Name = 'Codex.exe'
        CommandLine = 'Codex.exe'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes)[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'checkpoint-cleanup'

    $decision.Decision | Should Be 'preserve'
  }

  It 'keeps unowned browser-debug processes as inspect-only during full cleanup' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 205
        ParentProcessId = 1
        Name = 'msedge.exe'
        CommandLine = '"C:\Program Files\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222 --user-data-dir=C:\Temp\edge-profile'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes)[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'cleanup'

    $decision.Decision | Should Be 'inspect-only'
  }

  It 'treats full cleanup mode as cleanup-now for any task-owned killable record' {
    . $classificationLibraryPath
    . $policyLibraryPath

    $processes = @(
      [pscustomobject]@{
        ProcessId = 254
        ParentProcessId = 1
        Name = 'msedge.exe'
        CommandLine = '"C:\Program Files\Microsoft\Edge\Application\msedge.exe" --remote-debugging-port=9222 --user-data-dir=C:\Repo\.tmp\edge-profile'
      }
    )

    $record = @(Get-TemporaryProcessClassifications -Processes $processes -Workspace 'C:\Repo')[0]
    $decision = Get-CleanupDecision -Record $record -Mode 'cleanup'

    $decision.Decision | Should Be 'cleanup-now'
  }
}
