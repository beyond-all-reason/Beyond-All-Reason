#Requires -Version 5.1
<#
.SYNOPSIS
Starts the CampaignMaps companion using the mapper's existing Git identity.
.DESCRIPTION
Uses beyond-all-reason/CampaignMaps on main over HTTPS. Authentication stays
in the existing Git credential manager. Read-only unless -AllowPush is given;
uploads still require confirmation in Terraform Brush. Ctrl+C stops the helper.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[string]$DataDir,
	[ValidateNotNullOrEmpty()]
	[string]$PythonExecutable = 'python',
	[string]$Author,
	[string]$Email,
	[string[]]$Stage = @(),
	[switch]$AllowPush
)

$ErrorActionPreference = 'Stop'
$dataPath = (Resolve-Path -LiteralPath $DataDir).ProviderPath
if (-not (Test-Path -LiteralPath (Join-Path $dataPath 'MapProjects') -PathType Container)) {
	throw 'Choose the BAR writable data directory containing MapProjects. Save a project in-game first if needed.'
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$git = (Get-Command git -CommandType Application -ErrorAction Stop).Source
$python = (Get-Command $PythonExecutable -CommandType Application -ErrorAction Stop).Source
if ([string]::IsNullOrWhiteSpace($Author)) {
	$Author = & $git -C $repositoryRoot config user.name
	if ($LASTEXITCODE -ne 0) {
		throw 'Set a Git user.name or supply -Author. No Git settings were changed.'
	}
}
if ([string]::IsNullOrWhiteSpace($Email)) {
	$Email = & $git -C $repositoryRoot config user.email
	if ($LASTEXITCODE -ne 0) {
		throw 'Set a Git user.email or supply -Email (a GitHub noreply address is supported).'
	}
}

$helperArgs = @(
	'-u', (Join-Path $PSScriptRoot 'map_library.py'),
	'--data-dir', $dataPath,
	'--remote', 'https://github.com/beyond-all-reason/CampaignMaps.git',
	'--branch', 'main',
	'--author', $Author,
	'--email', $Email
)
foreach ($folder in $Stage) {
	$helperArgs += @('--stage', $folder)
}
if ($AllowPush) {
	$helperArgs += '--allow-push'
}

if ($PSCmdlet.ShouldProcess('beyond-all-reason/CampaignMaps [main]', 'Start map-library companion')) {
	& $python @helperArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Map-library companion exited with code $LASTEXITCODE. See its status and the setup guide."
	}
}
