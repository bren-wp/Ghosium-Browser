from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = "0.1.6"


def path(relative: str) -> Path:
    return ROOT / relative


def read(relative: str) -> str:
    return path(relative).read_text(encoding="utf-8")


def write(relative: str, content: str) -> None:
    path(relative).write_text(content, encoding="utf-8", newline="\n")


def replace_required(relative: str, old: str, new: str, count: int = 1) -> None:
    text = read(relative)
    if text.count(old) < count:
        raise RuntimeError(f"{relative}: required text not found: {old!r}")
    write(relative, text.replace(old, new, count))


def delete_file(relative: str) -> None:
    target = path(relative)
    if target.exists():
        target.unlink()


def delete_tree(relative: str) -> None:
    target = path(relative)
    if target.exists():
        shutil.rmtree(target)


# Versioned product state.
write("VERSION", VERSION + "\n")

extension = json.loads(read("extension/manifest.json"))
extension["version"] = VERSION
write("extension/manifest.json", json.dumps(extension, indent=2, ensure_ascii=False) + "\n")

store = json.loads(read("store-web/storage/data/extensions.json"))
store["updatedAt"] = "2026-09-08T19:40:00Z"
store_extensions = []
for item in store.get("extensions", []):
    if item.get("id") == "ghosium-search":
        continue
    if item.get("id") == "ghosium-privacy":
        item["version"] = VERSION
    store_extensions.append(item)
store["extensions"] = store_extensions
write("store-web/storage/data/extensions.json", json.dumps(store, indent=2, ensure_ascii=False) + "\n")

stable = json.loads(read("updates-web/windows/stable.json"))
stable["version"] = VERSION
stable["enabled"] = False
stable["sha256"] = ""
stable["size"] = 0
write("updates-web/windows/stable.json", json.dumps(stable, indent=2, ensure_ascii=False) + "\n")

product = json.loads(read("engine/branding/product.json"))
product.get("productUrls", {}).pop("search", None)
product["allowedProductUrls"] = [
    url for url in product.get("allowedProductUrls", [])
    if url != "https://search.ghosium.com/"
]
product["externalServices"] = {
    "defaultSearch": {
        "name": "Google Search",
        "searchUrl": "https://www.google.com/search?q={searchTerms}",
    }
}
write("engine/branding/product.json", json.dumps(product, indent=2, ensure_ascii=False) + "\n")

# New Tab sends q directly to Google. Ghosium neither proxies nor hosts search.
newtab = read("extension/newtab.html")
for old, new in {
    '<p class="eyebrow">GHOSIUM SEARCH</p>': '<p class="eyebrow">GOOGLE SEARCH</p>',
    "Fast browsing, private search and Ghosium protections in one clean experience.": "Fast browsing, Google Search and Ghosium protections in one clean experience.",
    '<form class="search" action="https://search.ghosium.com/" method="get" role="search">': '<form class="search" action="https://www.google.com/search" method="get" role="search">',
    '<label class="sr-only" for="q">Ghosium Search</label>': '<label class="sr-only" for="q">Google Search</label>',
    'placeholder="Search with Ghosium"': 'placeholder="Search with Google"',
    '<span><strong>Ghosium Search</strong> private search</span>': '<span><strong>Google Search</strong> web search</span>',
}.items():
    if old not in newtab:
        raise RuntimeError(f"extension/newtab.html: missing expected Search surface: {old!r}")
    newtab = newtab.replace(old, new)
write("extension/newtab.html", newtab)

