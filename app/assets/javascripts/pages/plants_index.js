// O'simliklar ro'yxati (index) kartochkalari — bir nechta tasdiqlangan
// rasmi bor o'simliklarda ular avtomatik almashib turadi (crossfade,
// sof CSS opacity transition orqali). Har kartochka uchun ALOHIDA
// setInterval EMAS — bitta umumiy taymer barcha ko'p-rasmli
// kartochkalarni bir yo'la yangilaydi, shuning uchun sahifada 24ta
// kartochka bo'lsa ham brauzer sekinlashmaydi.
$(function () {
    var $multiPhotoCards = $('.plant-card-photo').filter(function () {
        return $(this).find('.plant-card-photo-img').length > 1;
    });

    if ($multiPhotoCards.length === 0) {
        return;
    }

    setInterval(function () {
        $multiPhotoCards.each(function () {
            var $imgs = $(this).find('.plant-card-photo-img');
            var $active = $imgs.filter('.active');
            var nextIndex = ($imgs.index($active) + 1) % $imgs.length;

            $active.removeClass('active');
            $imgs.eq(nextIndex).addClass('active');
        });
    }, 3500);
});
