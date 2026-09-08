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
  [string]$ReportPath,

  [Parameter(Mandatory = $false)]
  [switch]$RequireSigning
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

$browserPath = Join-Path $stagePath 'Ghosium-Browser.exe'
$proxyPath = Join-Path $stagePath 'Ghosium-Proxy.exe'
foreach ($required in @($browserPath, $proxyPath)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Canonical Ghosium source stage is missing a public executable: $required"
  }
}

$signing = [ordered]@{
  required = [bool]$RequireSigning
  applied = $false
  certificateThumbprint = ''
  publisherSubject = ''
  timestampUrl = ''
  browserStatus = [string](Get-AuthenticodeSignature $browserPath).Status
  proxyStatus = [string](Get-AuthenticodeSignature $proxyPath).Status
  setupStatus = 'NotBuilt'
  portableStatus = 'NotBuilt'
}

$signtool = $null
$certificate = $null
$certificateStoreMachine = $false
$timestampUrl = ''

function Resolve-GhosiumSigningIdentity {
  if ([string]::IsNullOrWhiteSpace($env:GHOSIUM_SIGN_CERT_THUMBPRINT)) {
    throw 'Production Ghosium release signing requires GHOSIUM_SIGN_CERT_THUMBPRINT.'
  }
  $thumbprint = ($env:GHOSIUM_SIGN_CERT_THUMBPRINT -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
  if ($thumbprint -notmatch '^[0-9A-F]{40}$') {
    throw 'GHOSIUM_SIGN_CERT_THUMBPRINT must be a 40-character SHA-1 certificate thumbprint.'
  }
  if ([string]::IsNullOrWhiteSpace($env:GHOSIUM_TIMESTAMP_URL)) {
    throw 'Production Ghosium release signing requires GHOSIUM_TIMESTAMP_URL for RFC3161 timestamping.'
  }
  $timestampUri = $null
  if (![Uri]::TryCreate($env:GHOSIUM_TIMESTAMP_URL, [UriKind]::Absolute, [ref]$timestampUri) -or
      $timestampUri.Scheme -notin @('http', 'https')) {
    throw 'GHOSIUM_TIMESTAMP_URL must be an absolute HTTP(S) RFC3161 timestamp URL.'
  }

  $currentUserCert = Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue |
    Where-Object { $_.Thumbprint -eq $thumbprint } | Select-Object -First 1
  $machineCert = Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue |
    Where-Object { $_.Thumbprint -eq $thumbprint } | Select-Object -First 1
  $cert = if ($currentUserCert) { $currentUserCert } else { $machineCert }
  if (!$cert) {
    throw "Ghosium signing certificate $thumbprint was not found in CurrentUser/My or LocalMachine/My."
  }
  if (!$cert.HasPrivateKey) {
    throw "Ghosium signing certificate $thumbprint does not expose a private key to the builder account."
  }
  if ($cert.NotBefore.ToUniversalTime() -gt [DateTime]::UtcNow -or
      $cert.NotAfter.ToUniversalTime() -le [DateTime]::UtcNow) {
    throw "Ghosium signing certificate is outside its validity period: $($cert.NotBefore) - $($cert.NotAfter)"
  }

  $kitsRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' -Name KitsRoot10 -ErrorAction Stop).KitsRoot10
  $sdkVersion = '10.0.28000.2270'
  $tool = Join-Path $kitsRoot "bin\$sdkVersion\x64\signtool.exe"
  if (!(Test-Path $tool -PathType Leaf)) {
    throw "Required Windows SDK signtool.exe is missing: $tool"
  }

  return [ordered]@{
    Thumbprint = $thumbprint
    Certificate = $cert
    StoreMachine = [bool](!$currentUserCert -and $machineCert)
    TimestampUrl = $timestampUri.AbsoluteUri
    SignTool = (Resolve-Path $tool).Path
  }
}

function Sign-GhosiumFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if (!(Test-Path $Path -PathType Leaf)) {
    throw "Signing target is missing: $Path"
  }
  $args = @('sign')
  if ($certificateStoreMachine) {
    $args += '/sm'
  }
  $args += @(
    '/sha1', $certificate.Thumbprint,
    '/fd', 'SHA256',
    '/tr', $timestampUrl,
    '/td', 'SHA256',
    '/d', $Description,
    $Path
  )
  & $signtool @args | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Authenticode signing failed for $Path with exit code $LASTEXITCODE"
  }
  & $signtool verify /pa /all /v $Path | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Authenticode verification failed after signing: $Path"
  }
  $signature = Get-AuthenticodeSignature $Path
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or !$signature.SignerCertificate) {
    throw "PowerShell Authenticode validation is not Valid after signing: $Path / $($signature.Status)"
  }
  if ($signature.SignerCertificate.Thumbprint -ne $certificate.Thumbprint) {
    throw "Signing target was not signed by the configured Ghosium certificate: $Path"
  }
  return $signature
}

