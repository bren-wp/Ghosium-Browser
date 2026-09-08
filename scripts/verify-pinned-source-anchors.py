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

# The source paths below are pinned engine implementation anchors. Their names
# are upstream technical identifiers only; Ghosium public/release surfaces are
# verified separately and must never expose the upstream product brand.
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
        "IDS_SETTINGS_ABOUT_BROWSER_VERSION",
    ),
    "components/components_chromium_strings.grd": (
        "IDS_SHORT_PRODUCT_NAME",
        "IDS_PRODUCT_NAME",
        "IDS_BROWSER_WINDOW_TITLE_FORMAT",
    ),
    "extensions/strings/extensions_chromium_strings.grdp": (),
    "chrome/common/url_constants.h": (
        "kChromeUIScheme",
        "kChromeUIUntrustedScheme",
        "kChromeUINewTabURL",
    ),
    "chrome/app/theme/chromium/BRANDING": (
        "COMPANY_FULLNAME=The Chromium Authors",
        "COMPANY_SHORTNAME=The Chromium Authors",
        "PRODUCT_FULLNAME=Chromium",
        "PRODUCT_SHORTNAME=Chromium",
        "PRODUCT_INSTALLER_FULLNAME=Chromium Installer",
        "COPYRIGHT=Copyright 2026 The Chromium Authors. All rights reserved.",
        "MAC_BUNDLE_ID=org.chromium.Chromium",
    ),
    "chrome/browser/resources/signin/managed_user_profile_notice/managed_user_profile_notice_value_prop.html.ts": (
        "managedUserProfileNoticeValuePropTitle",
        "managedUserProfileNoticeValuePropSubtitle",
    ),
    "chrome/browser/resources/contextual_tasks/top_toolbar_logo.html.ts": (
        "chromeProductLogo",
        "productLogo",
    ),
    "components/search_engines/template_url_prepopulate_data.cc": (
        "google.com",
        "bing.com",
        "yahoo.com",
        "duckduckgo.com",
    ),
    "chrome/install_static/chromium_install_modes.h": (
        'kCompanyPathName[] = L"Chromium"',
        'kProductPathName[] = L"Chromium"',
        '.base_app_name = L"Chromium"',
        '.base_app_id = L"Chromium"',
        '.prog_id_prefix = L"ChromiumHTM"',
        '.prog_id_description = L"Chromium HTML Document"',
        '.active_setup_guid = L"{7A8D7EAD-4BD0-42A6-80C1-2F9F27EF2E14}"',
        '.legacy_command_execute_clsid = L"{A2DF06F9-A21A-44A8-8A99-8B9C84F29160}"',
        '.toast_activator_clsid = L"{635EFA6F-08D6-4EC9-BD14-8A0FDE975159}"',
        '.elevator_clsid = L"{B88C45B9-8825-4629-B83E-77CC67D9CEED}"',
    ),
    "chrome/BUILD.gn": (
        'output_name = "chrome"',
        'sources = [ "app/chrome_exe_main_win.cc" ]',
        'chrome_exe_manifest = "chrome_exe_manifest"',
        'chrome_exe_main_win = "chrome_exe_main_win.cc"',
        'chrome_exe_main_linux = "chrome_exe_main_linux.cc"',
    ),
    "build/win/reorder-imports.py": (
        'input_image = os.path.join(input_dir, "chrome.exe")',
        'output_image = os.path.join(output_dir, "chrome.exe")',
        'assert os.path.isfile(input_image)',
    ),
    "chrome/app/chrome_exe.ver": (
        'INTERNAL_NAME=chrome_exe',
        'ORIGINAL_FILENAME=chrome.exe',
    ),
    "chrome/installer/mini_installer/BUILD.gn": (
        'chrome_path = "$root_out_dir/chrome.exe"',
        'chrome_dll_path = "$root_out_dir/$chrome_dll_file"',
    ),
    "chrome/installer/mini_installer/chrome.release": (
        'chrome.exe: %(ChromeDir)s\\',
        'chrome_proxy.exe: %(ChromeDir)s\\',
    ),
    "chrome/installer/setup/setup_constants.cc": (
        'const wchar_t kChromeExe[] = L"chrome.exe";',
    ),
    "chrome/installer/launcher_support/chrome_launcher_support.cc": (
        'L"chrome.exe"',
        'kChromeExe',
    ),
    "chrome/chrome_proxy/BUILD.gn": (
        'output_name = "chrome_proxy"',
    ),
    "chrome/chrome_proxy/chrome_proxy.ver": (
        'INTERNAL_NAME=chrome_proxy',
        'ORIGINAL_FILENAME=chrome_proxy.exe',
    ),
    "chrome/chrome_proxy/chrome_proxy_main_win.cc": (
        'chrome_proxy',
        'chrome.exe',
    ),
    "chrome/browser/ui/webui/version/version_ui.cc": (
        'version_info::GetVersionNumber()',
        'version_info::GetOSType()',
        'version_info::GetLastChange()',
        'version_info::GetVersionStringWithModifier(',
    ),
    "chrome/browser/ui/webui/side_panel/customize_chrome/customize_chrome_page_handler.cc": (
        "CustomizeChromePageHandler",
    ),
    "chrome/browser/ui/chrome_pages.cc": (
        "ShowChromePageForURL",
        "chrome::kChromeUISettingsURL",
    ),
    "chrome/browser/ui/webui/extensions/extensions_ui.cc": (
        "ExtensionsUI::ExtensionsUI",
        "extensions::ExtensionManagement",
        "developerMode",
        "loadTimeData",
        "kChromeUIExtensionsHost",
        "GetWebUIDataSource",
        "ManagedUIHandler",
        "Profile",
        "WebUI",
        "WebUIDataSource",
    ),
    "chrome/browser/resources/settings/about_page/about_page.ts": (
        "requestUpdate()",
    ),
    "chrome/installer/setup/setup_main.cc": (
        "SetupMain",
        "UninstallProduct",
    ),
    "chrome/installer/setup/uninstall.cc": (
        "UninstallProduct",
    ),
    "chrome/installer/setup/install_worker.cc": (
        "InstallOrUpdateProduct",
        "AddUninstallShortcutWorkItems",
    ),
    "chrome/installer/util/util_constants.h": (
        "kSetupExe",
        "kChromeExe",
        "kChromeDll",
        "kChromeNewExe",
        "kChromeOldExe",
        "kChromeProxyExe",
        "kChromeVisualElementsManifest",
        "kChromeElfDll",
        "kChromePwaLauncherExe",
    ),
    "ui/webui/resources/images/chrome_logo_dark.svg": (),
    "chrome/app/theme/chromium/product_logo.svg": (),
    "components/vector_icons/chromium/product.icon": (),
    "components/vector_icons/chromium/product_refresh.icon": (),
}

