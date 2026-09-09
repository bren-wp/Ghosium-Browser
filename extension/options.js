const defaults = Object.freeze({
  accent: 'mint',
  compactMode: false,
  showTopNav: true,
  showStatus: true,
  reduceEffects: false,
});

const ids = Object.keys(defaults);
const saveState = document.querySelector('#saveState');
let saveTimer = 0;

function requireElement(selector) {
  const element = document.querySelector(selector);
  if (!element) throw new Error(`Missing required Ghosium options control: ${selector}`);
  return element;
}

function normalize(settings) {
  return {
    accent: ['mint', 'violet', 'blue'].includes(settings.accent) ? settings.accent : defaults.accent,
    compactMode: settings.compactMode === true,
    showTopNav: settings.showTopNav !== false,
    showStatus: settings.showStatus !== false,
    reduceEffects: settings.reduceEffects === true,
  };
}

function render(settings) {
  const normalized = normalize(settings);
  requireElement('#accent').value = normalized.accent;
  requireElement('#compactMode').checked = normalized.compactMode;
  requireElement('#showTopNav').checked = normalized.showTopNav;
  requireElement('#showStatus').checked = normalized.showStatus;
  requireElement('#reduceEffects').checked = normalized.reduceEffects;
}

function collect() {
  return {
    accent: requireElement('#accent').value,
    compactMode: requireElement('#compactMode').checked,
    showTopNav: requireElement('#showTopNav').checked,
    showStatus: requireElement('#showStatus').checked,
    reduceEffects: requireElement('#reduceEffects').checked,
  };
}

function setStatus(message) {
  if (saveState) saveState.textContent = message;
}

async function save() {
  try {
    await chrome.storage.local.set(normalize(collect()));
    setStatus('Saved locally');
    window.clearTimeout(saveTimer);
    saveTimer = window.setTimeout(() => setStatus('Up to date'), 1200);
  } catch (error) {
    console.error('Unable to save local Ghosium settings.', error);
    setStatus('Unable to save');
  }
}

for (const id of ids) {
  requireElement(`#${id}`).addEventListener('change', () => void save());
}

requireElement('#reset').addEventListener('click', async () => {
  try {
    await chrome.storage.local.set(defaults);
    render(defaults);
    setStatus('Defaults restored');
  } catch (error) {
    console.error('Unable to restore Ghosium defaults.', error);
    setStatus('Unable to restore defaults');
  }
});

chrome.storage.local.get(defaults).then(render).catch((error) => {
  console.error('Unable to load Ghosium options.', error);
  render(defaults);
  setStatus('Using local defaults');
});
