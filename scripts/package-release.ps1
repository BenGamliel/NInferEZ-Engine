# Modified by NInferEZ Engine in 2026: target-aware, self-contained Windows release packaging.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('86', '89', '120a')][string]$Arch,
    [string]$BuildRoot,
    [ValidateSet('preview', 'stable')][string]$Channel = 'preview',
    [string]$CudaRoot,
    [string]$DependencyRoot,
    [string]$VCRuntimeRoot,
    [switch]$IncludeCli,
    [string]$QualificationReport
)

$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not $BuildRoot) { $BuildRoot = Join-Path $RepoRoot "build-sm$Arch" }
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
$Version = (Get-Content -LiteralPath (Join-Path $RepoRoot 'VERSION') -Raw).Trim()
if (-not $Version) { throw 'VERSION is empty.' }

$CachePath = Join-Path $BuildRoot 'CMakeCache.txt'
if (-not (Test-Path -LiteralPath $CachePath)) { throw "Missing build cache: $CachePath" }
$Cache = Get-Content -LiteralPath $CachePath
function Get-CMakeCacheValue([string]$Name) {
    $Match = $Cache | Select-String "^$([regex]::Escape($Name)):[^=]+=(.*)$" | Select-Object -First 1
    if ($Match -and $Match.Matches.Count) { return $Match.Matches[0].Groups[1].Value }
    return $null
}

$BuiltArch = Get-CMakeCacheValue 'CMAKE_CUDA_ARCHITECTURES'
if ($BuiltArch -ne $Arch) { throw "Build target is sm$BuiltArch, not requested sm$Arch." }

if ($Channel -eq 'stable') {
    if (-not $QualificationReport -or -not (Test-Path -LiteralPath $QualificationReport -PathType Leaf)) {
        throw 'A Stable package requires -QualificationReport from a real-GPU qualification run.'
    }
    $Qualification = Get-Content -LiteralPath $QualificationReport -Raw | ConvertFrom-Json
    if (-not $Qualification.passed -or $Qualification.cudaArchitecture -ne "sm$Arch" -or
        $Qualification.gpuUsed -ne $true) {
        throw "Qualification report does not prove a passing real-GPU sm$Arch run."
    }
}

if (-not $CudaRoot) {
    $CudaRoot = Get-CMakeCacheValue 'CUDAToolkit_ROOT'
}
if (-not $CudaRoot) {
    $CudaCompiler = Get-CMakeCacheValue 'CMAKE_CUDA_COMPILER'
    if ($CudaCompiler) { $CudaRoot = Split-Path -Parent (Split-Path -Parent $CudaCompiler) }
}
if (-not $CudaRoot) { $CudaRoot = $env:CUDA_PATH }
if (-not $CudaRoot -or -not (Test-Path -LiteralPath $CudaRoot)) {
    throw 'CUDA Toolkit root could not be determined from the build cache or CUDA_PATH.'
}
$CudaRoot = [IO.Path]::GetFullPath($CudaRoot)

if (-not $DependencyRoot) {
    $DependencyRoot = Get-CMakeCacheValue 'CMAKE_PREFIX_PATH'
}
if (-not $DependencyRoot -or -not (Test-Path -LiteralPath $DependencyRoot)) {
    throw 'Dependency root could not be determined from the build cache.'
}
$DependencyRoot = [IO.Path]::GetFullPath($DependencyRoot)

$DistRoot = Join-Path $RepoRoot 'dist'
$ProductName = "NInferEZ-Engine-$Version-sm$Arch-windows-x64"
$ProductRoot = Join-Path $DistRoot $ProductName
$ArchivePath = Join-Path $DistRoot "$ProductName.zip"
$resolvedDist = [IO.Path]::GetFullPath($DistRoot)
$resolvedProduct = [IO.Path]::GetFullPath($ProductRoot)
if ((Split-Path -Parent $resolvedProduct) -ne $resolvedDist -or
    (Split-Path -Leaf $resolvedProduct) -ne $ProductName) {
    throw "Refusing to package outside the expected dist directory: $ProductRoot"
}

New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
if (Test-Path -LiteralPath $ProductRoot) { Remove-Item -LiteralPath $ProductRoot -Recurse -Force }
if (Test-Path -LiteralPath $ArchivePath) { Remove-Item -LiteralPath $ArchivePath -Force }
New-Item -ItemType Directory -Path $ProductRoot | Out-Null

