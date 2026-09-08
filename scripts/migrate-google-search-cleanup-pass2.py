from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def p(relative: str) -> Path:
    return ROOT / relative


def read(relative: str) -> str:
    return p(relative).read_text(encoding="utf-8")


def write(relative: str, content: str) -> None:
    p(relative).write_text(content, encoding="utf-8", newline="\n")


def replace_required(relative: str, old: str, new: str, count: int = 1) -> None:
    text = read(relative)
    if text.count(old) < count:
        raise RuntimeError(f"{relative}: required text not found: {old!r}")
    write(relative, text.replace(old, new, count))


# Store CI tracks the single bundled Ghosium Privacy component; Search is gone.
store_ci = read(".github/workflows/store-trust-audit.yml")
store_ci = store_ci.replace("      - 'search-provider/manifest.json'\n", "")
store_ci = store_ci.replace(
    "          curl --fail --silent --show-error 'http://127.0.0.1:8100/api/update.php?id=ghosium-search&version=0.7.0' | grep -Fq '\"updateAvailable\":false'\n",
    "          curl --fail --silent --show-error 'http://127.0.0.1:8100/api/update.php?id=ghosium-privacy&version=0.1.6' | grep -Fq '\"updateAvailable\":false'\n",
)
write(".github/workflows/store-trust-audit.yml", store_ci)

verify_store = read("scripts/verify-store.php")
block_start = verify_store.find("$privacyManifest = json_decode(")
block_end = verify_store.find("foreach ($catalog['extensions'] as $entry) {", block_start)
if block_start < 0 or block_end < 0:
    raise RuntimeError("scripts/verify-store.php: bundled-manifest verification block not found")
privacy_only = '''$privacyManifest = json_decode((string)file_get_contents($repoRoot . '/extension/manifest.json'), true, 32, JSON_THROW_ON_ERROR);
$privacy = store_find_extension($catalog, 'ghosium-privacy');
if ($privacy === null) {
    fail_store_audit('Built-in Ghosium Privacy Store catalog entry is missing.');
}

foreach ([[$privacy, $privacyManifest, 'Ghosium Privacy']] as [$entry, $manifest, $label]) {
    if (($entry['status'] ?? null) !== 'built_in' || ($entry['distribution']['type'] ?? null) !== 'bundled') {
        fail_store_audit($label . ' must remain a bundled built-in component.');
    }
    if ((string)$entry['version'] !== (string)$manifest['version']) {
        fail_store_audit($label . ' Store version does not match its manifest.');
    }
    if ((int)$entry['manifestVersion'] !== (int)$manifest['manifest_version']) {
        fail_store_audit($label . ' Store manifest version does not match its manifest.');
    }

    $manifestPermissions = array_values($manifest['permissions'] ?? []);
    $manifestHostPermissions = array_values($manifest['host_permissions'] ?? []);
    if (!same_string_set($entry['permissions'], $manifestPermissions)) {
        fail_store_audit($label . ' Store permissions do not match its manifest.');
    }
    if (!same_string_set($entry['hostPermissions'], $manifestHostPermissions)) {
        fail_store_audit($label . ' Store host permissions do not match its manifest.');
    }
}

'''
verify_store = verify_store[:block_start] + privacy_only + verify_store[block_end:]
verify_store = verify_store.replace(
    "Ghosium Store schema, bundled manifests, SHA-256 and Ed25519 trust verification: OK",
    "Ghosium Store schema, bundled manifest, SHA-256 and Ed25519 trust verification: OK",
)
write("scripts/verify-store.php", verify_store)

# Installer should not create a dead first-party Search shortcut.
replace_required(
    "installer/ghosium.nsi",
    '  WriteINIStr "$SMPROGRAMS\\Ghosium Browser\\Ghosium Search.url" "InternetShortcut" "URL" "https://search.ghosium.com/"\n',
    "",
)

# Store navigation is first-party only; search happens in the browser/New Tab.
replace_required(
    "store-web/index.php",
    '      <a href="https://search.ghosium.com/">Search</a>\n',
    "",
)

# Current contribution guidance no longer references removed Search services or
# the retired Portable release path.
write(
    "CONTRIBUTING.md",
    """# Contributing to Ghosium Browser

## Scope

Contributions should preserve the current source-built architecture and privacy/security guarantees.

## Desktop rules

- Ghosium-owned desktop executable code remains C++20.
- Do not add Tauri, WebView2 application wrappers, Rust browser cores or TypeScript/JavaScript browser runtimes.
- Keep the bundled New Tab and privacy component lightweight and script-free unless an architecture change is explicitly approved.
- Do not add switches that disable sandboxing, certificate validation or core browser security isolation.
- Keep Ghosium-controlled product links on approved Ghosium-owned domains; the New Tab search form is the explicit Google Search exception.
- Preserve native user, policy and extension precedence for search-engine selection.

## Web-service rules

`store-web/` and `updates-web/` target commodity shared hosting:

- PHP 8.1+ where server-side execution is required
- JSON data/metadata where appropriate
- no mandatory SQL database
- no analytics/advertising SDKs
- no remote font dependency
- secure headers and protected storage paths

Ghosium does not maintain a first-party web search service.

## Branding

User-facing product copy should use Ghosium branding. Required upstream legal attribution belongs only in the designated notice/license files and build metadata. External service names such as Google Search must be described accurately rather than relabeled as Ghosium services.

## Releases

The canonical public Windows release asset is:

- `Ghosium-Browser-Setup.exe`

The same Setup package handles install, update and uninstall. Technical source-runtime artifacts remain build evidence and are not stable end-user release assets.

## Testing

Before merge, applicable CI must pass source-transform, browser surface, installer/updater, Store, security, locale and release contracts. A production binary is valid only after the controlled full-source Windows build and signing gates succeed for the exact release commit.
""",
)

