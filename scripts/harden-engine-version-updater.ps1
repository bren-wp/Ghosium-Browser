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

function Add-IncludeAfter {
  param(
    [Parameter(Mandatory = $true)][string]$Include,
    [Parameter(Mandatory = $true)][string]$Anchor
  )

  if ($script:updated.Contains($Include)) {
    return
  }
  if (!$script:updated.Contains($Anchor)) {
    throw "Ghosium updater include layout changed; missing anchor: $Anchor"
  }
  $script:updated = $script:updated.Replace($Anchor, "$Anchor`n$Include")
}

Add-IncludeAfter -Include '#include <algorithm>' -Anchor '#include <array>'
Add-IncludeAfter -Include '#include "base/file_version_info.h"' -Anchor '#include "base/files/file_util.h"'
Add-IncludeAfter -Include '#include "base/strings/utf_string_conversions.h"' -Anchor '#include "base/strings/string_util.h"'

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

$oldUrlGuard = @'
  if (!url.is_valid() || !url.SchemeIs("https") || url.has_username() ||
      url.has_password() || url.has_ref() || url.has_query() ||
      url.host_piece() != kGhosiumUpdateHost) {
    return false;
  }

  if (require_setup_filename &&
      !base::EndsWith(url.path_piece(), "/Ghosium-Browser-Setup.exe",
                      base::CompareCase::SENSITIVE)) {
    return false;
  }
'@
$strictUrlGuard = @'
  if (!url.is_valid() || !url.SchemeIs("https") || url.has_username() ||
      url.has_password() || url.has_ref() || url.has_query() ||
      url.host_piece() != kGhosiumUpdateHost || url.EffectiveIntPort() != 443) {
    return false;
  }

  if (require_setup_filename &&
      url.path_piece() != "/windows/Ghosium-Browser-Setup.exe") {
    return false;
  }
'@
if ($updated.Contains($oldUrlGuard)) {
  $updated = $updated.Replace($oldUrlGuard, $strictUrlGuard)
} elseif (!$updated.Contains($strictUrlGuard)) {
  throw 'Ghosium updater URL allowlist layout changed unexpectedly.'
}