$Products = @(
    @{ Source = 'apps\ninfer-serve.exe'; Destination = 'ninfer-serve.exe' },
    @{ Source = 'apps\ninfer-inspect.exe'; Destination = 'ninfer-inspect.exe' }
)
if ($IncludeCli) {
    $Products += @{ Source = 'apps\ninfer.exe'; Destination = 'ninfer.exe' }
}
foreach ($Product in $Products) {
    $Source = Join-Path $BuildRoot $Product.Source
    if (-not (Test-Path -LiteralPath $Source)) { throw "Missing release product: $Source" }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $ProductRoot $Product.Destination)
}
Get-ChildItem -LiteralPath (Join-Path $BuildRoot 'apps') -Filter '*.dll' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $ProductRoot
}

$CudaBins = @((Join-Path $CudaRoot 'bin'), (Join-Path $CudaRoot 'bin\x64')) |
    Where-Object { Test-Path -LiteralPath $_ }
foreach ($Pattern in @('cublas64_*.dll', 'cublasLt64_*.dll')) {
    $CudaMatches = @($CudaBins | ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter $Pattern } |
        Sort-Object Name -Unique)
    if ($CudaMatches.Count -ne 1) { throw "Expected one $Pattern under $CudaRoot; found $($CudaMatches.Count)." }
    Copy-Item -LiteralPath $CudaMatches[0].FullName -Destination $ProductRoot
}
$CudaEula = Join-Path $CudaRoot 'EULA.txt'
if (-not (Test-Path -LiteralPath $CudaEula)) { throw "Missing CUDA EULA: $CudaEula" }

if (-not $VCRuntimeRoot) {
    $VsRoots = @(
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC',
        'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional\VC\Redist\MSVC',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\Enterprise\VC\Redist\MSVC'
    )
    $VCRuntimeRoot = $VsRoots | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Directory | Sort-Object Name -Descending | ForEach-Object {
            Join-Path $_.FullName 'x64\Microsoft.VC143.CRT'
        }
    } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $VCRuntimeRoot -or -not (Test-Path -LiteralPath $VCRuntimeRoot -PathType Container)) {
    throw 'Visual C++ 2022 x64 redistributable files were not found. Pass -VCRuntimeRoot.'
}
foreach ($Name in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    $Source = Join-Path $VCRuntimeRoot $Name
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Missing required Visual C++ runtime file: $Source"
    }
    Copy-Item -LiteralPath $Source -Destination $ProductRoot
}

$LicenseRoot = Join-Path $ProductRoot 'licenses'
New-Item -ItemType Directory -Path $LicenseRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $RepoRoot 'LICENSE') -Destination (Join-Path $LicenseRoot 'NInfer-Apache-2.0.txt')
Copy-Item -LiteralPath $CudaEula -Destination (Join-Path $LicenseRoot 'NVIDIA-CUDA-EULA.txt')
[IO.File]::WriteAllText(
    (Join-Path $LicenseRoot 'Microsoft-Visual-C-Runtime-NOTICE.txt'),
    "This package uses app-local Microsoft Visual C++ 2022 x64 Redistributable files. Redistribution is subject to the Microsoft Software License Terms. See https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files`r`n",
    [Text.UTF8Encoding]::new($false))
