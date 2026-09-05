// O'simlik nomi maydonlari uchun jonli qidiruv (autocomplete) —
// ".plant-autocomplete" konteyneri joylashgan istalgan sahifada ishlaydi
// (masalan "O'simlik" bosqichi edit_plant, va plants#index qidiruvi).
// Konteyner topilmagan sahifalarga ta'sir qilmaydi — application.js
// barcha sahifalarda yuklanadi (require_tree ./pages).
//
// document'ga bog'langan (delegated) va nomlangan (.plantAutocomplete)
// handlerlar ishlatiladi — navbar_locale_dropdown.js/donation_page.js
// bilan bir xil uslub (Turbolinks har sahifa yuklashda skriptni qayta
// ishga tushiradi, .off()+.on() bilan handler takrorlanib qolmaydi).
(function () {
  var DEBOUNCE_MS = 280;
  var MIN_CHARS = 2;

  function closeList($wrap) {
    $wrap.removeClass('open').find('.plant-autocomplete-list').empty();
  }

  function renderResults($wrap, plants) {
    var $list = $wrap.find('.plant-autocomplete-list').empty();

    if (!plants.length) {
      var notFoundText = $wrap.data('notFound');
      if (notFoundText) {
        $('<li class="plant-autocomplete-empty"></li>').text(notFoundText).appendTo($list);
      }
      $wrap.addClass('open');
      return;
    }

    plants.forEach(function (plant) {
      var label = plant.sci;
      if (plant.secondary) {
        label += ' (' + plant.secondary + ')';
      }
      $('<li></li>')
        .addClass('plant-autocomplete-item')
        .attr('data-id', plant.id)
        .attr('data-sci', plant.sci)
        .attr('data-selected-text', plant.selected_text)
        .text(label)
        .appendTo($list);
    });

    $wrap.addClass('open');
  }

  function selectPlant($wrap, $item) {
    var id = $item.data('id');
    if (!id) { return; }

    $wrap.find('.plant-autocomplete-input').val($item.data('sci'));
    closeList($wrap);

    // "O'simlik" bosqichi (edit_plant): tanlangan turni yon matn va
    // hidden plant_id maydoniga yozib qo'yamiz, forma avtomatik
    // yuborilmaydi ("Qidirish" tugmasi bosilishini kutadi).
    var $container = $wrap.closest('.add-plant-container');
    if ($container.length) {
      $container.find('span.selected-plant').text($item.data('selectedText'));
      $container.find('#plant_sighting_plant_id').val(id);
      return;
    }

    // Jamoaviy aniqlash — "Tur taklif qilish" vidjeti (bir sahifada bir
    // nechta vidjet bo'lishi mumkin — kuzatuv sahifasida bitta, moderatsiya
    // navbatida har kartada bittadan). plant_sighting_identifications.js
    // "Taklif qilish" tugmasi bosilganda shu hidden maydondagi qiymatni
    // yuboradi.
    //
    // MUHIM: bu tekshiruv pastdagi `.moderation-card`dan OLDIN turishi
    // SHART. pending.html.haml'da vidjet `.moderation-card` ICHIDA
    // render qilinadi (ekspertning "Biriktirish" formasi bilan bir xil
    // kartada) — shuning uchun vidjet ichidagi autokomplitning
    // `.closest('.moderation-card')`i ham HAQIQIY, TOPILADIGAN natija
    // beradi. Avval o'sha tekshiruv turgani uchun tanlangan tur HAR
    // DOIM (kuzatuv sahifasida ham, moderatsiyada ham) ekspertning
    // "Biriktirish" maydoniga yozilib, "Taklif qilish" tugmasi hech
    // qachon yoqilmas edi (bug: tugma bosilganda hech narsa bo'lmasdi).
    var $widget = $wrap.closest('.identifications-widget');
    if ($widget.length) {
      $widget.find('.identification-plant-id').val(id);
      $widget.find('.identification-propose-btn').prop('disabled', false);
      return;
    }

    // Ekspert moderatsiya navbati (pending.html.haml): bir sahifada bir
    // nechta karta bo'lgani uchun ID emas, shu kartaga xos class'lar
    // orqali ishlaymiz — moderate_plant_sightings.js "Biriktirish"
    // tugmasi bosilganda shu hidden maydondagi qiymatni yuboradi.
    var $card = $wrap.closest('.moderation-card');
    if ($card.length) {
      $card.find('.moderation-plant-id').val(id);
      $card.find('.moderation-assign-plant').prop('disabled', false);
      $card.find('.moderation-assign-feedback').text('');
      return;
    }

    // Boshqa sahifalar (masalan o'simliklar ro'yxati qidiruvi): tanlash
    // bilanoq mavjud qidiruv formasi (GET) yuboriladi — data-auto-submit
    // belgilangan bo'lsagina.
    if ($wrap.data('autoSubmit')) {
      $wrap.closest('form').trigger('submit');
    }
  }

  $(document)
    .off('input.plantAutocomplete')
    .on('input.plantAutocomplete', '.plant-autocomplete-input', function () {
      var $input = $(this);
      var $wrap = $input.closest('.plant-autocomplete');
      var text = $.trim($input.val());

      clearTimeout($wrap.data('plantAutocompleteTimer'));

      if (text.length < MIN_CHARS) {
        var runningXhr = $wrap.data('plantAutocompleteXhr');
        if (runningXhr) { runningXhr.abort(); }
        closeList($wrap);
        return;
      }

      var timer = setTimeout(function () {
        var prevXhr = $wrap.data('plantAutocompleteXhr');
        if (prevXhr) { prevXhr.abort(); }

        var xhr = $.ajax({
          url: $wrap.data('url'),
          method: 'GET',
          dataType: 'json',
          data: { text: text }
        }).done(function (plants) {
          renderResults($wrap, plants);
        });

        $wrap.data('plantAutocompleteXhr', xhr);
      }, DEBOUNCE_MS);

      $wrap.data('plantAutocompleteTimer', timer);
    })
    .off('keydown.plantAutocomplete')
    .on('keydown.plantAutocomplete', '.plant-autocomplete-input', function (e) {
      var $input = $(this);
      var $wrap = $input.closest('.plant-autocomplete');
      var $items = $wrap.find('.plant-autocomplete-item');

      if (e.which === 27) { // Esc
        closeList($wrap);
        return;
      }

      if (!$wrap.hasClass('open') || !$items.length) { return; }

      var $active = $items.filter('.active');
      var index = $items.index($active);

      if (e.which === 40) { // Arrow down
        e.preventDefault();
        index = (index + 1) % $items.length;
        $items.removeClass('active').eq(index).addClass('active');
      } else if (e.which === 38) { // Arrow up
        e.preventDefault();
        index = index <= 0 ? $items.length - 1 : index - 1;
        $items.removeClass('active').eq(index).addClass('active');
      } else if (e.which === 13) { // Enter
        if ($active.length) {
          e.preventDefault();
          selectPlant($wrap, $active);
        }
      }
    })
    .off('click.plantAutocomplete')
    .on('click.plantAutocomplete', '.plant-autocomplete-item', function (e) {
      e.preventDefault();
      selectPlant($(this).closest('.plant-autocomplete'), $(this));
    })
    .off('click.plantAutocompleteOutside')
    .on('click.plantAutocompleteOutside', function (e) {
      if (!$(e.target).closest('.plant-autocomplete').length) {
        $('.plant-autocomplete.open').each(function () {
          closeList($(this));
        });
      }
    });
})();
