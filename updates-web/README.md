# Ghosium Updates — shared hosting

This directory is the deployable source for `https://updates.ghosium.com/`.
It is intentionally small and works on ordinary Apache/LiteSpeed shared hosting.
No Node.js service, database, background daemon, `update.exe`, or `updater.exe` is required.

## Browser contract

Windows Ghosium Browser checks:

`https://updates.ghosium.com/windows/stable.json`

The manifest is accepted only when all of the following are true:

- HTTPS remains on the exact `updates.ghosium.com` host.
- `schema` is `1`, product is `Ghosium Browser`, platform is `windows`, and channel is `stable`.
- `enabled` is `true`.
- The advertised product version is newer than the running Ghosium product version.
- The package URL also remains on `updates.ghosium.com` and ends in `Ghosium-Browser-Setup.exe`.
- The downloaded byte count exactly matches `size`.
- SHA-256 exactly matches `sha256`.
- Windows Authenticode verification succeeds and the Setup publisher matches the running Ghosium Browser publisher.

After verification, the browser launches that same Setup package with `/S /UPDATE`.
The installer performs maintenance using the standard `Ghosium-Browser-Setup.exe`; Ghosium does not distribute a separate updater executable.

## Publishing a release

1. Build and sign the release `Ghosium-Browser-Setup.exe`.
2. Run `scripts/generate-update-manifest.ps1` against the signed Setup.
3. Upload the signed Setup to `windows/Ghosium-Browser-Setup.exe` on the update host.
4. Upload the generated `stable.json` only after the Setup upload is complete.
5. Verify the HTTPS endpoint and file hash from a second machine before enabling the release publicly.

The repository baseline manifest is deliberately `enabled: false`. This prevents an incomplete source checkout or an unsigned development artifact from becoming a production browser update.

## Shared-hosting deployment

Upload the contents of this directory to the document root of `updates.ghosium.com` and enable HTTPS. `.htaccess` disables directory listings and applies conservative browser security headers. No writable directory is required for normal operation because the release manifest is static.

Do not store private signing keys, certificate passwords, or release secrets anywhere in this directory or repository.
