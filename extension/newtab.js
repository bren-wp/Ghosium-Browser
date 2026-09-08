const defaults = Object.freeze({
  accent: 'mint',
  compactMode: false,
  showTopNav: true,
  showStatus: true,
  reduceEffects: false,
});

function apply(settings) {
  const accent = ['mint', 'violet', 'blue'].includes(settings.accent) ? settings.accent : defaults.accent;
  document.body.dataset.accent = accent;
  document.body.classList.toggle('compact-mode', settings.compactMode === true);
  document.body.classList.toggle('reduce-effects', settings.reduceEffects === true);

  const nav = document.querySelector('.product-nav');
  const status = document.querySelector('.status');
  if (nav) nav.hidden = settings.showTopNav === false;
  if (status) status.hidden = settings.showStatus === false;
}

chrome.storage.local.get(defaults).then(apply);
chrome.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== 'local') return;
  chrome.storage.local.get(defaults).then(apply);
});