SEARCH_FALLBACK_BLOCK = "TemplateURLPrepopulateData::GetPrepopulatedEngines"

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
    raise RuntimeError(f"Unable to fetch pinned source anchor URL after {attempts} attempts: {url}") from last_error


def fetch_file(revision: str, path: str) -> str:
    url = f"{GITILES_ROOT}/{revision}/{path}?format=TEXT"
    encoded = _request_bytes(url)
    try:
        decoded = base64.b64decode(encoded, validate=True)
    except Exception as error:  # noqa: BLE001 - surface a precise contract failure.
        preview = encoded[:120].decode("utf-8", errors="replace")
        raise RuntimeError(f"Gitiles returned non-base64 content for {path}: {preview!r}") from error
    return decoded.decode("utf-8")


def fetch_directory_names(revision: str, path: str) -> set[str]:
    url = f"{GITILES_ROOT}/{revision}/{path}/?format=JSON"
    raw = _request_bytes(url).decode("utf-8")
    if raw.startswith(")]}'"):
        raw = raw.split("\n", 1)[1]
    payload = json.loads(raw)
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise RuntimeError(f"Gitiles directory listing is malformed for {path}")
    return {str(entry.get("name")) for entry in entries if isinstance(entry, dict) and entry.get("name")}


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
        for anchor in anchors:
            if anchor not in text:
                raise RuntimeError(f"Pinned engine patch anchor changed: {path}: {anchor}")
        if path.endswith("template_url_prepopulate_data.cc") and SEARCH_FALLBACK_BLOCK not in text:
            raise RuntimeError("Pinned engine fallback-search implementation no longer matches the reviewed Ghosium rewrite block.")
        print(f"OK source anchors: {path} ({len(anchors)} required literal(s))")


def verify_locale_layout(revision: str) -> None:
    config = json.loads((REPO_ROOT / "engine/branding/product.json").read_text(encoding="utf-8"))
    locale_config = config.get("locales", {})
    locales = locale_config.get("supported", [])
    if not isinstance(locales, list) or len(locales) < 31:
        raise RuntimeError("engine/branding/product.json must define more than 30 supported locales before source layout validation.")
    if locale_config.get("default") != "en-US" or locale_config.get("required") != "hr":
        raise RuntimeError("Ghosium locale contract requires en-US as primary and hr as required Croatian locale.")
    if len(locales) != len(set(map(str, locales))):
        raise RuntimeError("Ghosium supported locale list contains duplicates.")

    expected_locales = [translation_locale(str(locale)) for locale in locales]
    expected_locales = [locale for locale in expected_locales if locale]

    for directory, prefix in LOCALE_DIRECTORIES:
        names = fetch_directory_names(revision, directory)
        missing = [f"{prefix}{locale}.xtb" for locale in expected_locales if f"{prefix}{locale}.xtb" not in names]
        if missing:
            raise RuntimeError(
                f"Pinned engine locale layout changed under {directory}; missing: {', '.join(missing)}"
            )
        print(f"OK locale layout: {directory} ({len(expected_locales)} translated locale bundle(s))")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--revision",
        help="Pinned engine Git commit. Defaults to ENGINE_SOURCE_REVISION.",
    )
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
