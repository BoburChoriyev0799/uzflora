// Telefon kamerasidan yuklangan rasmlar (8-10 MB) yuklashdan OLDIN shu
// yerda (brauzerda, canvas orqali) kichraytiriladi/siqiladi — serverga
// kamroq bayt boradi, ProcessSightingImageJob fon jarayoni ham
// yengillashadi. Faqat JPEG uchun (PNG shaffoflik/sifatni yo'qotmasdan
// JPEG'ga aylantirib bo'lmaydi, shuning uchun o'zgarishsiz qoladi).
// Muvaffaqiyatsiz bo'lsa yoki brauzer qo'llab-quvvatlamasa — ASL fayl
// yuklanadi (hech qachon yuklashni buzmaydi).
var SIGHTING_PHOTO_MAX_DIMENSION = 1600;
var SIGHTING_PHOTO_QUALITY = 0.82;

function uzfloraCompressSightingPhoto(file, callback) {
    var isCompressibleImage = file.type === 'image/jpeg' || file.type === 'image/jpg';
    if (!isCompressibleImage || typeof window.createImageBitmap !== 'function' || typeof window.File !== 'function') {
        callback(file);
        return;
    }

    // `imageOrientation: 'from-image'` — telefon rasmlarida keng
    // tarqalgan EXIF orientatsiya (yon/teskari) shu yerda avtomatik
    // to'g'rilanadi, canvas'ga chizishdan OLDIN.
    window.createImageBitmap(file, { imageOrientation: 'from-image' }).then(function(bitmap) {
        var longSide = Math.max(bitmap.width, bitmap.height);
        var scale = Math.min(1, SIGHTING_PHOTO_MAX_DIMENSION / longSide);
        if (scale >= 1) {
            // Rasm allaqachon kichik — qayta siqish shart emas (sifat
            // yo'qotib, hech narsa yutmaymiz).
            callback(file);
            return;
        }

        var canvas = document.createElement('canvas');
        canvas.width = Math.round(bitmap.width * scale);
        canvas.height = Math.round(bitmap.height * scale);
        canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height);

        canvas.toBlob(function(blob) {
            if (!blob) {
                callback(file);
                return;
            }
            callback(new File([blob], file.name.replace(/\.\w+$/, '.jpg'), { type: 'image/jpeg' }));
        }, 'image/jpeg', SIGHTING_PHOTO_QUALITY);
    }).catch(function() {
        callback(file);
    });
}

$(function() {
    //*** Plant sighting photo preview + brauzerda siqish ***
    $('.add-photo-container #plant_sighting_photo').on('change', function(event) {
        var input = event.target;
        var photo = input.files[0];
        if (!photo) {
            return;
        }

        var reader = new FileReader();
        reader.onload = function(file) {
            $('#set-plant-photo-preview').attr('src', file.target.result);
        }
        reader.readAsDataURL(photo);
        $('#set-plant-photo-path').val(photo.name);

        uzfloraCompressSightingPhoto(photo, function(processedFile) {
            if (processedFile === photo || typeof window.DataTransfer !== 'function') {
                return;
            }

            try {
                var dataTransfer = new DataTransfer();
                dataTransfer.items.add(processedFile);
                input.files = dataTransfer.files;
            } catch (e) {
                // DataTransfer bilan fayl almashtirib bo'lmadi — asl fayl
                // (allaqachon inputda turgan) o'zgarishsiz yuklanadi.
            }
        });
    });

    //*** Photo's date ***
    // Kalendar 2020-yildan bugungi kungacha ochiq; kelajak sanalar bloklangan.
    // Sarlavhani bosish (masalan "Iyul 2026") oy/yil ro'yxatiga tez o'tkazadi —
    // bu bootstrap-datetimepicker'ning standart xatti-harakati.
    $('#plant-sighting-datetime-group').datetimepicker({
        locale: 'ru',
        format: 'DD/MM/YYYY',
        minDate: moment('2020-01-01', 'YYYY-MM-DD'),
        maxDate: moment(),
        useCurrent: false
    });
});
