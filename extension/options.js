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
  document.querySelector('#accent').value = normalized.accent;
  document.querySelector('#compactMode').checked = normalized.compactMode;
  document.querySelector('#showTopNav').checked = normalized.showTopNav;
  document.querySelector('#showStatus').checked = normalized.showStatus;
  document.querySelector('#reduceEffects').checked = normalized.reduceEffects;
}

function collect() {
  return {
    accent: document.querySelector('#accent').value,
    compactMode: document.querySelector('#compactMode').checked,
    showTopNav: document.querySelector('#showTopNav').checked,
    showStatus: document.querySelector('#showStatus').checked,
    reduceEffects: document.querySelector('#reduceEffects').checked,
  };
}

async function save() {
  const values = normalize(collect());
  await chrome.storage.local.set(values);
  saveState.textContent = 'Saved locally';
  window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    saveState.textContent = 'Up to date';
  }, 1200);
}

for (const id of ids) {
  document.querySelector(`#${id}`).addEventListener('change', save);
}

document.querySelector('#reset').addEventListener('click', async () => {
  await chrome.storage.local.set(defaults);
  render(defaults);
  saveState.textContent = 'Defaults restored';
});

chrome.storage.local.get(defaults).then(render);