# Do not patch the engine search provider. Verify that the reviewed upstream
# fallback still resolves through Google's prepopulated entry.
write(
    "scripts/rewrite-engine-default-search.ps1",
    r'''param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Refusing to verify default search on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$target = Join-Path $sourceRootResolved 'components/search_engines/template_url_prepopulate_data.cc'
if (!(Test-Path $target -PathType Leaf)) {
  throw "Pinned Chromium search-engine source is missing: $target"
}

$googleFallback = @'
std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch(
    PrefService& prefs,
    const std::vector<raw_ptr<const PrepopulatedEngine>>&
        regional_prepopulated_engines) {
  return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,
                                        google.id,
                                        /*use_first_as_fallback=*/true);
}
'@

$text = [IO.File]::ReadAllText($target)
if (!$text.Contains($googleFallback)) {
  throw 'Pinned Chromium Google fallback changed; refusing an unreviewed default-search modification.'
}

foreach ($forbidden in @(
  'Ghosium Search',
  'search.ghosium.com',
  'prepopulate_id = 1101',
  '9e993bd9-c256-42d7-a1b1-000000001101'
)) {
  if ($text.Contains($forbidden)) {
    throw "Retired Ghosium Search integration remains in engine source: $forbidden"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after default-search verification.'
}
if ($thirdPartyChanges) {
  throw 'Default-search verification found modified third_party sources; refusing to continue.'
}

Write-Host 'Google Search remains the reviewed Chromium distribution fallback: OK'
''',
)

apply_text = read("scripts/apply-engine-branding.ps1")
old_apply = """# Install Ghosium Search as the distribution fallback in the owned search layer.
# This intentionally does not edit third_party engine data and does not use
# enterprise policy to force the provider.
& (Join-Path $PSScriptRoot 'rewrite-engine-default-search.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium Search source integration failed.'
}
"""
new_apply = """# Preserve Chromium's reviewed Google Search fallback. This is a no-op source
# guard: explicit user choices, policy and extension overrides keep their native
# precedence and no Ghosium-owned search provider is injected.
& (Join-Path $PSScriptRoot 'rewrite-engine-default-search.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Google Search fallback verification failed.'
}
"""
if old_apply not in apply_text:
    raise RuntimeError("scripts/apply-engine-branding.ps1: legacy Search integration block not found")
write("scripts/apply-engine-branding.ps1", apply_text.replace(old_apply, new_apply, 1))

verify = read("scripts/verify-engine-fork.ps1")
verify = verify.replace("  'https://search.ghosium.com/',\n", "", 1)
search_start = verify.find(
    "  $searchSource = Get-Content (Join-Path $resolvedSourceRoot 'components/search_engines/template_url_prepopulate_data.cc') -Raw"
)
search_end = verify.find(
    "  $windowsIdentity = Get-Content (Join-Path $resolvedSourceRoot 'chrome/install_static/chromium_install_modes.h') -Raw",
    search_start,
)
if search_start < 0 or search_end < 0:
    raise RuntimeError("scripts/verify-engine-fork.ps1: Search verifier markers not found")
google_verify = r'''  $searchSource = Get-Content (Join-Path $resolvedSourceRoot 'components/search_engines/template_url_prepopulate_data.cc') -Raw
  foreach ($requiredGoogleFallback in @(
    'return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,',
    'google.id,',
    '/*use_first_as_fallback=*/true'
  )) {
    if (!$searchSource.Contains($requiredGoogleFallback)) {
      throw "Google Search fallback integration is missing: $requiredGoogleFallback"
    }
  }
  foreach ($forbiddenSearchIdentity in @(
    'Ghosium Search',
    'search.ghosium.com',
    'prepopulate_id = 1101',
    '9e993bd9-c256-42d7-a1b1-000000001101'
  )) {
    if ($searchSource.Contains($forbiddenSearchIdentity)) {
      throw "Retired Ghosium Search integration remains in engine source: $forbiddenSearchIdentity"
    }
  }

'''
verify = verify[:search_start] + google_verify + verify[search_end:]
write("scripts/verify-engine-fork.ps1", verify)

anchors = read("scripts/verify-pinned-source-anchors.py").replace(
    "Pinned engine fallback-search implementation no longer matches the reviewed rewrite block.",
    "Pinned engine Google fallback-search implementation no longer matches the reviewed source contract.",
)
write("scripts/verify-pinned-source-anchors.py", anchors)

