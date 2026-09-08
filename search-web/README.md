# Ghosium Search — shared hosting

This directory contains the independently deployable Ghosium Search application for `https://search.ghosium.com/`. Browser and Search are versioned together, but the web deployment remains separate from the desktop binary.

## Public UI architecture

The public interface is deliberately simple: one search field on the home page and a compact browser-style search field above results. It uses the same dark Ghosium visual language as the browser—`#111016` base surface with mint/teal/cyan accents—and is responsive across desktop and mobile layouts.

The UI is componentized server-side in `inc/ui.php`. Requests are rendered by PHP and styled by the production stylesheet in `assets/app.css`. There is **no JavaScript runtime bundle**, hydration layer, client framework or Node application server in the request path. This avoids shipping framework overhead for a page whose primary interaction is submitting a search form.

Advanced parser capabilities are intentionally not advertised as developer syntax on the public home screen. They remain supported by the search engine and API for users/clients that need them.

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
3. Keep `provider.enabled` set to `false` unless an approved compatible provider is configured.
4. Add only HTTPS seed URLs you are permitted and prepared to crawl to `storage/data/seeds.json`.
5. Schedule `php /home/USER/search.ghosium.com/cron/reindex.php` in the hosting control panel when automatic index refresh is required.
6. Confirm `storage/`, `inc/`, `cron/` and JSON data files are not publicly browsable.

## Search syntax

The clean-room query parser supports:

- `privacy browser` — ordinary term search
- `"private browsing"` — required phrase
- `site:ghosium.com privacy` — restrict results to one host/domain and subdomains
- `intitle:privacy` or `intitle:"privacy policy"` — require title text
- `privacy -advertising` — exclude a term
- operator-only searches such as `site:store.ghosium.com`

Operators can be combined. Ranking gives additional weight to exact titles, title matches, phrases, tags and descriptions, then applies host diversity so one indexed domain does not unnecessarily dominate early results.

These operators are engine functionality, not public-home-page instructions. The production UI keeps implementation/query syntax out of the main user path.

## Explicit `!bang` shortcuts

A curated `!bang` is used only when a user explicitly types it. It redirects the query to the configured third-party destination and therefore leaves Ghosium Search.

Current shortcuts include:

- `!w` / `!wiki` — Wikipedia
- `!gh` — GitHub
- `!yt` — YouTube
- `!r` — Reddit
- `!mdn` — MDN Web Docs
- `!so` — Stack Overflow

Unknown bangs remain normal Ghosium queries. `/api/search.php` returns bang metadata rather than automatically redirecting, so an API client can decide whether to leave Ghosium Search.

## Local engine

`cron/reindex.php` is a bounded crawler for conventional shared hosting. It follows configured seed hosts and includes:

- public-address validation to reduce SSRF exposure;
- `robots.txt` handling;
- page-level `noindex` and `nofollow` handling;
- link-level `rel="nofollow"` handling;
- canonical URL handling limited to configured seed hosts;
- configurable page, depth and per-host limits;
- request delay;
- a non-blocking lock preventing overlapping cron runs;
- preservation of the existing index when a crawl yields no indexable pages;
- atomic JSON writes.

A successful crawl writes `storage/data/index.json` and `storage/data/crawl-state.json`.

A single shared-hosting JSON index is intentionally bounded and is not represented as a complete index of the public web. A future distributed Ghosium index can replace/extend the data source without forcing a redesign of the public Search interface.

## Optional server-side provider

A compatible HTTPS JSON provider can be enabled in protected configuration. Its credential remains server-side and is never embedded in Ghosium Browser or the public page.

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

Provider responses are normalized, tracking query parameters are stripped from result URLs, duplicates are collapsed and Ghosium query filters are applied before display.

## API

- `/api/search.php?q=...` — results plus parsed-query metadata
- `/api/suggest.php?q=...` — local title suggestions
- `/api/stats.php` — operational index/provider state
- `/health.php` — deployment health check

Search-result pages and APIs carry no-index/no-archive directives where appropriate.

## Privacy and security

The application does not create user accounts, set tracking cookies or maintain a raw application query log. Rate limiting stores an HMAC identifier per time window rather than a raw client IP address. Hosting-provider/CDN access logs can still exist outside the application and must be configured separately.

Security headers include CSP, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` and a restrictive Permissions Policy. External `!bang` shortcuts are curated HTTPS destinations and are never triggered without explicit bang syntax.

The public UI contains no inline JavaScript and no inline CSS. CI also rejects accidental JavaScript runtime bundles under `search-web/assets` and prevents developer/index implementation details from returning to the home page.

## External research and licensing

The product research behind advanced query behaviour is documented in [`RESEARCH.md`](RESEARCH.md). External projects described there are research inputs only; their code is not copied or rebranded into this application where their licenses do not permit that product boundary.

Ghosium Search is a clean-room shared hosting implementation under the Ghosium/Brendigo project licensing model.
