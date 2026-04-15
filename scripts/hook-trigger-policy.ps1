Set-StrictMode -Version Latest

$script:HookTriggerLongLivedCommandPatterns = @(
  '\bdev\b',
  '\bserve\b',
  '\bpreview\b',
  '\bwatch\b',
  '\brunserver\b',
  '\bstart\b',
  '\bpytest-watch\b',
  '\bptw\b',
  '\buvicorn\b',
  '\bgunicorn\b',
  '\b(run|exec)\b\s+storybook\b',
  '\bstorybook\b.*\b(dev|start)\b',
  '\bbootrun\b',
  '\bspring-boot:run\b',
  '\bquarkus:dev\b',
  '\brails\b.*\bserver\b',
  '\bphx\.server\b'
)

$script:HookTriggerOneShotCommandPatterns = @(
  '\btest\b',
  '\bbuild\b',
  '\bcheck\b',
  '\binstall\b',
  '\bci\b',
  '\bpublish\b',
  '\bpackage\b',
  '\blint\b',
  '\bcompile\b',
  '\bpytest\b(?!-)',
  '\bvitest\b(?!-)',
  '\brspec\b',
  '\bctest\b',
  '\bclippy\b',
  '\bverify\b'
)

$script:HookTriggerShellToolPatterns = @(
  '^shell_command$',
  '^functions\.shell_command$',
  '^shell$',
  '^bash$',
  '^cmd$',
  '^powershell$',
  '^terminal$'
)

$script:HookTriggerExplicitAutomationToolPatterns = @(
  '^mcp__chrome_devtools__',
  '^chrome[_-]?devtools',
  '^playwright'
)

$script:HookTriggerExplicitAutomationCommandPatterns = @(
  'chrome-devtools-mcp',
  'remote-debugging-port',
  '\bplaywright\b'
)

