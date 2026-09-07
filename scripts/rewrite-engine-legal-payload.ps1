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
  throw "Refusing to integrate the Ghosium legal payload on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$miniInstallerBuild = Join-Path $sourceRootResolved 'chrome/installer/mini_installer/BUILD.gn'
$miniInstallerRelease = Join-Path $sourceRootResolved 'chrome/installer/mini_installer/chrome.release'
foreach ($required in @($miniInstallerBuild, $miniInstallerRelease)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Pinned source layout changed; legal-payload target is missing: $required"
  }
}

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $text = [IO.File]::ReadAllText($Path)
  if ($text.Contains($NewValue)) {
    return
  }
  if (!$text.Contains($OldValue)) {
    throw "Pinned Chromium legal-payload anchor changed at ${Description}: $OldValue"
  }
  [IO.File]::WriteAllText(
    $Path,
    $text.Replace($OldValue, $NewValue),
    [Text.UTF8Encoding]::new($false)
  )
}

$browserInput = '    "$root_out_dir/Ghosium-Browser.exe",'
$legalInputs = @"
    "`$root_out_dir/Ghosium-Browser.exe",
    "`$root_out_dir/GHOSIUM-LICENSE.txt",
    "`$root_out_dir/THIRD_PARTY_NOTICES.md",
"@.TrimEnd("`r", "`n")
Replace-RequiredLiteral `
  -Path $miniInstallerBuild `
  -OldValue $browserInput `
  -NewValue $legalInputs `
  -Description 'mini_installer declared inputs'

$browserRelease = 'Ghosium-Browser.exe: %(ChromeDir)s\'
$legalRelease = @"
Ghosium-Browser.exe: %(ChromeDir)s\
GHOSIUM-LICENSE.txt: %(ChromeDir)s\
THIRD_PARTY_NOTICES.md: %(ChromeDir)s\
"@.TrimEnd("`r", "`n")
Replace-RequiredLiteral `
  -Path $miniInstallerRelease `
  -OldValue $browserRelease `
  -NewValue $legalRelease `
  -Description 'mini_installer installed application payload'

$buildText = [IO.File]::ReadAllText($miniInstallerBuild)
foreach ($required in @(
  '"$root_out_dir/GHOSIUM-LICENSE.txt",',
  '"$root_out_dir/THIRD_PARTY_NOTICES.md",'
)) {
  if (!$buildText.Contains($required)) {
    throw "Ghosium mini-installer build is missing legal input: $required"
  }
}

$releaseText = [IO.File]::ReadAllText($miniInstallerRelease)
foreach ($required in @(
  'GHOSIUM-LICENSE.txt: %(ChromeDir)s\',
  'THIRD_PARTY_NOTICES.md: %(ChromeDir)s\'
)) {
  if (!$releaseText.Contains($required)) {
    throw "Ghosium installed application payload is missing legal file: $required"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after legal-payload integration.'
}
if ($thirdPartyChanges) {
  throw 'Legal-payload integration modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium source-built legal payload integrated: GHOSIUM-LICENSE.txt + THIRD_PARTY_NOTICES.md'
