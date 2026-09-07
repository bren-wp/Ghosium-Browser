param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$OutDir = 'out/Ghosium',

  [Parameter(Mandatory = $true)]
  [string]$ArtifactsDir,

  [Parameter(Mandatory = $false)]
  [string]$StageDir,

  [Parameter(Mandatory = $false)]
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'Canonical Ghosium Windows Setup packaging must run on Windows.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^0\.[1-9]\d*\.\d+$') {
  throw "Ghosium product VERSION is invalid: '$version'"
}

$sourceRootResolved = (Resolve-Path $SourceRoot).Path
$artifactsPath = [IO.Path]::GetFullPath($ArtifactsDir)
New-Item -ItemType Directory -Force -Path $artifactsPath | Out-Null

if ([string]::IsNullOrWhiteSpace($StageDir)) {
  $StageDir = Join-Path $env:RUNNER_TEMP 'ghosium-source-release-stage'
}
$stagePath = [IO.Path]::GetFullPath($StageDir)

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $artifactsPath 'GHOSIUM-PUBLIC-SETUP.json'
}
$reportFullPath = [IO.Path]::GetFullPath($ReportPath)
$stageReport = Join-Path $artifactsPath 'GHOSIUM-SOURCE-STAGE.json'

& (Join-Path $repoRoot 'scripts/assemble-source-release-stage.ps1') `
  -SourceRoot $sourceRootResolved `
  -OutDir $OutDir `
  -StageDir $stagePath `
  -ReportPath $stageReport
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium source release stage assembly failed.'
}

$makensisOutput = @(& (Join-Path $repoRoot 'scripts/resolve-nsis.ps1'))
$makensis = ($makensisOutput | Where-Object { $_ -is [string] -and (Test-Path $_ -PathType Leaf) } | Select-Object -Last 1)
if (!$makensis) {
  throw 'Unable to resolve verified NSIS 3.12 makensis.exe.'
}
$makensis = (Resolve-Path $makensis).Path

$nsi = Join-Path $repoRoot 'installer/ghosium.nsi'
$icon = Join-Path $repoRoot 'ghosium.ico'
foreach ($required in @($nsi, $icon, (Join-Path $stagePath 'LICENSE'), (Join-Path $stagePath 'Ghosium-Browser.exe'))) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Canonical Setup packaging input is missing: $required"
  }
}

$setupPath = Join-Path $artifactsPath 'Ghosium-Browser-Setup.exe'
if (Test-Path $setupPath) {
  Remove-Item $setupPath -Force
}

$arguments = @(
  "/DGHOSIUM_VERSION=$version",
  "/DGHOSIUM_STAGE=$stagePath",
  "/DGHOSIUM_ARTIFACTS=$artifactsPath",
  "/DGHOSIUM_ICON=$icon",
  $nsi
)
& $makensis @arguments | Out-Host
if ($LASTEXITCODE -ne 0) {
  throw "Canonical Ghosium NSIS Setup build failed with exit code $LASTEXITCODE"
}
if (!(Test-Path $setupPath -PathType Leaf) -or (Get-Item $setupPath).Length -le 0) {
  throw 'Canonical Ghosium-Browser-Setup.exe was not produced.'
}

$setupInfo = (Get-Item $setupPath).VersionInfo
if ([string]$setupInfo.ProductName -ne 'Ghosium Browser') {
  throw "Canonical Setup ProductName mismatch: '$($setupInfo.ProductName)'"
}
if ([string]$setupInfo.CompanyName -ne 'Brendigo') {
  throw "Canonical Setup CompanyName mismatch: '$($setupInfo.CompanyName)'"
}
if ([string]$setupInfo.ProductVersion -notlike "$version*") {
  throw "Canonical Setup ProductVersion mismatch: '$($setupInfo.ProductVersion)' expected '$version'"
}

$outPath = if ([IO.Path]::IsPathRooted($OutDir)) {
  [IO.Path]::GetFullPath($OutDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $sourceRootResolved $OutDir))
}
$miniInstaller = Join-Path $outPath 'mini_installer.exe'
if (Test-Path $miniInstaller -PathType Leaf) {
  $publicHash = (Get-FileHash $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $miniHash = (Get-FileHash $miniInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($publicHash -eq $miniHash) {
    throw 'Public Ghosium Setup is still only a renamed Chromium mini_installer.exe.'
  }
}

$nsiText = [IO.File]::ReadAllText($nsi)
foreach ($requiredContract in @(
  '${GetOptions} $R0 "/UPDATE" $R1',
  '${GetOptions} $R0 "/UNINSTALL" $R1',
  '${GetOptions} $R0 "/DELETESELF" $R1',
  '${GetOptions} $R0 "/CLEANUPDATE" $R1',
  '!define INSTALLED_SETUP "Installer\Ghosium-Browser-Setup.exe"'
)) {
  if (!$nsiText.Contains($requiredContract)) {
    throw "Canonical Setup lost required maintenance interface: $requiredContract"
  }
}

$stage = Get-Content $stageReport -Raw | ConvertFrom-Json
$report = [ordered]@{
  schemaVersion = 2
  product = 'Ghosium Browser'
  productVersion = $version
  package = 'Ghosium-Browser-Setup.exe'
  packageBytes = [int64](Get-Item $setupPath).Length
  packageSha256 = (Get-FileHash $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
  publisherMetadata = [ordered]@{
    productName = [string]$setupInfo.ProductName
    companyName = [string]$setupInfo.CompanyName
    fileVersion = [string]$setupInfo.FileVersion
    productVersion = [string]$setupInfo.ProductVersion
  }
  sourceRuntime = [ordered]@{
    engineSourceRevision = [string]$stage.engineSourceRevision
    engineVersionDirectory = [string]$stage.engineVersionDirectory
    browserSha256BeforeSigning = [string]$stage.browserSha256
    fileCount = [int]$stage.fileCount
    totalBytes = [int64]$stage.totalBytes
  }
  maintenance = [ordered]@{
    sameSetupExecutable = $true
    install = $true
    updateSwitch = '/UPDATE'
    uninstallSwitch = '/UNINSTALL'
    downloadedUpdateCleanupSwitch = '/CLEANUPDATE'
    standaloneUpdaterExecutable = $false
    standaloneUninstallerExecutable = $false
  }
  publicSetupIsChromiumMiniInstallerRename = $false
}

$reportDirectory = Split-Path -Parent $reportFullPath
if ($reportDirectory -and !(Test-Path $reportDirectory -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
}
[IO.File]::WriteAllText(
  $reportFullPath,
  (($report | ConvertTo-Json -Depth 8) + "`n"),
  [Text.UTF8Encoding]::new($false)
)

Write-Host "Canonical Ghosium same-Setup package built: $setupPath"
Write-Host "SHA-256: $($report.packageSha256)"
Write-Output $setupPath
