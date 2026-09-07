param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$OutDir = 'out/Ghosium',

  [Parameter(Mandatory = $false)]
  [string]$ProvenancePath,

  [Parameter(Mandatory = $false)]
  [switch]$RunRuntimeSmoke
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$ghosiumVersion = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$productConfig = Get-Content (Join-Path $repoRoot 'engine/branding/product.json') -Raw | ConvertFrom-Json
$sourceRootResolved = (Resolve-Path $SourceRoot).Path
$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Build output does not originate from pinned Ghosium engine source $expectedRevision"
}

$outPath = if ([IO.Path]::IsPathRooted($OutDir)) {
  [IO.Path]::GetFullPath($OutDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $sourceRootResolved $OutDir))
}
if (!(Test-Path $outPath -PathType Container)) {
  throw "Ghosium build output directory does not exist: $outPath"
}

$requiredFiles = @(
  'args.gn',
  'chrome.exe',
  'chrome.dll',
  'chrome_elf.dll',
  'locales/en-US.pak',
  'setup.exe',
  'mini_installer.exe',
  'chrome.7z'
)
foreach ($relative in $requiredFiles) {
  $path = Join-Path $outPath $relative
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required full-source build artifact is missing: $relative"
  }
  if ((Get-Item $path).Length -le 0) {
    throw "Full-source build artifact is empty: $relative"
  }
}

# Uninstall is deliberately implemented by the installed setup.exe invoked with
# the normal --uninstall flow and registered Windows uninstall command. Ghosium
# must not ship a second standalone uninstall executable.
foreach ($forbiddenUninstaller in @(
  'uninstall.exe',
  'Ghosium-Uninstall.exe',
  'Ghosium-Browser-Uninstall.exe'
)) {
  if (Test-Path (Join-Path $outPath $forbiddenUninstaller) -PathType Leaf) {
    throw "Standalone uninstaller is forbidden; use setup.exe --uninstall instead: $forbiddenUninstaller"
  }
}

$uninstallSourceFiles = [ordered]@{
  setupMain = Join-Path $sourceRootResolved 'chrome/installer/setup/setup_main.cc'
  uninstall = Join-Path $sourceRootResolved 'chrome/installer/setup/uninstall.cc'
  installWorker = Join-Path $sourceRootResolved 'chrome/installer/setup/install_worker.cc'
  utilConstants = Join-Path $sourceRootResolved 'chrome/installer/util/util_constants.h'
}
foreach ($entry in $uninstallSourceFiles.GetEnumerator()) {
  if (!(Test-Path $entry.Value -PathType Leaf)) {
    throw "Pinned source is missing required Windows uninstall support: $($entry.Value)"
  }
}

$setupMainText = [IO.File]::ReadAllText($uninstallSourceFiles.setupMain)
$uninstallText = [IO.File]::ReadAllText($uninstallSourceFiles.uninstall)
$installWorkerText = [IO.File]::ReadAllText($uninstallSourceFiles.installWorker)
$utilConstantsText = [IO.File]::ReadAllText($uninstallSourceFiles.utilConstants)

if (!$setupMainText.Contains('HasSwitch(installer::switches::kUninstall)') -or
    !$setupMainText.Contains('UninstallProduct(')) {
  throw 'setup.exe no longer exposes the required --uninstall handling.'
}
if (!$uninstallText.Contains('InstallStatus UninstallProduct(')) {
  throw 'Pinned source no longer contains the browser uninstall implementation.'
}
if (!$utilConstantsText.Contains('kSetupExe[] = L"setup.exe"') -or
    !$utilConstantsText.Contains('kUninstallStringField[] = L"UninstallString"') -or
    !$utilConstantsText.Contains('kUninstallArgumentsField[] = L"UninstallArguments"')) {
  throw 'Windows uninstall registry/setup constants changed unexpectedly.'
}
if (!$installWorkerText.Contains('installer::kUninstallStringField') -or
    !$installWorkerText.Contains('installer::kUninstallArgumentsField')) {
  throw 'Installer no longer registers the setup-based uninstall command.'
}

$engineBinary = Get-Item (Join-Path $outPath 'chrome.exe')
$engineInfo = $engineBinary.VersionInfo
if ([string]$engineInfo.ProductName -ne 'Ghosium Browser') {
  throw "Engine ProductName is not Ghosium Browser: '$($engineInfo.ProductName)'"
}
if ([string]$engineInfo.CompanyName -ne 'Brendigo') {
  throw "Engine CompanyName is not Brendigo: '$($engineInfo.CompanyName)'"
}
if (!$engineInfo.ProductVersion) {
  throw 'Ghosium engine ProductVersion is empty.'
}

