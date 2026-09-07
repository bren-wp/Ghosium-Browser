# Ghosium Search research boundary

This document records external product research used to inform Ghosium Browser and Ghosium Search. It is intentionally explicit about licensing and implementation boundaries.

## AstianGO

Reference project: `goastian/astiango`.

AstianGO presents useful search-product concepts including an independent crawler/index, advanced query syntax such as `site:` and `intitle:`, `!bang` shortcuts, custom ranking/optics, tracker-aware ranking, and a Stract/Tantivy-based search architecture.

AstianGO is licensed under **AGPL-3.0**. Ghosium Search does **not** import, vendor, translate, port, rebrand, or copy AstianGO/Stract source code. The PHP implementation in this directory is a **clean-room** Ghosium implementation based on generic search behaviour and Ghosium's own data model.

The first shared-hosting implementation deliberately uses:

- PHP 8.1+ request handling;
- JSON files for the small first-party index, configuration and cache;
- a bounded seed-domain crawler run by hosting cron;
- `site:`, `intitle:`, quoted phrases and negative terms implemented in Ghosium PHP;
- curated `!bang` shortcuts that activate only when the user explicitly asks to leave Ghosium Search;
- an optional HTTPS JSON provider abstraction for infrastructure that is operated or licensed separately.

It does not claim to reproduce AstianGO's Stract/Tantivy index or its internet-scale crawler. A true global Ghosium index belongs on dedicated crawler/index infrastructure, while this shared-hosting frontend and API can remain stable.

## Midori Desktop

Reference project: `goastian/midori-desktop`.

Midori Desktop is licensed under **MPL-2.0** and is Gecko/Firefox-derived. Its public project documentation highlights privacy-oriented defaults, a built-in protection extension, workspaces, a customized new-tab page, custom branding/update configuration and Firefox WebExtension compatibility.

Ghosium is Chromium-derived, so engine-specific Midori implementation files are not suitable for direct transplantation. The preferred rule is to study product behaviour and implement equivalent Ghosium functionality against Chromium interfaces. Any future direct reuse of an MPL-covered file must be reviewed file-by-file and retain the license obligations applicable to that file.

Useful concepts for later Ghosium work include:

- named local workspaces for organizing tabs;
- keyboard-driven workspace switching;
- a cohesive browser-owned new-tab surface;
- privacy/protection status that is understandable without a cloud account;
- update configuration that points only to Ghosium-owned release infrastructure.

## Product and trademark rule

External project names and trademarks are research references only. Ghosium UI must not imply that Google, Chromium, Mozilla, Midori, AstianGO, Astian or another vendor's service is owned by Brendigo/Ghosium.

Ghosium-owned features may use Ghosium branding. Third-party services must either retain accurate attribution or be removed/hidden when Ghosium does not provide that service.

## Shared-hosting boundary

`search-web/` is the deployable web root for the Ghosium Search shared-hosting edition. It must remain usable on conventional Apache/LiteSpeed shared hosting without a long-running Node, Rust, Java or Python application process.

Cron is optional for serving requests but required to refresh the bundled first-party crawl index. The request path remains PHP-only. A future distributed index may be connected through the HTTPS provider interface without replacing the browser's `https://search.ghosium.com/?q=...` contract.
