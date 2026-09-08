from __future__ import annotations

import argparse
import base64
import json
import re
import ssl
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GITILES_ROOT = "https://chromium.googlesource.com/chromium/src/+"

# Revision-pinned source anchors used by Ghosium transforms. Technical upstream
# symbol/path names are implementation API, not public product branding.
FILE_ANCHORS: dict[str, tuple[str, ...]] = {
    "chrome/app/chromium_strings.grd": (
        "IDS_PRODUCT_NAME",
        "IDS_SHORT_PRODUCT_NAME",
        "IDS_ABOUT_VERSION_COMPANY_NAME",
        "IDS_PRODUCT_DESCRIPTION",
        "IDS_WELCOME_TO_CHROME",
    ),
    "chrome/app/settings_chromium_strings.grdp": (
        "IDS_SETTINGS_ABOUT_PROGRAM",
        "IDS_SETTINGS_GET_HELP_USING_CHROME",
        "IDS_SETTINGS_UPGRADE_UP_TO_DATE",
    ),
    "components/components_chromium_strings.grd": (
        "IDS_SHORT_PRODUCT_LOGO_ALT_TEXT",
        "IDS_VERSION_UI_LICENSE",
        "IDS_VERSION_UI_LICENSE_CHROMIUM",
    ),
    "extensions/strings/extensions_chromium_strings.grdp": (),
    "chrome/common/url_constants.h": (
        '"https://support.google.com/chrome?p=help&ctx=keyboard"',
        '"https://support.google.com/chrome?p=help&ctx=menu"',
        '"https://support.google.com/chrome?p=help&ctx=settings"',
    ),
    "chrome/common/webui_url_constants.h": (
        'inline constexpr char kChromeUIProfilePickerHost[] = "profile-picker";',
        'inline constexpr char kChromeUIProfilePickerUrl[] = "chrome://profile-picker/";',
        '"chrome://password-manager/checkup?start=true"',
        '"chrome://password-manager/settings"',
        '"chrome://password-manager"',
    ),
    "components/password_manager/content/common/web_ui_constants.h": (
        'inline constexpr char kChromeUIPasswordManagerHost[] = "password-manager";',
    ),
    "chrome/browser/ui/webui/signin/profile_picker_ui.h": (
        "ProfilePickerUIConfig",
        "chrome::kChromeUIProfilePickerHost",
    ),
    "chrome/browser/ui/webui/password_manager/password_manager_ui.h": (
        "PasswordManagerUIConfig",
        "password_manager::kChromeUIPasswordManagerHost",
    ),
    "content/public/common/url_constants.h": (
        'inline constexpr char kChromeUIScheme[] = "chrome";',
        'inline constexpr char kChromeUIUntrustedScheme[] = "chrome-untrusted";',
    ),
    "chrome/app/theme/chromium/BRANDING": (
        "COMPANY_FULLNAME=The Chromium Authors",
        "COMPANY_SHORTNAME=The Chromium Authors",
        "PRODUCT_FULLNAME=Chromium",
        "PRODUCT_SHORTNAME=Chromium",
        "PRODUCT_INSTALLER_FULLNAME=Chromium Installer",
        "COPYRIGHT=Copyright @LASTCHANGE_YEAR@ The Chromium Authors. All rights reserved.",
        "MAC_BUNDLE_ID=org.chromium.Chromium",
    ),
    "chrome/browser/resources/signin/managed_user_profile_notice/managed_user_profile_notice_value_prop.html.ts": (
        'alt="Chrome logo"',
        'src="chrome://theme/current-channel-logo@2x"',
    ),
    "chrome/browser/resources/contextual_tasks/top_toolbar_logo.html.ts": (
        'class="top-toolbar-logo chrome-logo-light"',
        'chrome_product.svg',
        'class="top-toolbar-logo chrome-logo-dark"',
        'chrome_logo_dark.svg',
    ),
    "components/search_engines/template_url_prepopulate_data.cc": (
        "std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch(",
        "return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,",
        "google.id,",
        "/*use_first_as_fallback=*/true",
    ),
    "chrome/install_static/chromium_install_modes.h": (
        'inline constexpr wchar_t kCompanyPathName[] = L"";',
        'inline constexpr wchar_t kProductPathName[] = L"Chromium";',
        '.base_app_name = L"Chromium",',
        '.base_app_id = L"Chromium",',
        '.browser_prog_id_prefix = L"ChromiumHTM",',
        'L"Chromium HTML Document",',
        '.direct_launch_url_scheme = "chromium",',
        '.pdf_prog_id_prefix = L"ChromiumPDF",',
        'L"Chromium PDF Document",',
        'kSafeBrowsingName[] = "chromium"',
    ),
    "chrome/BUILD.gn": (
        '$root_out_dir/initialexe/chrome.exe',
        '$root_out_dir/initialexe/chrome.exe.pdb',
        '$root_out_dir/chrome.exe',
        '$root_out_dir/chrome.exe.pdb',
        '_chrome_output_name = "initialexe/chrome"',
    ),
    "build/win/reorder-imports.py": (
        "os.path.join(input_dir, 'chrome.exe')",
        "os.path.join(output_dir, 'chrome.exe')",
        "os.path.join(input_dir, 'chrome.exe.*')",
    ),
    "chrome/app/chrome_exe.ver": (
        "INTERNAL_NAME=chrome_exe",
        "ORIGINAL_FILENAME=chrome.exe",
    ),
    "chrome/installer/mini_installer/BUILD.gn": (
        '"$root_out_dir/chrome.exe",',
    ),
    "chrome/installer/mini_installer/chrome.release": (
        'chrome.exe: %(ChromeDir)s\\',
        'chrome_proxy.exe: %(ChromeDir)s\\',
    ),
    "chrome/installer/util/util_constants.h": (
        'kChromeDll[] = L"chrome.dll"',
        'kChromeExe[] = L"chrome.exe"',
        'kChromeNewExe[] = L"new_chrome.exe"',
        'kChromeOldExe[] = L"old_chrome.exe"',
        'kChromeProxyExe[] = L"chrome_proxy.exe"',
        'kChromeProxyNewExe[] = L"new_chrome_proxy.exe"',
        'kChromeProxyOldExe[] = L"old_chrome_proxy.exe"',
    ),
    "chrome/installer/setup/setup_constants.cc": (
        'kVisualElementsManifest[] = L"chrome.VisualElementsManifest.xml"',
    ),
    "chrome/installer/launcher_support/chrome_launcher_support.cc": (
        'kInstallationRegKey[] = L"Software\\\\Chromium"',
        'kChromeExe[] = L"chrome.exe"',
    ),
    "chrome/chrome_proxy/BUILD.gn": (
        'executable("chrome_proxy") {',
    ),
    "chrome/chrome_proxy/chrome_proxy.ver": (
        "INTERNAL_NAME=chrome_proxy",
        "ORIGINAL_FILENAME=chrome_proxy.exe",
    ),
    "chrome/chrome_proxy/chrome_proxy_main_win.cc": (
        'FILE_PATH_LITERAL("chrome.exe")',
        'FILE_PATH_LITERAL("chrome_proxy.exe")',
    ),
    "chrome/browser/ui/webui/version/version_ui.cc": (
        '#include "chrome/common/url_constants.h"',
        "html_source->AddString(version_ui::kVersion,",
        "version_info::GetVersionNumber());",
        "base::UTF8ToUTF16(version_info::GetVersionNumber()),",
        "version_info::GetOSType()",
        "version_info::GetLastChange()",
    ),
    "chrome/browser/ui/webui/side_panel/customize_chrome/customize_chrome_page_handler.cc": (
        "CustomizeChromePageHandler",
    ),
    "chrome/browser/ui/chrome_pages.cc": (
        "void ShowWebStore(BrowserWindowInterface* browser,",
        "GURL webstore_url = extension_urls::GetNewWebstoreLaunchURL();",
        "browser, extension_urls::AppendUtmSource(webstore_url, utm_source_value));",
    ),
    "chrome/browser/ui/webui/extensions/extensions_ui.cc": (
        '"suspiciousInstallHelpUrl"',
        "chrome::kRemoveNonCWSExtensionURL",
        '"enhancedSafeBrowsingWarningHelpUrl"',
        "chrome::kCwsEnhancedSafeBrowsingLearnMoreURL",
        '"getMoreExtensionsUrl"',
        "extension_urls::GetWebstoreExtensionsCategoryURL()",
        '"modernWebGuidanceURL"',
        "extension_urls::GetModernWebGuidanceURL()",
        '"hostPermissionsLearnMoreLink"',
        "extension_permissions_constants::kRuntimeHostPermissionsHelpURL",
    ),
    "chrome/browser/resources/settings/about_page/about_page.ts": ("requestUpdate()",),
    "chrome/installer/setup/setup_main.cc": ("SetupMain", "UninstallProduct"),
    "chrome/installer/setup/uninstall.cc": ("UninstallProduct",),
    "chrome/installer/setup/install_worker.cc": (
        "InstallOrUpdateProduct",
        "AddUninstallShortcutWorkItems",
    ),
    "components/performance_manager/user_tuning/prefs.cc": (
        "kMemorySaverModeState, static_cast<int>(MemorySaverModeState::kDisabled));",
        "static_cast<int>(MemorySaverModeAggressiveness::kMedium)",
        "registry->RegisterBooleanPref(kTabFreezingEnabled, true);",
    ),
    "ui/webui/resources/images/chrome_logo_dark.svg": (),
    "chrome/app/theme/chromium/product_logo.svg": (),
    "components/vector_icons/chromium/product.icon": (),
    "components/vector_icons/chromium/product_refresh.icon": (),
}

