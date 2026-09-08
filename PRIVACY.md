# Ghosium Browser Privacy

## Scope

This document describes privacy behavior controlled by Ghosium Browser and Ghosium-controlled product services. Google Search is an external service and is not operated by Ghosium or Brendigo.

## Ghosium Browser

Ghosium does not operate a browser-account backend, advertising identifier system or application analytics SDK.

The source-built browser disables selected browser-owned background/reporting features, including browser Sync/account onboarding surfaces, crash-reporting integrations controlled by the product build, legacy background browser mode and other unowned promotional/background features covered by the source contracts.

The bundled Ghosium Privacy component uses declarative request rules to block selected third-party trackers and remove common campaign/click identifiers from top-level navigations.

## Local profile

Installed mode stores profile data under the Ghosium/Brendigo local application-data profile root defined by the Windows identity contract. History, cookies, bookmarks, site data and preferences are local browser data unless a website or installed extension sends its own data elsewhere.

## Google Search

Google Search is the default web search service. Queries submitted through the Ghosium New Tab search form are sent directly to `https://www.google.com/search`. Ghosium does not proxy, index, store or process those search queries on a first-party search server.

Google receives ordinary network requests for searches sent to its service and applies its own terms, privacy practices and service behavior. Users can change their search engine through supported browser controls; enterprise policy and extension overrides retain their native precedence.

## Ghosium Store

The Store source has no analytics, advertising SDK, remote font dependency or third-party asset dependency. The initial catalog is stored in local JSON and package delivery remains subject to the repository trust controls.

## Websites and search results

Ghosium is a browser, not an anonymity network. A website intentionally opened by the user receives ordinary network traffic and can apply its own cookies/fingerprinting subject to browser controls and Ghosium filtering. Search results are ordinary user-requested web destinations.

## Product links

Ghosium-controlled non-search product UI points to approved Ghosium-owned domains. The New Tab search action intentionally submits queries to Google Search as the configured external search service. This does not block the user from browsing the wider web.

Current public privacy policy: https://ghosium.com/legal/privacy-policy
