# Copyright 2026 NInferEZ Engine contributors.
# SPDX-License-Identifier: Apache-2.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BuildRoot,
    [ValidateSet('86', '89', '120a')][string]$ExpectedArch,
    [string[]]$ModelPath = @()
)

$ErrorActionPreference = 'Stop'
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
$Serve = Join-Path $BuildRoot 'apps\ninfer-serve.exe'
$Inspect = Join-Path $BuildRoot 'apps\ninfer-inspect.exe'
foreach ($Executable in @($Serve, $Inspect)) {
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "Missing executable: $Executable"
    }
}

function Invoke-JsonCommand {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [int]$ExpectedExitCode = 0
    )

    $Output = @(& $FilePath @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne $ExpectedExitCode) {
        throw "$FilePath exited with $ExitCode; expected $ExpectedExitCode.`n$($Output -join "`n")"
    }
    try {
        return (($Output -join "`n") | ConvertFrom-Json)
    } catch {
        throw "$FilePath did not return valid JSON.`n$($Output -join "`n")"
    }
}

$Identity = Invoke-JsonCommand -FilePath $Serve -Arguments @('--version-json')
if ($Identity.product -ne 'NInferEZ Engine' -or $Identity.contractVersion -ne 1) {
    throw 'Unexpected engine identity contract.'
}
if ($ExpectedArch -and $Identity.cudaArchitecture -ne "sm$ExpectedArch") {
    throw "Expected sm$ExpectedArch but binary reports $($Identity.cudaArchitecture)."
}

$Capabilities = Invoke-JsonCommand -FilePath $Serve -Arguments @('--capabilities-json')
if ($Capabilities.contractVersion -ne $Identity.contractVersion -or
    -not $Capabilities.serving.openAIResponses -or
    'rk8v4' -notin $Capabilities.kvFormats) {
    throw 'Capability contract is incomplete or inconsistent.'
}

$MissingPath = Join-Path $BuildRoot '__ninferez_missing__.ninfer'
$Failure = Invoke-JsonCommand -FilePath $Inspect `
    -Arguments @('--model', $MissingPath, '--json') -ExpectedExitCode 1
if ($Failure.valid -ne $false -or $Failure.error.code -ne 'artifact_invalid') {
    throw 'Inspector did not return the documented structured artifact error.'
}

$Models = @()
foreach ($Path in $ModelPath) {
    $Resolved = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $Resolved -PathType Leaf)) {
        throw "Model artifact does not exist: $Resolved"
    }
    $Inspection = Invoke-JsonCommand -FilePath $Inspect `
        -Arguments @('--model', $Resolved, '--json', '--estimate-memory')
    if (-not $Inspection.valid -or $Inspection.containerVersion -ne 3 -or
        $Inspection.memoryEstimate.runtimeVramAvailable -ne $false) {
        throw "Unexpected inspection result for $Resolved"
    }
    $Models += [ordered]@{
        path = $Resolved
        artifactId = $Inspection.artifactId
        fileBytes = $Inspection.fileBytes
        tensorBytes = $Inspection.tensorBytes
        weightFormats = @($Inspection.weightFormats)
        features = $Inspection.modelFeatures
        compatibility = $Inspection.compatibility
    }
}

[ordered]@{
    passed = $true
    gpuUsed = $false
    identity = $Identity
    capabilitiesChecked = $true
    structuredErrorsChecked = $true
    inspectedModels = $Models
} | ConvertTo-Json -Depth 12

$global:LASTEXITCODE = 0
