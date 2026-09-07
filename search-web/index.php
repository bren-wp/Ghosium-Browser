<?php
declare(strict_types=1);

require_once __DIR__ . '/inc/search.php';
require_once __DIR__ . '/inc/bangs.php';
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
$stats = $query === '' ? ghosium_search_stats() : [];
if ($query !== '') {
    header('X-Robots-Tag: noindex, nofollow, noarchive');
}

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="referrer" content="no-referrer">
  <?php if ($query !== ''): ?><meta name="robots" content="noindex,nofollow,noarchive"><?php endif; ?>
  <title><?= $query !== '' ? e($query) . ' — ' : '' ?>Ghosium Search</title>
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body class="<?= $query === '' ? 'home' : 'results-page' ?>">
  <header class="topbar">
    <a class="brand" href="/" aria-label="Ghosium Search home">
      <img src="/assets/ghosium-mark.svg" alt="" width="34" height="34">
      <span>Ghosium <strong>Search</strong></span>
    </a>
    <?php if ($query !== ''): ?>
      <form class="top-search" method="get" action="/" role="search">
        <label class="sr-only" for="top-q">Search the web</label>
        <input id="top-q" name="q" type="search" value="<?= e($query) ?>" autocomplete="off" maxlength="180" spellcheck="false">
        <button type="submit">Search</button>
      </form>
    <?php endif; ?>
  </header>

  <main>
    <?php if ($query === ''): ?>
      <section class="hero">
        <img class="hero-mark" src="/assets/ghosium-mark.svg" alt="" width="88" height="88">
        <p class="eyebrow">GHOSIUM SEARCH</p>
        <h1>Search with <span>Ghosium</span></h1>
        <p class="lead">A lightweight Ghosium-owned search surface for shared hosting, with a first-party index, optional server-side provider and no application advertising profile.</p>
        <form class="hero-search" method="get" action="/" role="search">
          <label class="sr-only" for="q">Ghosium Search</label>
          <input id="q" name="q" type="search" autofocus autocomplete="off" maxlength="180" spellcheck="false" placeholder="Search the web">
          <button type="submit">Search</button>
        </form>
        <div class="query-tools" aria-label="Advanced search examples">
          <code>site:example.com</code>
          <code>intitle:privacy</code>
          <code>&quot;exact phrase&quot;</code>
          <code>-exclude</code>
          <code title="Explicit external shortcut">!gh query</code>
        </div>
        <p class="privacy-note">No tracking cookies · no account required · external !bang shortcuts only when explicitly requested</p>
        <div class="index-health" aria-label="Ghosium Search index status">
          <span><strong><?= number_format((int)($stats['pages'] ?? 0)) ?></strong> indexed pages</span>
          <span><strong><?= number_format((int)($stats['domains'] ?? 0)) ?></strong> domains</span>
          <span><?= !empty($stats['provider_enabled']) ? 'Hybrid provider enabled' : 'First-party index mode' ?></span>
        </div>
      </section>
    <?php else: ?>
      <section class="results" aria-labelledby="results-title">
        <p class="count" id="results-title"><?= count($results) ?> results for <strong><?= e($query) ?></strong></p>
        <?php if ($results === []): ?>
          <article class="empty">
            <h2>No matching results in the current search sources.</h2>
            <p>Try broader terms, remove a filter, add more indexed seed domains, or configure a compatible server-side search provider.</p>
          </article>
        <?php endif; ?>
        <?php foreach ($results as $result):
          $host = (string)(parse_url((string)$result['url'], PHP_URL_HOST) ?: '');
        ?>
          <article class="result">
            <div class="result-host"><?= e($host) ?></div>
            <h2><a href="<?= e((string)$result['url']) ?>" rel="noopener noreferrer"><?= e((string)$result['title']) ?></a></h2>
            <?php if ((string)$result['description'] !== ''): ?><p><?= e((string)$result['description']) ?></p><?php endif; ?>
          </article>
        <?php endforeach; ?>
      </section>
    <?php endif; ?>
  </main>

  <footer>
    <span>Ghosium Search</span>
    <nav aria-label="Ghosium links">
      <a href="https://ghosium.com/">Home</a>
      <a href="https://store.ghosium.com/">Store</a>
      <a href="https://ghosium.com/support">Support</a>
      <a href="https://ghosium.com/security">Security</a>
      <a href="https://ghosium.com/legal/terms">Terms</a>
      <a href="https://ghosium.com/legal/privacy-policy">Privacy</a>
      <a href="https://ghosium.com/legal/licenses">Licenses</a>
      <a href="/health.php">Status</a>
    </nav>
  </footer>
</body>
</html>
