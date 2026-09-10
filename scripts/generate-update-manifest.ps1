param(
  [Parameter(Mandatory = $true)]
  [string]$SetupPath,

  [Parameter(Mandatory = $false)]
  [string]$Version,

  [Parameter(Mandatory = $false)]
  [string]$OutputPath,

  [Parameter(Mandatory = $false)]
  [switch]$RequireAuthenticode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
if (!$Version) {
  $Version = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()
}
if (!$OutputPath) {
  $OutputPath = Join-Path $repoRoot 'updates-web/windows/stable.json'
}
if ($Version -notmatch '^0\.\d+\.\d+$') {
  throw "Ghosium update version must use the 0.x.y product line; found '$Version'."
}

$resolvedSetup = (Resolve-Path $SetupPath).Path
$setupItem = Get-Item $resolvedSetup
if ($setupItem.PSIsContainer) {
  throw 'SetupPath must point to a file.'
}
if ($setupItem.Name -ne 'Ghosium-Browser-Setup.exe') {
  throw "Update package must be named Ghosium-Browser-Setup.exe; found '$($setupItem.Name)'."
}
if ($setupItem.Length -le 0 -or $setupItem.Length -gt 536870912) {
  throw "Update package size is outside the allowed range: $($setupItem.Length) bytes."
}

$runningOnWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
if ($RequireAuthenticode -and !$runningOnWindows) {
  throw 'Production Authenticode manifest generation must run on Windows so PE identity and signature validation cannot be bypassed.'
}

if ($runningOnWindows) {
  $versionInfo = $setupItem.VersionInfo
  if ([string]$versionInfo.ProductName -ne 'Ghosium Browser') {
    throw "Update Setup ProductName must be Ghosium Browser; found '$($versionInfo.ProductName)'."
  }
  if ([string]$versionInfo.CompanyName -ne 'Brendigo') {
    throw "Update Setup CompanyName must be Brendigo; found '$($versionInfo.CompanyName)'."
  }

  $setupProductVersion = ([string]$versionInfo.ProductVersion).Trim()
  $allowedProductVersions = @($Version, "$Version.0")
  if ($allowedProductVersions -notcontains $setupProductVersion) {
    throw "Update Setup ProductVersion '$setupProductVersion' does not exactly match release version '$Version'."
  }
}

$signerSubject = ''
if ($RequireAuthenticode) {
  $signature = Get-AuthenticodeSignature $resolvedSetup
  $signerSubject = if ($signature.SignerCertificate) {
    [string]$signature.SignerCertificate.Subject
  } else {
    ''
  }
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
      !$signature.SignerCertificate) {
    throw "Production update manifest requires a Valid Authenticode Ghosium Setup signature; status='$($signature.Status)'."
  }
  if ([string]::IsNullOrWhiteSpace($signerSubject)) {
    throw 'Production update manifest requires a non-empty Authenticode publisher subject.'
  }
}

$sha256 = (Get-FileHash $resolvedSetup -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sha256 -notmatch '^[0-9a-f]{64}$') {
  throw 'Unable to calculate a valid SHA-256 update package digest.'
}

$manifest = [ordered]@{
  schema = 1
  product = 'Ghosium Browser'
  platform = 'windows'
  channel = 'stable'
  enabled = $true
  version = $Version
  url = 'https://updates.ghosium.com/windows/Ghosium-Browser-Setup.exe'
  sha256 = $sha256
  size = [int64]$setupItem.Length
  release_notes = "https://ghosium.com/release-notes/$Version"
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $outputFullPath
if ($outputDirectory -and !(Test-Path $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}
if (!$outputDirectory) {
  throw "Unable to resolve update manifest output directory for '$OutputPath'."
}

function Assert-ManifestContent {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $verify = Get-Content $Path -Raw | ConvertFrom-Json
  if ($verify.schema -ne 1 -or !$verify.enabled -or
      $verify.product -ne 'Ghosium Browser' -or
      $verify.platform -ne 'windows' -or
      $verify.channel -ne 'stable' -or
      $verify.version -ne $Version -or
      $verify.url -ne 'https://updates.ghosium.com/windows/Ghosium-Browser-Setup.exe' -or
      $verify.sha256 -ne $sha256 -or
      [int64]$verify.size -ne [int64]$setupItem.Length -or
      $verify.release_notes -ne "https://ghosium.com/release-notes/$Version") {
    throw "Generated Ghosium update manifest failed verification: $Path"
  }
}

$json = $manifest | ConvertTo-Json -Depth 4
$tempOutput = Join-Path $outputDirectory ('.ghosium-manifest-' + [IO.Path]::GetRandomFileName())
try {
  [IO.File]::WriteAllText($tempOutput, $json + "`n", [Text.UTF8Encoding]::new($false))
  Assert-ManifestContent -Path $tempOutput

  # Publish only a fully written and independently parsed manifest. The temp
  # file lives beside the destination so the final rename remains on one volume
  # and consumers never observe a partially written stable.json/evidence file.
  [IO.File]::Move($tempOutput, $outputFullPath, $true)
  Assert-ManifestContent -Path $outputFullPath
} finally {
  if (Test-Path $tempOutput -PathType Leaf) {
    Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
  }
}

# Detect a Setup mutation during manifest generation. A changed package must be
# rebuilt/re-signed rather than publishing metadata for bytes no longer present.
$finalSetupItem = Get-Item $resolvedSetup
$finalSha256 = (Get-FileHash $resolvedSetup -Algorithm SHA256).Hash.ToLowerInvariant()
if ([int64]$finalSetupItem.Length -ne [int64]$setupItem.Length -or $finalSha256 -ne $sha256) {
  throw 'Ghosium Setup changed while the update manifest was being generated; refusing publication.'
}

Write-Host "Generated stable Ghosium update manifest for $Version ($($setupItem.Length) bytes, SHA-256 $sha256)."
if ($RequireAuthenticode) {
  Write-Host "Verified update publisher: $signerSubject"
}