$ThirdPartyLicenses = @(
    @('third_party\cpp-httplib\LICENSE', 'cpp-httplib-MIT.txt'),
    @('third_party\ggml-quants\LICENSE', 'ggml-quants-MIT.txt'),
    @('third_party\llama-jinja\LICENSE', 'llama-jinja-MIT.txt'),
    @('third_party\llama-jinja\UNICODE-LICENSE', 'llama-jinja-UNICODE.txt'),
    @('third_party\nlohmann\LICENSE.MIT', 'nlohmann-json-MIT.txt'),
    @('third_party\spdlog\LICENSE', 'spdlog-MIT.txt'),
    @('third_party\spdlog\include\spdlog\fmt\bundled\fmt.license.rst', 'fmt-MIT.txt'),
    @('third_party\utf8proc\LICENSE.md', 'utf8proc.txt'),
    @('third_party\xgrammar\LICENSE', 'xgrammar-Apache-2.0.txt'),
    @('third_party\xgrammar\NOTICE', 'xgrammar-NOTICE.txt'),
    @('third_party\xgrammar\3rdparty\dlpack\LICENSE', 'dlpack-Apache-2.0.txt')
)
foreach ($License in $ThirdPartyLicenses) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot $License[0]) -Destination (Join-Path $LicenseRoot $License[1])
}
$VcpkgShare = Join-Path $DependencyRoot 'share'
$DependencyLicenses = @(
    @('curl\copyright', 'curl.txt'),
    @('ffmpeg\copyright', 'ffmpeg.txt'),
    @('zlib\copyright', 'zlib.txt')
)
foreach ($License in $DependencyLicenses) {
    $Source = Join-Path $VcpkgShare $License[0]
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Missing packaged dependency license: $Source"
    }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $LicenseRoot $License[1])
}
foreach ($Name in @('VERSION', 'UPSTREAM.md', 'CONTRIBUTORS.md', 'LICENSING.md',
                     'THIRD-PARTY-NOTICES.txt', 'RELEASE_NOTES_0.1.0.md')) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot $Name) -Destination $ProductRoot
}
Copy-Item -LiteralPath (Join-Path $RepoRoot 'docs\release-archive-windows.md') `
    -Destination (Join-Path $ProductRoot 'README.md')
Copy-Item -LiteralPath (Join-Path $RepoRoot 'docs\engine-contract.md') `
    -Destination (Join-Path $ProductRoot 'ENGINE-CONTRACT.md')

$Serve = Join-Path $ProductRoot 'ninfer-serve.exe'
$Identity = (& $Serve --version-json | Out-String | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0) { throw 'ninfer-serve --version-json failed in the package directory.' }
$Target = switch ($Arch) {
    '86' {
        @{
            Family = 'NVIDIA Ampere GPUs with compute capability 8.6'
            Models = @('NVIDIA GeForce RTX 3090', 'NVIDIA GeForce RTX 3090 Ti')
            NativeNvfp4 = $false
        }
    }
    '89' {
        @{
            Family = 'NVIDIA Ada GPUs with compute capability 8.9'
            Models = @('NVIDIA GeForce RTX 4090')
            NativeNvfp4 = $false
        }
    }
    '120a' {
        @{
            Family = 'NVIDIA Blackwell GPUs with compute capability 12.0a'
            Models = @('NVIDIA GeForce RTX 5090', 'NVIDIA RTX PRO 6000 Blackwell')
            NativeNvfp4 = $true
        }
    }
}
$GpuNames = $Target.Models
$QualificationLabel = if ($Channel -eq 'stable') { 'hardware-qualified' } else { 'build-verified-preview' }
$Manifest = [ordered]@{
    schemaVersion = 1
    contractVersion = [int]$Identity.contractVersion
    product = 'NInferEZ Engine'
    engineVersion = $Version
    buildId = $Identity.buildId
    platform = 'windows-x64'
    cudaArchitecture = "sm$Arch"
    gpuFamily = $Target.Family
    gpuModels = $GpuNames
    architectureWideCompatibility = $true
    runtimeCalibrationForUnlistedDevices = $true
    nativeNvfp4 = [bool]$Target.NativeNvfp4
    channel = $Channel
    qualification = $QualificationLabel
    codeSigned = $false
    executable = 'ninfer-serve.exe'
    inspector = 'ninfer-inspect.exe'
    cliIncluded = [bool]$IncludeCli
    upstream = [ordered]@{ repository = 'https://github.com/iamwavecut/ninfer-all'; commit = '91576f32ee6147c31d5ead49393cce049530b6e1' }
    modelsBundled = $false
}
$Manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $ProductRoot 'engine-manifest.json') -Encoding utf8NoBOM

$SbomInventory = @(Get-ChildItem -LiteralPath $ProductRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
    $Relative = [IO.Path]::GetRelativePath($ProductRoot, $_.FullName).Replace('\', '/')
    $Sha1 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA1).Hash.ToLowerInvariant()
    $Sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    [pscustomobject]@{
        Sha1 = $Sha1
        Record = [ordered]@{
            fileName = "./$Relative"
            SPDXID = "SPDXRef-File-$($Sha256.Substring(0,16))"
            checksums = @(
                @{ algorithm = 'SHA1'; checksumValue = $Sha1 },
                @{ algorithm = 'SHA256'; checksumValue = $Sha256 }
            )
            licenseConcluded = 'NOASSERTION'
            licenseInfoInFiles = @('NOASSERTION')
            copyrightText = 'NOASSERTION'
        }
    }
})
$VerificationBytes = [Text.Encoding]::ASCII.GetBytes(
    ((@($SbomInventory | ForEach-Object Sha1 | Sort-Object)) -join ''))
