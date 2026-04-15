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
    $metadataYaml | Should Not Match 'plugin-style'
    $metadataYaml | Should Not Match '\.codex-plugin/plugin\.json'
    $metadataYaml | Should Not Match 'hooks'
    $metadataYaml | Should Not Match 'session end'
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
    $readmeEnglish | Should Not Match 'plugin-style'
    $readmeEnglish | Should Not Match '\.codex-plugin/plugin\.json'
    $readmeEnglish | Should Not Match 'hooks/'

    $projectIntroEnglish | Should Match 'skill'
    $projectIntroEnglish | Should Match 'best-effort'
    $projectIntroEnglish | Should Match 'checkpoint'
    $projectIntroEnglish | Should Match 'cross-platform'
    $projectIntroEnglish | Should Not Match 'plugin-style'
  }

  It 'documents a pure skill installation path in the Chinese docs' {
    $readmeChinese | Should Match 'skill'
    $readmeChinese | Should Match ([regex]::Escape($bestEffortZh))
    $readmeChinese | Should Match ([regex]::Escape($implicitZh))
    $readmeChinese | Should Match ([regex]::Escape($checkpointZh))
    $readmeChinese | Should Match ([regex]::Escape($multiProjectIsolationZh))
    $readmeChinese | Should Not Match ([regex]::Escape($pluginStyleZh))
    $readmeChinese | Should Not Match '\.codex-plugin/plugin\.json'
    $readmeChinese | Should Not Match 'hooks/'

    $projectIntroChinese | Should Match 'skill'
    $projectIntroChinese | Should Match ([regex]::Escape($bestEffortZh))
    $projectIntroChinese | Should Match ([regex]::Escape($checkpointZh))
    $projectIntroChinese | Should Match ([regex]::Escape($crossPlatformZh))
    $projectIntroChinese | Should Not Match ([regex]::Escape($pluginStyleZh))
  }

  It 'keeps the public trigger scenarios aligned with pure skill checkpoints' {
    $triggerScenariosEnglish | Should Match 'best-effort'
    $triggerScenariosEnglish | Should Match 'implicit invocation'
    $triggerScenariosEnglish | Should Match 'finished checkpoint'
    $triggerScenariosEnglish | Should Match 'subagent'
    $triggerScenariosEnglish | Should Match 'backlog relief'
    $triggerScenariosEnglish | Should Not Match 'plugin-style'
    $triggerScenariosEnglish | Should Not Match '\.codex-plugin/plugin\.json'

    $triggerScenariosChinese | Should Match ([regex]::Escape($bestEffortZh))
    $triggerScenariosChinese | Should Match ([regex]::Escape($implicitZh))
    $triggerScenariosChinese | Should Match ([regex]::Escape($checkpointZh))
    $triggerScenariosChinese | Should Match ([regex]::Escape($subagentZh))
    $triggerScenariosChinese | Should Not Match ([regex]::Escape($pluginStyleZh))
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
