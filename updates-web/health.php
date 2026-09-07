<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, max-age=0');
header('X-Content-Type-Options: nosniff');
header('X-Robots-Tag: noindex, nofollow, noarchive');

$manifestPath = __DIR__ . '/windows/stable.json';
$manifest = [];
if (is_file($manifestPath)) {
    $decoded = json_decode((string)file_get_contents($manifestPath), true);
    if (is_array($decoded)) {
        $manifest = $decoded;
    }
}

$healthy = ($manifest['schema'] ?? null) === 1
    && ($manifest['product'] ?? null) === 'Ghosium Browser'
    && ($manifest['platform'] ?? null) === 'windows'
    && ($manifest['channel'] ?? null) === 'stable';

http_response_code($healthy ? 200 : 503);
echo json_encode([
    'status' => $healthy ? 'ok' : 'invalid-manifest',
    'service' => 'Ghosium Updates',
    'channel' => 'stable',
    'publishingEnabled' => !empty($manifest['enabled']),
    'version' => (string)($manifest['version'] ?? ''),
], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
