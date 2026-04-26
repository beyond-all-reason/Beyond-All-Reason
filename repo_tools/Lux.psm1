<#
.SYNOPSIS
    Bootstraps the Lux Lua package manager into a repo-local directory.

.DESCRIPTION
    Pinned, idempotent, no-admin install of lux-cli (https://github.com/lumen-oss/lux)
    under <repo>/.tools/lux/<version>/. Other PowerShell scripts import this module
    and call Invoke-Lux to run lx with the pinned version.

    Supports Windows (via MSI) and Linux x64 (via tar.gz). Requires PowerShell 7+
    on Linux; Windows can use either PowerShell 5.1 or 7+.

    Layout assumption: this module lives at <repo>/repo_tools/Lux.psm1.

.EXAMPLE
    Import-Module "$PSScriptRoot/repo_tools/Lux.psm1" -Force
    Invoke-Lux help
#>

#Requires -Version 5.1

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# ---------- Pinned configuration (bump these together) ------------------------
# https://github.com/lumen-oss/lux/releases
$script:LuxVersion    = '0.28.5'
# SHA-256 of each platform asset, keyed by the download filename.
$script:LuxSha256 = @{
    'lx_0.28.5_x64_en-US.msi'      = '562919d6e1dc72eb1cfe71aa713da4a9fa0dc055a539e7028433ee7ccc7e319e'
    'lx_0.28.5_x86_64.tar.gz'      = 'a1f5701c7f8cb0e762dcdcebc1d75b6e17c448382e26538cef453aa39f67ae99'
}
$script:LuxLuaVersion = '5.1'
$script:LuxDefaultArgs = @('--lua-version', $script:LuxLuaVersion)

# ---------- Paths -------------------------------------------------------------
$script:RepoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$script:LuxStateDir = Join-Path $script:RepoRoot '.tools/lux'
$script:LuxHome     = Join-Path $script:LuxStateDir $script:LuxVersion
$script:LuxMarker   = Join-Path $script:LuxHome '.lx-path'

# ---------- Internals ---------------------------------------------------------

function Get-LuxBinName {
    if ($IsLinux) { 'lx' } else { 'lx.exe' }
}

function Get-LuxAssetName {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "lux only ships x86_64 binaries; this OS is not 64-bit."
    }
    # Windows (PS 5.1 does not define $IsWindows, so this is the default branch)
    if ($IsLinux) { return "lx_$($script:LuxVersion)_x86_64.tar.gz" }
    return "lx_$($script:LuxVersion)_x64_en-US.msi"
}

function Get-LuxDownloadUrl {
    param([string] $Asset = (Get-LuxAssetName))
    "https://github.com/lumen-oss/lux/releases/download/v$($script:LuxVersion)/$Asset"
}

