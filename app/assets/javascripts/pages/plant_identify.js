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
// elementga bog'langan handler shu holatda ESKI, endi hujjatdan olib
// tashlangan DOM elementiga bog'langan bo'lib qolar edi. Delegatsiya
// har doim JORIY elementni topadi.
//
// Ikkita fayl input bor ("Rasmga olish" — capture="environment", va
// "Rasm tanlash" — oddiy) — ikkalasi ham `.plant-identify-file-input`
// klassiga ega, shuning uchun BITTA delegated handler ikkalasini ham
// ushlaydi. Ikkalasi ham `name="image"` bo'lgani uchun (mos autofill/
// forma semantikasi uchun), FormData'ni BUTUN FORMADAN ("new
// FormData(form)") EMAS, faqat AYNAN TANLANGAN faylning o'zidan qo'lda
// yasaymiz — aks holda ikkinchi (bo'sh) input ham FormData'ga o'z
// "image" yozuvini qo'shib, qaysi biri serverga ketishini DOM tartibiga
// bog'liq qilib qo'yardi.
$(document).on('change', '.plant-identify-file-input', function () {
    var input = this;
    var photo = input.files[0];
    if (!photo) {
        return;
    }

    uzfloraCompressSightingPhoto(photo, function (processedFile) {
        submitPlantIdentifyForm(processedFile);
        // Xuddi shu faylni qayta tansa ham `change` qayta ishga tushishi
        // uchun (brauzer bir xil qiymatda hodisani takrorlamaydi).
        input.value = '';
    });
});

// Xavfsizlik uchun: agar forma boshqa yo'l bilan (masalan Enter
// tugmasi) haqiqatan submit qilinsa ham — sahifa to'liq qayta
// yuklanmasin (native submit 406/HTML sahifaga olib borar edi).
$(document).on('submit', '#plant-identify-form', function (event) {
    event.preventDefault();
});

function submitPlantIdentifyForm(file) {
    var $form = $('#plant-identify-form');
    var $status = $('.plant-identify-status');
    var $results = $('#plant-identify-results');

    $results.empty();
    $status.show();

    var formData = new FormData();
    formData.append('authenticity_token', $form.find('input[name="authenticity_token"]').val());
    formData.append('image', file, file.name);

    $.ajax({
        url: $form.attr('action'),
        type: 'POST',
        data: formData,
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