$Sha1Algorithm = [Security.Cryptography.SHA1]::Create()
try {
    $VerificationCode = -join ($Sha1Algorithm.ComputeHash($VerificationBytes) | ForEach-Object { $_.ToString('x2') })
} finally {
    $Sha1Algorithm.Dispose()
}
$SbomFiles = @($SbomInventory | ForEach-Object Record)
$Sbom = [ordered]@{
    spdxVersion = 'SPDX-2.3'; dataLicense = 'CC0-1.0'; SPDXID = 'SPDXRef-DOCUMENT'
    name = $ProductName
    documentNamespace = "https://ninferez.invalid/spdx/$Version/sm$Arch/$([guid]::NewGuid())"
    creationInfo = @{ created = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); creators = @('Tool: NInferEZ-Engine-packager') }
    packages = @(@{
        name = 'NInferEZ Engine'; SPDXID = 'SPDXRef-Package-NInferEZ-Engine'
        versionInfo = $Version; downloadLocation = 'NOASSERTION'; filesAnalyzed = $true
        packageVerificationCode = @{
            packageVerificationCodeValue = $VerificationCode
            packageVerificationCodeExcludedFiles = @('SBOM.spdx.json', 'SHA256SUMS.txt')
        }
        licenseConcluded = 'Apache-2.0'; licenseDeclared = 'Apache-2.0'
        copyrightText = 'NOASSERTION'
    })
    files = $SbomFiles
}
$Sbom | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $ProductRoot 'SBOM.spdx.json') -Encoding utf8NoBOM

$CleanPath = "$env:SystemRoot\System32;$env:SystemRoot"
foreach ($Exe in ($Products | ForEach-Object { $_.Destination })) {
    $null = cmd /c "set PATH=$CleanPath&& `"$(Join-Path $ProductRoot $Exe)`" --help 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "$Exe failed with a clean PATH (exit $LASTEXITCODE)." }
}
$null = cmd /c "set PATH=$CleanPath&& `"$Serve`" --version-json 2>&1"
if ($LASTEXITCODE -ne 0) { throw 'ninfer-serve --version-json failed with a clean PATH.' }

$InnerHashes = Get-ChildItem -LiteralPath $ProductRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
    $Hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
    $Relative = [IO.Path]::GetRelativePath($ProductRoot, $_.FullName).Replace('\', '/')
    "$($Hash.Hash.ToLowerInvariant())  $Relative"
}
[IO.File]::WriteAllText((Join-Path $ProductRoot 'SHA256SUMS.txt'), (($InnerHashes -join "`n") + "`n"), [Text.ASCIIEncoding]::new())
Compress-Archive -LiteralPath $ProductRoot -DestinationPath $ArchivePath -CompressionLevel Optimal
$Archive = Get-Item -LiteralPath $ArchivePath
$ArchiveHash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$ReleaseManifest = [ordered]@{
    schemaVersion = 1; product = 'NInferEZ Engine'; engineVersion = $Version; channel = $Channel
    cudaArchitecture = "sm$Arch"; gpuFamily = $Target.Family; gpuModels = $GpuNames
    architectureWideCompatibility = $true; runtimeCalibrationForUnlistedDevices = $true
    nativeNvfp4 = [bool]$Target.NativeNvfp4; fileName = $Archive.Name
    sizeBytes = $Archive.Length; sha256 = $ArchiveHash; cliIncluded = [bool]$IncludeCli
    codeSigned = $false; url = $null
}
$ReleaseManifestPath = Join-Path $DistRoot "release-manifest-sm$Arch.json"
$ReleaseManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReleaseManifestPath -Encoding utf8NoBOM
$ArchiveHashPath = "$ArchivePath.sha256"
[IO.File]::WriteAllText(
    $ArchiveHashPath,
    "$ArchiveHash  $($Archive.Name)`n",
    [Text.ASCIIEncoding]::new())

Get-Item -LiteralPath $ArchivePath, $ReleaseManifestPath, $ArchiveHashPath |
    Select-Object Name, @{ Name = 'SizeMiB'; Expression = { [math]::Round($_.Length / 1MB, 2) } }
