<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

/**
 * Ghosium Search query implementation.
 *
 * This is a clean-room Ghosium implementation for ordinary PHP shared hosting.
 * It does not contain AstianGO/Stract source code. Query operators are generic
 * search-product behaviour implemented against Ghosium's own JSON index and
 * optional provider abstraction.
 */

function query_words(string $text): array
{
    $parts = preg_split('/[^\p{L}\p{N}]+/u', lower_text($text), -1, PREG_SPLIT_NO_EMPTY) ?: [];
    $parts = array_values(array_unique(array_filter(
        $parts,
        static fn(string $token): bool => strlen($token) >= 2
    )));
    return array_slice($parts, 0, 20);
}

function normalize_site_filter(string $site): string
{
    $site = lower_text(trim($site));
    $site = preg_replace('#^https?://#i', '', $site) ?? $site;
    $site = trim(explode('/', $site, 2)[0] ?? '', '. ');
    if ($site === '' || strlen($site) > 253) {
        return '';
    }
    if (!preg_match('/^[a-z0-9.-]+$/i', $site) || str_contains($site, '..')) {
        return '';
    }
    return $site;
}

function parse_search_query(string $query): array
{
    $query = normalize_query($query);
    $filters = [
        'raw' => $query,
        'text' => '',
        'site' => '',
        'intitle' => [],
        'exclude' => [],
        'phrases' => [],
    ];

    if ($query === '') {
        return $filters;
    }

    $remaining = $query;

    if (preg_match_all('/(?:^|\s)site:([^\s]+)/iu', $remaining, $matches)) {
        foreach ($matches[1] as $candidate) {
            $site = normalize_site_filter((string)$candidate);
            if ($site !== '') {
                $filters['site'] = $site;
                break;
            }
        }
        $remaining = preg_replace('/(?:^|\s)site:[^\s]+/iu', ' ', $remaining) ?? $remaining;
    }

    if (preg_match_all('/(?:^|\s)intitle:(?:"([^"]+)"|([^\s]+))/iu', $remaining, $matches, PREG_SET_ORDER)) {
        foreach ($matches as $match) {
            $value = normalize_query((string)($match[1] !== '' ? $match[1] : $match[2]));
            if ($value !== '') {
                $filters['intitle'][] = lower_text($value);
            }
        }
        $remaining = preg_replace('/(?:^|\s)intitle:(?:"[^"]+"|[^\s]+)/iu', ' ', $remaining) ?? $remaining;
    }

    if (preg_match_all('/(?:^|\s)-(?:"([^"]+)"|([\p{L}\p{N}][^\s]*))/u', $remaining, $matches, PREG_SET_ORDER)) {
        foreach ($matches as $match) {
            $value = normalize_query((string)($match[1] !== '' ? $match[1] : $match[2]));
            if ($value !== '') {
                $filters['exclude'][] = lower_text($value);
            }
        }
        $remaining = preg_replace('/(?:^|\s)-(?:"[^"]+"|[\p{L}\p{N}][^\s]*)/u', ' ', $remaining) ?? $remaining;
    }

    if (preg_match_all('/"([^"]+)"/u', $remaining, $matches)) {
        foreach ($matches[1] as $phrase) {
            $phrase = normalize_query((string)$phrase);
            if ($phrase !== '') {
                $filters['phrases'][] = lower_text($phrase);
            }
        }
        $remaining = preg_replace('/"[^"]+"/u', ' ', $remaining) ?? $remaining;
    }

    $filters['text'] = normalize_query($remaining);
    $filters['intitle'] = array_values(array_unique($filters['intitle']));
    $filters['exclude'] = array_values(array_unique($filters['exclude']));
    $filters['phrases'] = array_values(array_unique($filters['phrases']));
    return $filters;
}

function query_tokens(string $query): array
{
    $parsed = parse_search_query($query);
    $combined = trim($parsed['text'] . ' ' . implode(' ', $parsed['phrases']));
    return array_slice(query_words($combined), 0, 12);
}

function result_matches_filters(array $record, array $parsed): bool
{
    $title = lower_text(trim((string)($record['title'] ?? '')));
    $description = lower_text(trim((string)($record['description'] ?? '')));
    $url = clean_result_url((string)($record['url'] ?? ''));
    $host = lower_text((string)(parse_url($url, PHP_URL_HOST) ?: ''));
    $haystack = trim($title . ' ' . $description . ' ' . lower_text($url));

    $site = (string)($parsed['site'] ?? '');
    if ($site !== '' && $host !== $site && !str_ends_with($host, '.' . $site)) {
        return false;
    }

    foreach (($parsed['intitle'] ?? []) as $requiredTitle) {
        if (!str_contains($title, (string)$requiredTitle)) {
            return false;
        }
    }

    foreach (($parsed['exclude'] ?? []) as $excluded) {
        if ($excluded !== '' && str_contains($haystack, (string)$excluded)) {
            return false;
        }
    }

    foreach (($parsed['phrases'] ?? []) as $phrase) {
        if ($phrase !== '' && !str_contains($haystack, (string)$phrase)) {
            return false;
        }
    }

    return true;
}

