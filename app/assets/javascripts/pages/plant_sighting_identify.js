// "O'simlik" bosqichi (edit_plant.html.haml) — kuzatuv rasmini PlantNet
// orqali AI bilan aniqlash. plants/index.html.haml'даgi plant_identify.js
// bilan bir xil naqsh (JSON javob, Turbolinks-xavfsiz delegatsiya) —
// lekin BUTUNLAY MUSTAQIL fayl: bu yerda YANGI rasm yuklanmaydi,
// ALLAQACHON R2'da saqlangan kuzatuv rasmi identifikatsiya qilinadi, va
// natijada "Tanlash" tugmasi ham bor (mavjud tur/hidden plant_id
// maydonini avtomatik saqlamasdan to'ldiradi).
$(document).on('click', '#sighting-identify-btn', function () {
    var $btn = $(this);
    var $status = $('.sighting-identify-status');
    var $results = $('#sighting-identify-results');

    $results.empty();
    $status.show();
    $btn.prop('disabled', true);

    $.ajax({
        url: $btn.data('url'),
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

// "Tanlash" — mavjud plant_autocomplete.js'ning `.add-plant-container`
// uchun yozgan naqshi bilan bir xil: yon matn va hidden plant_id
// maydonini to'ldiradi, forma AVTOMATIK yuborilmaydi ("Nashr qilish"
// tugmasi bosilishini kutadi).
$(document).on('click', '.sighting-identify-select-btn', function () {
    var $btn = $(this);
    var id = $btn.data('plantId');
    if (!id) {
        return;
    }

    $('.add-plant-container span.selected-plant').text($btn.data('selectedText'));
    $('.add-plant-container #plant_sighting_plant_id').val(id);
});
