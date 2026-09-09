const defaults = Object.freeze({
  accent: 'mint',
  compactMode: false,
  showTopNav: true,
  showStatus: true,
  reduceEffects: false,
});

let state = {...defaults};

function normalize(settings) {
  return {
    accent: ['mint', 'violet', 'blue'].includes(settings.accent) ? settings.accent : defaults.accent,
    compactMode: settings.compactMode === true,
    showTopNav: settings.showTopNav !== false,
    showStatus: settings.showStatus !== false,
    reduceEffects: settings.reduceEffects === true,
  };
}

function apply(settings) {
  state = normalize(settings);
  document.body.dataset.accent = state.accent;
  document.body.classList.toggle('compact-mode', state.compactMode);
  document.body.classList.toggle('reduce-effects', state.reduceEffects);

  const nav = document.querySelector('.product-nav');
  const status = document.querySelector('.status');
  if (nav) nav.hidden = !state.showTopNav;
  if (status) status.hidden = !state.showStatus;
}

async function initialize() {
  try {
    apply(await chrome.storage.local.get(defaults));
  } catch (error) {
    console.error('Unable to load local Ghosium New Tab settings.', error);
    apply(defaults);
  }
}

chrome.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== 'local') return;
  const next = {...state};
  for (const key of Object.keys(defaults)) {
    if (changes[key]) next[key] = changes[key].newValue;
  }
  apply(next);
});

void initialize();
