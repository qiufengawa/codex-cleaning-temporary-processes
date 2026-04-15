Set-StrictMode -Version Latest

function Test-IsWindowsPlatform {
  return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function New-InventoryProcessRecord {
  param(
    [int]$ProcessId,
    [int]$ParentProcessId,
    [string]$Name,
    [string]$CommandLine
  )

  [pscustomobject]@{
    ProcessId       = $ProcessId
    ParentProcessId = $ParentProcessId
    Name            = $Name
    CommandLine     = if ([string]::IsNullOrWhiteSpace($CommandLine)) { $Name } else { $CommandLine }
  }
}

function ConvertFrom-WindowsProcess {
  param([object]$Process)

  return New-InventoryProcessRecord `
    -ProcessId ([int]$Process.ProcessId) `
    -ParentProcessId ([int]$Process.ParentProcessId) `
    -Name ([string]$Process.Name) `
    -CommandLine ([string]$Process.CommandLine)
}

function Get-UnixProcessName {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $Value
  }

  $trimmed = $Value.Trim().Trim('"')
  if ($trimmed -match '[\\/]') {
    return [System.IO.Path]::GetFileName($trimmed)
  }

  return $trimmed
}

function ConvertFrom-UnixPsLine {
  param([string]$Line)

  if ([string]::IsNullOrWhiteSpace($Line)) {
    return $null
  }

  $match = [regex]::Match($Line, '^\s*(\d+)\s+(\d+)\s+(.*)$')
  if (-not $match.Success) {
    return $null
  }

  $processId = [int]$match.Groups[1].Value
  $parentProcessId = [int]$match.Groups[2].Value
  $name = Get-UnixProcessName -Value ([string]$match.Groups[3].Value)

  [pscustomobject]@{
    ProcessId       = $processId
    ParentProcessId = $parentProcessId
    Name            = $name
  }
}

function ConvertFrom-UnixCommandLine {
  param([string]$Line)

  if ([string]::IsNullOrWhiteSpace($Line)) {
    return $null
  }

  $match = [regex]::Match($Line, '^\s*(\d+)\s+(.*)$')
  if (-not $match.Success) {
    return $null
  }

  [pscustomobject]@{
    ProcessId   = [int]$match.Groups[1].Value
    CommandLine = [string]$match.Groups[2].Value
  }
}

function Get-TemporaryProcessInventory {
  if (Test-IsWindowsPlatform) {
    return @(Get-CimInstance Win32_Process | ForEach-Object { ConvertFrom-WindowsProcess -Process $_ })
  }

  $psCommand = Get-Command ps -CommandType Application -ErrorAction Stop
  $identityLines = & $psCommand.Source '-ww' '-axo' 'pid=,ppid=,comm='
  $commandLines = & $psCommand.Source '-ww' '-axo' 'pid=,command='

  $commandLineById = @{}
  foreach ($line in $commandLines) {
    $commandRecord = ConvertFrom-UnixCommandLine -Line $line
    if ($null -ne $commandRecord) {
      $commandLineById[[int]$commandRecord.ProcessId] = [string]$commandRecord.CommandLine
    }
  }

  $records = foreach ($line in $identityLines) {
    $identityRecord = ConvertFrom-UnixPsLine -Line $line
    if ($null -ne $identityRecord) {
      $commandLine = if ($commandLineById.ContainsKey([int]$identityRecord.ProcessId)) {
        $commandLineById[[int]$identityRecord.ProcessId]
      } else {
        [string]$identityRecord.Name
      }

      New-InventoryProcessRecord `
        -ProcessId ([int]$identityRecord.ProcessId) `
        -ParentProcessId ([int]$identityRecord.ParentProcessId) `
        -Name ([string]$identityRecord.Name) `
        -CommandLine $commandLine
    }
  }

  return @($records)
}