if ($RequireSigning) {
  $identity = Resolve-GhosiumSigningIdentity
  $signtool = [string]$identity.SignTool
  $certificate = $identity.Certificate
  $certificateStoreMachine = [bool]$identity.StoreMachine
  $timestampUrl = [string]$identity.TimestampUrl

  $browserSignature = Sign-GhosiumFile -Path $browserPath -Description 'Ghosium Browser'
  $proxySignature = Sign-GhosiumFile -Path $proxyPath -Description 'Ghosium Browser Proxy'
  if ($browserSignature.SignerCertificate.Subject -ne $proxySignature.SignerCertificate.Subject) {
    throw 'Ghosium Browser and Ghosium Proxy were not signed by the same publisher subject.'
  }

  $signing.applied = $true
  $signing.certificateThumbprint = $certificate.Thumbprint
  $signing.publisherSubject = $browserSignature.SignerCertificate.Subject
  $signing.timestampUrl = $timestampUrl
  $signing.browserStatus = [string]$browserSignature.Status
  $signing.proxyStatus = [string]$proxySignature.Status
}

$makensisOutput = @(& (Join-Path $repoRoot 'scripts/resolve-nsis.ps1'))
$makensis = ($makensisOutput | Where-Object { $_ -is [string] -and (Test-Path $_ -PathType Leaf) } | Select-Object -Last 1)
if (!$makensis) {
  throw 'Unable to resolve verified NSIS 3.12 makensis.exe.'
}
$makensis = (Resolve-Path $makensis).Path

