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

function ConvertFrom-UnixPsLine {
  param([string]$Line)

  if ([string]::IsNullOrWhiteSpace($Line)) {
    return $null
  }

  $match = [regex]::Match($Line, '^\s*(\d+)\s+(\d+)\s+(\S+)(?:\s+(.*))?$')
  if (-not $match.Success) {
    return $null
  }

  $processId = [int]$match.Groups[1].Value
  $parentProcessId = [int]$match.Groups[2].Value
  $name = [string]$match.Groups[3].Value
  $commandLine = [string]$match.Groups[4].Value

  return New-InventoryProcessRecord `
    -ProcessId $processId `
    -ParentProcessId $parentProcessId `
    -Name $name `
    -CommandLine $commandLine
}

function Get-TemporaryProcessInventory {
  if (Test-IsWindowsPlatform) {
    return @(Get-CimInstance Win32_Process | ForEach-Object { ConvertFrom-WindowsProcess -Process $_ })
  }

  $psCommand = Get-Command ps -CommandType Application -ErrorAction Stop
  $lines = & $psCommand.Source -axo 'pid=,ppid=,comm=,args='

  $records = foreach ($line in $lines) {
    $record = ConvertFrom-UnixPsLine -Line $line
    if ($null -ne $record) {
      $record
    }
  }

  return @($records)
}
