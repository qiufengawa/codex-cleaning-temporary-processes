$libraryPath = Join-Path $PSScriptRoot 'process-inventory.ps1'

Describe 'Unix inventory parsing' {
  It 'parses a standard unix identity line' {
    . $libraryPath

    $record = ConvertFrom-UnixPsLine -Line '  321   1 python3'

    $record.ProcessId | Should Be 321
    $record.ParentProcessId | Should Be 1
    $record.Name | Should Be 'python3'
  }

  It 'reduces app bundle executable paths to a stable process name' {
    . $libraryPath

    $record = ConvertFrom-UnixPsLine -Line '  654   1 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

    $record.ProcessId | Should Be 654
    $record.ParentProcessId | Should Be 1
    $record.Name | Should Be 'Google Chrome'
  }

  It 'parses a unix command line without losing spaces in the executable path' {
    . $libraryPath

    $record = ConvertFrom-UnixCommandLine -Line '  654 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-port=9222'

    $record.ProcessId | Should Be 654
    $record.CommandLine | Should Be '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-port=9222'
  }

  It 'falls back to the process name when the command line is empty' {
    . $libraryPath

    $identityRecord = ConvertFrom-UnixPsLine -Line '  777   1 bash'
    $commandRecord = ConvertFrom-UnixCommandLine -Line '  777 bash'

    $identityRecord.Name | Should Be 'bash'
    $commandRecord.CommandLine | Should Be 'bash'
  }
}
