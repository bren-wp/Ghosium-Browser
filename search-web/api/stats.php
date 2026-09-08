<?php
declare(strict_types=1);

require_once __DIR__ . '/../inc/search.php';
rate_limit_or_fail();
json_response(['status' => 'ok', 'index' => ghosium_search_stats()]);
