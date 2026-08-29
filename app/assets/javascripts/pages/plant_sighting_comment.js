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