# CI version synchronization no longer requires a retired Search extension.
replace_required(
    ".github/workflows/full-source-windows-build.yml",
    "              Path('search-provider/manifest.json'),\n",
    "",
)
replace_required(
    ".github/workflows/version-contract.yml",
    "          for path in (Path('extension/manifest.json'), Path('search-provider/manifest.json')):\n",
    "          for path in (Path('extension/manifest.json'),):\n",
)

brand = read(".github/workflows/brand-surface-contract.yml")
brand = brand.replace("      - 'search-provider/**'\n", "")
brand = brand.replace("      - 'search-web/**'\n", "")
brand = brand.replace("              Path('search-provider'),\n", "")
brand = brand.replace("              Path('search-web'),\n", "")
brand = brand.replace(
    "          explicit_non_product = {Path('search-web/RESEARCH.md')}\n",
    "          explicit_non_product = set()\n",
)
step_start = brand.find("      - name: Verify Ghosium product destinations\n")
step_end = brand.find("      - name: Verify Ghost route contract is documented\n", step_start)
if step_start < 0 or step_end < 0:
    raise RuntimeError("brand-surface-contract.yml: product destination step markers not found")
new_destination_step = r'''      - name: Verify first-party destinations and Google Search boundary
        shell: python
        run: |
          from pathlib import Path
          import re

          ghosium_files = (
              Path('store-web/index.php'),
              Path('updates-web/index.php'),
          )
          allowed_ghosium_hosts = {
              'ghosium.com',
              'store.ghosium.com',
              'updates.ghosium.com',
          }
          url_re = re.compile(r'https://([a-z0-9.-]+)(?:/[^\s"\'<>)]*)?', re.I)

          for path in ghosium_files:
              text = path.read_text(encoding='utf-8')
              for host in url_re.findall(text):
                  if host.lower() not in allowed_ghosium_hosts:
                      raise SystemExit(f'Non-Ghosium product URL in {path}: https://{host}')

          newtab = Path('extension/newtab.html').read_text(encoding='utf-8')
          if 'action="https://www.google.com/search"' not in newtab:
              raise SystemExit('New Tab must submit search queries directly to Google Search.')
          if 'name="q"' not in newtab:
              raise SystemExit('New Tab Google Search form must submit the q parameter.')
          for forbidden in ('search.ghosium.com', 'Ghosium Search', 'Search with Ghosium'):
              if forbidden in newtab:
                  raise SystemExit(f'Retired first-party Search surface remains in New Tab: {forbidden}')

          newtab_hosts = {host.lower() for host in url_re.findall(newtab)}
          allowed_newtab_hosts = allowed_ghosium_hosts | {'www.google.com'}
          unexpected = sorted(newtab_hosts - allowed_newtab_hosts)
          if unexpected:
              raise SystemExit('Unexpected New Tab external destination(s): ' + ', '.join(unexpected))

          print('Ghosium destinations + explicit Google Search boundary: OK')

'''
brand = brand[:step_start] + new_destination_step + brand[step_end:]
write(".github/workflows/brand-surface-contract.yml", brand)

# Current documentation: Google is external; Ghosium only owns Store/Updates.
readme = read("README.md")
readme = readme.replace(
    "The current development version is **0.1.5**.",
    "The current development version is **0.1.6**.",
    1,
)
readme = readme.replace(
    "- search: `https://search.ghosium.com/`\n",
    "- default search: **Google Search** (external service)\n",
    1,
)
section_start = readme.find("## Ghosium Search\n")
section_end = readme.find("## Ghosium Store\n", section_start)
if section_start < 0 or section_end < 0:
    raise RuntimeError("README.md: Search section markers not found")
search_section = """## Search

Ghosium Browser uses **Google Search** as its default web search service. New Tab queries are submitted directly to `https://www.google.com/search`; Ghosium does not proxy them and does not operate a first-party search endpoint.

The browser retains Chromium's reviewed Google fallback instead of injecting a Ghosium-specific provider. Explicit user search-engine choices, enterprise policy and extension overrides retain their native precedence.

The retired first-party search extension and server application are not part of the current product architecture.

"""
readme = readme[:section_start] + search_section + readme[section_end:]
readme = readme.replace("search-provider/        Ghosium Search browser integration\n", "")
readme = readme.replace("search-web/             shared-hosting Ghosium Search\n", "")
write("README.md", readme)

