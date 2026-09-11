# Contributing to Ghosium Browser

## Scope

Contributions must preserve the current source-built Windows architecture, Android application architecture and privacy/security guarantees.

## Windows rules

- Ghosium-owned desktop executable code remains C++20.
- Do not add Tauri, WebView2 wrappers, Rust browser cores or JavaScript desktop browser runtimes.
- Do not add switches that disable sandboxing, certificate validation or browser security isolation.
- Preserve native user, policy and extension precedence where applicable.
- Changes to Setup/Portable behavior require installer compilation and lifecycle/profile tests.

## Android rules

- Android package identity remains `com.brendigo.ghosium` unless a coordinated migration is explicitly approved.
- Minimum supported API for 0.0.3 is 29; compile/target SDK is 36.
- Keep third-party cookies blocked, mixed content blocked, direct WebView file/content access disabled, Safe Browsing enabled and TLS errors fail closed.
- Do not add analytics, advertising or crash-reporting SDKs without an explicit product/privacy decision.
- Do not commit Android production keystores, passwords or private keys.
- New browser behavior should have unit or lint/contract coverage where practical.

## Web-service rules

`store-web/` and `updates-web/` target commodity shared hosting with PHP/JSON, no mandatory SQL database, no analytics/advertising SDKs, no remote-font dependency, secure headers and protected storage paths.

## Branding and third-party identity

User-facing Ghosium-owned surfaces use Ghosium branding. Required upstream legal attribution remains in designated notice/license files. External services such as Google Search must be identified accurately.

## Release assets

The canonical 0.0.3 end-user assets are:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
Ghosium-Browser-Android.apk
```

A production artifact is valid only after the exact-commit platform build, security, signing and provenance gates succeed.
