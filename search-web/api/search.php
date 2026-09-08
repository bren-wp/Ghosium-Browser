<?php
declare(strict_types=1);

require_once __DIR__ . '/../inc/search.php';
require_once __DIR__ . '/../inc/bangs.php';
rate_limit_or_fail();

$query = normalize_query((string)($_GET['q'] ?? ''));
if ($query === '') {
    json_response([
        'query' => '',
        'parsed' => parse_search_query(''),
        'bang' => null,
        'results' => [],
    ]);
}

$bang = resolve_ghosium_bang($query);
if (is_array($bang)) {
    // API clients choose whether to leave Ghosium Search. The API never follows
    // an external shortcut itself.
    json_response([
        'query' => $query,
        'parsed' => parse_search_query($query),
        'bang' => $bang,
        'results' => [],
    ]);
}

json_response([
    'query' => $query,
    'parsed' => parse_search_query($query),
    'bang' => null,
    'results' => ghosium_search($query),
]);
