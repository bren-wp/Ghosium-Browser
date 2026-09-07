# Ghosium Search — shared hosting

This directory is the standalone PHP application for `https://search.ghosium.com/`. It is deliberately kept in a separate GitHub folder so the browser and web search deployment can be versioned together while remaining independently deployable.

The request path does not require a database or application daemon. Configuration, the small first-party index, cache and privacy rate-limit data use `storage/data/*.json`.

## Requirements

- PHP 8.1+
- PHP cURL and DOM extensions for crawler/optional provider functionality
- Apache or LiteSpeed shared hosting with `.htaccess`
- HTTPS
- `storage/data` writable by PHP
- optional hosting cron for index refresh

No Node/npm, Composer, Rust/Tantivy, Java or Python application process is required to serve searches.

## Install

1. Upload the **contents** of `search-web/` to the document root for `search.ghosium.com`.
2. Confirm `https://search.ghosium.com/health.php` returns `status: ok`.
3. Keep `provider.enabled` set to `false` for first-party JSON-index mode.
4. Add only HTTPS seed URLs you are permitted and prepared to crawl to `storage/data/seeds.json`.
5. Schedule `php /home/USER/search.ghosium.com/cron/reindex.php` in the hosting control panel if you want automatic index refresh.
6. Confirm `storage/`, `inc/`, `cron/` and JSON files are not publicly browsable.

## Search syntax

The shared-hosting engine supports Ghosium's own clean-room query parser:

- `privacy browser` — ordinary term search
- `"private browsing"` — required phrase
- `site:ghosium.com privacy` — restrict results to one host/domain and subdomains
- `intitle:privacy` or `intitle:"privacy policy"` — require title text
- `privacy -advertising` — exclude a term
- operator-only searches such as `site:store.ghosium.com`

Operators can be combined. The local ranker gives additional weight to exact titles, title matches, phrases, tags and descriptions, then applies host diversity so one indexed domain does not unnecessarily dominate the first results.

## Explicit `!bang` shortcuts

A curated `!bang` is used only when the user explicitly types it. It redirects the query directly to that third-party site and therefore leaves Ghosium Search.

Current shortcuts include:

- `!w` / `!wiki` — Wikipedia
- `!gh` — GitHub
- `!yt` — YouTube
- `!r` — Reddit
- `!mdn` — MDN Web Docs
- `!so` — Stack Overflow

Example: `browser !gh` opens GitHub search for `browser`. Unknown bangs remain normal Ghosium queries instead of being forwarded anywhere.

The JSON API does not automatically redirect external bangs; `/api/search.php` returns bang metadata so a client can decide whether to leave Ghosium Search.

## Local engine

`cron/reindex.php` is a bounded crawler intended for conventional shared hosting. It only follows configured seed hosts and now includes:

- public-address validation to reduce SSRF exposure;
- `robots.txt` handling;
- page-level `noindex` and `nofollow` handling;
- link-level `rel="nofollow"` handling;
- canonical URL handling limited to configured seed hosts;
- a configurable page limit, depth limit and per-host page limit;
- a request delay;
- a non-blocking lock that prevents overlapping cron runs;
- fail-safe preservation of the existing index if a crawl produces no indexable pages;
- atomic JSON writes.

A successful crawl writes `storage/data/index.json` and a crawl summary to `storage/data/crawl-state.json`.

A single shared-hosting account with JSON files cannot maintain a complete index of the public web. A global independent Ghosium index requires dedicated distributed crawler/index infrastructure. The web frontend does not need to change when that infrastructure is introduced.

## Optional server-side provider

A compatible HTTPS JSON provider can be enabled in the protected configuration. Its API key stays on the server and is never embedded in Ghosium Browser. This is the extension point for a future dedicated Ghosium index cluster or another search source that Ghosium is licensed to use.

Expected response shape:

```json
{
  "results": [
    {
      "title": "Ghosium",
      "url": "https://ghosium.com/",
      "description": "Ghosium result"
    }
  ]
}
```

The provider response is normalized, tracking query parameters are stripped from result URLs, duplicate URLs are collapsed and Ghosium query filters are applied before display.

## API

- `/api/search.php?q=...` — search results plus parsed query metadata
- `/api/suggest.php?q=...` — local title suggestions
- `/api/stats.php` — page/domain count and provider state
- `/health.php` — deployment health check

Search-result pages and APIs are sent with no-index/no-archive directives.

## Privacy and security

The application does not create user accounts, set tracking cookies or keep a raw application query log. Rate limiting stores an HMAC identifier per time window rather than a raw client IP address. Hosting-provider/CDN access logs can still exist outside the application and must be configured separately.

Security headers include CSP, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` and a restrictive Permissions Policy. External `!bang` shortcuts are curated HTTPS destinations and are never triggered without explicit bang syntax.

## External research and licensing

The product research behind advanced query behaviour is documented in [`RESEARCH.md`](RESEARCH.md). AstianGO is AGPL-3.0, so its code is not copied, ported or rebranded here. Midori Desktop is MPL-2.0 and Gecko-derived; useful browser concepts are treated separately from engine-specific source reuse.

Ghosium Search is a clean-room shared-hosting implementation under the Ghosium/Brendigo project licensing model.
