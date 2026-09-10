<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('Expires: 0');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Permissions-Policy: camera=(), microphone=(), geolocation=(), browsing-topics=()');
header('Cross-Origin-Resource-Policy: same-site');
header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
header('X-Robots-Tag: noindex, nofollow, noarchive');

$manifestPath = __DIR__ . '/windows/stable.json';
$manifest = [];
if (is_file($manifestPath)) {
    $raw = @file_get_contents($manifestPath);
    if (is_string($raw) && $raw !== '') {
        try {
            $decoded = json_decode($raw, true, 32, JSON_THROW_ON_ERROR);
            if (is_array($decoded)) {
                $manifest = $decoded;
            }
        } catch (JsonException) {
            $manifest = [];
        }
    }
}

$version = $manifest['version'] ?? null;
$enabled = $manifest['enabled'] ?? null;
$url = $manifest['url'] ?? null;
$sha256 = $manifest['sha256'] ?? null;
$size = $manifest['size'] ?? null;
$releaseNotes = $manifest['release_notes'] ?? null;

$healthy = ($manifest['schema'] ?? null) === 1
    && ($manifest['product'] ?? null) === 'Ghosium Browser'
    && ($manifest['platform'] ?? null) === 'windows'
    && ($manifest['channel'] ?? null) === 'stable'
    && is_bool($enabled)
    && is_string($version)
    && preg_match('/^0\.\d+\.\d+$/D', $version) === 1
    && $url === 'https://updates.ghosium.com/windows/Ghosium-Browser-Setup.exe'
    && $releaseNotes === "https://ghosium.com/release-notes/{$version}";

if ($healthy && $enabled === true) {
    $healthy = is_string($sha256)
        && preg_match('/^[0-9a-f]{64}$/D', $sha256) === 1
        && is_int($size)
        && $size > 0
        && $size <= 536870912;
} elseif ($healthy) {
    // A disabled repository/baseline manifest must fail closed rather than
    // retaining stale package integrity metadata from an older publication.
    $healthy = $sha256 === '' && $size === 0;
}

http_response_code($healthy ? 200 : 503);
echo json_encode([
    'status' => $healthy ? 'ok' : 'invalid-manifest',
    'service' => 'Ghosium Updates',
    'channel' => 'stable',
    'publishingEnabled' => $healthy && $enabled === true,
    'version' => is_string($version) ? $version : '',
], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