$setup = Get-Item (Join-Path $outPath 'setup.exe')
$setupInfo = $setup.VersionInfo
$installer = Get-Item (Join-Path $outPath 'mini_installer.exe')
$installerInfo = $installer.VersionInfo
foreach ($binaryInfo in @(
  [pscustomobject]@{ Name = 'setup.exe'; Info = $setupInfo },
  [pscustomobject]@{ Name = 'Ghosium source installer'; Info = $installerInfo }
)) {
  if ($binaryInfo.Info.ProductName -and [string]$binaryInfo.Info.ProductName -match '(?i)\bChromium\b|Google Chrome') {
    throw "$($binaryInfo.Name) exposes legacy product branding in ProductName: '$($binaryInfo.Info.ProductName)'"
  }
  if ($binaryInfo.Info.CompanyName -and [string]$binaryInfo.Info.CompanyName -match '(?i)Google LLC') {
    throw "$($binaryInfo.Name) exposes legacy publisher metadata: '$($binaryInfo.Info.CompanyName)'"
  }
}
if ($installerInfo.ProductName -and [string]$installerInfo.ProductName -notmatch 'Ghosium') {
  throw "Source installer exposes unexpected ProductName: '$($installerInfo.ProductName)'"
}

$argsText = [IO.File]::ReadAllText((Join-Path $outPath 'args.gn'))
foreach ($required in @(
  'is_debug = false',
  'is_component_build = false',
  'is_official_build = false',
  'is_chrome_branded = false',
  'target_cpu = "x64"',
  'use_remoteexec = false'
)) {
  if (!$argsText.Contains($required)) {
    throw "Generated args.gn lost required Ghosium invariant: $required"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state for built engine.'
}
if ($thirdPartyChanges) {
  throw 'Full-source build verification detected modified third_party sources.'
}

$expectedGhostRoutes = @(
  'ghost://newtab/',
  'ghost://history/',
  'ghost://bookmarks/',
  'ghost://downloads/',
  'ghost://settings/',
  'ghost://profiles/',
  'ghost://extensions/',
  'ghost://passwords/'
)
if ([string]$productConfig.internalUi.scheme -ne 'ghost' -or
    [string]$productConfig.internalUi.untrustedScheme -ne 'ghost-untrusted') {
  throw 'Ghosium source-build contract lost the ghost:// internal namespace.'
}
foreach ($route in $expectedGhostRoutes) {
  if (@($productConfig.internalUi.routes) -notcontains $route) {
    throw "Ghosium source-build contract is missing internal route: $route"
  }
}

$runtimeSmokePassed = $false
$runtimeSmokeTimeoutSeconds = 60
$ghostRouteResults = [ordered]@{}
if ($RunRuntimeSmoke) {
  $smokeRoot = Join-Path ([IO.Path]::GetTempPath()) "ghosium-source-smoke-$PID"
  New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null

  function Invoke-GhosiumHeadlessSmoke {
    param(
      [Parameter(Mandatory = $true)][string]$Url,
      [Parameter(Mandatory = $true)][string]$Name
    )

    $profile = Join-Path $smokeRoot "profile-$Name"
    $stdout = Join-Path $smokeRoot "$Name.stdout.txt"
    $stderr = Join-Path $smokeRoot "$Name.stderr.txt"
    $process = $null
    try {
      $runtimeArgs = @(
        '--headless=new',
        '--disable-gpu',
        '--disable-sync',
        '--no-pings',
        '--no-first-run',
        "--user-data-dir=$profile",
        '--dump-dom',
        $Url
      )
      $process = Start-Process `
        -FilePath $engineBinary.FullName `
        -ArgumentList $runtimeArgs `
        -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

      if (!$process.WaitForExit($runtimeSmokeTimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "Ghosium runtime smoke '$Name' exceeded ${runtimeSmokeTimeoutSeconds}s and was terminated."
      }
      $process.Refresh()

      $output = if (Test-Path $stdout -PathType Leaf) { Get-Content $stdout -Raw } else { '' }
      $errorText = if (Test-Path $stderr -PathType Leaf) { Get-Content $stderr -Raw } else { '' }
      $combined = "$output`n$errorText"
      if ($process.ExitCode -ne 0) {
        Write-Host $output
        Write-Host $errorText
        throw "Ghosium runtime smoke '$Name' failed with exit code $($process.ExitCode)."
      }
      if ($combined -match '(?i)ERR_UNKNOWN_URL_SCHEME|ERR_INVALID_URL|ERR_FAILED|ERR_ABORTED') {
        Write-Host $output
        Write-Host $errorText
        throw "Ghosium runtime smoke '$Name' exposed a navigation error."
      }
      if ([string]::IsNullOrWhiteSpace($output)) {
        throw "Ghosium runtime smoke '$Name' produced no DOM output."
      }
      return $true
    } finally {
      if ($process -and !$process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      }
    }
  }

  try {
    [void](Invoke-GhosiumHeadlessSmoke `
      -Url 'data:text/html,<html><body>ghosium-source-runtime-ok</body></html>' `
      -Name 'data-url')

    $routeIndex = 0
    foreach ($route in $expectedGhostRoutes) {
      $routeIndex++
      $name = "ghost-route-$routeIndex"
      $ghostRouteResults[$route] = [bool](Invoke-GhosiumHeadlessSmoke -Url $route -Name $name)
    }

    $runtimeSmokePassed = @($ghostRouteResults.Values | Where-Object { -not $_ }).Count -eq 0
  } finally {
    Remove-Item $smokeRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Public provenance uses Ghosium-facing labels even while the pinned build tree
# retains upstream technical target filenames required by the installer toolchain.
$filesToHash = [ordered]@{
  'Ghosium-Engine.exe' = 'chrome.exe'
  'Ghosium-Engine.dll' = 'chrome.dll'
  'Ghosium-Engine-ELF.dll' = 'chrome_elf.dll'
  'setup.exe' = 'setup.exe'
  'Ghosium-Source-Installer.exe' = 'mini_installer.exe'
  'Ghosium-Engine.7z' = 'chrome.7z'
  'args.gn' = 'args.gn'
}
$hashes = [ordered]@{}
foreach ($entry in $filesToHash.GetEnumerator()) {
  $hashes[$entry.Key] = (Get-FileHash (Join-Path $outPath $entry.Value) -Algorithm SHA256).Hash.ToLowerInvariant()
}

if (!$ProvenancePath) {
  $ProvenancePath = Join-Path $outPath 'GHOSIUM-SOURCE-BUILD.json'
} elseif (![IO.Path]::IsPathRooted($ProvenancePath)) {
  $ProvenancePath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $ProvenancePath))
}

$provenance = [ordered]@{
  schemaVersion = 3
  product = 'Ghosium Browser'
  ghosiumVersion = $ghosiumVersion
  architecture = 'windows-x64'
  engineSourceRevision = $expectedRevision
  engineProductVersion = [string]$engineInfo.ProductVersion
  publisher = [string]$engineInfo.CompanyName
  engineProductName = [string]$engineInfo.ProductName
  setupProductName = [string]$setupInfo.ProductName
  installerProductName = [string]$installerInfo.ProductName
  internalUi = [ordered]@{
    scheme = 'ghost'
    untrustedScheme = 'ghost-untrusted'
    routes = $expectedGhostRoutes
    runtimeVerified = $runtimeSmokePassed
    routeResults = $ghostRouteResults
  }
  runtimeSmoke = [ordered]@{
    requested = [bool]$RunRuntimeSmoke
    passed = $runtimeSmokePassed
    timeoutSecondsPerNavigation = $runtimeSmokeTimeoutSeconds
    sandboxDisabled = $false
  }
  uninstall = [ordered]@{
    supported = $true
    mechanism = 'setup.exe --uninstall via Windows registered uninstall command'
    standaloneExecutable = $false
  }
  repositoryCommit = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { $null }
  verifiedUtc = [DateTime]::UtcNow.ToString('o')
  sha256 = $hashes
}
$provenance | ConvertTo-Json -Depth 7 | Set-Content $ProvenancePath -Encoding utf8

Write-Host 'Ghosium full-source Windows binary verification: OK'
Write-Host "Engine version: $($engineInfo.ProductVersion)"
if ($RunRuntimeSmoke) {
  Write-Host "Runtime smoke: data URL plus all eight ghost:// routes passed without disabling the browser sandbox."
}
Write-Host 'Uninstall: supported through registered setup.exe --uninstall flow; no standalone uninstall.exe'
Write-Host "Provenance: $ProvenancePath"
