<?php
declare(strict_types=1);

function ghosium_escape(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function ghosium_render_brand(bool $compact = false): void
{
    $class = $compact ? 'brand brand--compact' : 'brand';
    ?>
    <a class="<?= $class ?>" href="/" aria-label="Ghosium Search home">
      <span class="brand__mark" aria-hidden="true">
        <img src="/assets/ghosium-mark.svg" alt="" width="32" height="32">
      </span>
      <span class="brand__wordmark">Ghosium</span>
      <span class="brand__product">Search</span>
    </a>
    <?php
}

function ghosium_render_search_form(string $query = '', bool $compact = false, bool $autofocus = false): void
{
    $class = $compact ? 'search-box search-box--compact' : 'search-box';
    ?>
    <form class="<?= $class ?>" method="get" action="/" role="search">
      <label class="sr-only" for="<?= $compact ? 'q-top' : 'q' ?>">Search the web</label>
      <span class="search-box__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="20" height="20" focusable="false">
          <path d="m20 20-4.35-4.35m2.35-5.15a7.5 7.5 0 1 1-15 0 7.5 7.5 0 0 1 15 0Z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
        </svg>
      </span>
      <input
        id="<?= $compact ? 'q-top' : 'q' ?>"
        name="q"
        type="search"
        value="<?= ghosium_escape($query) ?>"
        autocomplete="off"
        maxlength="180"
        spellcheck="false"
        enterkeyhint="search"
        placeholder="Search the web"
        <?= $autofocus ? 'autofocus' : '' ?>
      >
      <button type="submit" aria-label="Search">
        <svg viewBox="0 0 24 24" width="18" height="18" focusable="false" aria-hidden="true">
          <path d="M5 12h13m-5-5 5 5-5 5" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
    </form>
    <?php
}

/** @param array<string, mixed> $result */
function ghosium_render_result(array $result): void
{
    $url = (string)($result['url'] ?? '');
    $title = (string)($result['title'] ?? '');
    $description = (string)($result['description'] ?? '');
    $host = (string)(parse_url($url, PHP_URL_HOST) ?: '');
    ?>
    <article class="result-card">
      <div class="result-card__source">
        <span class="result-card__source-mark" aria-hidden="true"><?= $host !== '' ? strtoupper(ghosium_escape(substr($host, 0, 1))) : '•' ?></span>
        <span><?= ghosium_escape($host) ?></span>
      </div>
      <h2><a href="<?= ghosium_escape($url) ?>" rel="noopener noreferrer"><?= ghosium_escape($title) ?></a></h2>
      <?php if ($description !== ''): ?>
        <p><?= ghosium_escape($description) ?></p>
      <?php endif; ?>
    </article>
    <?php
}