function local_search(string $query, int $limit): array
{
    $records = json_read(GHOSIUM_DATA . '/index.json');
    $parsed = parse_search_query($query);
    $needle = lower_text((string)$parsed['text']);
    $tokens = query_tokens($query);
    $scored = [];

    foreach ($records as $record) {
        if (!is_array($record) || !result_matches_filters($record, $parsed)) {
            continue;
        }

        $title = trim((string)($record['title'] ?? ''));
        $url = clean_result_url((string)($record['url'] ?? ''));
        $description = trim((string)($record['description'] ?? ''));
        $tags = implode(' ', array_map('strval', is_array($record['tags'] ?? null) ? $record['tags'] : []));
        if ($title === '' || $url === '') {
            continue;
        }

        $titleLower = lower_text($title);
        $descriptionLower = lower_text($description);
        $urlLower = lower_text($url);
        $tagsLower = lower_text($tags);
        $score = 0;

        if ($needle !== '' && $titleLower === $needle) {
            $score += 60;
        } elseif ($needle !== '' && str_contains($titleLower, $needle)) {
            $score += 30;
        }
        if ($needle !== '' && str_contains($descriptionLower, $needle)) {
            $score += 12;
        }

        foreach (($parsed['phrases'] ?? []) as $phrase) {
            if (str_contains($titleLower, (string)$phrase)) {
                $score += 26;
            } elseif (str_contains($descriptionLower, (string)$phrase)) {
                $score += 14;
            }
        }

        foreach ($tokens as $token) {
            if (str_contains($titleLower, $token)) $score += 8;
            if (str_contains($tagsLower, $token)) $score += 6;
            if (str_contains($descriptionLower, $token)) $score += 3;
            if (str_contains($urlLower, $token)) $score += 2;
        }

        if (($parsed['site'] ?? '') !== '') {
            $score += 10;
        }
        if (($parsed['intitle'] ?? []) !== []) {
            $score += 10;
        }

        // An operator-only query such as site:example.com is valid. Matching
        // filters are sufficient to include the result even when no free-text
        // term remains after parsing.
        $operatorOnly = $needle === '' && $tokens === [] && (
            ($parsed['site'] ?? '') !== '' ||
            ($parsed['intitle'] ?? []) !== [] ||
            ($parsed['phrases'] ?? []) !== []
        );
        if ($score <= 0 && !$operatorOnly) {
            continue;
        }
        if ($operatorOnly) {
            $score = max($score, 5);
        }

        $scored[] = [
            'title' => $title,
            'url' => $url,
            'description' => $description,
            'score' => $score,
            'source' => 'local',
            'indexed_at' => (string)($record['indexed_at'] ?? ''),
        ];
    }

    usort($scored, static fn(array $a, array $b): int =>
        ($b['score'] <=> $a['score']) ?: strcmp($a['title'], $b['title'])
    );
    return array_slice($scored, 0, max($limit * 3, $limit));
}

function provider_search(string $query, int $limit): array
{
    $config = ghosium_config();
    $provider = $config['provider'] ?? [];
    if (empty($provider['enabled']) || empty($provider['endpoint']) || !function_exists('curl_init')) {
        return [];
    }

    $cachePath = GHOSIUM_DATA . '/cache.json';
    $cache = json_read($cachePath);
    $cacheKey = hash('sha256', lower_text($query));
    $ttl = max(60, (int)($config['cache_ttl_seconds'] ?? 600));
    $cached = $cache[$cacheKey] ?? null;
    if (is_array($cached) && (int)($cached['expires'] ?? 0) >= time() && is_array($cached['results'] ?? null)) {
        return array_slice($cached['results'], 0, $limit);
    }

    $endpoint = (string)$provider['endpoint'];
    $parts = parse_url($endpoint);
    if (!is_array($parts) || strtolower((string)($parts['scheme'] ?? '')) !== 'https') {
        return [];
    }
    $separator = str_contains($endpoint, '?') ? '&' : '?';
    $url = $endpoint . $separator . rawurlencode((string)($provider['query_param'] ?? 'q')) . '=' . rawurlencode($query);

    $headers = ['Accept: application/json'];
    $apiKey = trim((string)($provider['api_key'] ?? ''));
    if ($apiKey !== '') {
        $headers[] = (string)($provider['auth_header'] ?? 'Authorization') . ': ' . (string)($provider['auth_prefix'] ?? 'Bearer ') . $apiKey;
    }

    $handle = curl_init($url);
    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_CONNECTTIMEOUT => 3,
        CURLOPT_TIMEOUT => max(3, min(12, (int)($provider['timeout_seconds'] ?? 6))),
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_USERAGENT => 'GhosiumSearch/0.7',
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
    ]);
    $body = curl_exec($handle);
    $status = (int)curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);
    if (!is_string($body) || $status < 200 || $status >= 300 || strlen($body) > 4_000_000) {
        return [];
    }

    $decoded = json_decode($body, true);
    $items = is_array($decoded) && is_array($decoded['results'] ?? null) ? $decoded['results'] : [];
    $parsed = parse_search_query($query);
    $results = [];
    foreach ($items as $item) {
        if (!is_array($item)) continue;
        $urlValue = clean_result_url((string)($item['url'] ?? ''));
        $title = trim((string)($item['title'] ?? ''));
        if ($urlValue === '' || $title === '') continue;

        $candidate = [
            'title' => $title,
            'url' => $urlValue,
            'description' => trim((string)($item['description'] ?? '')),
        ];
        if (!result_matches_filters($candidate, $parsed)) {
            continue;
        }

        $results[] = $candidate + [
            'score' => 1,
            'source' => 'provider',
            'indexed_at' => '',
        ];
        if (count($results) >= $limit) break;
    }

    $cache[$cacheKey] = ['expires' => time() + $ttl, 'results' => $results];
    foreach ($cache as $key => $value) {
        if (!is_array($value) || (int)($value['expires'] ?? 0) < time()) unset($cache[$key]);
    }
    if (count($cache) > 500) {
        $cache = array_slice($cache, -500, null, true);
    }
    json_write_atomic($cachePath, $cache);
    return $results;
}