function Get-LuxBinPath {
    if (Test-Path -LiteralPath $script:LuxMarker) {
        $p = (Get-Content -LiteralPath $script:LuxMarker -Raw).Trim()
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    return $null
}

function Find-LuxBin {
    param([string] $SearchDir)
    Get-ChildItem -LiteralPath $SearchDir -Filter (Get-LuxBinName) -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Test-LuxBinVersion {
    param([string] $BinPath)
    try {
        $out = & $BinPath --version 2>$null
        return ($LASTEXITCODE -eq 0 -and $out -match ('(?<![\d.])' + [regex]::Escape($script:LuxVersion) + '(?![\d.])'))
    } catch { return $false }
}

function Test-LuxInstalled {
    $bin = Get-LuxBinPath
    if (-not $bin) { return $false }
    return (Test-LuxBinVersion $bin)
}

function Expand-MsiPayload {
    param(
        [Parameter(Mandatory)] [string] $MsiPath,
        [Parameter(Mandatory)] [string] $TargetDir,
        [Parameter(Mandatory)] [string] $LogPath
    )
    # msiexec quoting is finicky; build the command line explicitly.
    # /a = administrative install (extract payload only — no admin rights, registry, or shortcuts).
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'msiexec.exe'
    $psi.Arguments = '/a "{0}" /qn TARGETDIR="{1}" /L*v "{2}"' -f $MsiPath, $TargetDir, $LogPath
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    $code = $proc.ExitCode
    $proc.Dispose()
    return $code
}

function Expand-TarGz {
    param(
        [Parameter(Mandatory)] [string] $ArchivePath,
        [Parameter(Mandatory)] [string] $TargetDir
    )
    $proc = Start-Process -FilePath 'tar' -ArgumentList @('-xzf', $ArchivePath, '-C', $TargetDir) `
        -Wait -PassThru -NoNewWindow
    return $proc.ExitCode
}

# ---------- Public API --------------------------------------------------------

function Install-Lux {
    [CmdletBinding()]
    param([switch] $Force)

    if (-not $Force -and (Test-LuxInstalled)) { return Get-LuxBinPath }

    # This version may already be extracted (e.g. switching back to a commit that pinned it).
    if (-not $Force) {
        $cached = Find-LuxBin $script:LuxHome
        if ($cached -and (Test-LuxBinVersion $cached.FullName)) {
            Set-Content -LiteralPath $script:LuxMarker -Value $cached.FullName -Encoding ASCII
            Write-Host "lux $($script:LuxVersion) already cached -> $($cached.FullName)"
            return $cached.FullName
        }
    }

    # Windows PowerShell 5.1 defaults to TLS 1.0/1.1; GitHub requires 1.2+.
    if (-not $IsLinux) {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol
    }

    if (Test-Path -LiteralPath $script:LuxHome) {
        Remove-Item -LiteralPath $script:LuxHome -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $script:LuxHome | Out-Null

    $asset    = Get-LuxAssetName
    $url      = Get-LuxDownloadUrl -Asset $asset
    $tempDir  = [System.IO.Path]::GetTempPath()
    $dlPath   = Join-Path $tempDir $asset

    Write-Host "Downloading $url"
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # ~10x faster Invoke-WebRequest on PS 5.1
    try {
        Invoke-WebRequest -Uri $url -OutFile $dlPath -UseBasicParsing -TimeoutSec 240
    } finally {
        $ProgressPreference = $oldProgress
    }

    $expectedHash = $script:LuxSha256[$asset].ToUpperInvariant()
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dlPath).Hash
    if ($hash -ne $expectedHash) {
        Remove-Item -LiteralPath $dlPath -Force -ErrorAction Ignore
        throw "SHA-256 mismatch for $url`nExpected: $expectedHash`nActual:   $hash"
    }

    Write-Host "Extracting to $script:LuxHome"
    try {
        if ($IsLinux) {
            $exitCode = Expand-TarGz -ArchivePath $dlPath -TargetDir $script:LuxHome
            if ($exitCode -ne 0) {
                throw "tar extraction failed with exit code $exitCode"
            }
        } else {
            $logPath  = Join-Path $tempDir "lx_$($script:LuxVersion)_install.log"
            $exitCode = Expand-MsiPayload -MsiPath $dlPath -TargetDir $script:LuxHome -LogPath $logPath
            if ($exitCode -ne 0) {
                throw "msiexec /a failed with exit code $exitCode; see log: $logPath"
            }
        }
    } finally {
        Remove-Item -LiteralPath $dlPath -Force -ErrorAction Ignore
    }

    $found = Find-LuxBin $script:LuxHome
    if (-not $found) {
        throw "$(Get-LuxBinName) not found under $script:LuxHome after extraction."
    }
    if (-not (Test-LuxBinVersion $found.FullName)) {
        $reported = & $found.FullName --version 2>&1
        throw "lux installed but 'lx --version' did not report $($script:LuxVersion). Got: $reported"
    }
    Set-Content -LiteralPath $script:LuxMarker -Value $found.FullName -Encoding ASCII

    Write-Host "Installed lux $($script:LuxVersion) -> $($found.FullName)"
    return $found.FullName
}

function Invoke-Lux {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $LuxArgs
    )
    $bin = Install-Lux
    & $bin @script:LuxDefaultArgs @LuxArgs
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "lx exited with code $code"
    }
}

Set-Alias -Name lx -Value Invoke-Lux

Export-ModuleMember -Function Install-Lux, Invoke-Lux, Test-LuxInstalled, Get-LuxBinPath -Alias lx
