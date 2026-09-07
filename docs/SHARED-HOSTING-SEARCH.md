# Deploying Ghosium Search on Shared Hosting

Target: `https://search.ghosium.com/`

The deployable application lives in the repository's separate `search-web/` directory. It is designed for conventional shared hosting and does not require a long-running Node, Rust, Java or Python application process.

## Requirements

- PHP 8.1+
- cURL + DOM PHP extensions
- Apache/LiteSpeed `.htaccess`
- HTTPS
- writable `storage/data`
- optional cron support for index refresh

## Steps

1. Obtain the source code for the matching Ghosium release tag.
2. Upload the **contents** of `search-web/` to the Search subdomain document root.
3. Ensure `storage/data` is writable by PHP but remains blocked from direct HTTP access.
4. Open `/health.php` and confirm `status: ok`.
5. Add only desired public HTTPS seeds to `storage/data/seeds.json`.
6. Configure hosting cron to run `php /absolute/path/to/cron/reindex.php`.
7. Leave the optional provider disabled unless you intentionally configure a compatible HTTPS JSON search service that Ghosium is authorized to use.

## Search behaviour

The shared-hosting edition supports ordinary terms plus Ghosium's clean-room advanced syntax:

- `site:example.com`
- `intitle:privacy`
- `intitle:"privacy policy"`
- `"exact phrase"`
- `-excluded`
- explicit `!bang` shortcuts such as `!gh`, `!w`, `!yt`, `!r`, `!mdn` and `!so`

The local index ranks title, tag, description and URL matches, then limits early same-host saturation to improve result diversity.

## Crawler safeguards

The cron crawler is intentionally bounded for shared hosting. It validates public addresses, stays on configured seed hosts, honors `robots.txt`, page-level `noindex`/`nofollow` and link-level `rel="nofollow"`, applies page/depth/per-host limits and uses a configurable request delay.

Overlapping cron runs are rejected with a non-blocking file lock. If a crawl produces no indexable pages, the existing index is preserved instead of being replaced by an empty file.

This crawler is not represented as an internet-scale independent index. A full public-web Ghosium index requires separate distributed crawler/index infrastructure; the same `search.ghosium.com` frontend can connect to it through the HTTPS provider interface.

## Privacy

Do not enable hosting analytics or query logging if you want the deployed service to match the repository privacy model. Review your hosting provider/CDN access-log settings separately because those logs are outside the PHP application.

Ghosium Search itself does not set tracking cookies or store raw application query logs. Rate limiting uses a time-bucketed HMAC of the client address.

Explicit `!bang` shortcuts are the exception to first-party search handling: the user intentionally requests a third-party destination, and the query is sent to that selected site. Unknown bangs are not forwarded.

## Browser endpoints

Search:

`https://search.ghosium.com/?q={searchTerms}`

Suggestions:

`https://search.ghosium.com/api/suggest.php?q={searchTerms}`

Search JSON API:

`https://search.ghosium.com/api/search.php?q={searchTerms}`

Index statistics:

`https://search.ghosium.com/api/stats.php`

## Licensing boundary

See `search-web/RESEARCH.md`. AstianGO research is treated as product/architecture research only because its code is AGPL-3.0. The shared-hosting PHP engine is a clean-room Ghosium implementation. Midori Desktop is MPL-2.0 and Gecko-derived; any future direct file reuse would require separate file-level review and is not implicit in this search deployment.
