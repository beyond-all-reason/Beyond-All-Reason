#Requires -Version 5.1
param([Parameter(Mandatory)] [string] $Command)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Lux.psm1') -Force
Set-Location (Join-Path $PSScriptRoot '..')

switch ($Command) {
    'install'       { lx build --only-deps }
    'debug-project' { lx debug project }
    default         { throw "Unknown command: '$Command'. Valid commands: install, debug-project" }
}
