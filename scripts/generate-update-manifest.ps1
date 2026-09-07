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
if ($Version -notmatch '^0\.[1-9]\d*\.\d+$') {
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

$versionInfo = $setupItem.VersionInfo
if ([string]$versionInfo.ProductName -ne 'Ghosium Browser') {
  throw "Update Setup ProductName must be Ghosium Browser; found '$($versionInfo.ProductName)'."
}
if ([string]$versionInfo.CompanyName -ne 'Brendigo') {
  throw "Update Setup CompanyName must be Brendigo; found '$($versionInfo.CompanyName)'."
}
if ([string]$versionInfo.ProductVersion -notlike "$Version*") {
  throw "Update Setup ProductVersion '$($versionInfo.ProductVersion)' does not match release version '$Version'."
}

$signature = Get-AuthenticodeSignature $resolvedSetup
$signerSubject = if ($signature.SignerCertificate) {
  [string]$signature.SignerCertificate.Subject
} else {
  ''
}
if ($RequireAuthenticode) {
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

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and !(Test-Path $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

$json = $manifest | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($OutputPath, $json + "`n", [Text.UTF8Encoding]::new($false))

$verify = Get-Content $OutputPath -Raw | ConvertFrom-Json
if ($verify.schema -ne 1 -or !$verify.enabled -or
    $verify.product -ne 'Ghosium Browser' -or
    $verify.platform -ne 'windows' -or
    $verify.channel -ne 'stable' -or
    $verify.version -ne $Version -or
    $verify.sha256 -ne $sha256 -or
    [int64]$verify.size -ne [int64]$setupItem.Length) {
  throw 'Generated Ghosium update manifest failed its post-write contract.'
}

Write-Host "Generated stable Ghosium update manifest for $Version ($($setupItem.Length) bytes, SHA-256 $sha256)."
if ($RequireAuthenticode) {
  Write-Host "Verified update publisher: $signerSubject"
}
