from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old in text:
        text = text.replace(old, new, 1)
        p.write_text(text, encoding="utf-8", newline="\n")
        return
    if new in text:
        return
    raise SystemExit(f"migration anchor missing in {path}: {old[:120]!r}")


# Modern MUI2 header/welcome artwork. Existing secure installer logic stays intact.
replace_once(
    "installer/ghosium.nsi",
    '!define MUI_ICON "${GHOSIUM_ICON}"\n',
    '!define MUI_ICON "${GHOSIUM_ICON}"\n'
    '!define MUI_HEADERIMAGE\n'
    '!define MUI_HEADERIMAGE_BITMAP "${__FILEDIR__}\\assets\\header.bmp"\n'
    '!define MUI_HEADERIMAGE_RIGHT\n'
    '!define MUI_WELCOMEFINISHPAGE_BITMAP "${__FILEDIR__}\\assets\\welcome.bmp"\n',
)

# Canonical packager: require portable NSIS input.
replace_once(
    "scripts/build-source-release-installer.ps1",
    "$nsi = Join-Path $repoRoot 'installer/ghosium.nsi'\n$icon = Join-Path $repoRoot 'ghosium.ico'\nforeach ($required in @($nsi, $icon, (Join-Path $stagePath 'LICENSE'), $browserPath)) {",
    "$nsi = Join-Path $repoRoot 'installer/ghosium.nsi'\n"
    "$portableNsi = Join-Path $repoRoot 'installer/ghosium-portable.nsi'\n"
    "$icon = Join-Path $repoRoot 'ghosium.ico'\n"
    "$headerArt = Join-Path $repoRoot 'installer/assets/header.bmp'\n"
    "$welcomeArt = Join-Path $repoRoot 'installer/assets/welcome.bmp'\n"
    "foreach ($required in @($nsi, $portableNsi, $icon, $headerArt, $welcomeArt, (Join-Path $stagePath 'LICENSE'), $browserPath)) {",
)

# Build portable after Setup from the exact same verified/signable stage.
setup_anchor = """if (!(Test-Path $setupPath -PathType Leaf) -or (Get-Item $setupPath).Length -le 0) {
  throw 'Canonical Ghosium-Browser-Setup.exe was not produced.'
}

$setupInfo = (Get-Item $setupPath).VersionInfo
"""
setup_replacement = """if (!(Test-Path $setupPath -PathType Leaf) -or (Get-Item $setupPath).Length -le 0) {
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
"""
replace_once("scripts/build-source-release-installer.ps1", setup_anchor, setup_replacement)

# Sign both public package executables on production builds.
replace_once(
    "scripts/build-source-release-installer.ps1",
    """  $setupSignature = Sign-GhosiumFile -Path $setupPath -Description 'Ghosium Browser Setup'
  $browserSignature = Get-AuthenticodeSignature $browserPath
  if ($setupSignature.SignerCertificate.Subject -ne $browserSignature.SignerCertificate.Subject) {
    throw 'Ghosium Setup publisher subject does not match the signed Ghosium Browser publisher subject.'
  }
  $signing.setupStatus = [string]$setupSignature.Status
} else {
  $signing.setupStatus = [string](Get-AuthenticodeSignature $setupPath).Status
}
""",
    """  $setupSignature = Sign-GhosiumFile -Path $setupPath -Description 'Ghosium Browser Setup'
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
""",
)

# Signing report needs portable state from initialization.
replace_once(
    "scripts/build-source-release-installer.ps1",
    "  setupStatus = 'NotBuilt'\n}",
    "  setupStatus = 'NotBuilt'\n  portableStatus = 'NotBuilt'\n}",
)

# Provenance includes both public packages and explicit portable guarantees.
replace_once(
    "scripts/build-source-release-installer.ps1",
    """  package = 'Ghosium-Browser-Setup.exe'
  packageBytes = [int64](Get-Item $setupPath).Length
  packageSha256 = (Get-FileHash $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
""",
    """  package = 'Ghosium-Browser-Setup.exe'
  packageBytes = [int64](Get-Item $setupPath).Length
  packageSha256 = (Get-FileHash $setupPath -Algorithm SHA256).Hash.ToLowerInvariant()
  portablePackage = 'Ghosium-Browser-Portable.exe'
  portableBytes = [int64](Get-Item $portablePath).Length
  portableSha256 = (Get-FileHash $portablePath -Algorithm SHA256).Hash.ToLowerInvariant()
""",
)
replace_once(
    "scripts/build-source-release-installer.ps1",
    """  maintenance = [ordered]@{
    sameSetupExecutable = $true
""",
    """  portable = [ordered]@{
    executable = 'Ghosium-Browser-Portable.exe'
    registryFree = $true
    createsShortcuts = $false
    adjacentProfileDirectory = 'Ghosium-Portable-Data'
    adjacentRuntimeDirectory = '.ghosium-portable-runtime'
    profileSwitch = '--user-data-dir'
  }
  maintenance = [ordered]@{
    sameSetupExecutable = $true
""",
)
replace_once(
    "scripts/build-source-release-installer.ps1",
    "if ($RequireSigning -and (!$report.signing.applied -or $report.signing.setupStatus -ne 'Valid')) {\n  throw 'Production same-Setup package did not satisfy the mandatory Authenticode signing contract.'\n}",
    "if ($RequireSigning -and (!$report.signing.applied -or $report.signing.setupStatus -ne 'Valid' -or $report.signing.portableStatus -ne 'Valid')) {\n  throw 'Production Setup/Portable packages did not satisfy the mandatory Authenticode signing contract.'\n}",
)
replace_once(
    "scripts/build-source-release-installer.ps1",
    'Write-Host "Canonical Ghosium same-Setup package built: $setupPath"\nWrite-Host "SHA-256: $($report.packageSha256)"',
    'Write-Host "Canonical Ghosium Setup built: $setupPath"\nWrite-Host "Setup SHA-256: $($report.packageSha256)"\nWrite-Host "Canonical Ghosium Portable built: $portablePath"\nWrite-Host "Portable SHA-256: $($report.portableSha256)"',
)
replace_once(
    "scripts/build-source-release-installer.ps1",
    "Write-Output $setupPath\n",
    "Write-Output $setupPath\nWrite-Output $portablePath\n",
)

# Ensure portable source declares its registry-free contract.
portable = Path("installer/ghosium-portable.nsi").read_text(encoding="utf-8")
for forbidden in ("WriteRegStr", "WriteRegDWORD", "CreateShortCut", "SHChangeNotify"):
    if forbidden in portable:
        raise SystemExit(f"Portable package contains forbidden install-side primitive: {forbidden}")
for required in (
    'OutFile "${GHOSIUM_ARTIFACTS}\\Ghosium-Browser-Portable.exe"',
    '${PORTABLE_DATA_DIR}',
    '${GHOSIUM_PORTABLE_PROFILE_SWITCH}',
    'RequestExecutionLevel user',
):
    if required not in portable:
        raise SystemExit(f"Portable contract missing: {required}")

print("Ghosium 0.1.9 Setup + Portable packaging migration complete")
