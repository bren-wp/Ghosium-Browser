# Ghosium Engine Updates

## Pinning

Production builds use the exact browser source commit in `ENGINE_SOURCE_REVISION` and the exact compatible build-tool commit in `DEPOT_TOOLS_REVISION`.

The new Ghosium product line does not publish from a precompiled Windows snapshot revision. Historical snapshot pins belong only to the old release history and must not be reintroduced into the production workflow.

## Source update process

1. Review the upstream security/release delta and select the exact source commit to adopt.
2. Create a development branch and update `ENGINE_SOURCE_REVISION`.
3. Update `DEPOT_TOOLS_REVISION` when the pinned source requires a different compatible tool revision.
4. Run `scripts/verify-pinned-source-anchors.py` and update the Ghosium rewrite/verifier logic only when the new source genuinely changes the expected anchors.
5. Bootstrap a clean or fully reset source workspace.
6. Apply the Ghosium fork and run `scripts/verify-engine-fork.ps1`.
7. Perform the full Windows compile and source-built installer build.
8. Run compiled-output, runtime, install, upgrade/uninstall, branding and security verification.
9. Compare performance with the accepted baseline where the engine update can affect startup, memory, CPU or network behavior.
10. Merge only after the required CI checks pass and the product version has advanced.
11. Publish the new immutable `ghosium-v0.x.y` release only from the verified production commit.

Do not weaken source anchors or verifier rules simply because a new upstream revision changed. Review the change and adapt the fork deliberately.

## Provenance

Production release evidence records the exact Ghosium repository commit, pinned browser source revision, builder readiness, source-built runtime verification, installer round trip and SHA-256 hashes.

A source audit without a completed compile is not source-build provenance.

## Technical identity

Some upstream build-system target/intermediate names may remain until a coordinated rename is proven across GN/Ninja, DLL/process loading, installer, sandbox/crash integration and runtime tests. Keep those technical dependencies isolated from public Ghosium product surfaces.

## Legal attribution

Required upstream and third-party licenses/copyright notices remain intact and are shipped in their legal context. They are not converted into Ghosium product branding.
