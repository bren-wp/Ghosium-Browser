# Ghosium Browser for Android

Ghosium Android 0.0.3 is the native Android companion to the Windows browser. It uses the Android System WebView rendering engine inside a Brendigo-owned Material interface and does not add Ghosium analytics or telemetry.

## Browser behavior

- Search/address field with HTTPS-first hostname resolution and Google Search for plain queries.
- Back, Forward, Home and Reload controls with Android accessibility labels and 48dp+ touch targets.
- New Tab is a local Ghosium asset served through an HTTPS-shaped, network-isolated appassets origin.
- Third-party cookies are blocked by default; mixed active content and invalid TLS certificates are blocked.
- File/content URL access is disabled; browser-owned local assets are allow-listed explicitly.
- External app schemes require user confirmation and are dispatched as browsable intents.
- Renderer termination is handled and the active URL is recovered into a fresh WebView rather than crashing the Activity.
- Downloads use Android DownloadManager and the public Downloads collection on Android 10+.
- File upload, full-screen media, desktop-site mode, find-in-page, sharing and local browsing-data clearing are implemented.
- English and Croatian native UI strings are included; unsupported device locales fall back to English.

## Build

The project requires JDK 17, Android SDK 36 / Build Tools 36.0.0, Android Gradle Plugin 8.13.2 and Gradle 8.13. The CI build verifies the exact Gradle distribution SHA-256 before executing it.

A production release can be signed without committing credentials by setting `GHOSIUM_ANDROID_KEYSTORE_PATH`, `GHOSIUM_ANDROID_KEYSTORE_PASSWORD`, `GHOSIUM_ANDROID_KEY_ALIAS` and `GHOSIUM_ANDROID_KEY_PASSWORD`. The 0.0.3 GitHub-hosted preview release creates a one-run preview certificate when production signing credentials are not available and publishes its certificate digest in release evidence.
