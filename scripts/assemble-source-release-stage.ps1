param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$OutDir = 'out/Ghosium',

  [Parameter(Mandatory = $true)]
  [string]$StageDir,

  [Parameter(Mandatory = $false)]
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$productVersion = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path
$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Release stage requires pinned Chromium $expectedRevision; found $actualRevision"
}

$outPath = if ([IO.Path]::IsPathRooted($OutDir)) {
  [IO.Path]::GetFullPath($OutDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $sourceRootResolved $OutDir))
}
if (!(Test-Path $outPath -PathType Container)) {
  throw "Ghosium source build output is missing: $outPath"
}

$archive = Join-Path $outPath 'chrome.7z'
$compiledBrowser = Join-Path $outPath 'Ghosium-Browser.exe'
foreach ($required in @($archive, $compiledBrowser)) {
  if (!(Test-Path $required -PathType Leaf) -or (Get-Item $required).Length -le 0) {
    throw "Required verified source-build input is missing or empty: $required"
  }
}
if (Test-Path (Join-Path $outPath 'chrome.exe') -PathType Leaf) {
  throw 'Legacy public chrome.exe exists in the source build output; refusing to package it.'
}

# Chromium builds chrome.7z using the source-controlled LZMA SDK. Reuse that
# exact pinned extractor instead of depending on a machine-wide mutable 7-Zip
# installation or downloading a new tool during release packaging.
$sevenZipCandidates = @(
  (Join-Path $sourceRootResolved 'third_party/lzma_sdk/bin/host_platform/7za.exe'),
  (Join-Path $sourceRootResolved 'third_party/lzma_sdk/bin/win64/7za.exe')
)
$sevenZip = $sevenZipCandidates | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
if (!$sevenZip) {
  throw 'Pinned Chromium LZMA SDK 7za.exe was not found; cannot assemble release stage reproducibly.'
}
$sevenZip = (Resolve-Path $sevenZip).Path

