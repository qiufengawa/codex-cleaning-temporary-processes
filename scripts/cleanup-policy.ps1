Set-StrictMode -Version Latest

$script:CheckpointCleanupCategories = @(
  "devtools-launcher",
  "devtools-watchdog",
  "devtools-mcp",
  "browser-automation",
  "browser-debug"
)

$script:CheckpointAutomationShellMarkers = @(
  "chrome-devtools-mcp",
  "remote-debugging-port",
  "playwright"
)

$script:CheckpointLongLivedMarkers = @(
  "\bdev\b",
  "\bserve\b",
  "\bpreview\b",
  "\bwatch\b",
  "\brunserver\b",
  "\bstart\b",
  "\bpytest-watch\b",
  "\bptw\b",
  "\buvicorn\b",
  "\bgunicorn\b",
  "\b(run|exec)\b\s+storybook\b",
  "\bstorybook\b.*\b(dev|start)\b",
  "\bbootrun\b",
  "\bspring-boot:run\b",
  "\bquarkus:dev\b",
  "\brails\b.*\bserver\b",
  "\bphx\.server\b"
)

$script:CheckpointOneShotMarkers = @(
  "\btest\b",
  "\bbuild\b",
  "\bcheck\b",
  "\bpublish\b",
  "\bpackage\b",
  "\blint\b",
  "\bcompile\b",
  "\bpytest\b(?!-)",
  "\bvitest\b(?!-)",
  "\brspec\b",
  "\bctest\b",
  "\bclippy\b",
  "\bverify\b"
)

function Test-CleanupPolicyPatternList {
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

function Get-CleanupDecision {
  param(
    [pscustomobject]$Record,
    [ValidateSet("inspect", "cleanup", "checkpoint-cleanup")]
    [string]$Mode = "inspect"
  )

  if ($Mode -eq "inspect") {
    return [pscustomobject]@{
      Decision = "inspect-only"
      Reason   = "Inspection mode never kills processes"
    }
  }

  if (-not $Record.Killable) {
    return [pscustomobject]@{
      Decision = "preserve"
      Reason   = "Protected process class"
    }
  }

  if ($Mode -eq "cleanup") {
    return [pscustomobject]@{
      Decision = "cleanup-now"
      Reason   = "Full cleanup mode removes killable temporary processes"
    }
  }

  if ($Record.Category -in $script:CheckpointCleanupCategories) {
    return [pscustomobject]@{
      Decision = "cleanup-now"
      Reason   = "High-confidence automation process with no reuse value after the step"
    }
  }

  if (
    $Record.Category -eq "tool-shell" -and
    (Test-CleanupPolicyPatternList -Value $Record.CommandLine -Patterns $script:CheckpointAutomationShellMarkers)
  ) {
    return [pscustomobject]@{
      Decision = "cleanup-now"
      Reason   = "Wrapper shell launched a high-confidence automation or DevTools helper"
    }
  }

  if (Test-CleanupPolicyPatternList -Value $Record.CommandLine -Patterns $script:CheckpointLongLivedMarkers) {
    return [pscustomobject]@{
      Decision = "inspect-only"
      Reason   = "Potentially reusable long-lived dev process"
    }
  }

  if (Test-CleanupPolicyPatternList -Value $Record.CommandLine -Patterns $script:CheckpointOneShotMarkers) {
    return [pscustomobject]@{
      Decision = "cleanup-now"
      Reason   = "One-shot build or test command finished for this step"
    }
  }

  return [pscustomobject]@{
    Decision = "inspect-only"
    Reason   = "Checkpoint cleanup needs stronger evidence before killing"
  }
}
