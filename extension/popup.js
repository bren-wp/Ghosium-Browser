document.querySelector('#options').addEventListener('click', () => {
  chrome.runtime.openOptionsPage();
});

document.querySelector('#newTab').addEventListener('click', () => {
  chrome.tabs.create({});
});
