(function() {
  var STORAGE_KEY = 'theme-preference';
  var THEMES = ['system', 'dark', 'light'];
  var labelMap = {
    system: 'System',
    dark: 'Dark',
    light: 'Light'
  };

  function getStoredPreference() {
    try {
      var value = localStorage.getItem(STORAGE_KEY);
      return THEMES.indexOf(value) >= 0 ? value : 'system';
    } catch (e) {
      return 'system';
    }
  }

  function setStoredPreference(value) {
    try {
      localStorage.setItem(STORAGE_KEY, value);
    } catch (e) {}
  }

  function getSystemTheme() {
    if (window.matchMedia) {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return 'light';
  }

  function getEffectiveTheme(preference) {
    return preference === 'system' ? getSystemTheme() : preference;
  }

  function applyTheme(preference) {
    var effective = getEffectiveTheme(preference);
    var link = document.getElementById('theme-css');
    if (link) {
      link.href = effective === 'dark' ? link.dataset.themeDark : link.dataset.themeLight;
    }
    document.documentElement.dataset.theme = effective;
    document.documentElement.dataset.themePreference = preference;
    updateToggleButton(preference);
  }

  function updateToggleButton(preference) {
    var button = document.querySelector('.js-theme-toggle');
    if (!button) {
      return;
    }
    var label = labelMap[preference] || 'System';
    button.dataset.themeState = preference;
    button.setAttribute('aria-label', 'Theme: ' + preference);
    var labelNode = button.querySelector('.theme-toggle__label');
    if (labelNode) {
      labelNode.textContent = label;
    }
  }

  function getNextPreference(current) {
    var index = THEMES.indexOf(current);
    var nextIndex = index >= 0 ? (index + 1) % THEMES.length : 0;
    return THEMES[nextIndex];
  }

  function bindToggle() {
    var button = document.querySelector('.js-theme-toggle');
    if (!button) {
      return;
    }
    button.addEventListener('click', function() {
      var current = document.documentElement.dataset.themePreference || 'system';
      var next = getNextPreference(current);
      setStoredPreference(next);
      applyTheme(next);
    });
  }

  function bindSystemListener() {
    if (!window.matchMedia) {
      return;
    }
    var media = window.matchMedia('(prefers-color-scheme: dark)');
    var handler = function() {
      var preference = document.documentElement.dataset.themePreference || 'system';
      if (preference === 'system') {
        applyTheme(preference);
      }
    };
    if (typeof media.addEventListener === 'function') {
      media.addEventListener('change', handler);
    } else if (typeof media.addListener === 'function') {
      media.addListener(handler);
    }
  }

  document.addEventListener('DOMContentLoaded', function() {
    var preference = getStoredPreference();
    applyTheme(preference);
    bindToggle();
    bindSystemListener();
  });
})();
