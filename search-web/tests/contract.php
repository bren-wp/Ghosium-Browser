<?php
declare(strict_types=1);

require_once __DIR__ . '/../inc/search.php';
require_once __DIR__ . '/../inc/bangs.php';

function check(bool $condition, string $message): void
{
    if (!$condition) {
        fwrite(STDERR, "FAIL: {$message}\n");
        exit(1);
    }
}

$parsed = parse_search_query('browser site:ghosium.com intitle:"Ghosium" -store "private browsing"');
check($parsed['site'] === 'ghosium.com', 'site: operator must be parsed');
check($parsed['intitle'] === ['ghosium'], 'intitle: operator must be parsed');
check($parsed['exclude'] === ['store'], 'negative term must be parsed');
check($parsed['phrases'] === ['private browsing'], 'quoted phrase must be parsed');
check($parsed['text'] === 'browser', 'free search text must remain after operators');

$siteOnly = ghosium_search('site:store.ghosium.com');
check(count($siteOnly) === 1, 'operator-only site query must return matching indexed result');
check(parse_url((string)$siteOnly[0]['url'], PHP_URL_HOST) === 'store.ghosium.com', 'site filter must not leak other hosts');

$titleOnly = ghosium_search('intitle:"Ghosium Search"');
check(count($titleOnly) >= 1, 'intitle query must return title match');
check(str_contains(lower_text((string)$titleOnly[0]['title']), 'ghosium search'), 'intitle result must match title');

$excluded = ghosium_search('ghosium -store');
foreach ($excluded as $result) {
    check(!str_contains(lower_text((string)$result['title']), 'store'), 'excluded term must not appear in result title');
}

$bang = resolve_ghosium_bang('chromium !gh');
check(is_array($bang), 'known bang must resolve');
check($bang['bang'] === 'gh', 'GitHub bang shortcut must resolve as gh');
check($bang['query'] === 'chromium', 'bang must be removed from external query');
check(str_starts_with((string)$bang['url'], 'https://github.com/search?'), 'bang destination must use curated HTTPS origin');
check(resolve_ghosium_bang('privacy !unknown') === null, 'unknown bang must remain an ordinary Ghosium query');

$stats = ghosium_search_stats();
check((int)$stats['pages'] >= 3, 'index statistics must count bundled pages');
check((int)$stats['domains'] >= 3, 'index statistics must count distinct bundled domains');

$diversified = diversify_results([
    ['url' => 'https://a.example/1'],
    ['url' => 'https://a.example/2'],
    ['url' => 'https://a.example/3'],
    ['url' => 'https://b.example/1'],
], 3, 1);
check(count($diversified) === 3, 'diversifier must still fill requested result count');
check(parse_url((string)$diversified[0]['url'], PHP_URL_HOST) === 'a.example', 'first ranked result must remain first');
check(parse_url((string)$diversified[1]['url'], PHP_URL_HOST) === 'b.example', 'host diversity must promote another domain before deferred duplicates');

echo "Ghosium Search contract: OK\n";
