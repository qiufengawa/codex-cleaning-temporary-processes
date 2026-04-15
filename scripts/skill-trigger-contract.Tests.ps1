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

    $autoStrongTriggerZh = -join [char[]](0x81EA, 0x52A8, 0x5F3A, 0x89E6, 0x53D1)
    $manualFallbackZh = -join [char[]](0x624B, 0x52A8, 0x515C, 0x5E95)
    $installZh = -join [char[]](0x5B89, 0x88C5)
    $pluginStyleInstallZh = -join [char[]](0x63D2, 0x4EF6, 0x5F0F, 0x5B89, 0x88C5)
    $skillStyleInstallZh = 'skill ' + (-join [char[]](0x5F0F, 0x5B89, 0x88C5))
    $fixedCheckpointZh = -join [char[]](0x56FA, 0x5B9A, 0x68C0, 0x67E5, 0x70B9)
    $sessionEndZh = -join [char[]](0x4F1A, 0x8BDD, 0x7ED3, 0x675F)
    $multiProjectIsolationZh = -join [char[]](0x591A, 0x9879, 0x76EE, 0x9694, 0x79BB)

    $autoStrongTriggerZhPattern = [regex]::Escape($autoStrongTriggerZh)
    $manualFallbackZhPattern = [regex]::Escape($manualFallbackZh)
    $installZhPattern = [regex]::Escape($installZh)
    $pluginStyleInstallZhPattern = [regex]::Escape($pluginStyleInstallZh)
    $skillStyleInstallZhPattern = [regex]::Escape($skillStyleInstallZh)
    $fixedCheckpointZhPattern = [regex]::Escape($fixedCheckpointZh)
    $sessionEndZhPattern = [regex]::Escape($sessionEndZh)
    $multiProjectIsolationZhPattern = [regex]::Escape($multiProjectIsolationZh)
  }

  It 'keeps the skill positioned as plugin-style automatic triggering with manual fallback' {
    $skillMarkdown | Should Match '(?m)^description: .*manual'
    $skillMarkdown | Should Match 'plugin-style installation'
    $skillMarkdown | Should Match '\.codex-plugin/plugin\.json'
    $skillMarkdown | Should Match 'CODEX_HOME/skills'
    $skillMarkdown | Should Match 'fixed checkpoints'
    $skillMarkdown | Should Match 'session end'
    $skillMarkdown | Should Match 'sanitized thread identifiers'
  }

  It 'keeps implicit invocation enabled and the metadata install-mode aware' {
    $metadataYaml | Should Match 'allow_implicit_invocation:\s*true'
    $metadataYaml | Should Match 'plugin-style mode'
    $metadataYaml | Should Match '\.codex-plugin/plugin\.json'
    $metadataYaml | Should Match 'CODEX_HOME/skills'
    $metadataYaml | Should Match 'fixed checkpoints'
    $metadataYaml | Should Match 'session end'
    $metadataYaml | Should Match 'manual fallback guidance'
    $metadataYaml | Should Match 'multi-project isolation'
  }

  It 'documents the plugin-style and skill-style split in the English docs' {
    $readmeEnglish | Should Match '## Automatic Strong Triggering'
    $readmeEnglish | Should Match '## Manual Fallback'
    $readmeEnglish | Should Match '## Cross-Platform Packaging'
    $readmeEnglish | Should Match '## Multi-Project Isolation'
    $readmeEnglish | Should Match 'plugin-style installation'
    $readmeEnglish | Should Match 'skill-style installation'
    $readmeEnglish | Should Match '\.codex-plugin/plugin\.json'
    $readmeEnglish | Should Match 'hooks/'
    $readmeEnglish | Should Match 'CODEX_HOME/skills'
    $readmeEnglish | Should Match 'fixed checkpoints'
    $readmeEnglish | Should Match 'session end'
    $readmeEnglish | Should Match 'sanitized thread identifiers'
    $readmeEnglish | Should Match 'explicitly ask Codex to use `\$codex-cleaning-temporary-processes`'

    $projectIntroEnglish | Should Match 'plugin-style installation'
    $projectIntroEnglish | Should Match 'skill-style installation'
    $projectIntroEnglish | Should Match '\.codex-plugin/plugin\.json'
    $projectIntroEnglish | Should Match 'CODEX_HOME/skills'
    $projectIntroEnglish | Should Match 'fixed checkpoints'
  }

  It 'documents the install-mode split in the Chinese docs' {
    $readmeChinese | Should Match $autoStrongTriggerZhPattern
    $readmeChinese | Should Match $manualFallbackZhPattern
    $readmeChinese | Should Match $pluginStyleInstallZhPattern
    $readmeChinese | Should Match $skillStyleInstallZhPattern
    $readmeChinese | Should Match $installZhPattern
    $readmeChinese | Should Match $fixedCheckpointZhPattern
    $readmeChinese | Should Match $sessionEndZhPattern
    $readmeChinese | Should Match $multiProjectIsolationZhPattern
    $readmeChinese | Should Match '\.codex-plugin/plugin\.json'
    $readmeChinese | Should Match 'CODEX_HOME/skills'

    $projectIntroChinese | Should Match $pluginStyleInstallZhPattern
    $projectIntroChinese | Should Match $skillStyleInstallZhPattern
    $projectIntroChinese | Should Match $fixedCheckpointZhPattern
    $projectIntroChinese | Should Match $sessionEndZhPattern
  }

  It 'keeps the public trigger scenario docs aligned with plugin-style checkpoints and manual fallback' {
    $triggerScenariosEnglish | Should Match 'plugin-style installation'
    $triggerScenariosEnglish | Should Match '\.codex-plugin/plugin\.json'
    $triggerScenariosEnglish | Should Match 'CODEX_HOME/skills'
    $triggerScenariosEnglish | Should Match 'fixed-checkpoint based'
    $triggerScenariosEnglish | Should Match 'session end'
    $triggerScenariosEnglish | Should Match 'backlog relief'
    $triggerScenariosEnglish | Should Match 'manual fallback'

    $triggerScenariosChinese | Should Match $pluginStyleInstallZhPattern
    $triggerScenariosChinese | Should Match $skillStyleInstallZhPattern
    $triggerScenariosChinese | Should Match $fixedCheckpointZhPattern
    $triggerScenariosChinese | Should Match $sessionEndZhPattern
    $triggerScenariosChinese | Should Match $manualFallbackZhPattern
    $triggerScenariosChinese | Should Match 'CODEX_HOME/skills'
  }
}
