param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$OutDir = 'out/Ghosium'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'The Ghosium Windows full-source configuration must run on Windows.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$argsTemplate = Join-Path $repoRoot 'engine/build/windows-x64.args.gn'
$productLicense = Join-Path $repoRoot 'LICENSE'
$thirdPartyNotices = Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md'
$legalPayloadRewrite = Join-Path $PSScriptRoot 'rewrite-engine-legal-payload.ps1'

foreach ($requiredFile in @($argsTemplate, $productLicense, $thirdPartyNotices, $legalPayloadRewrite)) {
  if (!(Test-Path $requiredFile -PathType Leaf)) {
    throw "Missing deterministic Ghosium source-build input: $requiredFile"
  }
}

$licenseText = [IO.File]::ReadAllText($productLicense)
if (!$licenseText.Contains('Proprietary Commercial Software License Agreement') -or
    !$licenseText.Contains('Open-source components remain governed by their respective licenses.')) {
  throw 'Ghosium product LICENSE does not satisfy the production legal contract.'
}
if ((Get-Item $thirdPartyNotices).Length -le 100) {
  throw 'THIRD_PARTY_NOTICES.md is unexpectedly empty or incomplete.'
}

$sourceRootResolved = (Resolve-Path $SourceRoot).Path
if (!(Test-Path (Join-Path $sourceRootResolved '.git'))) {
  throw "SourceRoot is not a Chromium Git checkout: $sourceRootResolved"
}

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Chromium source must be detached at $expectedRevision; found $actualRevision"
}

# Integrate legal documents into the declared mini-installer source graph before
# GN sees the target. This patch is source-revision pinned and order-independent
# with the public executable rename.
& $legalPayloadRewrite -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium source-built legal payload integration failed.'
}

$gn = Get-Command gn -ErrorAction SilentlyContinue
$autoninja = Get-Command autoninja -ErrorAction SilentlyContinue
if (!$gn -or !$autoninja) {
  throw 'Chromium depot_tools must be installed and first on PATH; gn and autoninja are required.'
}

$argsText = [IO.File]::ReadAllText($argsTemplate)
$requiredArgs = @(
  '(?m)^\s*is_debug\s*=\s*false\s*$',
  '(?m)^\s*is_component_build\s*=\s*false\s*$',
  '(?m)^\s*is_official_build\s*=\s*false\s*$',
  '(?m)^\s*is_chrome_branded\s*=\s*false\s*$',
  '(?m)^\s*target_cpu\s*=\s*"x64"\s*$',
  '(?m)^\s*use_remoteexec\s*=\s*false\s*$'
)
foreach ($pattern in $requiredArgs) {
  if ($argsText -notmatch $pattern) {
    throw "Required Ghosium Windows GN invariant is missing: $pattern"
  }
}

foreach ($forbiddenPattern in @(
  '(?im)^\s*is_chrome_branded\s*=\s*true\s*$',
  '(?im)^\s*is_official_build\s*=\s*true\s*$',
  '(?im)^\s*use_remoteexec\s*=\s*true\s*$',
  '(?im)google_api_key\s*=',
  '(?im)google_default_client_id\s*=',
  '(?im)google_default_client_secret\s*='
)) {
  if ($argsText -match $forbiddenPattern) {
    throw "Forbidden Google/proprietary build configuration found in $argsTemplate"
  }
}

$outPath = if ([IO.Path]::IsPathRooted($OutDir)) {
  [IO.Path]::GetFullPath($OutDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $sourceRootResolved $OutDir))
}
$sourcePrefix = $sourceRootResolved.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (!$outPath.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "OutDir must stay inside the pinned Chromium checkout: $outPath"
}

New-Item -ItemType Directory -Force -Path $outPath | Out-Null
[IO.File]::WriteAllText(
  (Join-Path $outPath 'args.gn'),
  $argsText,
  [Text.UTF8Encoding]::new($false)
)

# Stage the exact reviewed repository legal files as declared mini-installer
# inputs before GN generation. Hash equality makes local/self-hosted builds fail
# closed if either staged file diverges from the repository contract.
$stagedLicense = Join-Path $outPath 'GHOSIUM-LICENSE.txt'
$stagedNotices = Join-Path $outPath 'THIRD_PARTY_NOTICES.md'
Copy-Item $productLicense $stagedLicense -Force
Copy-Item $thirdPartyNotices $stagedNotices -Force

$expectedLicenseHash = (Get-FileHash $productLicense -Algorithm SHA256).Hash.ToLowerInvariant()
$stagedLicenseHash = (Get-FileHash $stagedLicense -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedNoticesHash = (Get-FileHash $thirdPartyNotices -Algorithm SHA256).Hash.ToLowerInvariant()
$stagedNoticesHash = (Get-FileHash $stagedNotices -Algorithm SHA256).Hash.ToLowerInvariant()
if ($stagedLicenseHash -ne $expectedLicenseHash) {
  throw 'Staged GHOSIUM-LICENSE.txt does not match repository LICENSE.'
}
if ($stagedNoticesHash -ne $expectedNoticesHash) {
  throw 'Staged THIRD_PARTY_NOTICES.md does not match repository notices.'
}

$relativeOut = [IO.Path]::GetRelativePath($sourceRootResolved, $outPath)
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'

Push-Location $sourceRootResolved
try {
  Write-Host "Generating Ghosium Windows x64 build files in $relativeOut"
  & $gn.Source gen $relativeOut --check --fail-on-unused-args
  if ($LASTEXITCODE -ne 0) {
    throw "GN generation failed with exit code $LASTEXITCODE"
  }

  & $gn.Source args $relativeOut --list --short
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect generated GN arguments in $relativeOut"
  }
} finally {
  Pop-Location
}

Write-Host "Ghosium full-source Windows build configuration ready: $outPath"
Write-Host "Verified legal build inputs: GHOSIUM-LICENSE.txt + THIRD_PARTY_NOTICES.md"
Write-Host "Build command: autoninja -C $relativeOut chrome mini_installer"
