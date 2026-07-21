// Navbar til-tanlash dropdown'i — Bootstrap'ning o'z dropdown.js (data-api)
// mexanizmiga TAYANMAYDI: productionda (Render + Cloudflare) sababi aniq
// bo'lmagan holda ishlamay qolgani kuzatildi (lokal sinovda esa ishlagan —
// ehtimol Cloudflare'ning JS'ni kechiktirish/o'zgartirish xususiyati yoki
// Turbolinks bilan bog'liq vaqt muammosi). Shuning uchun mustaqil, oddiy
// jQuery bilan yozilgan.
//
// document'ga bog'langan (delegated) handler ishlatiladi — bu elementning
// o'zi emas, balki document doimiy qolgani uchun Turbolinks sahifa
// almashtirganda ham ishlayveradi. .off() + nomlangan event (.navbarLocaleDropdown)
// esa bu skript har safar (Turbolinks har bir sahifa yuklashda body
// ichidagi <script>larni qayta ishga tushiradi) qayta ishlaganda handler
// TAKRORLANIB qolmasligini kafolatlaydi.
$(document)
  .off('click.navbarLocaleDropdown')
  .on('click.navbarLocaleDropdown', '.navbar-locale-dropdown > .dropdown-toggle', function (e) {
    e.preventDefault();
    e.stopPropagation();

    var $dropdown = $(this).closest('.navbar-locale-dropdown');
    var wasOpen = $dropdown.hasClass('open');

    $('.navbar-locale-dropdown').removeClass('open');

    if (!wasOpen) {
      $dropdown.addClass('open');
    }
  })
  .off('click.navbarLocaleDropdownClose')
  .on('click.navbarLocaleDropdownClose', function () {
    $('.navbar-locale-dropdown').removeClass('open');
  })
  .off('click.navbarLocaleDropdownMenu')
  .on('click.navbarLocaleDropdownMenu', '.navbar-locale-menu', function (e) {
    // Dropdown ichidagi (bo'sh joyga) bosish uni yopib qo'ymasin —
    // faqat haqiqiy til havolasi (<a>) bosilganda sahifa o'zi almashadi.
    e.stopPropagation();
  });
