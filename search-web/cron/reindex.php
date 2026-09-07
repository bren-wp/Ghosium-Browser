<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit("CLI only\n");
}

require_once __DIR__ . '/../inc/bootstrap.php';

function public_web_url(string $url): bool
{
    $parts = parse_url($url);
    if (!is_array($parts) || !isset($parts['scheme'], $parts['host'])) return false;
    if (!in_array(strtolower((string)$parts['scheme']), ['http', 'https'], true)) return false;

    $host = strtolower((string)$parts['host']);
    if ($host === 'localhost' || str_ends_with($host, '.local')) return false;

    if (filter_var($host, FILTER_VALIDATE_IP)) {
        return filter_var(
            $host,
            FILTER_VALIDATE_IP,
            FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE
        ) !== false;
    }

    $addresses = gethostbynamel($host) ?: [];
    if ($addresses === []) return false;
    foreach ($addresses as $address) {
        if (filter_var(
            $address,
            FILTER_VALIDATE_IP,
            FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE
        ) === false) {
            return false;
        }
    }
    return true;
}

function fetch_resource(string $url, string $userAgent, array $acceptedTypes, int $maxBytes): array
{
    if (!function_exists('curl_init') || !public_web_url($url)) {
        return ['', '', 0, ''];
    }

    $handle = curl_init($url);
    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_CONNECTTIMEOUT => 4,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_USERAGENT => $userAgent,
        CURLOPT_HTTPHEADER => ['Accept: ' . implode(',', $acceptedTypes)],
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_PROTOCOLS => CURLPROTO_HTTP | CURLPROTO_HTTPS,
        CURLOPT_REDIR_PROTOCOLS => CURLPROTO_HTTP | CURLPROTO_HTTPS,
    ]);

    $body = curl_exec($handle);
    $status = (int)curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    $type = strtolower((string)curl_getinfo($handle, CURLINFO_CONTENT_TYPE));
    $effective = (string)curl_getinfo($handle, CURLINFO_EFFECTIVE_URL);
    curl_close($handle);

    if (!is_string($body) || strlen($body) > $maxBytes) {
        return ['', '', $status, $type];
    }
    return [$body, $effective !== '' ? $effective : $url, $status, $type];
}

function fetch_html(string $url, string $userAgent): array
{
    [$body, $effective, $status, $type] = fetch_resource(
        $url,
        $userAgent,
        ['text/html', 'application/xhtml+xml'],
        2_000_000
    );
    if ($status < 200 || $status >= 300 || !str_contains($type, 'text/html')) {
        return ['', ''];
    }
    return [$body, $effective];
}

function canonicalize_link(string $base, string $href): string
{
    $href = trim($href);
    if ($href === '' || str_starts_with($href, '#') || preg_match('/^(mailto|tel|javascript|data):/i', $href)) {
        return '';
    }
    if (preg_match('#^https?://#i', $href)) return clean_result_url($href);

    $baseParts = parse_url($base);
    if (!is_array($baseParts) || !isset($baseParts['scheme'], $baseParts['host'])) return '';

    $origin = $baseParts['scheme'] . '://' . $baseParts['host'];
    if (isset($baseParts['port'])) {
        $origin .= ':' . (int)$baseParts['port'];
    }
    if (str_starts_with($href, '//')) return clean_result_url($baseParts['scheme'] . ':' . $href);
    if (str_starts_with($href, '/')) return clean_result_url($origin . $href);

    $path = (string)($baseParts['path'] ?? '/');
    $directory = rtrim(str_replace('\\', '/', dirname($path)), '/');
    return clean_result_url($origin . ($directory === '' ? '' : $directory) . '/' . $href);
}

function robots_url_for(string $url): string
{
    $parts = parse_url($url);
    if (!is_array($parts) || !isset($parts['scheme'], $parts['host'])) return '';
    $origin = strtolower((string)$parts['scheme']) . '://' . $parts['host'];
    if (isset($parts['port'])) {
        $origin .= ':' . (int)$parts['port'];
    }
    return $origin . '/robots.txt';
}

