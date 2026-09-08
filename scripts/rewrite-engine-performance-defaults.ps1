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
  throw "Refusing to apply Ghosium performance defaults outside pinned engine revision $expectedRevision; found $actualRevision"
}

$prefsPath = Join-Path $sourceRootResolved 'components/performance_manager/user_tuning/prefs.cc'
if (!(Test-Path $prefsPath -PathType Leaf)) {
  throw "Pinned engine performance preferences source is missing: $prefsPath"
}

$text = [IO.File]::ReadAllText($prefsPath)
$oldState = 'kMemorySaverModeState, static_cast<int>(MemorySaverModeState::kDisabled));'
$newState = 'kMemorySaverModeState, static_cast<int>(MemorySaverModeState::kEnabled));'

if ($text.Contains($oldState)) {
  $text = $text.Replace($oldState, $newState)
} elseif (!$text.Contains($newState)) {
  throw 'Pinned engine Memory Saver registration changed; refusing an unreviewed performance rewrite.'
}

# Keep the upstream medium aggressiveness, two-hour discard threshold and tab
# freezing behavior. Ghosium changes only the default on/off state here, so
# users retain the native Performance controls and explicit user preferences
# continue to override this distribution default.
foreach ($required in @(
  'kMemorySaverModeAggressiveness,',
  'static_cast<int>(MemorySaverModeAggressiveness::kMedium)',
  'kMemorySaverModeTimeBeforeDiscardInMinutes,',
  'kDefaultMemorySaverModeTimeBeforeDiscardInMinutes',
  'registry->RegisterBooleanPref(kTabFreezingEnabled, true);'
)) {
  if (!$text.Contains($required)) {
    throw "Pinned engine performance behavior changed; missing reviewed invariant: $required"
  }
}

[IO.File]::WriteAllText($prefsPath, $text, [Text.UTF8Encoding]::new($false))

$verify = [IO.File]::ReadAllText($prefsPath)
if (!$verify.Contains($newState) -or $verify.Contains($oldState)) {
  throw 'Ghosium Memory Saver default rewrite did not reach the required enabled state.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after performance-default rewrite.'
}
if ($thirdPartyChanges) {
  throw 'Ghosium performance-default rewrite modified third_party source.'
}

Write-Host 'Ghosium performance defaults: native Memory Saver enabled by default; upstream medium aggressiveness, tab freezing and user controls preserved.'
