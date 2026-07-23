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

# $IsLinux is not an automatic variable in Windows PowerShell 5.1 (PSEdition = 'Desktop').
# The -and operator short-circuits, so $IsLinux is never evaluated on PS 5.1.
$script:OnLinux = ($PSVersionTable.PSEdition -eq 'Core') -and $IsLinux

# ---------- Pinned configuration (bump these together) ------------------------
# https://github.com/lumen-oss/lux/releases
$script:LuxVersion    = '0.28.5'
# SHA-256 of each platform asset, keyed by the download filename.
$script:LuxSha256 = @{
    'lx_0.28.5_x64_en-US.msi'      = '562919d6e1dc72eb1cfe71aa713da4a9fa0dc055a539e7028433ee7ccc7e319e'
    'lx_0.28.5_x86_64.tar.gz'      = 'a1f5701c7f8cb0e762dcdcebc1d75b6e17c448382e26538cef453aa39f67ae99'
}
$script:LuxLuaVersion = '5.1'

# Pinned Lua binaries from https://luabinaries.sourceforge.net/download.html.
# Lux otherwise tries to compile Lua from source, which requires a C toolchain.
$script:LuaBinariesVersion = '5.1.5'
$script:LuaBinariesSha256 = @{
    'lua-5.1.5_Linux68_64_lib.tar.gz' = 'b2ba68f70e9fe98ef77d872bd158b693c386e5bc2dd9771ae72b0dd95e76945e'
    'lua-5.1.5_Linux68_64_bin.tar.gz' = '2c8c4c16dce54271b723cf5e5b41e3f933868cd2ba4e9be0415a78bc0fb201ae'
    'lua-5.1.5_Win64_vc17_lib.zip'    = 'dc555e386e4d26345b82d34b322c48dfc7ebc599531c89d7a892632f22743a6a'
    'lua-5.1.5_Win64_bin.zip'         = '5f34cf7d40a20a587ea351482a4207d93b92ef6f1983e910a13338253819fe93'
}

# ---------- Paths -------------------------------------------------------------
$script:RepoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$script:LuxStateDir = Join-Path $script:RepoRoot '.tools/lux'
$script:LuxHome     = Join-Path $script:LuxStateDir $script:LuxVersion
$script:LuxMarker   = Join-Path $script:LuxHome '.lx-path'
$script:LuaHome     = Join-Path $script:RepoRoot ".tools/lua/$($script:LuaBinariesVersion)"
$script:LuaMarker   = Join-Path $script:LuaHome '.installed'

# ---------- Internals ---------------------------------------------------------

function Get-LuxBinName {
    if ($script:OnLinux) { 'lx' } else { 'lx.exe' }
}

function Get-LuxAssetName {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "lux only ships x86_64 binaries; this OS is not 64-bit."
    }
    # Windows (PS 5.1 does not define $IsWindows, so this is the default branch)
    if ($script:OnLinux) { return "lx_$($script:LuxVersion)_x86_64.tar.gz" }
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
    if ($proc.ExitCode -ne 0) {
        throw "tar extraction of $ArchivePath failed with exit code $($proc.ExitCode)"
    }
}

function Expand-Archive-Auto {
    param([string] $Path, [string] $TargetDir)
    if ($Path -like '*.zip') {
        Expand-Archive -LiteralPath $Path -DestinationPath $TargetDir -Force
    } else {
        Expand-TarGz -ArchivePath $Path -TargetDir $TargetDir
    }
}

function Get-LuaBinariesAssets {
    if (-not [Environment]::Is64BitOperatingSystem) { return $null }
    $v = $script:LuaBinariesVersion
    if ($script:OnLinux) {
        return @(
            [PSCustomObject]@{ Name = "lua-${v}_Linux68_64_lib.tar.gz"; Subdir = 'Linux Libraries';   Kind = 'Lib'; LibGlob = 'liblua*' }
            [PSCustomObject]@{ Name = "lua-${v}_Linux68_64_bin.tar.gz"; Subdir = 'Tools Executables'; Kind = 'Bin' }
        )
    }
    # Static lib (vc17) so consumers don't need a matching lua5.1.dll on PATH at link time.
    return @(
        [PSCustomObject]@{ Name = "lua-${v}_Win64_vc17_lib.zip"; Subdir = 'Windows Libraries/Static'; Kind = 'Lib'; LibGlob = 'lua*.lib' }
        [PSCustomObject]@{ Name = "lua-${v}_Win64_bin.zip";      Subdir = 'Tools Executables';        Kind = 'Bin' }
    )
}

function Get-LuaBinariesUrl {
    param([Parameter(Mandatory)] [string] $Asset, [Parameter(Mandatory)] [string] $Subdir)
    "https://sourceforge.net/projects/luabinaries/files/$($script:LuaBinariesVersion)/$Subdir/$Asset/download"
}