# Privacy copy must not claim that Ghosium operates Google Search or a retired
# launcher/Portable architecture.
write(
    "PRIVACY.md",
    """# Ghosium Browser Privacy

## Scope

This document describes privacy behavior controlled by Ghosium Browser and Ghosium-controlled product services. Google Search is an external service and is not operated by Ghosium or Brendigo.

## Ghosium Browser

Ghosium does not operate a browser-account backend, advertising identifier system or application analytics SDK.

The source-built browser disables selected browser-owned background/reporting features, including browser Sync/account onboarding surfaces, crash-reporting integrations controlled by the product build, legacy background browser mode and other unowned promotional/background features covered by the source contracts.

The bundled Ghosium Privacy component uses declarative request rules to block selected third-party trackers and remove common campaign/click identifiers from top-level navigations.

## Local profile

Installed mode stores profile data under the Ghosium/Brendigo local application-data profile root defined by the Windows identity contract. History, cookies, bookmarks, site data and preferences are local browser data unless a website or installed extension sends its own data elsewhere.

## Google Search

Google Search is the default web search service. Queries submitted through the Ghosium New Tab search form are sent directly to `https://www.google.com/search`. Ghosium does not proxy, index, store or process those search queries on a first-party search server.

Google receives ordinary network requests for searches sent to its service and applies its own terms, privacy practices and service behavior. Users can change their search engine through supported browser controls; enterprise policy and extension overrides retain their native precedence.

## Ghosium Store

The Store source has no analytics, advertising SDK, remote font dependency or third-party asset dependency. The initial catalog is stored in local JSON and package delivery remains subject to the repository trust controls.

## Websites and search results

Ghosium is a browser, not an anonymity network. A website intentionally opened by the user receives ordinary network traffic and can apply its own cookies/fingerprinting subject to browser controls and Ghosium filtering. Search results are ordinary user-requested web destinations.

## Product links

Ghosium-controlled non-search product UI points to approved Ghosium-owned domains. The New Tab search action intentionally submits queries to Google Search as the configured external search service. This does not block the user from browsing the wider web.

Current public privacy policy: https://ghosium.com/legal/privacy-policy
""",
)

release = read("docs/RELEASE.md")
section_start = release.find("## Search gate\n")
section_end = release.find("## Update and uninstall gate\n", section_start)
if section_start < 0 or section_end < 0:
    raise RuntimeError("docs/RELEASE.md: Search gate section not found")
search_gate = """## Search gate

Ghosium Browser does not publish or bundle a first-party web search service. The release candidate must preserve all of the following:

- Chromium's reviewed Google fallback remains intact;
- New Tab submits `q` directly to `https://www.google.com/search`;
- no Ghosium-owned default-search provider is injected into engine source;
- explicit user search-engine choices, enterprise policy and extension overrides retain native precedence;
- no first-party Search server/deployment payload is packaged or published;
- Google Search is described as an external service rather than a Ghosium privacy service.

"""
release = release[:section_start] + search_gate + release[section_end:]
write("docs/RELEASE.md", release)

engine_readme = read("engine/README.md")
engine_readme = engine_readme.replace("## Store and Search\n", "## Store and search\n", 1)
engine_readme = engine_readme.replace(
    "`search.ghosium.com` is the Ghosium default search endpoint. Search results are ordinary user-requested web destinations and are not restricted by the product-link host allowlist.\n",
    "Google Search is the default external web search service. The Ghosium source transform keeps Chromium's reviewed Google fallback and does not inject a Ghosium-owned search provider. User, policy and extension search overrides retain native precedence.\n",
    1,
)
engine_readme = engine_readme.replace(
    "Until that controlled compile and runtime chain succeeds, `0.1.2` remains a source-development milestone rather than a proven source-built release.",
    "Until that controlled compile and runtime chain succeeds, `0.1.6` remains a source-development milestone rather than a proven source-built release.",
)
write("engine/README.md", engine_readme)

# Remove this pass after it has completed; it is migration tooling, not product code.
p("scripts/migrate-google-search-cleanup-pass2.py").unlink()