function Test-HookTriggerPatternList {
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

function Get-HookTriggerPropertyValue {
  param(
    [object]$InputObject,
    [string[]]$PropertyNames
  )

  if ($null -eq $InputObject) {
    return $null
  }

  foreach ($propertyName in $PropertyNames) {
    $property = $InputObject.PSObject.Properties[$propertyName]
    if ($null -ne $property) {
      return $property.Value
    }
  }

  return $null
}

function Normalize-HookTriggerThreadId {
  param([string]$ThreadId)

  if ([string]::IsNullOrWhiteSpace($ThreadId)) {
    return $null
  }

  return $ThreadId.Trim()
}

function Normalize-HookTriggerWorkspace {
  param([string]$Workspace)

  if ([string]::IsNullOrWhiteSpace($Workspace)) {
    return $null
  }

  return $Workspace.Trim().TrimEnd('\', '/').ToLowerInvariant()
}

function Get-HookTriggerEventName {
  param([object]$HookInput)

  $eventName = [string](Get-HookTriggerPropertyValue -InputObject $HookInput -PropertyNames @(
      'hook_event_name',
      'hookEventName',
      'event_name',
      'eventName',
      'event'
    ))

  if ([string]::IsNullOrWhiteSpace($eventName)) {
    return $null
  }

  return $eventName.Trim()
}

function Get-HookTriggerToolName {
  param([object]$HookInput)

  $toolName = [string](Get-HookTriggerPropertyValue -InputObject $HookInput -PropertyNames @(
      'tool_name',
      'toolName',
      'tool'
    ))

  if ([string]::IsNullOrWhiteSpace($toolName)) {
    return $null
  }

  return $toolName.Trim()
}

function Get-HookTriggerCommandText {
  param([object]$HookInput)

  $toolInput = Get-HookTriggerPropertyValue -InputObject $HookInput -PropertyNames @('tool_input', 'toolInput', 'input')
  $commandText = [string](Get-HookTriggerPropertyValue -InputObject $toolInput -PropertyNames @(
      'command',
      'cmd',
      'script'
    ))

  if ([string]::IsNullOrWhiteSpace($commandText)) {
    $commandText = [string](Get-HookTriggerPropertyValue -InputObject $HookInput -PropertyNames @(
        'command',
        'cmd'
      ))
  }

  if ([string]::IsNullOrWhiteSpace($commandText)) {
    return $null
  }

  return $commandText.Trim()
}

function Get-HookTriggerCommandFingerprint {
  param([string]$CommandText)

  if ([string]::IsNullOrWhiteSpace($CommandText)) {
    return 'no-command'
  }

  return (($CommandText -replace '\s+', ' ').Trim().ToLowerInvariant())
}

function New-HookTriggerIsolationMetadata {
  param(
    $ThreadId,
    $Workspace,
    [bool]$RequiresWorkspace = $false,
    [bool]$RequiresThreadId = $false
  )

  [pscustomobject]@{
    ThreadId          = $ThreadId
    WorkspaceKey      = $Workspace
    RequiresWorkspace = $RequiresWorkspace
    RequiresThreadId  = $RequiresThreadId
    WorkspaceWildcard = $false
  }
}

function New-HookTriggerDecision {
  param(
    [string]$HookEvent,
    [bool]$ShouldTrigger,
    $CleanupMode,
    [bool]$RequireExplicitAutomationConfirmation,
    [string]$TriggerClass,
    [string]$AuditReason,
    $ThreadId,
    $Workspace,
    $ToolName,
    $CommandText,
    [bool]$RequiresWorkspace = $false,
    [bool]$RequiresThreadId = $false,
    [int]$DebounceWindowSeconds = 12,
    [int]$CooldownSeconds = 45
  )

  $eventKey = if ([string]::IsNullOrWhiteSpace($HookEvent)) {
    'unknown'
  } else {
    ($HookEvent.Trim().ToLowerInvariant() -replace '\s+', '-')
  }

  $threadKey = if ([string]::IsNullOrWhiteSpace($ThreadId)) { 'no-thread' } else { $ThreadId }
  $workspaceKey = if ([string]::IsNullOrWhiteSpace($Workspace)) { 'no-workspace' } else { $Workspace }
  $toolKey = if ([string]::IsNullOrWhiteSpace($ToolName)) { 'no-tool' } else { $ToolName.Trim().ToLowerInvariant() }
  $commandKey = Get-HookTriggerCommandFingerprint -CommandText $CommandText
  $classKey = if ([string]::IsNullOrWhiteSpace($TriggerClass)) { 'none' } else { $TriggerClass }

  [pscustomobject]@{
    HookEvent                            = $HookEvent
    ShouldTrigger                        = $ShouldTrigger
    CleanupMode                          = $CleanupMode
    RequireExplicitAutomationConfirmation = $RequireExplicitAutomationConfirmation
    TriggerClass                         = $TriggerClass
    DebounceKey                          = '{0}|{1}|{2}|{3}|{4}' -f $eventKey, $classKey, $threadKey, $workspaceKey, $toolKey
    CooldownKey                          = '{0}|{1}|{2}|{3}' -f $eventKey, $classKey, $threadKey, $workspaceKey
    DebounceWindowSeconds                = $DebounceWindowSeconds
    CooldownSeconds                      = $CooldownSeconds
    ToolName                             = $ToolName
    CommandText                          = $CommandText
    Isolation                            = New-HookTriggerIsolationMetadata -ThreadId $ThreadId -Workspace $Workspace -RequiresWorkspace:$RequiresWorkspace -RequiresThreadId:$RequiresThreadId
    AuditReason                          = $AuditReason
  }
}

function Get-HookTriggerDecision {
  param(
    [pscustomobject]$HookInput,
    [string]$Workspace,
    [string]$ThreadId
  )

  $normalizedThreadId = Normalize-HookTriggerThreadId -ThreadId $ThreadId
  $normalizedWorkspace = Normalize-HookTriggerWorkspace -Workspace $Workspace
  $hookEvent = Get-HookTriggerEventName -HookInput $HookInput
  $toolName = Get-HookTriggerToolName -HookInput $HookInput
  $commandText = Get-HookTriggerCommandText -HookInput $HookInput
  $normalizedToolName = if ([string]::IsNullOrWhiteSpace($toolName)) { $null } else { $toolName.ToLowerInvariant() }
  $codexAppServerLineage = [bool](Get-HookTriggerPropertyValue -InputObject (Get-HookTriggerPropertyValue -InputObject $HookInput -PropertyNames @('automation_context', 'automationContext')) -PropertyNames @('codex_app_server_lineage', 'codexAppServerLineage'))

  switch ($hookEvent) {
    'SessionEnd' {
      return New-HookTriggerDecision -HookEvent $hookEvent -ShouldTrigger:$true -CleanupMode 'cleanup' -RequireExplicitAutomationConfirmation:$false -TriggerClass 'session-end' -AuditReason 'Session end requests the final cleanup sweep for temporary process leftovers' -ThreadId $normalizedThreadId -Workspace $normalizedWorkspace -ToolName $toolName -CommandText $commandText -DebounceWindowSeconds 5 -CooldownSeconds 5
    }

    'SubagentStop' {
      return New-HookTriggerDecision -HookEvent $hookEvent -ShouldTrigger:$true -CleanupMode 'checkpoint-cleanup' -RequireExplicitAutomationConfirmation:$false -TriggerClass 'subagent-stop' -AuditReason 'Subagent completion is a cleanup checkpoint because helper shells and runtimes may now be disposable' -ThreadId $normalizedThreadId -Workspace $normalizedWorkspace -ToolName $toolName -CommandText $commandText -DebounceWindowSeconds 10 -CooldownSeconds 30
    }

    'PostToolUse' {
      $isExplicitAutomation = (
        (Test-HookTriggerPatternList -Value $normalizedToolName -Patterns $script:HookTriggerExplicitAutomationToolPatterns) -or
        (Test-HookTriggerPatternList -Value $commandText -Patterns $script:HookTriggerExplicitAutomationCommandPatterns)
      )

      if ($isExplicitAutomation) {
        $canConfirmCurrentThread = (
          -not [string]::IsNullOrWhiteSpace($normalizedThreadId) -and
          -not [string]::IsNullOrWhiteSpace($normalizedWorkspace)
        )

        $auditReason = if ($canConfirmCurrentThread) {
          'Finished explicit automation step should trigger checkpoint cleanup and current-thread confirmation for same-workspace follow-up'
        } else {
          'Finished explicit automation step should trigger checkpoint cleanup, but current-thread confirmation is skipped without a non-blank workspace and thread id'
        }

        if ($codexAppServerLineage -and $canConfirmCurrentThread) {
          $auditReason += '; Codex app-server lineage is only treated as reclaimable explicit automation after this safe confirmation path'
        }

        return New-HookTriggerDecision -HookEvent $hookEvent -ShouldTrigger:$true -CleanupMode 'checkpoint-cleanup' -RequireExplicitAutomationConfirmation:$canConfirmCurrentThread -TriggerClass 'explicit-automation' -AuditReason $auditReason -ThreadId $normalizedThreadId -Workspace $normalizedWorkspace -ToolName $toolName -CommandText $commandText -RequiresWorkspace:$true -RequiresThreadId:$true -DebounceWindowSeconds 8 -CooldownSeconds 20
      }

      $isShellTool = Test-HookTriggerPatternList -Value $normalizedToolName -Patterns $script:HookTriggerShellToolPatterns
      if ($isShellTool -and (Test-HookTriggerPatternList -Value $commandText -Patterns $script:HookTriggerLongLivedCommandPatterns)) {
        return New-HookTriggerDecision -HookEvent $hookEvent -ShouldTrigger:$false -CleanupMode $null -RequireExplicitAutomationConfirmation:$false -TriggerClass 'long-lived-dev-server' -AuditReason 'Finished tool call looks like a reusable dev server or watch process, so cleanup is skipped conservatively' -ThreadId $normalizedThreadId -Workspace $normalizedWorkspace -ToolName $toolName -CommandText $commandText -DebounceWindowSeconds 15 -CooldownSeconds 60
      }

      if ($isShellTool -and (Test-HookTriggerPatternList -Value $commandText -Patterns $script:HookTriggerOneShotCommandPatterns)) {
        return New-HookTriggerDecision -HookEvent $hookEvent -ShouldTrigger:$true -CleanupMode 'checkpoint-cleanup' -RequireExplicitAutomationConfirmation:$false -TriggerClass 'one-shot-shell' -AuditReason 'Finished one-shot shell or tool command is a high-risk checkpoint and can trigger conservative checkpoint cleanup' -ThreadId $normalizedThreadId -Workspace $normalizedWorkspace -ToolName $toolName -CommandText $commandText -DebounceWindowSeconds 10 -CooldownSeconds 30
      }

      return New-HookTriggerDecision -HookEvent $hookEvent -ShouldTrigger:$false -CleanupMode $null -RequireExplicitAutomationConfirmation:$false -TriggerClass 'non-risk-tool' -AuditReason 'Post-tool event did not provide strong evidence for a finished high-risk checkpoint' -ThreadId $normalizedThreadId -Workspace $normalizedWorkspace -ToolName $toolName -CommandText $commandText -DebounceWindowSeconds 15 -CooldownSeconds 30
    }

    default {
      return New-HookTriggerDecision -HookEvent $hookEvent -ShouldTrigger:$false -CleanupMode $null -RequireExplicitAutomationConfirmation:$false -TriggerClass 'unsupported-event' -AuditReason 'Unsupported hook event leaves cleanup decisions to the existing safety model' -ThreadId $normalizedThreadId -Workspace $normalizedWorkspace -ToolName $toolName -CommandText $commandText -DebounceWindowSeconds 15 -CooldownSeconds 30
    }
  }
}