$manifestLoaderAnchor = @'
    manifest_loader_ = CreateUpdateLoader(manifest_url);
    manifest_loader_->DownloadToString(
'@
$manifestLoaderHardened = @'
    manifest_loader_ = CreateUpdateLoader(manifest_url);
    manifest_loader_->SetOnRedirectCallback(base::BindRepeating(
        &VersionUpdaterGhosiumWin::OnManifestRedirect,
        weak_factory_.GetWeakPtr()));
    manifest_loader_->DownloadToString(
'@
if ($updated.Contains($manifestLoaderAnchor)) {
  $updated = $updated.Replace($manifestLoaderAnchor, $manifestLoaderHardened)
} elseif (!$updated.Contains($manifestLoaderHardened)) {
  throw 'Ghosium manifest loader layout changed; cannot install redirect rejection.'
}

$setupLoaderAnchor = @'
    setup_loader_ = CreateUpdateLoader(setup_url_);
    setup_loader_->SetOnDownloadProgressCallback(base::BindRepeating(
'@
$setupLoaderHardened = @'
    setup_loader_ = CreateUpdateLoader(setup_url_);
    setup_loader_->SetOnRedirectCallback(base::BindRepeating(
        &VersionUpdaterGhosiumWin::OnSetupRedirect,
        weak_factory_.GetWeakPtr()));
    setup_loader_->SetOnDownloadProgressCallback(base::BindRepeating(
'@
if ($updated.Contains($setupLoaderAnchor)) {
  $updated = $updated.Replace($setupLoaderAnchor, $setupLoaderHardened)
} elseif (!$updated.Contains($setupLoaderHardened)) {
  throw 'Ghosium Setup loader layout changed; cannot install redirect rejection.'
}

$privateAnchor = @'
 private:
  void OnManifestDownloaded(std::optional<std::string> body) {
'@
$privateHardened = @'
 private:
  void OnManifestRedirect(const GURL&,
                          const net::RedirectInfo&,
                          const network::mojom::URLResponseHead&,
                          std::vector<std::string>*) {
    Fail(FAILED_HTTP,
         u"Ghosium update manifest redirects are not permitted.");
  }

  void OnSetupRedirect(const GURL&,
                       const net::RedirectInfo&,
                       const network::mojom::URLResponseHead&,
                       std::vector<std::string>*) {
    Fail(FAILED_DOWNLOAD,
         u"Ghosium update package redirects are not permitted.");
  }

  void OnManifestDownloaded(std::optional<std::string> body) {
'@
if ($updated.Contains($privateAnchor)) {
  $updated = $updated.Replace($privateAnchor, $privateHardened)
} elseif (!$updated.Contains($privateHardened)) {
  throw 'Ghosium updater class layout changed; cannot install redirect rejection handlers.'
}

$oldComment = @'
    // IsBinaryTrusted validates Authenticode and, for production builds,
    // requires the downloaded Setup publisher subject to match the running
    // Ghosium Browser publisher. This prevents an arbitrary executable from
    // being launched even if it is served from the update host.
'@
$newComment = @'
    // Force Authenticode validation even though Ghosium is built from the
    // unbranded upstream configuration. IsBinaryTrusted validates the Setup
    // signature and requires its publisher subject to match the signed running
    // Ghosium Browser executable before launch.
'@
if ($updated.Contains($oldComment)) {
  $updated = $updated.Replace($oldComment, $newComment)
}

$identityAnchor = @'
    if (!base::win::IsBinaryTrusted(setup_path_, true,
                                    true /* force_verify_in_dev_builds */)) {
      Fail(FAILED_DOWNLOAD,
           u"The Ghosium update package failed publisher verification.");
      return;
    }

    callback_.Run(UPDATING, 100, false, false, available_version_,
'@
$identityHardened = @'
    if (!base::win::IsBinaryTrusted(setup_path_, true,
                                    true /* force_verify_in_dev_builds */)) {
      Fail(FAILED_DOWNLOAD,
           u"The Ghosium update package failed publisher verification.");
      return;
    }

    // Bind the manifest version to the signed PE metadata. HTTPS, SHA-256 and
    // publisher validation alone must not allow a compromised update endpoint
    // to label an older signed Setup as a newer release and trigger rollback.
    std::unique_ptr<FileVersionInfo> setup_version_info =
        FileVersionInfo::CreateFileVersionInfo(setup_path_);
    if (!setup_version_info) {
      Fail(FAILED_DOWNLOAD,
           u"The Ghosium update package has no readable product metadata.");
      return;
    }
    const std::string setup_product_name =
        base::UTF16ToUTF8(setup_version_info->product_name());
    const std::string setup_company_name =
        base::UTF16ToUTF8(setup_version_info->company_name());
    const std::string setup_product_version =
        base::UTF16ToUTF8(setup_version_info->product_version());
    if (setup_product_name != "Ghosium Browser" ||
        setup_company_name != "Brendigo" ||
        setup_product_version != available_version_) {
      Fail(FAILED_DOWNLOAD,
           u"The signed Ghosium Setup identity/version does not match the update manifest.");
      return;
    }

    callback_.Run(UPDATING, 100, false, false, available_version_,
'@
if ($updated.Contains($identityAnchor)) {
  $updated = $updated.Replace($identityAnchor, $identityHardened)
} elseif (!$updated.Contains($identityHardened)) {
  throw 'Ghosium updater trust block changed; cannot bind signed PE identity to the manifest version.'
}

if ($updated -ne $text) {
  [IO.File]::WriteAllText($sourcePath, $updated, [Text.UTF8Encoding]::new($false))
}

$verify = [IO.File]::ReadAllText($sourcePath)
foreach ($required in @(
  '#include <algorithm>',
  '#include "base/file_version_info.h"',
  '#include "base/strings/utf_string_conversions.h"',
  'url.EffectiveIntPort() != 443',
  'url.path_piece() != "/windows/Ghosium-Browser-Setup.exe"',
  'SetOnRedirectCallback',
  'OnManifestRedirect',
  'OnSetupRedirect',
  'base::win::IsBinaryTrusted(setup_path_, true,',
  'true /* force_verify_in_dev_builds */',
  'FileVersionInfo::CreateFileVersionInfo(setup_path_)',
  'setup_product_name != "Ghosium Browser"',
  'setup_company_name != "Brendigo"',
  'setup_product_version != available_version_'
)) {
  if (!$verify.Contains($required)) {
    throw "Ghosium updater hardening failed: missing $required"
  }
}
if ($verify.Contains('false /* force_verify_in_dev_builds */')) {
  throw 'Ghosium updater still permits unbranded builds to bypass Authenticode verification.'
}
if ($verify.Contains('base::EndsWith(url.path_piece(), "/Ghosium-Browser-Setup.exe"')) {
  throw 'Ghosium updater still accepts arbitrary same-host Setup paths instead of the canonical Windows package path.'
}

$hashIndex = $verify.IndexOf('crypto::hash::HashFile')
$trustIndex = $verify.IndexOf('base::win::IsBinaryTrusted(setup_path_, true,')
$identityIndex = $verify.IndexOf('FileVersionInfo::CreateFileVersionInfo(setup_path_)')
$launchIndex = $verify.IndexOf('base::LaunchProcess')
if ($hashIndex -lt 0 -or $trustIndex -lt 0 -or $identityIndex -lt 0 -or $launchIndex -lt 0 -or
    $hashIndex -gt $launchIndex -or $trustIndex -gt $launchIndex -or $identityIndex -gt $launchIndex) {
  throw 'Ghosium updater must verify hash, Authenticode publisher and signed PE identity/version before launching Setup.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after updater hardening.'
}
if ($thirdPartyChanges) {
  throw 'Ghosium updater hardening modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium updater hardening: exact HTTPS package path, no redirects, mandatory Authenticode and signed PE identity/version binding.'
