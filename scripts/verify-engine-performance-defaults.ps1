param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path
$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Ghosium performance verification requires pinned engine $expectedRevision; found $actualRevision"
}

$prefsPath = Join-Path $sourceRootResolved 'components/performance_manager/user_tuning/prefs.cc'
if (!(Test-Path $prefsPath -PathType Leaf)) {
  throw "Ghosium performance verifier is missing pinned preferences source: $prefsPath"
}
$text = [IO.File]::ReadAllText($prefsPath)

$required = @(
  'kMemorySaverModeState, static_cast<int>(MemorySaverModeState::kEnabled));',
  'kMemorySaverModeAggressiveness,',
  'static_cast<int>(MemorySaverModeAggressiveness::kMedium)',
  'kMemorySaverModeTimeBeforeDiscardInMinutes,',
  'kDefaultMemorySaverModeTimeBeforeDiscardInMinutes',
  'registry->RegisterBooleanPref(kTabFreezingEnabled, true);'
)
foreach ($value in $required) {
  if (!$text.Contains($value)) {
    throw "Ghosium performance source invariant is missing: $value"
  }
}
if ($text.Contains('kMemorySaverModeState, static_cast<int>(MemorySaverModeState::kDisabled));')) {
  throw 'Ghosium distribution still defaults native Memory Saver to disabled.'
}

$gnArgs = [IO.File]::ReadAllText((Join-Path $repoRoot 'engine/build/windows-x64.args.gn'))
if ($gnArgs -notmatch '(?m)^\s*enable_background_mode\s*=\s*false\s*$') {
  throw 'Ghosium Windows build must disable legacy background-app keep-alive mode.'
}

$forbidden = @(
  '--renderer-process-limit',
  '--no-sandbox',
  '--disable-gpu-sandbox',
  '--disable-site-isolation-trials',
  '--disable-web-security',
  '--ignore-certificate-errors'
)
foreach ($value in $forbidden) {
  if ($gnArgs.Contains($value)) {
    throw "Security-reducing or renderer-capping flag is forbidden in Ghosium performance configuration: $value"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during Ghosium performance audit.'
}
if ($thirdPartyChanges) {
  throw 'Ghosium performance audit detected third_party modifications.'
}

Write-Host 'Ghosium performance-default contract: native Memory Saver on; background keep-alive off; sandbox/isolation invariants untouched.'
