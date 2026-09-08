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


# Full sparse source audit now proves the upstream Google fallback was preserved
# and that the former first-party provider was not reintroduced by transforms.
engine_audit = read(".github/workflows/engine-source-audit.yml")
old = "          grep -F 'Ghosium Search' \"$src/components/search_engines/template_url_prepopulate_data.cc\"\n"
new = """          grep -F 'google.id,' "$src/components/search_engines/template_url_prepopulate_data.cc"
          grep -F '/*use_first_as_fallback=*/true' "$src/components/search_engines/template_url_prepopulate_data.cc"
          if grep -Fq 'Ghosium Search' "$src/components/search_engines/template_url_prepopulate_data.cc" || \\
             grep -Fq 'search.ghosium.com' "$src/components/search_engines/template_url_prepopulate_data.cc"; then
            echo 'Retired Ghosium Search source integration returned.' >&2
            exit 1
          fi
"""
if old not in engine_audit:
    raise RuntimeError("engine-source-audit.yml: old Search assertion not found")
write(".github/workflows/engine-source-audit.yml", engine_audit.replace(old, new, 1))

# Security documentation is aligned with the current full-source architecture;
# no retired launcher/Portable/Search-server claims remain.
write(
    "SECURITY.md",
    """# Ghosium Browser Security Policy

## Supported release

Only the newest stable Ghosium Browser release is supported with security fixes. Older releases should be upgraded.

## Security baseline

Ghosium inherits a large security surface from its pinned upstream open-source browser engine. Each release therefore pins an exact `ENGINE_SOURCE_REVISION`; updating that revision and rerunning the complete source/CI pipeline is part of Ghosium security maintenance.

Ghosium does not disable the browser sandbox, GPU sandbox, certificate validation, site/process isolation or update verification to improve performance or reduce memory use.

## Source-built protections

The controlled Windows source build and verification chain preserves:

- compiler/toolchain memory-safety and control-flow mitigations;
- browser, renderer and GPU sandbox boundaries;
- site/process isolation and TLS/certificate validation;
- extension permission and package-trust checks;
- fail-closed update size, SHA-256, Authenticode publisher and PE metadata validation;
- Ghosium/Brendigo executable identity and canonical same-Setup maintenance;
- pinned-source verification before product transforms are applied.

Search-provider customization does not weaken these boundaries. Ghosium keeps Chromium's reviewed Google Search fallback and does not inject a first-party search engine into source.

## Release verification

Hosted CI verifies source transforms, public surfaces, JSON/PHP syntax where applicable, Store trust, updater behavior, installer contracts, localization, release metadata and security invariants.

The controlled full-source Windows release additionally requires:

- source-builder preflight and exact pinned source/tool revisions;
- successful native browser/runtime compilation;
- source-built runtime smoke;
- measured performance evidence;
- canonical Setup assembly from verified source-built runtime;
- install/update/uninstall round-trip validation;
- valid production Authenticode signing on `main`;
- exact update-manifest and SHA-256 provenance;
- immutable release publication.

Hosted contracts alone are not proof that a production binary was built or signed.

## Reporting

Use the repository's private vulnerability reporting / Security Advisory flow when available. Avoid publishing exploit details before a fix exists.

Useful reports include the Ghosium version, Windows version, minimal reproduction steps, expected/observed behavior and whether the issue appears specific to Ghosium-owned code.

Public security page: https://ghosium.com/security
""",
)

# Third-party notices distinguish Brendigo-authored product code from the
# external Google Search service without claiming ownership or integration code.
write(
    "THIRD_PARTY_NOTICES.md",
    """# Third-Party Notices

Ghosium Browser includes a pinned upstream open-source browser engine and third-party components distributed under their respective licenses.

Ghosium does not claim ownership of upstream project names, third-party code, codecs, trademarks, copyrights or artwork.

The source-built release preserves the license and attribution material required by the exact upstream engine revision. The engine's built-in credits material remains available for third-party component notices.

Required upstream copyright/license text is legal attribution and must not be removed merely for product branding.

## Ghosium-authored code

Ghosium source transformations, privacy rules, Store/update web sources, installer/release tooling, branding and presentation resources are covered by the repository `LICENSE` unless a file states otherwise.

## External services

Google Search is the browser's default external web search service; it is not operated, proxied or relabeled as a Ghosium service. Ghosium Store and Ghosium update endpoints remain first-party product services controlled by Brendigo.

Third-party services, libraries and open-source components remain governed by their respective terms, licenses and trademark rights.
""",
)

release = read("docs/RELEASE.md")
release = release.replace("The active development version is `0.1.5`.", "The active development version is `0.1.6`.", 1)
release = release.replace(
    "Every production PR must advance `VERSION`. Ghosium Privacy, Ghosium Search, built-in Store metadata and the disabled Windows update baseline must remain synchronized.",
    "Every production PR must advance `VERSION`. Ghosium Privacy, built-in Store metadata and the disabled Windows update baseline must remain synchronized.",
    1,
)
release = release.replace("ghosium-v0.1.5\n", "ghosium-v0.1.5\nghosium-v0.1.6\n", 1)
scope_start = release.find("## 0.1.5 release scope\n")
scope_end = release.find("## Candidate before production\n", scope_start)
if scope_start < 0 or scope_end < 0:
    raise RuntimeError("docs/RELEASE.md: old 0.1.5 scope block not found")
new_scope = """## 0.1.6 release scope

The 0.1.6 line simplifies the search architecture and removes obsolete release orchestration state:

- Google Search is the default external web search service;
- Chromium's reviewed Google fallback remains intact instead of being replaced by a Ghosium-specific engine entry;
- the former first-party search provider extension, PHP search service, Search-only deployment docs and Search-only CI are removed;
- New Tab submits search queries directly to `https://www.google.com/search` using the standard `q` parameter;
- explicit user search-engine choices, enterprise policy and extension overrides retain native precedence;
- Ghosium Privacy tracker/campaign-parameter rules remain independent of the search provider;
- stale 0.1.5 candidate/production markers and the hard-coded 0.1.5 production dispatcher are removed;
- the 0.1.6 checked-in update baseline remains fail-closed with `enabled:false`, empty SHA-256 and zero size until a real signed package exists.

This scope is not a production-binary or performance claim. Canonical release status still requires the controlled full-source candidate/production compile, runtime, performance, installer, signing and provenance gates for the exact 0.1.6 release tree.

"""
release = release[:scope_start] + new_scope + release[scope_end:]
write("docs/RELEASE.md", release)

engine_readme = read("engine/README.md")
engine_readme = engine_readme.replace("0.1.2", "0.1.6")
engine_readme = engine_readme.replace(
    "- Ghosium Search, Store, Support, Security, Terms, Privacy and update destinations;",
    "- Google Search as the explicit external default search service plus Ghosium Store, Support, Security, Terms, Privacy and update destinations;",
    1,
)
engine_readme = engine_readme.replace(
    "Public Ghosium product surfaces must not expose legacy upstream browser product branding. This includes About, Settings, New Tab, installer UI, shortcuts, public executable metadata, Search/Store/Update pages and first-party help links.",
    "Public Ghosium product surfaces must not expose legacy upstream browser product branding. This includes About, Settings, New Tab, installer UI, shortcuts, public executable metadata, Store/Update pages and first-party help links. External services such as Google Search must be named accurately rather than relabeled as Ghosium products.",
    1,
)
write("engine/README.md", engine_readme)

p("scripts/migrate-google-search-cleanup-pass3.py").unlink()
