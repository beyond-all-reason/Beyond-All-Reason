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
	[switch]$AllowPush,
	[switch]$NoShader
)

$ErrorActionPreference = 'Stop'
$dataPath = (Resolve-Path -LiteralPath $DataDir).ProviderPath
if (-not (Test-Path -LiteralPath (Join-Path $dataPath 'MapProjects') -PathType Container)) {
	throw 'Choose the BAR writable data directory containing MapProjects. Save a project in-game first if needed.'
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$git = @(Get-Command git -CommandType Application -ErrorAction Stop)[0].Source
# PATH commonly holds several python.exe: a Microsoft Store stub that is not
# Python, older versions, and real ones. Get-Command returns them all, so take
# the first that actually reports 3.12+ instead of whichever comes first.
$python = $null
$rejected = @()
foreach ($candidate in @(Get-Command $PythonExecutable -CommandType Application -ErrorAction SilentlyContinue)) {
	$reported = $null
	try { $reported = & $candidate.Source -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null } catch { }
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($reported)) {
		$rejected += ('{0} (not a working Python)' -f $candidate.Source)
		continue
	}
	$parts = $reported.Trim().Split('.')
	if ([int]$parts[0] -gt 3 -or ([int]$parts[0] -eq 3 -and [int]$parts[1] -ge 12)) {
		$python = $candidate.Source
		break
	}
	$rejected += ('{0} (Python {1}, needs 3.12+)' -f $candidate.Source, $reported.Trim())
}
if (-not $python) {
	$detail = if ($rejected) { "`nChecked: `n  " + ($rejected -join "`n  ") } else { '' }
	throw "No Python 3.12+ found. Install one, or pass -PythonExecutable with a full path.$detail"
}
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
if (-not $NoShader) {
	# Same companion, second repository: the tileset shader and its textures.
	# Read only in both directions; -NoShader turns the in-game update row off.
	$helperArgs += @('--shader-remote', 'https://github.com/beyond-all-reason/tileset-shader.git',
		'--shader-branch', 'main')
}

if ($PSCmdlet.ShouldProcess('beyond-all-reason/CampaignMaps [main]', 'Start map-library companion')) {
	& $python @helperArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Map-library companion exited with code $LASTEXITCODE. See its status and the setup guide."
	}
}
