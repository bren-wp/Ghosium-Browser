<?php
declare(strict_types=1);

header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Permissions-Policy: camera=(), microphone=(), geolocation=(), browsing-topics=()');
header("Content-Security-Policy: default-src 'self'; style-src 'self'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; object-src 'none'; form-action 'none'");

$manifestPath = __DIR__ . '/windows/stable.json';
$manifest = [];
if (is_file($manifestPath)) {
    $decoded = json_decode((string)file_get_contents($manifestPath), true);
    if (is_array($decoded)) {
        $manifest = $decoded;
    }
}

function e(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

$enabled = !empty($manifest['enabled']);
$version = (string)($manifest['version'] ?? 'unknown');
?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="robots" content="noindex,nofollow,noarchive">
  <title>Ghosium Browser Updates</title>
  <link rel="stylesheet" href="/assets/app.css">
</head>
<body>
  <main class="shell">
    <section class="card" aria-labelledby="title">
      <p class="eyebrow">BRENDIGO RELEASE SERVICE</p>
      <h1 id="title">Ghosium <span>Updates</span></h1>
      <p class="lead">First-party update metadata for Ghosium Browser. Browser updates use the standard signed Ghosium Setup package; no standalone updater executable is distributed.</p>

      <div class="status-grid">
        <div><span>Channel</span><strong>Stable</strong></div>
        <div><span>Manifest version</span><strong><?= e($version) ?></strong></div>
        <div><span>Publishing</span><strong><?= $enabled ? 'Enabled' : 'Disabled' ?></strong></div>
      </div>

      <p class="note">The browser independently verifies HTTPS origin, manifest fields, exact file size, SHA-256 and Windows Authenticode publisher identity before launching an update.</p>
      <nav>
        <a href="/windows/stable.json">Stable manifest</a>
        <a href="/health.php">Health</a>
        <a href="https://ghosium.com/security">Security</a>
        <a href="https://ghosium.com/support">Support</a>
      </nav>
    </section>
  </main>
</body>
</html>
