// 1-ish: kuzatuvni to'liq tahrirlash sahifasi.
// Rasm oldindan ko'rish/siqish (`#plant_sighting_photo` change) va
// xaritaga nuqta qo'yish — mavjud `add_plant_sighting.js` / `plant_map.js`
// orqali (`.add-photo-container` / `#map_canvas` selektorlari bir xil,
// bu sahifada QAYTADAN yozilmagan). Bu fayl FAQAT shu sahifaga xos: rasm
// almashtirilganda (aniqlashlar mavjud bo'lsa) tasdiqlash so'rovi.
$(function () {
    var $form = $('#full-edit-form');
    if ($form.length === 0) {
        return;
    }

    var photoChanged = false;

    $form.on('change', '#plant_sighting_photo', function () {
        photoChanged = this.files && this.files.length > 0;
    });

    $form.on('submit', function (event) {
        var hasIdentifications = $form.data('hasIdentifications');
        if (!photoChanged || !hasIdentifications) {
            return;
        }

        var message = $form.data('confirmPhotoReplace');
        if (message && !window.confirm(message)) {
            event.preventDefault();
        }
    });
});