SEARCH_FALLBACK_BLOCK = "std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch("
LOCALE_DIRECTORIES: tuple[tuple[str, str], ...] = (
    ("chrome/app/resources", "chromium_strings_"),
    ("chrome/app/resources", "generated_resources_"),
    ("components/strings", "components_chromium_strings_"),
    ("extensions/strings", "extensions_strings_"),
)


def _request_bytes(url: str, attempts: int = 4) -> bytes:
    context = ssl.create_default_context()
    headers = {"User-Agent": "Ghosium-Source-Anchor-Audit/1.0"}
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request, timeout=30, context=context) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            if attempt + 1 < attempts:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Unable to fetch pinned source after {attempts} attempts: {url}") from last_error


def fetch_file(revision: str, path: str) -> str:
    encoded = _request_bytes(f"{GITILES_ROOT}/{revision}/{path}?format=TEXT")
    try:
        decoded = base64.b64decode(encoded, validate=True)
    except Exception as error:  # noqa: BLE001
        preview = encoded[:120].decode("utf-8", errors="replace")
        raise RuntimeError(f"Gitiles returned non-base64 content for {path}: {preview!r}") from error
    return decoded.decode("utf-8")


def fetch_directory_names(revision: str, path: str) -> set[str]:
    raw = _request_bytes(f"{GITILES_ROOT}/{revision}/{path}/?format=JSON").decode("utf-8")
    if raw.startswith(")]}'"):
        raw = raw.split("\n", 1)[1]
    payload = json.loads(raw)
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise RuntimeError(f"Gitiles directory listing is malformed for {path}")
    return {str(entry["name"]) for entry in entries if isinstance(entry, dict) and entry.get("name")}


