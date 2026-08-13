// "O'simliklar" sahifasi tepasidagi rasm orqali aniqlash bo'limi. Rasm
// tanlangach avtomatik yuboradi (alohida "Yuborish" tugmasi shart emas —
// bu asosan telefondan ishlatiladi, bir marta bosish yetarli bo'lsin).
// Siqish uchun add_plant_sighting.js'даgi uzfloraCompressSightingPhoto
// qayta ishlatiladi (application.js manifestida require_tree orqali
// barcha sahifalarga allaqachon ulangan).
$(function () {
    var $form = $('#plant-identify-form');
    if ($form.length === 0) {
        return;
    }

    var $input = $('#plant-identify-file');
    var $status = $('.plant-identify-status');
    var $results = $('#plant-identify-results');

    function submitIdentifyForm() {
        $results.empty();
        $status.show();
        $form.trigger('submit');
    }

    $input.on('change', function () {
        var photo = $input[0].files[0];
        if (!photo) {
            return;
        }

        uzfloraCompressSightingPhoto(photo, function (processedFile) {
            if (processedFile !== photo && typeof window.DataTransfer === 'function') {
                try {
                    var dataTransfer = new DataTransfer();
                    dataTransfer.items.add(processedFile);
                    $input[0].files = dataTransfer.files;
                } catch (e) {
                    // DataTransfer bilan almashtirib bo'lmadi — asl fayl
                    // (inputda allaqachon turgan) o'zgarishsiz yuboriladi.
                }
            }

            submitIdentifyForm();
        });
    });

    $form.on('ajax:error', function () {
        $status.hide();
        $results.text($results.data('error-generic'));
    });
});
