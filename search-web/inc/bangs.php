<?php
declare(strict_types=1);

/**
 * Explicit external shortcuts for Ghosium Search.
 *
 * A bang is never used unless the user types it. The resulting query is sent
 * directly to the selected third-party site, so this is intentionally separate
 * from ordinary private Ghosium Search requests.
 */
function ghosium_bang_catalog(): array
{
    return [
        'w' => [
            'name' => 'Wikipedia',
            'url' => 'https://en.wikipedia.org/w/index.php?search=%s',
        ],
        'wiki' => [
            'name' => 'Wikipedia',
            'url' => 'https://en.wikipedia.org/w/index.php?search=%s',
        ],
        'gh' => [
            'name' => 'GitHub',
            'url' => 'https://github.com/search?q=%s',
        ],
        'yt' => [
            'name' => 'YouTube',
            'url' => 'https://www.youtube.com/results?search_query=%s',
        ],
        'r' => [
            'name' => 'Reddit',
            'url' => 'https://www.reddit.com/search/?q=%s',
        ],
        'mdn' => [
            'name' => 'MDN Web Docs',
            'url' => 'https://developer.mozilla.org/en-US/search?q=%s',
        ],
        'so' => [
            'name' => 'Stack Overflow',
            'url' => 'https://stackoverflow.com/search?q=%s',
        ],
    ];
}

function resolve_ghosium_bang(string $query): ?array
{
    $query = normalize_query($query);
    if ($query === '') {
        return null;
    }

    // Support both "!gh chromium" and "chromium !gh". Only one bang is
    // consumed; an unknown bang stays an ordinary Ghosium Search query.
    if (!preg_match('/(?:^|\s)!([a-z0-9_-]{1,16})(?:\s|$)/i', $query, $match, PREG_OFFSET_CAPTURE)) {
        return null;
    }

    $shortcut = lower_text((string)$match[1][0]);
    $catalog = ghosium_bang_catalog();
    if (!isset($catalog[$shortcut])) {
        return null;
    }

    $fullMatch = (string)$match[0][0];
    $offset = (int)$match[0][1];
    $before = substr($query, 0, $offset);
    $after = substr($query, $offset + strlen($fullMatch));
    $search = normalize_query(trim($before . ' ' . $after));
    if ($search === '') {
        return null;
    }

    $entry = $catalog[$shortcut];
    return [
        'bang' => $shortcut,
        'name' => (string)$entry['name'],
        'query' => $search,
        'url' => sprintf((string)$entry['url'], rawurlencode($search)),
    ];
}