$stagePath = [IO.Path]::GetFullPath($StageDir)
$stageParent = Split-Path -Parent $stagePath
if ([string]::IsNullOrWhiteSpace($stageParent)) {
  throw "StageDir must have a parent directory: $StageDir"
}
if (Test-Path $stagePath) {
  Remove-Item $stagePath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagePath | Out-Null

$extractRoot = Join-Path $stageParent ('.ghosium-source-extract-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
try {
  & $sevenZip x '-y' "-o$extractRoot" $archive | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Pinned 7za extraction of chrome.7z failed with exit code $LASTEXITCODE"
  }

  $chromeBin = Join-Path $extractRoot 'Chrome-bin'
  if (!(Test-Path $chromeBin -PathType Container)) {
    throw 'chrome.7z does not contain the expected Chrome-bin runtime root.'
  }

  $archiveBrowser = Join-Path $chromeBin 'Ghosium-Browser.exe'
  if (!(Test-Path $archiveBrowser -PathType Leaf)) {
    throw 'Source runtime archive is missing Ghosium-Browser.exe at Chrome-bin root.'
  }
  if (Test-Path (Join-Path $chromeBin 'chrome.exe') -PathType Leaf) {
    throw 'Source runtime archive still contains legacy chrome.exe.'
  }
  if (Test-Path (Join-Path $chromeBin 'chrome_proxy.exe') -PathType Leaf) {
    throw 'Source runtime archive still contains legacy chrome_proxy.exe.'
  }

  $archiveBrowserHash = (Get-FileHash $archiveBrowser -Algorithm SHA256).Hash.ToLowerInvariant()
  $compiledBrowserHash = (Get-FileHash $compiledBrowser -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($archiveBrowserHash -ne $compiledBrowserHash) {
    throw 'Ghosium-Browser.exe inside chrome.7z does not match the verified source-built browser executable.'
  }

  $versionDirs = @(
    Get-ChildItem $chromeBin -Directory -Force | Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' }
  )
  if ($versionDirs.Count -ne 1) {
    throw "Source runtime archive must contain exactly one Chromium engine version directory; found $($versionDirs.Count)."
  }
  $engineVersionDir = $versionDirs[0]
  foreach ($requiredRuntime in @(
    (Join-Path $engineVersionDir.FullName 'chrome.dll'),
    (Join-Path $engineVersionDir.FullName 'chrome_elf.dll'),
    (Join-Path $engineVersionDir.FullName 'resources.pak'),
    (Join-Path $engineVersionDir.FullName 'Locales/en-US.pak')
  )) {
    if (!(Test-Path $requiredRuntime -PathType Leaf) -or (Get-Item $requiredRuntime).Length -le 0) {
      throw "Source runtime archive is incomplete: $requiredRuntime"
    }
  }

  # Copy the content *inside* Chrome-bin to the NSIS stage. This is the normal
  # Chromium installed layout: primary executable at install root plus one
  # engine-version directory below it. The NSIS package therefore wraps the
  # exact runtime already produced and verified by the source build.
  Get-ChildItem $chromeBin -Force | ForEach-Object {
    Copy-Item $_.FullName -Destination $stagePath -Recurse -Force
  }
} finally {
  if (Test-Path $extractRoot) {
    Remove-Item $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# The standard Ghosium Setup license page consumes LICENSE directly from the
# stage. Also ship third-party notices beside the runtime so installed builds
# retain the product and open-source legal payload.
Copy-Item (Join-Path $repoRoot 'LICENSE') (Join-Path $stagePath 'LICENSE') -Force
Copy-Item (Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md') (Join-Path $stagePath 'THIRD_PARTY_NOTICES.md') -Force

$stageBrowser = Join-Path $stagePath 'Ghosium-Browser.exe'
if (!(Test-Path $stageBrowser -PathType Leaf)) {
  throw 'Assembled release stage lost Ghosium-Browser.exe.'
}
if ((Get-FileHash $stageBrowser -Algorithm SHA256).Hash.ToLowerInvariant() -ne
    (Get-FileHash $compiledBrowser -Algorithm SHA256).Hash.ToLowerInvariant()) {
  throw 'Assembled stage browser no longer matches the verified source build.'
}

$forbiddenBasenames = @(
  'chrome.exe',
  'chrome_proxy.exe',
  'update.exe',
  'updater.exe',
  'uninstall.exe'
)
foreach ($forbidden in $forbiddenBasenames) {
  $match = Get-ChildItem $stagePath -File -Recurse -Force -ErrorAction Stop |
    Where-Object { $_.Name -ieq $forbidden } |
    Select-Object -First 1
  if ($match) {
    throw "Forbidden public/maintenance executable exists in release stage: $($match.FullName)"
  }
}

$reparsePoints = @(
  Get-ChildItem $stagePath -Recurse -Force -ErrorAction Stop |
    Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
)
if ($reparsePoints.Count -gt 0) {
  throw "Release stage contains reparse points and is not safe for recursive installer packaging: $($reparsePoints[0].FullName)"
}

$files = @(Get-ChildItem $stagePath -File -Recurse -Force -ErrorAction Stop)
if ($files.Count -lt 10) {
  throw "Assembled release stage is unexpectedly small: only $($files.Count) files."
}
$totalBytes = [int64](($files | Measure-Object Length -Sum).Sum)
if ($totalBytes -le 0) {
  throw 'Assembled release stage has zero bytes.'
}

$stageHashRecords = foreach ($file in ($files | Sort-Object FullName)) {
  $relative = [IO.Path]::GetRelativePath($stagePath, $file.FullName).Replace('\', '/')
  [ordered]@{
    path = $relative
    size = [int64]$file.Length
    sha256 = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
}

$report = [ordered]@{
  schemaVersion = 1
  product = 'Ghosium Browser'
  productVersion = $productVersion
  engineSourceRevision = $expectedRevision
  sourceArchive = 'chrome.7z'
  sourceArchiveSha256 = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
  engineVersionDirectory = $engineVersionDir.Name
  browserExecutable = 'Ghosium-Browser.exe'
  browserSha256 = (Get-FileHash $stageBrowser -Algorithm SHA256).Hash.ToLowerInvariant()
  fileCount = $files.Count
  totalBytes = $totalBytes
  legalPayload = [ordered]@{
    license = Test-Path (Join-Path $stagePath 'LICENSE') -PathType Leaf
    thirdPartyNotices = Test-Path (Join-Path $stagePath 'THIRD_PARTY_NOTICES.md') -PathType Leaf
  }
  files = @($stageHashRecords)
}

if ($ReportPath) {
  $reportFullPath = [IO.Path]::GetFullPath($ReportPath)
  $reportDirectory = Split-Path -Parent $reportFullPath
  if ($reportDirectory -and !(Test-Path $reportDirectory -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  }
  [IO.File]::WriteAllText(
    $reportFullPath,
    (($report | ConvertTo-Json -Depth 8) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
}

Write-Host "Ghosium source release stage assembled: $($files.Count) files, $totalBytes bytes, engine $($engineVersionDir.Name)."
