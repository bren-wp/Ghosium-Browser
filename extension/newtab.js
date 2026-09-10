const defaults = Object.freeze({
  accent: 'mint',
  compactMode: false,
  showTopNav: true,
  showStatus: true,
  reduceEffects: false,
});

const settingKeys = Object.freeze(Object.keys(defaults));
const body = document.body;
const nav = document.querySelector('.product-nav');
const status = document.querySelector('.status');
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
  body.dataset.accent = state.accent;
  body.classList.toggle('compact-mode', state.compactMode);
  body.classList.toggle('reduce-effects', state.reduceEffects);

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
  let relevantChange = false;
  for (const key of settingKeys) {
    if (!Object.hasOwn(changes, key)) continue;
    next[key] = changes[key].newValue;
    relevantChange = true;
  }
  if (relevantChange) apply(next);
});

void initialize();