function diversify_results(array $results, int $limit, int $maxPerHost): array
{
    $selected = [];
    $deferred = [];
    $hostCounts = [];

    foreach ($results as $result) {
        $host = lower_text((string)(parse_url((string)($result['url'] ?? ''), PHP_URL_HOST) ?: ''));
        if ($host === '') {
            continue;
        }
        if (($hostCounts[$host] ?? 0) >= $maxPerHost) {
            $deferred[] = $result;
            continue;
        }
        $hostCounts[$host] = ($hostCounts[$host] ?? 0) + 1;
        $selected[] = $result;
        if (count($selected) >= $limit) {
            return $selected;
        }
    }

    foreach ($deferred as $result) {
        $selected[] = $result;
        if (count($selected) >= $limit) break;
    }
    return $selected;
}

function ghosium_search(string $query): array
{
    $config = ghosium_config();
    $limit = max(1, min(50, (int)($config['max_results'] ?? 20)));
    $maxPerHost = max(1, min(10, (int)($config['max_results_per_host'] ?? 3)));

    $remote = provider_search($query, $limit * 2);
    $local = local_search($query, $limit * 2);
    $merged = [];
    $seen = [];

    // Provider results retain provider order; local results retain Ghosium's
    // deterministic local score. Exact URL duplicates are collapsed.
    foreach (array_merge($remote, $local) as $result) {
        $key = lower_text((string)$result['url']);
        if (isset($seen[$key])) continue;
        $seen[$key] = true;
        $merged[] = $result;
    }

    return diversify_results($merged, $limit, $maxPerHost);
}

function ghosium_suggestions(string $query, int $limit = 8): array
{
    $query = normalize_query($query);
    if ($query === '') return [];

    $parsed = parse_search_query($query);
    $needle = lower_text((string)$parsed['text']);
    if ($needle === '') {
        return [];
    }

    $records = json_read(GHOSIUM_DATA . '/index.json');
    $suggestions = [];
    foreach ($records as $record) {
        if (!is_array($record) || !result_matches_filters($record, $parsed)) continue;
        $title = trim((string)($record['title'] ?? ''));
        if ($title !== '' && str_contains(lower_text($title), $needle)) {
            $suggestions[$title] = true;
        }
        if (count($suggestions) >= $limit) break;
    }
    return array_slice(array_keys($suggestions), 0, $limit);
}

function ghosium_search_stats(): array
{
    $records = json_read(GHOSIUM_DATA . '/index.json');
    $domains = [];
    $latest = '';
    foreach ($records as $record) {
        if (!is_array($record)) continue;
        $url = clean_result_url((string)($record['url'] ?? ''));
        $host = lower_text((string)(parse_url($url, PHP_URL_HOST) ?: ''));
        if ($host !== '') {
            $domains[$host] = true;
        }
        $indexedAt = (string)($record['indexed_at'] ?? '');
        if ($indexedAt !== '' && ($latest === '' || strcmp($indexedAt, $latest) > 0)) {
            $latest = $indexedAt;
        }
    }

    return [
        'pages' => count($records),
        'domains' => count($domains),
        'last_indexed_at' => $latest !== '' ? $latest : null,
        'provider_enabled' => !empty((ghosium_config()['provider'] ?? [])['enabled']),
    ];
}
