// "O'simlik" bosqichidagi (edit_plant) o'simlik nomi maydoni uchun
// jonli qidiruv (autocomplete). Faqat shu sahifada ".plant-autocomplete"
// konteyneri mavjud, shuning uchun boshqa sahifalarga ta'sir qilmaydi —
// application.js barcha sahifalarda yuklanadi (require_tree ./pages).
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

    var $container = $wrap.closest('.add-plant-container');
    $wrap.find('.plant-autocomplete-input').val($item.data('sci'));
    $container.find('span.selected-plant').text($item.data('selectedText'));
    $container.find('#plant_sighting_plant_id').val(id);

    closeList($wrap);
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
