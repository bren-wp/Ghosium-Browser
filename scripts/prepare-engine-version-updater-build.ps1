param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedCommit = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualCommit = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $expectedCommit) {
  throw "Refusing to prepare updater BUILD.gn in an unpinned checkout. Expected $expectedCommit; found $actualCommit"
}

$buildPath = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/help/BUILD.gn'
if (!(Test-Path $buildPath -PathType Leaf)) {
  throw "Pinned Chromium updater layout changed; expected file missing: $buildPath"
}

$buildText = [IO.File]::ReadAllText($buildPath)
foreach ($requiredAnchor in @(
  'if (is_win) {',
  'if (is_chrome_branded) {',
  'sources = [ "version_updater_win.cc" ]',
  'if (is_linux) {'
)) {
  if (!$buildText.Contains($requiredAnchor)) {
    throw "Pinned Chromium help/BUILD.gn changed; missing required updater anchor: $requiredAnchor"
  }
}

# depot_tools materializes Chromium BUILD.gn with LF on the GitHub-hosted
# Windows runner while repository PowerShell scripts may be checked out with
# CRLF. The original exact here-string comparison therefore rejected the exact
# pinned source even though the GN structure had not changed. Match only the
# reviewed Windows fallback block with newline-tolerant regex, then emit the
# canonical generated block using this script's own newline representation so
# rewrite-engine-version-updater.ps1 can continue its existing idempotent gate.
$oldPattern = '(?m)^    \} else \{\r?\n      sources = \[ "version_updater_basic\.cc" \]\r?\n    \}$'
$newPattern = '(?m)^    \} else \{\r?\n      sources = \[ "version_updater_ghosium_win\.cc" \]\r?\n      deps \+= \[\r?\n        "//chrome/browser:browser_process",\r?\n        "//chrome/browser/net",\r?\n        "//crypto",\r?\n        "//net",\r?\n        "//services/network/public/cpp",\r?\n        "//url",\r?\n      \]\r?\n    \}$'
$newBuildBlock = @'
    } else {
      sources = [ "version_updater_ghosium_win.cc" ]
      deps += [
        "//chrome/browser:browser_process",
        "//chrome/browser/net",
        "//crypto",
        "//net",
        "//services/network/public/cpp",
        "//url",
      ]
    }
'@

$oldMatches = [regex]::Matches($buildText, $oldPattern)
$newMatches = [regex]::Matches($buildText, $newPattern)
if ($oldMatches.Count -eq 1 -and $newMatches.Count -eq 0) {
  $buildText = [regex]::Replace(
    $buildText,
    $oldPattern,
    [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $newBuildBlock },
    1
  )
  [IO.File]::WriteAllText($buildPath, $buildText, [Text.UTF8Encoding]::new($false))
  Write-Host 'Prepared pinned Windows VersionUpdater GN block using newline-safe anchor matching.'
} elseif ($oldMatches.Count -eq 0 -and $newMatches.Count -eq 1) {
  # Re-emit only this reviewed block so a direct follow-on exact comparison has
  # the same newline representation as the repository PowerShell here-string.
  $buildText = [regex]::Replace(
    $buildText,
    $newPattern,
    [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $newBuildBlock },
    1
  )
  [IO.File]::WriteAllText($buildPath, $buildText, [Text.UTF8Encoding]::new($false))
  Write-Host 'Pinned Windows VersionUpdater GN block was already prepared; canonicalized newline representation.'
} else {
  throw "Pinned Chromium help/BUILD.gn updater structure changed or became ambiguous. old=$($oldMatches.Count), new=$($newMatches.Count)"
}

$verify = [IO.File]::ReadAllText($buildPath)
if (![regex]::IsMatch($verify, $newPattern)) {
  throw 'Ghosium Windows VersionUpdater GN block preparation failed verification.'
}
if ([regex]::IsMatch($verify, $oldPattern)) {
  throw 'Legacy basic Windows VersionUpdater fallback remains after preparation.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after updater BUILD.gn preparation.'
}
if ($thirdPartyChanges) {
  throw 'Updater BUILD.gn preparation modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium pinned Windows VersionUpdater BUILD.gn preparation: OK'
