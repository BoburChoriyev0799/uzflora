// Kuzatuvga izoh — bir sahifada bir nechta vidjet bo'lishi mumkin
// (profil/o'simlik sahifasidagi rasm kartochkalari, har birida o'zining
// izoh blokи) shuning uchun HAMMA handler documentga bog'langan
// (delegated) va eng yaqin `.form-add-plant-sighting-comment`/
// `.sighting-comments-block` konteyner ichida ishlaydi.
//
// XAVFSIZLIK: yangi izoh HTML ko'rinishida SERVERDAN keladi
// (PlantSightingCommentsController#create — render_to_string orqali,
// Haml avto-escape bilan) — JS xom matndan HTML yig'MAYDI, shuning
// uchun <script> kabi matn izoh sifatida yozilsa ham ishlamaydi.
$(function() {
    function ajaxErrorMessage(xhr) {
        return (xhr.responseJSON && xhr.responseJSON.error) || 'Xatolik yuz berdi.';
    }

    // 💬 belgisi — bosilganda shu kuzatuvning izohlar blokini ochadi/yopadi.
    $(document).on('click', '.sighting-comment-toggle', function(event) {
        event.preventDefault();
        $('#' + $(this).data('target')).slideToggle(150);
    });

    // Ro'yxatlardagi (profil, o'simlik sahifasi) 💬 tugmasi — tor
    // kartochka ichida EMAS, umumiy MODAL oynada ochiladi
    // (plant_sightings/_comment_modal.html.haml). Kartochka ichidagi
    // yashirin `.sighting-comment-modal-content` DOM tuguni modal ichiga
    // KO'CHIRILADI (klonlanmaydi — shunda ID takrorlanmaydi va mavjud
    // izoh qo'shish/o'chirish delegatsiyasi o'zgarishsiz ishlayveradi),
    // yopilganda esa aynan o'sha joyiga qaytariladi (bo'sh <span> belgi
    // orqali eslab qolinadi).
    function openSightingCommentModal($trigger) {
        var $content = $('#' + $trigger.data('target'));
        if (!$content.length) {
            return;
        }

        var $modal = $('#sighting-comment-modal');
        var $placeholder = $('<span style="display:none"></span>').insertAfter($content);
        $content.data('sightingModalPlaceholder', $placeholder);

        $modal.find('.sighting-comment-modal-slot').append($content.show());
        $modal.data('activeContent', $content);

        $modal.css('display', 'flex');
        $('body').css('overflow', 'hidden');
        $content.find('.comment-text').first().trigger('focus');
    }

    function closeSightingCommentModal() {
        var $modal = $('#sighting-comment-modal');
        var $content = $modal.data('activeContent');

        if ($content && $content.length) {
            var $placeholder = $content.data('sightingModalPlaceholder');
            $content.hide();
            if ($placeholder && $placeholder.length) {
                $content.insertBefore($placeholder);
                $placeholder.remove();
            }
        }

        $modal.hide();
        $modal.removeData('activeContent');
        $('body').css('overflow', '');
    }

    $(document).on('click', '.sighting-comment-modal-trigger', function(event) {
        event.preventDefault();
        openSightingCommentModal($(this));
    });

    $(document).on('click', '.sighting-comment-modal-close', function(event) {
        event.preventDefault();
        closeSightingCommentModal();
    });

    // Fonga bosilsa yopiladi — faqat overlayning O'ZIGA bosilganda
    // (ichidagi qutiga bosish yopmasin).
    $(document).on('click', '.sighting-comment-modal-overlay', function(event) {
        if (event.target === this) {
            closeSightingCommentModal();
        }
    });

    $(document).on('keydown', function(event) {
        if (event.key === 'Escape' && $('#sighting-comment-modal').is(':visible')) {
            closeSightingCommentModal();
        }
    });

    // Jonli hisoblagich ("87/100").
    $(document).on('input', '.comment-text', function() {
        var $textarea = $(this);
        var max = parseInt($textarea.attr('maxlength'), 10) || 100;
        var used = $textarea.val().length;
        $textarea.closest('.add-comment-form').find('.comment-char-count').text(used + '/' + max);
    });

    $(document).on('click', '.add-plant-sighting-comment-btn', function(event) {
        event.preventDefault();
        var $btn = $(this);
        var $form = $btn.closest('.form-add-plant-sighting-comment');
        var $textarea = $form.find('.comment-text');
        var text = $textarea.val();

        if (!text || text.trim().length === 0) {
            return;
        }

        $.post(
            $form.attr('action'),
            { comment: text, plant_sighting_id: $form.data('plantSightingId') }
        ).done(function(response) {
            if (response.success) {
                $textarea.val('');
                $form.closest('.sighting-comments').find('.comments-container').append(response.html);
                bumpCommentCount($form.data('plantSightingId'), 1);
            } else {
                alert(response.error || 'Xatolik yuz berdi.');
            }
        }).fail(function(xhr) {
            alert(ajaxErrorMessage(xhr));
        });
    });

    $(document).on('click', '.delete-plant-sighting-comment-lnk', function(event) {
        event.preventDefault();
        var $lnk = $(this);
        var commentId = $lnk.data('id');
        var $row = $lnk.closest('.comment-row');
        var plantSightingId = $row.closest('.sighting-comments-block').data('plantSightingId');

        $.ajax({
            url: '/plant_sighting_comments/' + commentId,
            type: 'DELETE'
        }).done(function(response) {
            $row.remove();
            if (plantSightingId && typeof response.comments_count !== 'undefined') {
                setCommentCount(plantSightingId, response.comments_count);
            }
        }).fail(function(xhr) {
            alert(ajaxErrorMessage(xhr));
        });
    });

    function setCommentCount(plantSightingId, count) {
        $('.sighting-comment-count[data-plant-sighting-id="' + plantSightingId + '"]').text(count);
    }

    function bumpCommentCount(plantSightingId, delta) {
        var $el = $('.sighting-comment-count[data-plant-sighting-id="' + plantSightingId + '"]');
        var current = parseInt($el.text(), 10) || 0;
        $el.text(current + delta);
    }
});
