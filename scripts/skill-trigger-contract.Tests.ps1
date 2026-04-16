$repoRoot = Split-Path $PSScriptRoot -Parent

Describe 'public skill trigger contract' {
  BeforeAll {
    $skillMarkdown = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'SKILL.md')
    $metadataYaml = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'agents\openai.yaml')
    $readmeEnglish = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'README.md')
    $readmeChinese = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'README.zh-CN.md')
    $projectIntroEnglish = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'docs\project-introduction.md')
    $projectIntroChinese = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'docs\project-introduction.zh-CN.md')
    $triggerScenariosEnglish = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'docs\trigger-regression-scenarios.md')
    $triggerScenariosChinese = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'docs\trigger-regression-scenarios.zh-CN.md')
    $triggerFixturesPath = Join-Path $repoRoot 'scripts\trigger-fixtures'

    $bestEffortZh = -join [char[]](0x6700, 0x4F73, 0x52AA, 0x529B)
    $implicitZh = -join [char[]](0x9690, 0x5F0F)
    $checkpointZh = -join [char[]](0x68C0, 0x67E5, 0x70B9)
    $multiProjectIsolationZh = -join [char[]](0x591A, 0x9879, 0x76EE, 0x9694, 0x79BB)
    $pluginStyleZh = -join [char[]](0x63D2, 0x4EF6, 0x5F0F)
    $crossPlatformZh = -join [char[]](0x8DE8, 0x5E73, 0x53F0)
    $subagentZh = -join [char[]](0x5B50, 0x4EE3, 0x7406)
  }

  It 'positions the package as a pure skill instead of a plugin-plus-skill bundle' {
    $skillMarkdown | Should Match '(?m)^description: Use when'
    $skillMarkdown | Should Match 'best-effort'
    $skillMarkdown | Should Match 'implicit'
    $skillMarkdown | Should Match 'checkpoint'
    $skillMarkdown | Should Match 'multi-project'
    $skillMarkdown | Should Match 'must reconsider now'
    $skillMarkdown | Should Match 'should reconsider soon'
    $skillMarkdown | Should Match 'do not reconsider from this checkpoint alone'
    $skillMarkdown | Should Match 'failed one-shot high-risk'
    $skillMarkdown | Should Not Match 'plugin-style'
    $skillMarkdown | Should Not Match '\.codex-plugin/plugin\.json'
    $skillMarkdown | Should Not Match 'hooks\.json'
    $skillMarkdown | Should Not Match 'hooks/'
  }

  It 'keeps implicit invocation enabled without promising host-hook automation' {
    $metadataYaml | Should Match 'allow_implicit_invocation:\s*true'
    $metadataYaml | Should Match 'checkpoint'
    $metadataYaml | Should Match 'best-effort'
    $metadataYaml | Should Match 'implicit'
    $metadataYaml | Should Match 'multi-project'
    $metadataYaml | Should Match 'must reconsider cleanup now'
    $metadataYaml | Should Match 'failed one-shot'
    $metadataYaml | Should Match 'session-end alone'
    $metadataYaml | Should Not Match 'plugin-style'
    $metadataYaml | Should Not Match '\.codex-plugin/plugin\.json'
    $metadataYaml | Should Not Match 'hooks'
    $metadataYaml | Should Not Match 'session end'
    $metadataYaml | Should Not Match 'always-on'
    $metadataYaml | Should Not Match 'background callback'
  }

  It 'documents a pure skill installation path in the English docs' {
    $readmeEnglish | Should Match '## Installation'
    $readmeEnglish | Should Match '## Trigger Cadence'
    $readmeEnglish | Should Match '## Safety Model'
    $readmeEnglish | Should Match '## Multi-Project Isolation'
    $readmeEnglish | Should Match 'best-effort'
    $readmeEnglish | Should Match 'implicit invocation'
    $readmeEnglish | Should Match 'CODEX_HOME/skills'
    $readmeEnglish | Should Match 'checkpoint-cleanup'
    $readmeEnglish | Should Match 'npm'
    $readmeEnglish | Should Match 'vite'
    $readmeEnglish | Should Match 'vitest'
    $readmeEnglish | Should Match 'cargo'
    $readmeEnglish | Should Match 'tauri'
    $readmeEnglish | Should Match 'trunk'
    $readmeEnglish | Should Match 'hatch'
    $readmeEnglish | Should Match 'jupyter'
    $readmeEnglish | Should Match 'streamlit'
    $readmeEnglish | Should Match 'kotlin'
    $readmeEnglish | Should Match 'scala'
    $readmeEnglish | Should Match 'clj'
    $readmeEnglish | Should Match 'cabal'
    $readmeEnglish | Should Match 'dune'
    $readmeEnglish | Should Match 'Rscript'
    $readmeEnglish | Should Match 'zig'
    $readmeEnglish | Should Match 'julia'
    $readmeEnglish | Should Match 'tox'
    $readmeEnglish | Should Match 'xcodebuild'
    $readmeEnglish | Should Match 'bazel'
    $readmeEnglish | Should Match 'must reconsider now'
    $readmeEnglish | Should Match 'should reconsider soon'
    $readmeEnglish | Should Match 'do not reconsider from this checkpoint alone'
    $readmeEnglish | Should Match 'failed one-shot high-risk'
    $readmeEnglish | Should Match 'not stronger kill authority'
    $readmeEnglish | Should Match 'long-lived'
    $readmeEnglish | Should Match 'session-end alone'
    $readmeEnglish | Should Not Match 'plugin-style'
    $readmeEnglish | Should Not Match '\.codex-plugin/plugin\.json'
    $readmeEnglish | Should Not Match 'hooks/'

    $projectIntroEnglish | Should Match 'skill'
    $projectIntroEnglish | Should Match 'best-effort'
    $projectIntroEnglish | Should Match 'checkpoint'
    $projectIntroEnglish | Should Match 'cross-platform'
    $projectIntroEnglish | Should Match 'language'
    $projectIntroEnglish | Should Match 'trunk'
    $projectIntroEnglish | Should Match 'streamlit'
    $projectIntroEnglish | Should Match 'clj'
    $projectIntroEnglish | Should Match 'cabal'
    $projectIntroEnglish | Should Match 'zig'
    $projectIntroEnglish | Should Match 'julia'
    $projectIntroEnglish | Should Match 'bazel'
    $projectIntroEnglish | Should Not Match 'plugin-style'
  }

  It 'documents a pure skill installation path in the Chinese docs' {
    $readmeChinese | Should Match 'skill'
    $readmeChinese | Should Match ([regex]::Escape($bestEffortZh))
    $readmeChinese | Should Match ([regex]::Escape($implicitZh))
    $readmeChinese | Should Match ([regex]::Escape($checkpointZh))
    $readmeChinese | Should Match ([regex]::Escape($multiProjectIsolationZh))
    $readmeChinese | Should Match 'trunk'
    $readmeChinese | Should Match 'hatch'
    $readmeChinese | Should Match 'jupyter'
    $readmeChinese | Should Match 'streamlit'
    $readmeChinese | Should Match 'kotlin'
    $readmeChinese | Should Match 'scala'
    $readmeChinese | Should Match 'clj'
    $readmeChinese | Should Match 'cabal'
    $readmeChinese | Should Match 'dune'
    $readmeChinese | Should Match 'Rscript'
    $readmeChinese | Should Match 'zig'
    $readmeChinese | Should Match 'julia'
    $readmeChinese | Should Match 'tox'
    $readmeChinese | Should Match 'xcodebuild'
    $readmeChinese | Should Match 'bazel'
    $readmeChinese | Should Match 'must reconsider now'
    $readmeChinese | Should Match 'should reconsider soon'
    $readmeChinese | Should Match 'do not reconsider from this checkpoint alone'
    $readmeChinese | Should Match 'failed one-shot high-risk'
    $readmeChinese | Should Match 'session-end alone'
    $readmeChinese | Should Not Match ([regex]::Escape($pluginStyleZh))
    $readmeChinese | Should Not Match '\.codex-plugin/plugin\.json'
    $readmeChinese | Should Not Match 'hooks/'

    $projectIntroChinese | Should Match 'skill'
    $projectIntroChinese | Should Match ([regex]::Escape($bestEffortZh))
    $projectIntroChinese | Should Match ([regex]::Escape($checkpointZh))
    $projectIntroChinese | Should Match ([regex]::Escape($crossPlatformZh))
    $projectIntroChinese | Should Match 'trunk'
    $projectIntroChinese | Should Match 'streamlit'
    $projectIntroChinese | Should Match 'clj'
    $projectIntroChinese | Should Match 'cabal'
    $projectIntroChinese | Should Match 'zig'
    $projectIntroChinese | Should Match 'julia'
    $projectIntroChinese | Should Match 'bazel'
    $projectIntroChinese | Should Not Match ([regex]::Escape($pluginStyleZh))
  }

  It 'keeps the public trigger scenarios aligned with pure skill checkpoints' {
    $triggerScenariosEnglish | Should Match 'best-effort'
    $triggerScenariosEnglish | Should Match 'implicit invocation'
    $triggerScenariosEnglish | Should Match 'finished checkpoint'
    $triggerScenariosEnglish | Should Match 'subagent'
    $triggerScenariosEnglish | Should Match 'backlog relief'
    $triggerScenariosEnglish | Should Match 'must reconsider now'
    $triggerScenariosEnglish | Should Match 'should reconsider soon'
    $triggerScenariosEnglish | Should Match 'do not reconsider from this checkpoint alone'
    $triggerScenariosEnglish | Should Match 'failed one-shot high-risk'
    $triggerScenariosEnglish | Should Match 'long-lived'
    $triggerScenariosEnglish | Should Match 'session-end alone'
    $triggerScenariosEnglish | Should Not Match 'plugin-style'
    $triggerScenariosEnglish | Should Not Match '\.codex-plugin/plugin\.json'

    $triggerScenariosChinese | Should Match ([regex]::Escape($bestEffortZh))
    $triggerScenariosChinese | Should Match ([regex]::Escape($implicitZh))
    $triggerScenariosChinese | Should Match ([regex]::Escape($checkpointZh))
    $triggerScenariosChinese | Should Match ([regex]::Escape($subagentZh))
    $triggerScenariosChinese | Should Match 'must reconsider now'
    $triggerScenariosChinese | Should Match 'should reconsider soon'
    $triggerScenariosChinese | Should Match 'do not reconsider from this checkpoint alone'
    $triggerScenariosChinese | Should Match 'failed one-shot high-risk'
    $triggerScenariosChinese | Should Match 'session-end alone'
    $triggerScenariosChinese | Should Not Match ([regex]::Escape($pluginStyleZh))
  }

  It 'ships neutral checkpoint trigger fixtures instead of hook-shaped public fixtures' {
    Test-Path $triggerFixturesPath | Should Be $true
    Test-Path (Join-Path $repoRoot 'scripts\hook-trigger-fixtures') | Should Be $false

    $fixtureNames = @(Get-ChildItem -File $triggerFixturesPath | ForEach-Object { $_.Name })

    ($fixtureNames -contains 'checkpoint-one-shot-success.json') | Should Be $true
    ($fixtureNames -contains 'checkpoint-one-shot-failure.json') | Should Be $true
    ($fixtureNames -contains 'checkpoint-explicit-automation.json') | Should Be $true
    ($fixtureNames -contains 'checkpoint-subagent-complete.json') | Should Be $true
    ($fixtureNames -contains 'checkpoint-batch-finished.json') | Should Be $true
    ($fixtureNames -contains 'checkpoint-low-risk.json') | Should Be $true
    ($fixtureNames -contains 'checkpoint-long-running-dev.json') | Should Be $true
    ($fixtureNames -contains 'checkpoint-session-end.json') | Should Be $true
  }

  It 'stores trigger fixtures as checkpoint simulations rather than host-hook requirements' {
    $fixtureContents = @(Get-ChildItem -File $triggerFixturesPath | ForEach-Object {
      Get-Content -Raw -Encoding UTF8 $_.FullName
    })

    foreach ($fixture in $fixtureContents) {
      $fixture | Should Match 'checkpoint_type'
      $fixture | Should Not Match '"hook_event_name"'
    }
  }

  It 'does not ship plugin manifests or hook entrypoints in the public package' {
    Test-Path (Join-Path $repoRoot '.codex-plugin\plugin.json') | Should Be $false
    Test-Path (Join-Path $repoRoot '.agents\plugins\marketplace.json') | Should Be $false
    Test-Path (Join-Path $repoRoot 'hooks.json') | Should Be $false
    Test-Path (Join-Path $repoRoot 'hooks') | Should Be $false
    Test-Path (Join-Path $repoRoot 'scripts\hook-trigger-policy.ps1') | Should Be $false
    Test-Path (Join-Path $repoRoot 'scripts\invoke-hook-trigger.ps1') | Should Be $false
    Test-Path (Join-Path $repoRoot 'scripts\trigger-runtime-state.ps1') | Should Be $false
  }
}
