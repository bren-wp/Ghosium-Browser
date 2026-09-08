# Contributing to Ghosium Browser

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
