# Ghosium Production Release Procedure

## Product version line

The current Ghosium Browser product line starts at `0.1.0`.

Use:

- `0.x.0` for a new feature, major rebranding/redesign, or meaningful performance/security milestone;
- `0.x.y` for a smaller production bugfix.

Every merged production change must carry a new version. `VERSION`, bundled browser component manifests, and built-in Store metadata must match.

Historical `v0.x.y` tags are retained. New product releases use the separate namespace:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.2.0
```

## Release gate

A release may be published only after the exact production commit completes the pinned full-source Windows pipeline successfully.

Required evidence:

1. source-builder readiness report;
2. pinned browser source revision checkout;
3. pinned patch-anchor verification;
4. Ghosium fork application and source verification;
5. Windows executable/source-shell identity verification;
6. full browser compile;
7. compiled-output/product verification;
8. runtime smoke test;
9. source-built installer install/uninstall round trip;
10. Brendigo proprietary product-license verification and preserved third-party attribution;
11. build provenance;
12. SHA-256 manifest.

A source audit, source patch, precompiled snapshot package, or launcher/installer smoke test alone does not satisfy this gate.

## Public release assets

The full-source pipeline publishes only artifacts produced or copied into the verified full-source payload before hashing. The current release set includes:

- `Ghosium-Browser-Setup.exe`;
- `Ghosium-Browser-Source-Runtime.7z`;
- `GHOSIUM-SOURCE-BUILD.json`;
- `GHOSIUM-BUILDER-READY.json`;
- `GHOSIUM-SOURCE-INSTALLER-SMOKE.json`;
- `GHOSIUM-VERSION.txt`;
- `GHOSIUM-LICENSE.txt` — Brendigo Proprietary Commercial Software License Agreement;
- `THIRD_PARTY_NOTICES.md` — required third-party/open-source notices and attribution;
- `SHA256SUMS.txt`.

`GHOSIUM-LICENSE.txt` does not replace or override the licenses of Chromium or any other third-party/open-source component. Their rights and obligations remain governed by their respective license texts and required notices.

A Portable executable must not be advertised for the new source-built product line until its packaging path is built from the same verified source output and passes equivalent runtime/cleanup tests. Historical Portable assets remain attached to their historical releases.

GitHub also provides source archives for the release tag. Repository visibility does not itself change the proprietary license applicable to Brendigo-authored portions.

## Immutability

Never overwrite an existing release asset or repoint an existing Ghosium release tag to a different build.

The production workflow checks whether `ghosium-v0.x.y` already exists. If it does, release publication fails. Fixes require a new product version.

## Required CI contracts

Before production publication, the repository must keep passing the applicable contracts for:

- immutable GitHub Action SHAs and minimal token permissions;
- version progression and bundled-component synchronization;
- proprietary Ghosium product-license consistency and third-party rights preservation;
- absence of the historical snapshot-based stable release path;
- Ghosium-only controlled product surfaces, with upstream names isolated to legal/technical contexts;
- pinned source/build tooling;
- Ghosium source fork and Windows identity;
- installer/runtime verification;
- Search and Store trust rules.

Tests must not be weakened merely to make a release green.

## Performance evidence

For releases that make startup/RAM/CPU claims, attach or retain comparable benchmark evidence. `scripts/benchmark-ghosium-windows.ps1` is the repository benchmark contract.

The immutable historical `v0.8.0` Setup is used only as the pre-0.1.0 baseline and is hash-verified before benchmarking. Performance claims for a new release require a comparable source-built result.

## Signing

Do not describe a build as Authenticode-signed unless a valid Brendigo code-signing certificate actually signs the published executable and the signature is verified as part of release CI.
