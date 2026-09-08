<?php
declare(strict_types=1);

require_once __DIR__ . '/inc/search.php';
require_once __DIR__ . '/inc/bangs.php';
require_once __DIR__ . '/inc/ui.php';

ghosium_headers(false);
rate_limit_or_fail();

$query = normalize_query((string)($_GET['q'] ?? ''));
$bang = $query !== '' ? resolve_ghosium_bang($query) : null;
if (is_array($bang)) {
    header('Cache-Control: no-store, max-age=0');
    header('X-Robots-Tag: noindex, nofollow, noarchive');
    header('Location: ' . (string)$bang['url'], true, 302);
    exit;
}

$results = $query !== '' ? ghosium_search($query) : [];
if ($query !== '') {
    header('X-Robots-Tag: noindex, nofollow, noarchive');
}
?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="theme-color" content="#111016">
  <meta name="referrer" content="no-referrer">
  <meta name="application-name" content="Ghosium Search">
  <?php if ($query !== ''): ?><meta name="robots" content="noindex,nofollow,noarchive"><?php endif; ?>
  <title><?= $query !== '' ? ghosium_escape($query) . ' — ' : '' ?>Ghosium Search</title>
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="preload" href="/assets/ghosium-mark.svg" as="image" type="image/svg+xml">
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body class="<?= $query === '' ? 'home' : 'results-page' ?>">
  <header class="browser-bar">
    <div class="browser-bar__inner">
      <?php ghosium_render_brand($query !== ''); ?>
      <?php if ($query !== ''): ?>
        <div class="browser-bar__search">
          <?php ghosium_render_search_form($query, true); ?>
        </div>
      <?php endif; ?>
      <nav class="browser-bar__nav" aria-label="Ghosium products">
        <a href="https://ghosium.com/">Browser</a>
        <a href="https://store.ghosium.com/">Store</a>
        <a href="https://ghosium.com/support">Support</a>
      </nav>
    </div>
  </header>

  <?php if ($query === ''): ?>
    <main class="home-main">
      <section class="search-stage" aria-labelledby="search-title">
        <div class="search-stage__mark" aria-hidden="true">
          <img src="/assets/ghosium-mark.svg" alt="" width="92" height="92">
        </div>
        <div class="search-stage__identity">
          <span>Ghosium</span>
          <strong>Search</strong>
        </div>
        <h1 id="search-title">Search without the noise.</h1>
        <p class="search-stage__lead">One focused search box, clear results and the same visual language as Ghosium Browser.</p>
        <div class="search-stage__form">
          <?php ghosium_render_search_form('', false, true); ?>
        </div>
        <div class="search-stage__signals" aria-label="Ghosium Search principles">
          <span><i aria-hidden="true"></i> Focused interface</span>
          <span><i aria-hidden="true"></i> Fast navigation</span>
          <span><i aria-hidden="true"></i> No account required</span>
        </div>
      </section>
    </main>
  <?php else: ?>
    <main class="results-main">
      <section class="results-shell" aria-labelledby="results-title">
        <div class="results-heading">
          <div>
            <p class="results-heading__eyebrow">Web results</p>
            <h1 id="results-title"><?= ghosium_escape($query) ?></h1>
          </div>
          <span class="results-heading__count"><?= number_format(count($results)) ?> result<?= count($results) === 1 ? '' : 's' ?></span>
        </div>

        <?php if ($results === []): ?>
          <article class="empty-state">
            <div class="empty-state__icon" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="26" height="26" focusable="false">
                <path d="m20 20-4.35-4.35m2.35-5.15a7.5 7.5 0 1 1-15 0 7.5 7.5 0 0 1 15 0Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>
              </svg>
            </div>
            <h2>No results found</h2>
            <p>Try another search with fewer or different words.</p>
          </article>
        <?php else: ?>
          <div class="results-list">
            <?php foreach ($results as $result): ?>
              <?php ghosium_render_result($result); ?>
            <?php endforeach; ?>
          </div>
        <?php endif; ?>
      </section>
    </main>
  <?php endif; ?>

  <footer class="site-footer">
    <div class="site-footer__inner">
      <span>Ghosium Search</span>
      <nav aria-label="Ghosium links">
        <a href="https://ghosium.com/security">Security</a>
        <a href="https://ghosium.com/legal/privacy-policy">Privacy</a>
        <a href="https://ghosium.com/legal/terms">Terms</a>
        <a href="https://ghosium.com/legal/licenses">Licenses</a>
        <a href="/health.php">Status</a>
      </nav>
    </div>
  </footer>
</body>
</html>
