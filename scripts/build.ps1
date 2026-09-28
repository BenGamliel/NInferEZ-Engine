# Modified by NInferEZ Engine in 2026: one reproducible Windows build entry point for every target.
[CmdletBinding()]
param(
    [ValidateSet('86', '89', '120a')][string]$Arch = '120a',
    [switch]$Test,
    [switch]$Package,
    [switch]$Clean,
    [switch]$Benchmarks,
    [string[]]$Target,
    [string]$BuildDir,
    [string]$DependencyRoot,
    [string]$CudaRoot,
    [ValidateRange(1, 64)][int]$Jobs = 8
)

$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not $BuildDir) { $BuildDir = Join-Path $RepoRoot "build-sm$Arch" }
$BuildDir = [IO.Path]::GetFullPath($BuildDir)

# Clean is intentionally limited to a named build directory inside this repository.
$repoPrefix = $RepoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $BuildDir.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    -not (Split-Path -Leaf $BuildDir).StartsWith('build-', [StringComparison]::OrdinalIgnoreCase)) {
    throw "BuildDir must be a build-* directory inside the repository: $BuildDir"
}

$VcVarsCandidates = @(
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat'
)
$VcVars = $VcVarsCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $VcVars) { throw 'Visual Studio 2022 with Desktop development for C++ is required.' }

if (-not $CudaRoot) {
    $CudaCandidates = @($env:NINFEREZ_CUDA_ROOT,
        'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.1',
        'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9',
        'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8',
        $env:CUDA_PATH) |
        Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin\nvcc.exe')) }
    $CudaRoot = $CudaCandidates | Select-Object -First 1
}
if (-not $CudaRoot -or -not (Test-Path -LiteralPath (Join-Path $CudaRoot 'bin\nvcc.exe'))) {
    throw 'CUDA 12.8 or newer is required. Pass -CudaRoot or set NINFEREZ_CUDA_ROOT.'
}
$CudaRoot = [IO.Path]::GetFullPath($CudaRoot)

if (-not $DependencyRoot) {
    $DependencyCandidates = @($env:NINFEREZ_DEPENDENCY_ROOT,
        (Join-Path $RepoRoot '.deps\vcpkg-deps\installed\x64-windows'),
        (Join-Path $RepoRoot 'vcpkg_installed\x64-windows')) |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $DependencyRoot = $DependencyCandidates | Select-Object -First 1
}
if (-not $DependencyRoot -or -not (Test-Path -LiteralPath $DependencyRoot)) {
    throw 'Windows dependencies are missing. Run scripts\bootstrap-dependencies.ps1 or pass -DependencyRoot.'
}
$DependencyRoot = [IO.Path]::GetFullPath($DependencyRoot)

$NinjaCandidates = @(
    (Get-Command ninja.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe',
    'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
$Ninja = $NinjaCandidates | Select-Object -First 1
if (-not $Ninja) { throw 'Ninja is required and was not found.' }

$VcPath = $null
$VcEnvironment = cmd /c "`"$VcVars`" >nul 2>&1 && set"
$VcEnvironment | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $Name = $Matches[1]
        $Value = $Matches[2]
        # The sandbox can expose both Path and PATH. vcvars writes the complete toolchain value as
        # PATH; importing the stale mixed-case copy afterwards would hide rc.exe and cl.exe again.
        if ($Name -ceq 'PATH') { $VcPath = $Value }
        elseif ($Name -ine 'PATH') { Set-Item -Path "Env:$Name" -Value $Value }
    }
}
if (-not $VcPath) { throw 'vcvars did not return a PATH value.' }
$env:Path = $VcPath
$CompilerBin = Join-Path $env:VCToolsInstallDir 'bin\Hostx64\x64'
if (-not (Test-Path -LiteralPath (Join-Path $CompilerBin 'cl.exe'))) {
    throw "vcvars did not expose a usable x64 compiler: $CompilerBin"
}
$env:Path = "$CompilerBin;$($env:Path)"
$env:CUDA_PATH = $CudaRoot
$env:CUDACXX = Join-Path $CudaRoot 'bin\nvcc.exe'
$env:VCPKG_ROOT = Split-Path -Parent (Split-Path -Parent $DependencyRoot)
$env:VCPKG_TARGET_TRIPLET = 'x64-windows'

if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
    Write-Host "Removing $BuildDir"
    Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

$TestingOption = if ($Test) { 'ON' } else { 'OFF' }
$BenchmarksOption = if ($Benchmarks) { 'ON' } else { 'OFF' }
$configure = @(
    '-S', $RepoRoot, '-B', $BuildDir, '-G', 'Ninja',
    "-DCMAKE_MAKE_PROGRAM=$Ninja",
    '-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_CUDA_ARCHITECTURES=$Arch",
    "-DCMAKE_CUDA_COMPILER=$env:CUDACXX",
    "-DCMAKE_PREFIX_PATH=$DependencyRoot",
    '-DVCPKG_TARGET_TRIPLET=x64-windows',
    '-DNINFER_BUILD_APPS=ON',
    "-DNINFER_BUILD_BENCHMARKS=$BenchmarksOption",
    "-DBUILD_TESTING=$TestingOption"
)

Write-Host "NInferEZ Engine target: sm$Arch"
Write-Host "CUDA: $CudaRoot"
Write-Host "Dependencies: $DependencyRoot"
& cmake @configure
if ($LASTEXITCODE -ne 0) { throw "Configure failed ($LASTEXITCODE)." }

$build = @('--build', $BuildDir, '--parallel', $Jobs)
if ($Target) { $build += @('--target') + $Target }
& cmake @build
if ($LASTEXITCODE -ne 0) { throw "Build failed ($LASTEXITCODE)." }

$ServeProduct = Join-Path $BuildDir 'apps\ninfer-serve.exe'
$InspectProduct = Join-Path $BuildDir 'apps\ninfer-inspect.exe'
if ((Test-Path -LiteralPath $ServeProduct) -and (Test-Path -LiteralPath $InspectProduct)) {
    & (Join-Path $PSScriptRoot 'test-contract.ps1') -BuildRoot $BuildDir -ExpectedArch $Arch
}

if ($Test) {
    & ctest --test-dir $BuildDir -j2 --output-on-failure
    if ($LASTEXITCODE -ne 0) { throw "Tests failed ($LASTEXITCODE)." }
}

if ($Package) {
    & (Join-Path $PSScriptRoot 'package-release.ps1') -Arch $Arch -BuildRoot $BuildDir
    if ($LASTEXITCODE -ne 0) { throw "Packaging failed ($LASTEXITCODE)." }
}

Write-Host "Built NInferEZ Engine sm$Arch in $BuildDir"
