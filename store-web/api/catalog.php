<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/store.php';

header('Access-Control-Allow-Origin: https://store.ghosium.com');
header('Vary: Origin');

try {
    $catalog = store_load_catalog(false);
    $revocations = store_load_revocations();
    // Public catalog output includes revocation-sensitive state. Keep its cache
    // lifetime aligned with revocation/key metadata rather than the generic API default.
    store_json_response(store_public_catalog($catalog, $revocations), 200, 'public, max-age=60, must-revalidate');
} catch (Throwable) {
    store_public_error();
}
