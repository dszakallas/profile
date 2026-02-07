(async function() {
  var STORAGE_KEY = 'snowfall-enabled';

  // Import shared winter utility
  const { isWinter } = await import('/assets/js/winter-utils.js');

  function getStoredValue() {
    if (!isWinter()) {
      return false;
    }
    try {
      return localStorage.getItem(STORAGE_KEY) === 'true';
    } catch (e) {
      return false;
    }
  }

  function setStoredValue(value) {
    try {
      localStorage.setItem(STORAGE_KEY, value ? 'true' : 'false');
    } catch (e) {}
  }

  function setButtonState(enabled) {
    var button = document.querySelector('.js-snow-toggle');
    if (!button) {
      return;
    }
    button.dataset.snowState = enabled ? 'on' : 'off';
    button.setAttribute('aria-label', 'Snowfall: ' + (enabled ? 'on' : 'off'));
  }

  function setButtonVisibility(visible) {
    var button = document.querySelector('.js-snow-toggle');
    if (!button) {
      return;
    }
    button.style.display = visible ? '' : 'none';
  }

  function applySnowState(enabled) {
    setButtonState(enabled);
    if (window.__snow && typeof window.__snow.start === 'function' && typeof window.__snow.stop === 'function') {
      enabled ? window.__snow.start() : window.__snow.stop();
    }
  }

  function bindToggle() {
    var button = document.querySelector('.js-snow-toggle');
    if (!button) {
      return;
    }
    button.addEventListener('click', function() {
      if (!isWinter()) {
        return; // Prevent toggling if not winter
      }
      var next = !getStoredValue();
      setStoredValue(next);
      applySnowState(next);
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    // Show/hide button based on winter season
    setButtonVisibility(isWinter());

    var enabled = getStoredValue();
    applySnowState(enabled);
    bindToggle();
  });
})();
