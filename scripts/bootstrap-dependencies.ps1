# Copyright 2026 NInferEZ Engine contributors.
# SPDX-License-Identifier: Apache-2.0
[CmdletBinding()]
param([string]$VcpkgRoot)

$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not $VcpkgRoot) { $VcpkgRoot = Join-Path $RepoRoot '.deps\vcpkg' }
$VcpkgRoot = [IO.Path]::GetFullPath($VcpkgRoot)
$depsPrefix = (Join-Path $RepoRoot '.deps').TrimEnd([IO.Path]::DirectorySeparatorChar) +
    [IO.Path]::DirectorySeparatorChar
if (-not $VcpkgRoot.StartsWith($depsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "VcpkgRoot must remain under $depsPrefix"
}
$Manifest = Get-Content -LiteralPath (Join-Path $RepoRoot 'vcpkg.json') -Raw | ConvertFrom-Json
$VcpkgCommit = $Manifest.'builtin-baseline'
if (-not $VcpkgCommit -or $VcpkgCommit -notmatch '^[0-9a-f]{40}$') {
    throw 'vcpkg.json must pin a 40-character builtin-baseline.'
}

if (-not (Test-Path -LiteralPath (Join-Path $VcpkgRoot '.git'))) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $VcpkgRoot) | Out-Null
    git clone https://github.com/microsoft/vcpkg.git $VcpkgRoot
    if ($LASTEXITCODE -ne 0) { throw 'vcpkg clone failed.' }
}

git -C $VcpkgRoot cat-file -e "$VcpkgCommit^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) {
    git -C $VcpkgRoot fetch origin $VcpkgCommit
    if ($LASTEXITCODE -ne 0) { throw "Could not fetch pinned vcpkg commit $VcpkgCommit." }
}
git -C $VcpkgRoot checkout --detach $VcpkgCommit
if ($LASTEXITCODE -ne 0) { throw "Could not check out pinned vcpkg commit $VcpkgCommit." }

& (Join-Path $VcpkgRoot 'bootstrap-vcpkg.bat') -disableMetrics
if ($LASTEXITCODE -ne 0) { throw 'vcpkg bootstrap failed.' }
$InstallRoot = Join-Path $RepoRoot '.deps\vcpkg-deps\installed'
& (Join-Path $VcpkgRoot 'vcpkg.exe') install --triplet x64-windows `
    --x-manifest-root=$RepoRoot --x-install-root=$InstallRoot
if ($LASTEXITCODE -ne 0) { throw 'vcpkg dependency installation failed.' }

Write-Host "Dependencies installed under $(Join-Path $RepoRoot '.deps\vcpkg-deps\installed\x64-windows')"
