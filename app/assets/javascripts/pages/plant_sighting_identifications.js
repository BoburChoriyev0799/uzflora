// Jamoaviy aniqlash (community identification) — "Tur taklif qilish"
// vidjeti (plant_sightings/_identifications.html.haml). Bir sahifada
// bir nechta vidjet bo'lishi mumkin (moderatsiya navbatida har kartada
// bittadan) — shuning uchun har doim eng yaqin `.identifications-widget`
// konteyner ichida ishlaymiz, moderate_plant_sightings.js uslubida.
//
// Har amaldan keyin server YANGI HTML qaytaradi (render_to_string —
// IdentificationsController), shu vidjetning ICHINI shu bilan almashtiramiz
// — qo'lda satr qo'shish/o'chirish yo'q, shuning uchun XSS xavfi yo'q
// (Haml auto-escape) va hisoblagichlar/progress chizig'i har doim
// serverdagi haqiqiy holatni ko'rsatadi.
$(function() {
    function ajaxErrorMessage(xhr) {
        return (xhr.responseJSON && xhr.responseJSON.error) || 'Xatolik yuz berdi.';
    }

    function replaceWidget($widget, html) {
        $widget.replaceWith(html);
    }

    $(document).on('input', '.identifications-widget .plant-autocomplete-input', function() {
        var $widget = $(this).closest('.identifications-widget');
        $widget.find('.identification-plant-id').val('');
        $widget.find('.identification-propose-btn').prop('disabled', true);
    });

    $(document).on('click', '.identification-propose-btn', function(event) {
        event.preventDefault();
        var $btn = $(this);
        var $widget = $btn.closest('.identifications-widget');
        var plantId = $widget.find('.identification-plant-id').val();
        if (!plantId) {
            return;
        }

        $btn.prop('disabled', true);
        $.post($widget.data('createUrl'), { plant_id: plantId, compact: $widget.hasClass('compact') ? 1 : 0 })
            .done(function(response) {
                if (response.success) {
                    replaceWidget($widget, response.html);
                } else {
                    $btn.prop('disabled', false);
                    alert(response.error || 'Xatolik yuz berdi.');
                }
            })
            .fail(function(xhr) {
                $btn.prop('disabled', false);
                alert(ajaxErrorMessage(xhr));
            });
    });

    $(document).on('click', '.identification-withdraw-lnk, .identification-delete-lnk', function(event) {
        event.preventDefault();
        var $lnk = $(this);
        var $widget = $lnk.closest('.identifications-widget');
        var id = $lnk.data('id');

        $.ajax({ url: '/identifications/' + id, type: 'DELETE', data: { compact: $widget.hasClass('compact') ? 1 : 0 } })
            .done(function(response) {
                if (response.success) {
                    replaceWidget($widget, response.html);
                } else {
                    alert(response.error || 'Xatolik yuz berdi.');
                }
            })
            .fail(function(xhr) {
                alert(ajaxErrorMessage(xhr));
            });
    });
});
