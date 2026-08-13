// "O'simliklar" sahifasi tepasidagi rasm orqali aniqlash bo'limi.
//
// MUHIM: jquery_ujs'ning "data-remote" (remote: true) mexanizmiga
// TAYANMAYDI. Productionda shu yo'l HTTP 406 ("Not Acceptable") berardi:
// controller `respond_to(&:js)` orqali faqat "text/javascript" formatni
// kutgan, lekin brauzer (yoki forma jquery_ujs tomonidan to'g'ri
// ushlanmagan holatda) so'rovni oddiy "text/html" Accept header bilan
// yuborgan — Rails formatga mos javob topa olmay 406 qaytargan.
// Yechim: `$.ajax` bilan BEVOSITA JSON so'rov (controller ham endi
// har doim `render json:` qaytaradi, Accept header'dan qat'i nazar).
//
// Elementlar DOCUMENT darajasida delegatsiya orqali ushlanadi
// ($(document).on(...)) — bu Turbolinks'ga xavfsiz: application.js
// (shu fayl ichidagi kod) sahifada FAQAT birinchi to'liq yuklanishda
// ishga tushadi, Turbolinks esa keyingi navigatsiyalarda <body>'ni
// almashtiradi (`$(function(){})` qayta ishga tushmaydi). To'g'ridan
// elementga bog'langan handler (`$('#plant-identify-file').on(...)`)
// shu holatda ESKI, endi hujjatdan olib tashlangan DOM elementiga
// bog'langan bo'lib qolar edi — foydalanuvchi rasm tansa ham hech
// narsa sodir bo'lmasdi. Delegatsiya har doim JORIY elementni topadi.
$(document).on('change', '#plant-identify-file', function () {
    var input = this;
    var $form = $(input).closest('form');
    var photo = input.files[0];
    if (!photo) {
        return;
    }

    uzfloraCompressSightingPhoto(photo, function (processedFile) {
        if (processedFile !== photo && typeof window.DataTransfer === 'function') {
            try {
                var dataTransfer = new DataTransfer();
                dataTransfer.items.add(processedFile);
                input.files = dataTransfer.files;
            } catch (e) {
                // DataTransfer bilan almashtirib bo'lmadi — asl fayl
                // (inputda allaqachon turgan) o'zgarishsiz yuboriladi.
            }
        }

        submitPlantIdentifyForm($form);
    });
});

// Xavfsizlik uchun: agar forma boshqa yo'l bilan (masalan Enter
// tugmasi) haqiqatan submit qilinsa ham — sahifa to'liq qayta
// yuklanmasin (native submit 406/HTML sahifaga olib borar edi),
// xuddi shu AJAX yo'li ishlatilsin.
$(document).on('submit', '#plant-identify-form', function (event) {
    event.preventDefault();
    submitPlantIdentifyForm($(this));
});

function submitPlantIdentifyForm($form) {
    var $status = $('.plant-identify-status');
    var $results = $('#plant-identify-results');

    $results.empty();
    $status.show();

    $.ajax({
        url: $form.attr('action'),
        type: 'POST',
        data: new FormData($form[0]),
        processData: false,
        contentType: false,
        dataType: 'json'
    }).done(function (data) {
        $status.hide();
        $results.html(data.html);
    }).fail(function () {
        $status.hide();
        $results.text($results.data('error-generic'));
    });
}
