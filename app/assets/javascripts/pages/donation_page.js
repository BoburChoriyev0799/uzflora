// "Loyihani qo'llab-quvvatlash" sahifasi va uning formasi: summa
// kartochkalari (+ qo'lda kiritish), to'lov usuli tanlovi, izoh
// hisoblagichi va karta raqamini clipboard'ga nusxalash tugmasi (bu
// oxirgisi /donations/thanks sahifasida ham ishlatiladi).
//
// navbar_locale_dropdown.js'dagi kabi: document'ga bog'langan delegated
// handler + nomlangan event (.off().on()) ishlatiladi, chunki Turbolinks
// har bir sahifa yuklanishida <script>larni qayta ishga tushiradi va bu
// handler'lar takrorlanib qolmasligini kafolatlaydi.
$(document)
  .off('click.donationAmount')
  .on('click.donationAmount', '.donation-amount-card', function () {
    var $card = $(this);
    var amount = $card.data('amount');
    var $input = $('#donation_amount');

    $card.siblings('.donation-amount-card').removeClass('selected');
    $card.addClass('selected');

    if (amount !== 'other') {
      $input.val(amount);
    } else {
      $input.trigger('focus');
      $input[0] && $input[0].select && $input[0].select();
    }
  })
  .off('input.donationAmountInput')
  .on('input.donationAmountInput', '#donation_amount', function () {
    var val = String($(this).val());
    var $cards = $('.donation-amount-card');
    var matched = $cards.filter(function () {
      var cardAmount = $(this).data('amount');
      return cardAmount !== 'other' && String(cardAmount) === val;
    });

    $cards.removeClass('selected');
    if (matched.length) {
      matched.addClass('selected');
    } else {
      $cards.filter('[data-amount="other"]').addClass('selected');
    }
  })
  .off('click.donationMethod')
  .on('click.donationMethod', '.donation-method-select-card', function () {
    var $card = $(this);
    $card.siblings('.donation-method-select-card').removeClass('selected');
    $card.addClass('selected');
    $('#donation_payment_method').val($card.data('method'));
  })
  .off('input.donationCommentCount')
  .on('input.donationCommentCount', '#donation_comment', function () {
    var len = $(this).val().length;
    $('#donation-comment-count').text(len + '/100');
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
