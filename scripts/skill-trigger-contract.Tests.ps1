$repoRoot = Split-Path $PSScriptRoot -Parent

Describe 'public skill trigger contract' {
  BeforeAll {
    $skillMarkdown = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'SKILL.md')
    $metadataYaml = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'agents\openai.yaml')
    $readmeEnglish = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'README.md')
    $readmeChinese = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'README.zh-CN.md')
    $triggerScenariosEnglish = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'docs\trigger-regression-scenarios.md')
    $triggerScenariosChinese = Get-Content -Raw -Encoding UTF8 (Join-Path $repoRoot 'docs\trigger-regression-scenarios.zh-CN.md')
    $triggerCadenceZh = '## ' + (-join [char[]](0x89E6, 0x53D1, 0x8282, 0x594F))
    $afterFinishedStepZh = -join [char[]](0x6BCF, 0x4E2A, 0x5DF2, 0x7ECF, 0x7ED3, 0x675F, 0x7684, 0x9AD8, 0x98CE, 0x9669, 0x6B65, 0x9AA4, 0x4E4B, 0x540E)
    $subagentZh = -join [char[]](0x5B50, 0x4EE3, 0x7406)
    $troubleshootingZh = '## ' + (-join [char[]](0x6545, 0x969C, 0x6392, 0x67E5))
    $askCodexZh = (-join [char[]](0x663E, 0x5F0F, 0x8981, 0x6C42)) + ' Codex ' + (-join [char[]](0x4F7F, 0x7528))
    $currentThreadZh = -join [char[]](0x5F53, 0x524D, 0x7EBF, 0x7A0B)
    $installZh = -join [char[]](0x5B89, 0x88C5)
    $triggerCadenceZhPattern = [regex]::Escape($triggerCadenceZh)
    $afterFinishedStepZhPattern = [regex]::Escape($afterFinishedStepZh)
    $subagentZhPattern = [regex]::Escape($subagentZh)
    $troubleshootingZhPattern = [regex]::Escape($troubleshootingZh)
    $currentThreadZhPattern = [regex]::Escape($currentThreadZh)
    $installZhPattern = [regex]::Escape($installZh)
    $askCodexZhPattern = [regex]::Escape($askCodexZh) + ' `\$codex-cleaning-temporary-processes`'
  }

  It 'keeps the skill description focused on stacked-process checkpoint cleanup' {
    $skillMarkdown | Should Match '(?m)^description: Use when .*stack'
    $skillMarkdown | Should Match '(?m)^description: Use when .*checkpoint'
  }

  It 'keeps the skill instructions explicit about mid-task checkpoint cleanup' {
    $skillMarkdown | Should Match 'Do not wait for the entire task to finish'
    $skillMarkdown | Should Match 'after each finished high-risk step'
    $skillMarkdown | Should Match 'after a subagent finishes'
    $skillMarkdown | Should Match 'after a batch of one-shot shell or tool commands'
    $skillMarkdown | Should Match 'current-task ownership evidence'
    $skillMarkdown | Should Match 'current-thread-owned'
  }

  It 'keeps implicit invocation enabled and the default prompt explicit about checkpoint timing' {
    $metadataYaml | Should Match 'allow_implicit_invocation:\s*true'
    $metadataYaml | Should Match 'default_prompt:\s*".*\$codex-cleaning-temporary-processes'
    $metadataYaml | Should Match 'after each finished high-risk step'
    $metadataYaml | Should Match 'DevTools MCP'
    $metadataYaml | Should Match 'subagent'
    $metadataYaml | Should Match 'before process stacks grow'
    $metadataYaml | Should Match 'current-thread-owned explicit automation'
  }

  It 'documents trigger cadence and troubleshooting in the English README' {
    $readmeEnglish | Should Match '## Trigger Cadence'
    $readmeEnglish | Should Match '## Multi-Project Safety'
    $readmeEnglish | Should Match 'after each finished high-risk step'
    $readmeEnglish | Should Match 'DevTools MCP'
    $readmeEnglish | Should Match 'subagent'
    $readmeEnglish | Should Match 'current-task ownership evidence'
    $readmeEnglish | Should Match 'current-thread ownership'
    $readmeEnglish | Should Match 'generic runtimes'
    $readmeEnglish | Should Match '## Troubleshooting'
    $readmeEnglish | Should Match 'explicitly ask Codex to use `\$codex-cleaning-temporary-processes`'
  }

  It 'documents trigger cadence and troubleshooting in the Chinese README' {
    $readmeChinese | Should Match $triggerCadenceZhPattern
    $readmeChinese | Should Match $afterFinishedStepZhPattern
    $readmeChinese | Should Match 'DevTools MCP'
    $readmeChinese | Should Match $subagentZhPattern
    $readmeChinese | Should Match $currentThreadZhPattern
    $readmeChinese | Should Match $troubleshootingZhPattern
    $readmeChinese | Should Match $askCodexZhPattern
  }

  It 'keeps the public trigger scenario docs aligned with install and current-thread behavior' {
    $triggerScenariosEnglish | Should Match 'install'
    $triggerScenariosEnglish | Should Match 'current-thread'
    $triggerScenariosChinese | Should Match $installZhPattern
    $triggerScenariosChinese | Should Match $currentThreadZhPattern
  }
}