function Save-VerifiedDownload {
    param(
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $OutPath,
        [Parameter(Mandatory)] [string] $ExpectedSha256,
        [string] $UserAgent
    )
    # Windows PowerShell 5.1 defaults to TLS 1.0/1.1; GitHub and many CDNs require 1.2+.
    if (-not $script:OnLinux) {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol
    }
    Write-Host "Downloading $Url"
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # ~10x faster Invoke-WebRequest on PS 5.1
    try {
        $params = @{
            Uri                = $Url
            OutFile            = $OutPath
            UseBasicParsing    = $true
            TimeoutSec         = 240
            MaximumRedirection = 10
        }
        if ($UserAgent) { $params['UserAgent'] = $UserAgent }
        Invoke-WebRequest @params
    } finally {
        $ProgressPreference = $oldProgress
    }
    $expected = $ExpectedSha256.ToUpperInvariant()
    $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutPath).Hash
    if ($actual -ne $expected) {
        Remove-Item -LiteralPath $OutPath -Force -ErrorAction Ignore
        throw "SHA-256 mismatch for $Url`nExpected: $expected`nActual:   $actual"
    }
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

    Remove-Item -LiteralPath $script:LuxHome -Recurse -Force -ErrorAction Ignore
    New-Item -ItemType Directory -Force -Path $script:LuxHome | Out-Null

    $asset   = Get-LuxAssetName
    $url     = Get-LuxDownloadUrl -Asset $asset
    $tempDir = [System.IO.Path]::GetTempPath()
    $dlPath  = Join-Path $tempDir $asset

    Save-VerifiedDownload -Url $url -OutPath $dlPath -ExpectedSha256 $script:LuxSha256[$asset]

    Write-Host "Extracting to $script:LuxHome"
    try {
        if ($script:OnLinux) {
            Expand-TarGz -ArchivePath $dlPath -TargetDir $script:LuxHome
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

function Test-LuaInstalled {
    if (-not (Test-Path -LiteralPath $script:LuaMarker)) { return $false }
    $stamp = (Get-Content -LiteralPath $script:LuaMarker -Raw).Trim()
    return $stamp -eq $script:LuaBinariesVersion
}

function Install-Lua {
    [CmdletBinding()]
    param([switch] $Force)

    $assets = Get-LuaBinariesAssets
    if (-not $assets) {
        # No prebuilt binaries available for this platform; let lux try its own thing.
        return $null
    }

    if (-not $Force -and (Test-LuaInstalled)) { return $script:LuaHome }

    Remove-Item -LiteralPath $script:LuaHome -Recurse -Force -ErrorAction Ignore
    New-Item -ItemType Directory -Force -Path (Join-Path $script:LuaHome 'lib') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $script:LuaHome 'bin') | Out-Null

    # SourceForge serves an HTML download page to browser-like User-Agents and the actual
    # file otherwise; force a curl-style UA so the redirect chain reaches a mirror.
    $sfUa    = 'curl/8.0'
    $tempDir = [System.IO.Path]::GetTempPath()
    foreach ($asset in $assets) {
        $dlPath = Join-Path $tempDir $asset.Name
        $stage  = Join-Path $tempDir "lua-stage-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        try {
            Save-VerifiedDownload -Url (Get-LuaBinariesUrl -Asset $asset.Name -Subdir $asset.Subdir) `
                -OutPath $dlPath -ExpectedSha256 $script:LuaBinariesSha256[$asset.Name] -UserAgent $sfUa
            if ($asset.Kind -eq 'Bin') {
                # Bin archive is flat: dropping it into <prefix>/bin keeps the DLL/runtime beside the .exe.
                Expand-Archive-Auto -Path $dlPath -TargetDir (Join-Path $script:LuaHome 'bin')
            } else {
                Expand-Archive-Auto -Path $dlPath -TargetDir $stage
                Move-Item -LiteralPath (Join-Path $stage 'include') -Destination $script:LuaHome
                Get-ChildItem -LiteralPath $stage -Filter $asset.LibGlob -File |
                    ForEach-Object { Move-Item -LiteralPath $_.FullName -Destination (Join-Path $script:LuaHome 'lib') }
            }
        } finally {
            Remove-Item -LiteralPath $dlPath -Force -ErrorAction Ignore
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Ignore
        }
    }

    Set-Content -LiteralPath $script:LuaMarker -Value $script:LuaBinariesVersion -Encoding ASCII
    Write-Host "Installed Lua $($script:LuaBinariesVersion) -> $script:LuaHome"
    return $script:LuaHome
}

function Invoke-Lux {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $LuxArgs
    )
    $bin       = Install-Lux
    $luaPrefix = Install-Lua
    $defaults  = @('--lua-version', $script:LuxLuaVersion)
    if ($luaPrefix) { $defaults += @('--lua-dir', $luaPrefix) }
    & $bin @defaults @LuxArgs
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "lx exited with code $code"
    }
}

Set-Alias -Name lx -Value Invoke-Lux

Export-ModuleMember -Function Install-Lux, Install-Lua, Invoke-Lux, Test-LuxInstalled, Test-LuaInstalled, Get-LuxBinPath -Alias lx

