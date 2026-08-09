// Navbar xabarnoma qo'ng'irog'i — xuddi navbar_locale_dropdown.js kabi,
// Bootstrap'ning data-api'siga TAYANMAYDI (o'sha faylda tushuntirilgan
// production muammosi tufayli), mustaqil jQuery bilan yozilgan va
// document'ga bog'langan (Turbolinks-xavfsiz).
//
// DESKTOPDA: bosilganda dropdown ochiladi, oxirgi xabarlar AJAX orqali
// yuklanadi (navbar har sahifada render bo'lgani uchun bu ro'yxat
// oldindan navbar HTML'ining o'zida YO'Q — faqat bosilganda so'raladi).
// MOBILDA (767px va pastda): oddiy havola sifatida ishlaydi, to'g'ridan
// -to'g'ri /notifications sahifasiga o'tadi — mobil hamburger ichida
// position:absolute dropdown avval (navbar-locale-dropdown'da) ishonchsiz
// ishlagani hujjatlashtirilgan, shu sababli bu yerda takrorlanmaydi.
(function () {
  function isDesktop() {
    return window.matchMedia('(min-width: 768px)').matches;
  }

  function loadRecent($dropdown) {
    var $list = $dropdown.find('.navbar-notifications-list');
    $list.html('<li class="navbar-notifications-loading">' + $list.data('loadingText') + '</li>');
    $.ajax({ url: '/notifications/recent', type: 'GET', dataType: 'script' });
  }

  $(document)
    .off('click.notificationsDropdown')
    .on('click.notificationsDropdown', '.navbar-notifications-dropdown > .nav-bell-lnk', function (e) {
      if (!isDesktop()) {
        return;
      }
      e.preventDefault();
      e.stopPropagation();

      var $dropdown = $(this).closest('.navbar-notifications-dropdown');
      var wasOpen = $dropdown.hasClass('open');

      $('.navbar-notifications-dropdown').removeClass('open');
      // Til dropdown'i ochiq bo'lsa ham yopamiz — ikkalasi bir vaqtda
      // ochiq turmasin (navbar_locale_dropdown.js'ning o'ziga tegmasdan).
      $('.navbar-locale-dropdown').removeClass('open');

      if (!wasOpen) {
        $dropdown.addClass('open');
        loadRecent($dropdown);
      }
    })
    .off('click.notificationsDropdownClose')
    .on('click.notificationsDropdownClose', function () {
      $('.navbar-notifications-dropdown').removeClass('open');
    })
    .off('click.notificationsDropdownMenu')
    .on('click.notificationsDropdownMenu', '.navbar-notifications-menu', function (e) {
      e.stopPropagation();
    });
})();
