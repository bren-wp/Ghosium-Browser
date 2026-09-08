from pathlib import Path


def read(path):
    return Path(path).read_text(encoding="utf-8")


def write(path, text):
    Path(path).write_text(text, encoding="utf-8", newline="\n")


# Brand/public-surface contract: Search is external Google only on New Tab.
brand_path = ".github/workflows/brand-surface-contract.yml"
brand = read(brand_path)
brand = brand.replace("      - 'search-provider/**'\n", "")
brand = brand.replace("      - 'search-web/**'\n", "")
brand = brand.replace("              Path('search-provider'),\n", "")
brand = brand.replace("              Path('search-web'),\n", "")
brand = brand.replace(
    "          explicit_non_product = {Path('search-web/RESEARCH.md')}\n",
    "          explicit_non_product = set()\n",
)
start = brand.find("      - name: Verify Ghosium product destinations\n")
end = brand.find("      - name: Verify Ghost route contract is documented\n", start)
if start < 0 or end < 0:
    raise SystemExit("brand-surface-contract.yml destination markers not found")
replacement = '''      - name: Verify first-party destinations and Google Search boundary
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
          url_re = re.compile(r"https://([a-z0-9.-]+)(?:/[^\\s\\\"'<>)]*)?", re.I)

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
write(brand_path, brand[:start] + replacement + brand[end:])

# Sparse/full engine audit requires Google's reviewed upstream fallback and rejects
# any accidental return of the retired first-party Search provider.
engine_path = ".github/workflows/engine-source-audit.yml"
engine = read(engine_path)
old = "          grep -F 'Ghosium Search' \"$src/components/search_engines/template_url_prepopulate_data.cc\"\n"
new = '''          grep -F 'google.id,' "$src/components/search_engines/template_url_prepopulate_data.cc"
          grep -F '/*use_first_as_fallback=*/true' "$src/components/search_engines/template_url_prepopulate_data.cc"
          if grep -Fq 'Ghosium Search' "$src/components/search_engines/template_url_prepopulate_data.cc" || \\
             grep -Fq 'search.ghosium.com' "$src/components/search_engines/template_url_prepopulate_data.cc"; then
            echo 'Retired Ghosium Search source integration returned.' >&2
            exit 1
          fi
'''
if old not in engine:
    raise SystemExit("engine-source-audit.yml old Search assertion not found")
write(engine_path, engine.replace(old, new, 1))

# Full-source package no longer synchronizes a removed Search extension manifest.
full_path = ".github/workflows/full-source-windows-build.yml"
full = read(full_path)
marker = "              Path('search-provider/manifest.json'),\n"
if marker not in full:
    raise SystemExit("full-source-windows-build.yml Search manifest marker not found")
write(full_path, full.replace(marker, "", 1))

# Store trust tracks only Ghosium Privacy as the remaining bundled component.
store_path = ".github/workflows/store-trust-audit.yml"
store = read(store_path)
if "search-provider/manifest.json" not in store:
    raise SystemExit("store-trust-audit.yml Search trigger not found")
store = store.replace("      - 'search-provider/manifest.json'\n", "")
store = store.replace(
    "          curl --fail --silent --show-error 'http://127.0.0.1:8100/api/update.php?id=ghosium-search&version=0.7.0' | grep -Fq '\"updateAvailable\":false'\n",
    "          curl --fail --silent --show-error 'http://127.0.0.1:8100/api/update.php?id=ghosium-privacy&version=0.1.6' | grep -Fq '\"updateAvailable\":false'\n",
)
write(store_path, store)

# Version synchronization only includes the still-bundled privacy extension.
version_path = ".github/workflows/version-contract.yml"
version = read(version_path)
marker = "          for path in (Path('extension/manifest.json'), Path('search-provider/manifest.json')):\n"
if marker not in version:
    raise SystemExit("version-contract.yml Search manifest marker not found")
write(version_path, version.replace(marker, "          for path in (Path('extension/manifest.json'),):\n", 1))
