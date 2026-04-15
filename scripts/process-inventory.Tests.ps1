$libraryPath = Join-Path $PSScriptRoot 'process-inventory.ps1'

Describe 'ConvertFrom-UnixPsLine' {
  It 'parses a standard unix ps output line' {
    . $libraryPath

    $record = ConvertFrom-UnixPsLine -Line '  321   1 python3 python3 -m uvicorn app.main:app --app-dir /repo'

    $record.ProcessId | Should Be 321
    $record.ParentProcessId | Should Be 1
    $record.Name | Should Be 'python3'
    $record.CommandLine | Should Be 'python3 -m uvicorn app.main:app --app-dir /repo'
  }

  It 'falls back to the process name when the args column is empty' {
    . $libraryPath

    $record = ConvertFrom-UnixPsLine -Line '  654   1 bash'

    $record.ProcessId | Should Be 654
    $record.ParentProcessId | Should Be 1
    $record.Name | Should Be 'bash'
    $record.CommandLine | Should Be 'bash'
  }
}
