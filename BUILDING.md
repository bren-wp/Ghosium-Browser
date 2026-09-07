# Building Ghosium Browser

## Production build definition

A Ghosium production release is a **full-source build**. Packaging a precompiled upstream browser snapshot is not a production build and must not be used to publish a stable Ghosium release.

The canonical Windows release path is `.github/workflows/full-source-windows-build.yml`.

It performs the following fail-closed sequence:

1. validate the Ghosium product version and bundled component versions;
2. validate the Windows source-builder host;
3. verify the pinned source patch anchors;
4. checkout the exact revision from `ENGINE_SOURCE_REVISION` using pinned `depot_tools`;
5. apply the Ghosium source fork;
6. verify the resulting source tree;
7. configure the reviewed Windows x64 GN arguments;
8. compile the browser and installer from source;
9. verify compiled product identity and run the runtime smoke test;
10. run a real source-built install/uninstall round trip;
11. generate provenance records and SHA-256 hashes;
12. upload verified artifacts;
13. on a production `main` push, create a new immutable `ghosium-v0.x.y` release only if that tag does not already exist.

No source audit, patch verifier, launcher build, snapshot package, or installer-only test is sufficient evidence of a source-built Ghosium Browser.

## Source revisions

The production source toolchain is pinned by:

- `ENGINE_SOURCE_REVISION` — exact browser-engine source commit;
- `DEPOT_TOOLS_REVISION` — exact build-tool revision;
- `engine/build/windows-x64.args.gn` — reviewed Windows x64 build configuration.

The historical `ENGINE_REVISION` snapshot mechanism belongs to the earlier packaging line and is not part of the new production release path.

## Windows source-builder requirements

The full-source workflow targets a controlled self-hosted runner labelled:

```text
self-hosted
Windows
X64
ghosium-source-builder
```

The builder must pass `scripts/verify-source-builder-host.ps1` before any source checkout/build is trusted. Persistent workspaces are reset to the pinned dependency state before use.

The source tree and build output require substantially more disk space, memory, and build time than the historical snapshot package. Do not weaken verification to make a constrained builder appear healthy.

## Technical upstream build names

The pinned upstream build graph currently uses technical target/intermediate names such as `chrome`, `mini_installer`, and `chrome.7z`. These names must not leak into user-facing Ghosium product identity.

Do not globally rename them. A technical rename is complete only after the full dependency chain, process spawning, DLL loading, installer logic, sandbox/crash integration, tests, and runtime behavior have been rebuilt and verified successfully.

## Desktop source language

Ghosium-owned launcher code is C++20. HTML, CSS and JSON are presentation/configuration assets. PHP is used only by the separate Ghosium Search and Store web services.

## Local source build

Use the repository scripts rather than reproducing ad-hoc commands:

```powershell
./scripts/verify-source-builder-host.ps1
./scripts/bootstrap-engine-source.ps1 -Destination <work-root>
./scripts/apply-engine-branding.ps1 -SourceRoot <work-root>\src
./scripts/verify-engine-fork.ps1 -SourceRoot <work-root>\src
./scripts/configure-engine-build.ps1 -SourceRoot <work-root>\src -OutDir out/Ghosium
```

Then run the same compile and verification sequence used by CI. A local result must not be called a stable release unless the corresponding production workflow also succeeds for the exact release commit.

## Performance measurement

Use `scripts/benchmark-ghosium-windows.ps1` for comparable Windows startup/resource measurements. The benchmark uses the launcher's validated `--ghosium-portable-profile` control to isolate profiles without bypassing the launcher's profile-security boundary.

The current benchmark reports startup time, RAM, process/handle count, CPU, disk transfer counters and active TCP connections. It intentionally does not claim reliable GPU-memory or per-process network-byte measurements yet.

## Legal and security requirements

Required upstream and third-party notices/licenses remain intact regardless of branding level. Performance work must preserve sandboxing, site isolation, certificate validation and other browser security invariants.
