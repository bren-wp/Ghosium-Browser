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
5. full browser compile;
6. compiled-output/product verification;
7. runtime smoke test;
8. source-built installer install/uninstall round trip;
9. build provenance;
10. SHA-256 manifest.

A source audit, source patch, precompiled snapshot package, or launcher/installer smoke test alone does not satisfy this gate.

## Public release assets

The full-source pipeline currently publishes verified source-built artifacts and verification records, including:

- `Ghosium-Browser-Setup.exe`;
- `Ghosium-Browser-Source-Runtime.7z`;
- `GHOSIUM-SOURCE-BUILD.json`;
- `GHOSIUM-BUILDER-READY.json`;
- `GHOSIUM-SOURCE-INSTALLER-SMOKE.json`;
- `GHOSIUM-VERSION.txt`;
- `SHA256SUMS.txt`.

A Portable executable must not be advertised for the new source-built product line until its packaging path is built from the same verified source output and passes equivalent runtime/cleanup tests. Historical Portable assets remain attached to their historical releases.

GitHub also provides source archives for the release tag.

## Immutability

Never overwrite an existing release asset or repoint an existing Ghosium release tag to a different build.

The production workflow checks whether `ghosium-v0.x.y` already exists. If it does, release publication fails. Fixes require a new product version.

## Required CI contracts

Before production publication, the repository must keep passing the applicable contracts for:

- immutable GitHub Action SHAs and minimal token permissions;
- version progression and bundled-component synchronization;
- absence of the historical snapshot-based stable release path;
- Ghosium-only controlled product surfaces;
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