function parse_robots_groups(string $body): array
{
    $groups = [];
    $agents = [];
    $rules = [];
    $rulesStarted = false;

    $flush = static function () use (&$groups, &$agents, &$rules, &$rulesStarted): void {
        if ($agents !== []) {
            $groups[] = ['agents' => $agents, 'rules' => $rules];
        }
        $agents = [];
        $rules = [];
        $rulesStarted = false;
    };

    $lines = preg_split('/\R/u', $body) ?: [];
    foreach ($lines as $line) {
        $line = trim(preg_replace('/\s*#.*$/u', '', (string)$line) ?? '');
        if ($line === '') {
            if ($rulesStarted) $flush();
            continue;
        }
        if (!str_contains($line, ':')) continue;
        [$field, $value] = array_map('trim', explode(':', $line, 2));
        $field = lower_text($field);

        if ($field === 'user-agent') {
            if ($rulesStarted) $flush();
            if ($value !== '') $agents[] = lower_text($value);
            continue;
        }
        if (($field === 'allow' || $field === 'disallow') && $agents !== []) {
            $rulesStarted = true;
            $rules[] = ['allow' => $field === 'allow', 'path' => $value];
        }
    }
    if ($agents !== []) $flush();
    return $groups;
}

function robots_pattern_matches(string $pattern, string $path): bool
{
    if ($pattern === '') return false;
    $endAnchored = str_ends_with($pattern, '$');
    if ($endAnchored) $pattern = substr($pattern, 0, -1);
    $quoted = preg_quote($pattern, '#');
    $quoted = str_replace('\\*', '.*', $quoted);
    $regex = '#^' . $quoted . ($endAnchored ? '$' : '') . '#u';
    return preg_match($regex, $path) === 1;
}

function robots_allowed(string $url, string $userAgent, bool $respectRobots): bool
{
    if (!$respectRobots) return true;

    static $cache = [];
    $robotsUrl = robots_url_for($url);
    if ($robotsUrl === '') return false;

    if (!array_key_exists($robotsUrl, $cache)) {
        [$body, , $status] = fetch_resource(
            $robotsUrl,
            $userAgent,
            ['text/plain', 'text/*'],
            512_000
        );
        // Missing robots.txt means no crawler-specific restriction. A 401/403
        // is treated conservatively as disallow-all rather than bypassing it.
        if ($status === 401 || $status === 403) {
            $cache[$robotsUrl] = ['deny_all' => true, 'groups' => []];
        } elseif ($status >= 200 && $status < 300 && $body !== '') {
            $cache[$robotsUrl] = ['deny_all' => false, 'groups' => parse_robots_groups($body)];
        } else {
            $cache[$robotsUrl] = ['deny_all' => false, 'groups' => []];
        }
    }

    $robots = $cache[$robotsUrl];
    if (!empty($robots['deny_all'])) return false;

    $groups = is_array($robots['groups'] ?? null) ? $robots['groups'] : [];
    $uaToken = lower_text(explode('/', $userAgent, 2)[0] ?? $userAgent);
    $specific = [];
    $wildcard = [];
    foreach ($groups as $group) {
        if (!is_array($group)) continue;
        $agents = is_array($group['agents'] ?? null) ? $group['agents'] : [];
        foreach ($agents as $agent) {
            $agent = lower_text((string)$agent);
            if ($agent === '*') {
                $wildcard[] = $group;
            } elseif ($agent !== '' && str_contains($uaToken, $agent)) {
                $specific[] = $group;
            }
        }
    }
    $selected = $specific !== [] ? $specific : $wildcard;
    if ($selected === []) return true;

    $parts = parse_url($url);
    $path = (string)($parts['path'] ?? '/');
    if (!empty($parts['query'])) $path .= '?' . $parts['query'];

    $winner = null;
    $winnerLength = -1;
    foreach ($selected as $group) {
        foreach (($group['rules'] ?? []) as $rule) {
            if (!is_array($rule)) continue;
            $rulePath = (string)($rule['path'] ?? '');
            if ($rulePath === '' || !robots_pattern_matches($rulePath, $path)) continue;
            $specificity = strlen(str_replace(['*', '$'], '', $rulePath));
            $allow = !empty($rule['allow']);
            if ($specificity > $winnerLength || ($specificity === $winnerLength && $allow)) {
                $winner = $allow;
                $winnerLength = $specificity;
            }
        }
    }
    return $winner ?? true;
}