def translation_locale(locale: str) -> str | None:
    if locale == "en-US":
        return None
    if locale == "nb":
        return "no"
    if locale == "he":
        return "iw"
    return locale


def verify_file_anchors(revision: str) -> None:
    for path, anchors in FILE_ANCHORS.items():
        text = fetch_file(revision, path)
        missing = [anchor for anchor in anchors if anchor not in text]
        if missing:
            raise RuntimeError(
                f"Pinned engine patch anchor changed: {path}: {', '.join(missing)}"
            )
        if path.endswith("template_url_prepopulate_data.cc") and SEARCH_FALLBACK_BLOCK not in text:
            raise RuntimeError(
                "Pinned engine fallback-search implementation no longer matches the reviewed rewrite block."
            )
        print(f"OK source anchors: {path} ({len(anchors)} required literal(s))")


def verify_locale_layout(revision: str) -> None:
    config = json.loads((REPO_ROOT / "engine/branding/product.json").read_text(encoding="utf-8"))
    locale_config = config.get("locales", {})
    locales = locale_config.get("supported", [])
    if not isinstance(locales, list) or len(locales) != 38:
        raise RuntimeError("Ghosium product configuration must define exactly 38 supported locales.")
    if locale_config.get("default") != "en-US" or locale_config.get("required") != "hr":
        raise RuntimeError("Ghosium locale contract requires en-US default and hr required locale.")

    normalized = [str(locale) for locale in locales]
    if len(normalized) != len(set(normalized)):
        raise RuntimeError("Ghosium supported locale list contains duplicates.")

    expected = [translation_locale(locale) for locale in normalized]
    expected = [locale for locale in expected if locale]
    for directory, prefix in LOCALE_DIRECTORIES:
        names = fetch_directory_names(revision, directory)
        missing = [f"{prefix}{locale}.xtb" for locale in expected if f"{prefix}{locale}.xtb" not in names]
        if missing:
            raise RuntimeError(
                f"Pinned engine locale layout changed under {directory}; missing: {', '.join(missing)}"
            )
        print(f"OK locale layout: {directory} ({len(expected)} translated locale bundle(s))")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", help="Pinned engine Git commit. Defaults to ENGINE_SOURCE_REVISION.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    revision = args.revision or (REPO_ROOT / "ENGINE_SOURCE_REVISION").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise RuntimeError(f"ENGINE_SOURCE_REVISION is not one lowercase 40-character Git commit: {revision!r}")

    verify_file_anchors(revision)
    verify_locale_layout(revision)
    print(f"Ghosium pinned engine source patch-anchor contract: OK ({revision})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
