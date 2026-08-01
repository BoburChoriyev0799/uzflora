// Admin > Kuzatuvlar sahifasidagi "O'simlik nomi" filtr maydoniga
// saytda mavjud .plant-autocomplete mexanizmini (pages/plant_autocomplete.js,
// active_admin.js'da ham require qilingan) ulaydi. Boshqa yozma qidiruv
// mantig'i yo'q — faqat filtr input'ini kerakli markup bilan o'raymiz,
// qolganini mavjud delegated handlerlar bajaradi.
//
// Aniq filtr input id'i bo'yicha ishlaydi, shuning uchun boshqa admin
// sahifalarida (bu id yo'q joyda) hech narsa qilmaydi.
(function () {
  var FILTER_INPUT_ID = 'q_plant_species_sci_or_plant_species_uz_or_plant_species_ru_cont';
  var AUTOCOMPLETE_URL = '/plant_sightings_autocomplete';
  var NOT_FOUND_TEXT = "Hech narsa topilmadi";

  function init() {
    var $input = $('#' + FILTER_INPUT_ID);
    if (!$input.length || $input.parent().hasClass('plant-autocomplete')) { return; }

    $input.attr('autocomplete', 'off').addClass('plant-autocomplete-input');
    $input.wrap(
      $('<div class="plant-autocomplete"></div>')
        .attr('data-url', AUTOCOMPLETE_URL)
        .attr('data-not-found', NOT_FOUND_TEXT)
    );
    $input.after('<ul class="plant-autocomplete-list"></ul>');
  }

  $(init);
})();
