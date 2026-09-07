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
  throw "Refusing to harden updater source in an unpinned checkout. Expected $expectedCommit; found $actualCommit"
}

$sourcePath = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/help/version_updater_ghosium_win.cc'
if (!(Test-Path $sourcePath -PathType Leaf)) {
  throw "Generated Ghosium updater source is missing: $sourcePath"
}

$text = [IO.File]::ReadAllText($sourcePath)
$updated = $text

if (!$updated.Contains('#include <algorithm>')) {
  if (!$updated.Contains('#include <array>')) {
    throw 'Ghosium updater include layout changed; cannot add <algorithm> deterministically.'
  }
  $updated = $updated.Replace('#include <array>', "#include <algorithm>`n#include <array>")
}

$weakTrust = @'
base::win::IsBinaryTrusted(setup_path_, true,
                                    false /* force_verify_in_dev_builds */)
'@
$strictTrust = @'
base::win::IsBinaryTrusted(setup_path_, true,
                                    true /* force_verify_in_dev_builds */)
'@
if ($updated.Contains($weakTrust)) {
  $updated = $updated.Replace($weakTrust, $strictTrust)
} elseif (!$updated.Contains($strictTrust)) {
  throw 'Ghosium updater Authenticode verification call changed unexpectedly.'
}

$oldComment = @'
    // IsBinaryTrusted validates Authenticode and, for production builds,
    // requires the downloaded Setup publisher subject to match the running
    // Ghosium Browser publisher. This prevents an arbitrary executable from
    // being launched even if it is served from the update host.
'@
$newComment = @'
    // Force Authenticode validation even though Ghosium is built from the
    // unbranded Chromium configuration. IsBinaryTrusted must validate the
    // downloaded Setup signature and require its publisher subject to match
    // the signed running Ghosium Browser executable before launch.
'@
if ($updated.Contains($oldComment)) {
  $updated = $updated.Replace($oldComment, $newComment)
}

if ($updated -ne $text) {
  [IO.File]::WriteAllText($sourcePath, $updated, [Text.UTF8Encoding]::new($false))
}

$verify = [IO.File]::ReadAllText($sourcePath)
foreach ($required in @(
  '#include <algorithm>',
  'base::win::IsBinaryTrusted(setup_path_, true,',
  'true /* force_verify_in_dev_builds */'
)) {
  if (!$verify.Contains($required)) {
    throw "Ghosium updater hardening failed: missing $required"
  }
}
if ($verify.Contains('false /* force_verify_in_dev_builds */')) {
  throw 'Ghosium updater still permits Chromium unbranded builds to bypass Authenticode verification.'
}

# Keep this verifier structural rather than dependent on prose comments: what
# matters is that the trust API is present and its unbranded-build bypass is
# forcibly disabled before Setup launch.
$trustIndex = $verify.IndexOf('base::win::IsBinaryTrusted(setup_path_, true,')
$launchIndex = $verify.IndexOf('base::LaunchProcess')
if ($trustIndex -lt 0 -or $launchIndex -lt 0 -or $trustIndex -gt $launchIndex) {
  throw 'Ghosium updater must perform Authenticode publisher verification before launching Setup.'
}

Write-Host 'Ghosium updater hardening: Authenticode is mandatory in unbranded release/dev configurations.'