architecture = read("ARCHITECTURE.md")
architecture = architecture.replace("Ghosium Browser 0.1.2", "Ghosium Browser 0.1.6")
architecture = architecture.replace("Version 0.1.2", "Version 0.1.6")
architecture = architecture.replace("For 0.1.2:", "For 0.1.6:")
arch_start = architecture.find("## Search, Store and update services\n")
arch_end = architecture.find("## Update trust boundary\n", arch_start)
if arch_start < 0 or arch_end < 0:
    raise RuntimeError("ARCHITECTURE.md: Search/services section markers not found")
services = """## Search and first-party web services

Ghosium does not operate or bundle a first-party web search service. The browser default and New Tab search use Google Search as an external service and submit queries directly to Google.

The independently deployable Ghosium-controlled shared-hosting services are limited to:

```text
store-web/       store.ghosium.com
updates-web/     updates.ghosium.com
```

These web applications are not linked into the browser executable and can be deployed independently.

"""
architecture = architecture[:arch_start] + services + architecture[arch_end:]
write("ARCHITECTURE.md", architecture)

write(
    "docs/WEB-SERVICES.md",
    """# Ghosium web services deployment note

Ghosium Browser 0.1.6 does not ship or operate a first-party web search service. Browser and New Tab searches use Google Search as an external service.

The repository keeps only the Ghosium-controlled shared-hosting services needed for product distribution:

- Store source: `store-web/`
- Update source: `updates-web/`
- Store deployment guide: `docs/SHARED-HOSTING-STORE.md`

Retired search integration, server code and deployment assets are intentionally absent.
""",
)

changelog = read("CHANGELOG.md")
if not changelog.startswith("# Changelog\n\n"):
    raise RuntimeError("CHANGELOG.md: unexpected heading")
entry = """# Changelog

## 0.1.6 — Google Search default and Search stack removal

### Search simplification
- Switched the browser and New Tab default web search experience to Google Search.
- Removed the bundled Ghosium Search provider extension and the complete first-party search web service.
- Removed Search-only deployment documentation and CI that no longer represent the product architecture.
- Preserved Chromium's reviewed Google fallback instead of maintaining a custom default-search source patch, reducing source delta and maintenance risk.
- Preserved explicit user search-engine choices, enterprise policy and extension override precedence.

### Code quality and privacy
- Removed stale Search metadata from product URL allowlists and the built-in Store catalog.
- Kept Ghosium Privacy declarative tracker protection independent from search-provider removal.
- Updated public-surface CI so `www.google.com` is allowed only for the intentional New Tab search action while Ghosium-controlled product links remain restricted to approved first-party hosts.
- Advanced the browser, bundled Ghosium Privacy component and fail-closed update baseline to 0.1.6; the stable updater remains disabled until a real signed production package exists.

"""
write("CHANGELOG.md", entry + changelog[len("# Changelog\n\n"):])

# Retire first-party Search implementation, Search-only docs/CI, and stale 0.1.5
# dispatch markers. The old production run remains external GitHub history and
# must not be mistaken for the 0.1.6 release candidate.
delete_tree("search-provider")
delete_tree("search-web")
for retired in (
    "docs/SEARCH.md",
    "docs/SHARED-HOSTING-SEARCH.md",
    ".github/workflows/search-web-contract.yml",
    ".release/ghosium-v0.1.5.request",
    ".release/ghosium-v0.1.5.production",
    ".github/workflows/production-release-dispatch.yml",
):
    delete_file(retired)

# One-shot migration artifacts remove themselves before the resulting commit.
delete_file(".github/workflows/google-search-cleanup-migration.yml")
delete_file("scripts/migrate-google-search-cleanup.py")
