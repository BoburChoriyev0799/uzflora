// Kirish / ro'yxatdan o'tish kartasi (shared/_auth_card) — "Ro'yxatdan
// o'tish" / "Kirish" tugmasi bosilganda kartani slayd qiladi
// (.is-register klassi). Tugmalar HAQIQIY havola bo'lgani uchun JS
// o'chirilgan bo'lsa ham ishlaydi (server sahifani to'g'ri holatda
// beradi).
//
// Turbolinks-xavfsiz: hodisa document'ga delegatsiya qilinadi (bir marta
// o'rnatiladi, sahifalar orasida saqlanadi). Karta bo'lmagan sahifalarda
// jim (no-op).
(function () {
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function') {
      return;
    }

    var trigger = target.closest('[data-auth-toggle]');
    if (!trigger) {
      return;
    }

    var card = document.querySelector('.auth-page .auth-card');
    if (!card) {
      return;
    }

    event.preventDefault();

    var toRegister = trigger.getAttribute('data-auth-toggle') === 'register';
    card.classList.toggle('is-register', toRegister);

    var toRegPanel = card.querySelector('.auth-visual-panel--to-register');
    var toLoginPanel = card.querySelector('.auth-visual-panel--to-login');
    if (toRegPanel && toLoginPanel) {
      toRegPanel.classList.toggle('is-hidden', toRegister);
      toLoginPanel.classList.toggle('is-hidden', !toRegister);
    }

    // Manzil satrini yangilaymiz — sahifa yangilansa to'g'ri Devise
    // sahifasi ochilsin.
    var href = trigger.getAttribute('href');
    if (href && window.history && window.history.replaceState) {
      window.history.replaceState({}, '', href);
    }

    // Aktiv formaning birinchi maydoniga fokus.
    var visibleBox = toRegister
      ? card.querySelector('.auth-form-box--register')
      : card.querySelector('.auth-form-box--login');
    if (visibleBox) {
      var firstInput = visibleBox.querySelector('input:not([type="hidden"])');
      if (firstInput) {
        firstInput.focus();
      }
    }
  });
})();
