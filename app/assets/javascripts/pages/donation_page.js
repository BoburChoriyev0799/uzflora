// "Loyihani qo'llab-quvvatlash" sahifasi: tavsiya etilgan summa
// kartochkalari (faqat vizual tanlov — hech qayerga yubormaydi) va karta
// raqamini clipboard'ga nusxalash tugmasi.
//
// navbar_locale_dropdown.js'dagi kabi: document'ga bog'langan delegated
// handler + nomlangan event (.off().on()) ishlatiladi, chunki Turbolinks
// har bir sahifa yuklanishida <script>larni qayta ishga tushiradi va bu
// handler'lar takrorlanib qolmasligini kafolatlaydi.
$(document)
  .off('click.donationAmount')
  .on('click.donationAmount', '.donation-amount-card', function () {
    $(this).siblings('.donation-amount-card').removeClass('selected');
    $(this).addClass('selected');
  })
  .off('click.donationCopy')
  .on('click.donationCopy', '.donation-copy-btn', function () {
    var $btn = $(this);
    var text = $btn.data('clipboardText');
    if (!text) {
      return;
    }

    var showCopied = function () {
      var $confirm = $btn.siblings('.donation-copy-confirm');
      $confirm.addClass('visible');
      clearTimeout($confirm.data('hideTimeout'));
      $confirm.data('hideTimeout', setTimeout(function () {
        $confirm.removeClass('visible');
      }, 1800));
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(String(text)).then(showCopied);
    } else {
      var $tmp = $('<textarea readonly></textarea>')
        .val(text)
        .css({ position: 'fixed', top: '-1000px', left: '-1000px' });
      $('body').append($tmp);
      $tmp[0].select();
      document.execCommand('copy');
      $tmp.remove();
      showCopied();
    }
  });
