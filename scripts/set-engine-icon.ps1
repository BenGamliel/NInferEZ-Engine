param([Parameter(Mandatory=$true)][string]$Executable,[string]$IconPath)
$ErrorActionPreference='Stop'
$sourceRoot=Split-Path -Parent $PSScriptRoot
if(!$IconPath){$IconPath=Join-Path $sourceRoot 'assets\NInferEZ-Engine.ico'}
if(-not ('ExecutableBranding' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ExecutableBranding.cs')}
$before=[ExecutableBranding]::NonResourceSections($Executable)
try{$count=[ExecutableBranding]::VerifyIcon($Executable,$IconPath)}catch{$count=0}
if($count-eq0){[ExecutableBranding]::ApplyIcon($Executable,$IconPath)}
$after=[ExecutableBranding]::NonResourceSections($Executable)
if($before.Count-ne$after.Count){throw 'Executable sections changed unexpectedly.'}
foreach($section in $before.Keys){if($before[$section]-ne$after[$section]){throw "Non-resource executable section changed: $section"}}
$count=[ExecutableBranding]::VerifyIcon($Executable,$IconPath)
Write-Host "Engine icon verified at $count sizes; all non-resource sections unchanged."
