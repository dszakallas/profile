(function() {
  // Menu toggle functionality for mobile header
  
  function bindMenuToggle() {
    var menuToggle = document.querySelector('.js-menu-toggle');
    var navigation = document.getElementById('header-navigation');
    var menuContainer = document.querySelector('.header__menu-container');
    
    if (!menuToggle || !navigation) {
      return;
    }
    
    // Toggle menu on button click
    menuToggle.addEventListener('click', function(e) {
      e.stopPropagation();
      var isOpen = navigation.classList.contains('navigation--open');
      if (isOpen) {
        closeMenu();
      } else {
        openMenu();
      }
    });
    
    // Close menu when a navigation link is clicked
    var navLinks = navigation.querySelectorAll('a');
    navLinks.forEach(function(link) {
      link.addEventListener('click', function(e) {
        closeMenu();
      });
    });
    
    // Close menu when clicking outside (but not on menu container or toggle button)
    document.addEventListener('click', function(e) {
      var isClickOnToggle = menuToggle.contains(e.target);
      var isClickOnMenu = menuContainer && menuContainer.contains(e.target);
      
      if (!isClickOnToggle && !isClickOnMenu && navigation.classList.contains('navigation--open')) {
        closeMenu();
      }
    });
    
    // Close menu when user scrolls
    window.addEventListener('scroll', function() {
      if (navigation.classList.contains('navigation--open')) {
        closeMenu();
      }
    }, { passive: true });
  }
  
  function openMenu() {
    var menuToggle = document.querySelector('.js-menu-toggle');
    var navigation = document.getElementById('header-navigation');
    
    navigation.classList.add('navigation--open');
    menuToggle.setAttribute('aria-expanded', 'true');
  }
  
  function closeMenu() {
    var menuToggle = document.querySelector('.js-menu-toggle');
    var navigation = document.getElementById('header-navigation');
    
    navigation.classList.remove('navigation--open');
    menuToggle.setAttribute('aria-expanded', 'false');
  }
  
  document.addEventListener('DOMContentLoaded', function() {
    bindMenuToggle();
  });
})();