function meta_robots_policy(DOMDocument $dom, string $userAgent): array
{
    $noindex = false;
    $nofollow = false;
    $uaToken = lower_text(explode('/', $userAgent, 2)[0] ?? $userAgent);

    foreach ($dom->getElementsByTagName('meta') as $meta) {
        $name = lower_text(trim((string)$meta->getAttribute('name')));
        if ($name !== 'robots' && $name !== $uaToken) continue;
        $content = lower_text((string)$meta->getAttribute('content'));
        $tokens = preg_split('/[\s,]+/u', $content, -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $noindex = $noindex || in_array('noindex', $tokens, true) || in_array('none', $tokens, true);
        $nofollow = $nofollow || in_array('nofollow', $tokens, true) || in_array('none', $tokens, true);
    }
    return ['noindex' => $noindex, 'nofollow' => $nofollow];
}

function page_description(DOMDocument $dom): string
{
    $fallback = '';
    foreach ($dom->getElementsByTagName('meta') as $meta) {
        $name = lower_text(trim((string)$meta->getAttribute('name')));
        $property = lower_text(trim((string)$meta->getAttribute('property')));
        $content = trim((string)$meta->getAttribute('content'));
        if ($content === '') continue;
        if ($name === 'description') return $content;
        if ($property === 'og:description') $fallback = $content;
    }
    return $fallback;
}

function page_canonical(DOMDocument $dom, string $effective, array $seedHosts): string
{
    foreach ($dom->getElementsByTagName('link') as $link) {
        $rels = preg_split('/\s+/u', lower_text(trim((string)$link->getAttribute('rel'))), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if (!in_array('canonical', $rels, true)) continue;
        $candidate = canonicalize_link($effective, (string)$link->getAttribute('href'));
        $host = lower_text((string)(parse_url($candidate, PHP_URL_HOST) ?: ''));
        if ($candidate !== '' && isset($seedHosts[$host])) {
            return $candidate;
        }
    }
    return clean_result_url($effective);
}

$lockPath = GHOSIUM_DATA . '/reindex.lock';
$lockHandle = fopen($lockPath, 'c');
if ($lockHandle === false || !flock($lockHandle, LOCK_EX | LOCK_NB)) {
    fwrite(STDERR, "Another Ghosium Search reindex job is already running.\n");
    exit(2);
}

$config = ghosium_config();
$crawler = $config['crawler'] ?? [];
$maxPages = max(1, min(500, (int)($crawler['max_pages'] ?? 40)));
$maxDepth = max(0, min(4, (int)($crawler['max_depth'] ?? 2)));
$maxPagesPerHost = max(1, min($maxPages, (int)($crawler['max_pages_per_host'] ?? 20)));
$respectRobots = !array_key_exists('respect_robots', $crawler) || !empty($crawler['respect_robots']);
$requestDelayMs = max(100, min(10_000, (int)($crawler['request_delay_ms'] ?? 350)));
$userAgent = trim((string)($crawler['user_agent'] ?? 'GhosiumSearchBot/0.7'));
if ($userAgent === '') $userAgent = 'GhosiumSearchBot/0.7';

$seeds = json_read(GHOSIUM_DATA . '/seeds.json');
$queue = [];
$seedHosts = [];
foreach ($seeds as $seed) {
    $url = clean_result_url((string)$seed);
    $host = lower_text((string)(parse_url($url, PHP_URL_HOST) ?: ''));
    if ($url !== '' && $host !== '' && public_web_url($url)) {
        $queue[] = [$url, 0];
        $seedHosts[$host] = true;
    }
}

if ($queue === []) {
    fwrite(STDERR, "No valid public seed URLs are configured. Existing index was preserved.\n");
    flock($lockHandle, LOCK_UN);
    fclose($lockHandle);
    exit(3);
}

$startedAt = gmdate('c');
$seen = [];
$indexedUrls = [];
$hostCounts = [];
$index = [];
$fetchFailures = 0;
$robotsSkipped = 0;
$noindexSkipped = 0;

while ($queue !== [] && count($index) < $maxPages) {
    [$url, $depth] = array_shift($queue);
    if (isset($seen[$url])) continue;
    $seen[$url] = true;

    $host = lower_text((string)(parse_url($url, PHP_URL_HOST) ?: ''));
    if ($host === '' || !isset($seedHosts[$host])) continue;
    if (($hostCounts[$host] ?? 0) >= $maxPagesPerHost) continue;

    if (!robots_allowed($url, $userAgent, $respectRobots)) {
        $robotsSkipped++;
        continue;
    }

    [$html, $effective] = fetch_html($url, $userAgent);
    if ($html === '') {
        $fetchFailures++;
        continue;
    }
    $hostCounts[$host] = ($hostCounts[$host] ?? 0) + 1;

    $dom = new DOMDocument();
    libxml_use_internal_errors(true);
    $loaded = $dom->loadHTML($html, LIBXML_NOERROR | LIBXML_NOWARNING | LIBXML_NONET);
    libxml_clear_errors();
    if (!$loaded) {
        $fetchFailures++;
        continue;
    }

    $robotsPolicy = meta_robots_policy($dom, $userAgent);
    $title = trim((string)($dom->getElementsByTagName('title')->item(0)?->textContent ?? ''));
    $canonical = page_canonical($dom, $effective, $seedHosts);

    if (!$robotsPolicy['noindex'] && $title !== '' && $canonical !== '' && !isset($indexedUrls[$canonical])) {
        $description = page_description($dom);
        $indexedUrls[$canonical] = true;
        $index[] = [
            'url' => $canonical,
            'title' => function_exists('mb_substr') ? mb_substr($title, 0, 180, 'UTF-8') : substr($title, 0, 180),
            'description' => function_exists('mb_substr')
                ? mb_substr(strip_tags($description), 0, 420, 'UTF-8')
                : substr(strip_tags($description), 0, 420),
            'tags' => [(string)(parse_url($canonical, PHP_URL_HOST) ?: '')],
            'indexed_at' => gmdate('c'),
        ];
    } elseif ($robotsPolicy['noindex']) {
        $noindexSkipped++;
    }

    if ($depth < $maxDepth && !$robotsPolicy['nofollow']) {
        foreach ($dom->getElementsByTagName('a') as $anchor) {
            $rel = lower_text((string)$anchor->getAttribute('rel'));
            $rels = preg_split('/\s+/u', trim($rel), -1, PREG_SPLIT_NO_EMPTY) ?: [];
            if (in_array('nofollow', $rels, true)) continue;

            $next = canonicalize_link($effective, (string)$anchor->getAttribute('href'));
            if ($next === '' || isset($seen[$next])) continue;
            $nextHost = lower_text((string)(parse_url($next, PHP_URL_HOST) ?: ''));
            if (!isset($seedHosts[$nextHost])) continue;
            if (($hostCounts[$nextHost] ?? 0) >= $maxPagesPerHost) continue;

            $queue[] = [$next, $depth + 1];
            if (count($queue) > $maxPages * 12) break;
        }
    }

    usleep($requestDelayMs * 1000);
}

if ($index === []) {
    fwrite(STDERR, "Crawler produced no indexable pages. Existing index was preserved.\n");
    json_write_atomic(GHOSIUM_DATA . '/crawl-state.json', [
        'status' => 'failed-empty',
        'started_at' => $startedAt,
        'finished_at' => gmdate('c'),
        'fetch_failures' => $fetchFailures,
        'robots_skipped' => $robotsSkipped,
        'noindex_skipped' => $noindexSkipped,
    ]);
    flock($lockHandle, LOCK_UN);
    fclose($lockHandle);
    exit(4);
}

if (!json_write_atomic(GHOSIUM_DATA . '/index.json', $index)) {
    fwrite(STDERR, "Unable to write index.json\n");
    flock($lockHandle, LOCK_UN);
    fclose($lockHandle);
    exit(1);
}

$domains = [];
foreach ($index as $item) {
    $host = lower_text((string)(parse_url((string)$item['url'], PHP_URL_HOST) ?: ''));
    if ($host !== '') $domains[$host] = true;
}

json_write_atomic(GHOSIUM_DATA . '/crawl-state.json', [
    'status' => 'ok',
    'started_at' => $startedAt,
    'finished_at' => gmdate('c'),
    'pages' => count($index),
    'domains' => count($domains),
    'fetch_failures' => $fetchFailures,
    'robots_skipped' => $robotsSkipped,
    'noindex_skipped' => $noindexSkipped,
]);

echo 'Indexed ' . count($index) . ' pages across ' . count($domains) . " domains.\n";

flock($lockHandle, LOCK_UN);
fclose($lockHandle);
