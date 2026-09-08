# Ghosium Browser Security Policy

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
