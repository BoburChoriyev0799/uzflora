// Ekspert moderatsiyasi (pending.html.haml, 2b-bosqich) — har kartadagi
// "AI bilan aniqlash" tugmasi. moderate_plant_sightings.js'даgi mavjud
// tugmalar (Biriktirish/Tasdiqlash/Rad etish) bilan bir xil URL/ID
// naqshini ishlatadi (`$('#sighting-' + id)`), lekin MUSTAQIL fayl —
// mavjud fayl(lar)ga tegilmadi.
//
// document'ga bog'langan (delegated) handlerlar ishlatiladi
// (plant_autocomplete.js/navbar_locale_dropdown.js bilan bir xil
// uslub) — Turbolinks sahifani almashtirsa ham, yangi kartalarda ham
// ishlayveradi (moderate_plant_sightings.js'даgi `$list.on(...)`
// birinchi to'liq yuklanishda ANIQLANGAN `$list` obyektiga bog'langan —
// bu yerda takrorlanmaydi).
//
// Bir nechta karta bo'lsa chalkashmasligi uchun: har amal `data-id`
// orqali FAQAT o'sha kartani (`#sighting-<id>`) topadi va shu karta
// ichidagi (`.find(...)`) elementlar bilan ishlaydi.
$(document).on('click', '.moderation-identify-btn', function (event) {
    event.preventDefault();
    var $btn = $(this);
    var id = $btn.data('id');
    var $card = $('#sighting-' + id);
    var $status = $card.find('.moderation-identify-status');
    var $results = $card.find('.moderation-identify-results');

    $results.empty();
    $status.show();
    $btn.prop('disabled', true);

    $.ajax({
        url: '/plant_sightings/' + id + '/identify',
        type: 'POST',
        dataType: 'json'
    }).done(function (data) {
        $status.hide();
        $btn.prop('disabled', false);
        $results.html(data.html);
    }).fail(function () {
        $status.hide();
        $btn.prop('disabled', false);
        $results.text($results.data('error-generic'));
    });
});

// "Tanlash" — mavjud avtokomplitdan tanlashning (plant_autocomplete.js,
// `.moderation-card` bo'limi) bir xil natijasini beradi: qidiruv
// maydonini, hidden plant_id'ni to'ldiradi va "Biriktirish"ni yoqadi.
// Ekspert baribir "Biriktirish"ni QO'LDA bosishi kerak — bu yerda
// assign_plant chaqirilmaydi (inson nazorati saqlanadi).
$(document).on('click', '.moderation-identify-select-btn', function () {
    var $btn = $(this);
    var plantId = $btn.data('plantId');
    if (!plantId) {
        return;
    }

    var $card = $btn.closest('.moderation-card');
    $card.find('.plant-autocomplete-input').val($btn.data('sci'));
    $card.find('.moderation-plant-id').val(plantId);
    $card.find('.moderation-assign-plant').prop('disabled', false);
    $card.find('.moderation-assign-feedback').text('');
});