$nsi = Join-Path $repoRoot 'installer/ghosium.nsi'
$portableNsi = Join-Path $repoRoot 'installer/ghosium-portable.nsi'
$icon = Join-Path $repoRoot 'ghosium.ico'
$headerArt = Join-Path $repoRoot 'installer/assets/header.bmp'
$welcomeArt = Join-Path $repoRoot 'installer/assets/welcome.bmp'
foreach ($required in @($nsi, $portableNsi, $icon, $headerArt, $welcomeArt, (Join-Path $stagePath 'LICENSE'), $browserPath)) {
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

$portablePath = Join-Path $artifactsPath 'Ghosium-Browser-Portable.exe'
if (Test-Path $portablePath) {
  Remove-Item $portablePath -Force
}
$portableArguments = @(
  "/DGHOSIUM_VERSION=$version",
  "/DGHOSIUM_STAGE=$stagePath",
  "/DGHOSIUM_ARTIFACTS=$artifactsPath",
  "/DGHOSIUM_ICON=$icon",
  '/DGHOSIUM_PORTABLE_PROFILE_SWITCH=--user-data-dir',
  $portableNsi
)
& $makensis @portableArguments | Out-Host
if ($LASTEXITCODE -ne 0) {
  throw "Canonical Ghosium Portable NSIS build failed with exit code $LASTEXITCODE"
}
if (!(Test-Path $portablePath -PathType Leaf) -or (Get-Item $portablePath).Length -le 0) {
  throw 'Canonical Ghosium-Browser-Portable.exe was not produced.'
}

$setupInfo = (Get-Item $setupPath).VersionInfo
$portableInfo = (Get-Item $portablePath).VersionInfo
foreach ($metadata in @(
  [ordered]@{ Label='Setup'; Info=$setupInfo; ExpectedDescription='Ghosium Browser Setup' },
  [ordered]@{ Label='Portable'; Info=$portableInfo; ExpectedDescription='Ghosium Browser Portable' }
)) {
  if ([string]$metadata.Info.ProductName -ne 'Ghosium Browser') {
    throw "$($metadata.Label) ProductName mismatch: '$($metadata.Info.ProductName)'"
  }
  if ([string]$metadata.Info.CompanyName -ne 'Brendigo') {
    throw "$($metadata.Label) CompanyName mismatch: '$($metadata.Info.CompanyName)'"
  }
  if ([string]$metadata.Info.FileDescription -ne $metadata.ExpectedDescription) {
    throw "$($metadata.Label) FileDescription mismatch: '$($metadata.Info.FileDescription)'"
  }
  if ([string]$metadata.Info.ProductVersion -notlike "$version*") {
    throw "$($metadata.Label) ProductVersion mismatch: '$($metadata.Info.ProductVersion)' expected '$version'"
  }
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

if ($RequireSigning) {
  $setupSignature = Sign-GhosiumFile -Path $setupPath -Description 'Ghosium Browser Setup'
  $portableSignature = Sign-GhosiumFile -Path $portablePath -Description 'Ghosium Browser Portable'
  $browserSignature = Get-AuthenticodeSignature $browserPath
  foreach ($publicSignature in @($setupSignature, $portableSignature)) {
    if ($publicSignature.SignerCertificate.Subject -ne $browserSignature.SignerCertificate.Subject) {
      throw 'Ghosium public package publisher subject does not match the signed Ghosium Browser publisher subject.'
    }
  }
  $signing.setupStatus = [string]$setupSignature.Status
  $signing.portableStatus = [string]$portableSignature.Status
} else {
  $signing.setupStatus = [string](Get-AuthenticodeSignature $setupPath).Status
  $signing.portableStatus = [string](Get-AuthenticodeSignature $portablePath).Status
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
  schemaVersion = 3
  product = 'Ghosium Browser'
  productVersion = $version
  package = 'Ghosium-Browser-Setup.exe'
  packageBytes = [int64](Get-Item $setupPath).Length
  packageSha256 = (Get-FileHash $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
  portablePackage = 'Ghosium-Browser-Portable.exe'
  portableBytes = [int64](Get-Item $portablePath).Length
  portableSha256 = (Get-FileHash $portablePath -Algorithm SHA256).Hash.ToLowerInvariant()
  publisherMetadata = [ordered]@{
    productName = [string]$setupInfo.ProductName
    companyName = [string]$setupInfo.CompanyName
    fileVersion = [string]$setupInfo.FileVersion
    productVersion = [string]$setupInfo.ProductVersion
  }
  signing = $signing
  sourceRuntime = [ordered]@{
    engineSourceRevision = [string]$stage.engineSourceRevision
    engineVersionDirectory = [string]$stage.engineVersionDirectory
    browserSha256BeforeSigning = [string]$stage.browserSha256
    browserSha256Packaged = (Get-FileHash $browserPath -Algorithm SHA256).Hash.ToLowerInvariant()
    proxySha256Packaged = (Get-FileHash $proxyPath -Algorithm SHA256).Hash.ToLowerInvariant()
    fileCountBeforeSigning = [int]$stage.fileCount
    totalBytesBeforeSigning = [int64]$stage.totalBytes
  }
  portable = [ordered]@{
    executable = 'Ghosium-Browser-Portable.exe'
    registryFree = $true
    createsShortcuts = $false
    adjacentProfileDirectory = 'Ghosium-Portable-Data'
    adjacentRuntimeDirectory = '.ghosium-portable-runtime'
    profileSwitch = '--user-data-dir'
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

if ($RequireSigning -and (!$report.signing.applied -or $report.signing.setupStatus -ne 'Valid' -or $report.signing.portableStatus -ne 'Valid')) {
  throw 'Production Setup/Portable packages did not satisfy the mandatory Authenticode signing contract.'
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

Write-Host "Canonical Ghosium Setup built: $setupPath"
Write-Host "Setup SHA-256: $($report.packageSha256)"
Write-Host "Canonical Ghosium Portable built: $portablePath"
Write-Host "Portable SHA-256: $($report.portableSha256)"
if ($RequireSigning) {
  Write-Host "Authenticode publisher: $($report.signing.publisherSubject)"
}
Write-Output $setupPath
Write-Output $portablePath
