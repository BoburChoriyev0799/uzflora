$(function() {
    var $list = $('.moderation-list');
    if ($list.length === 0) {
        return;
    }

    function removeCard(id) {
        $('#sighting-' + id).fadeOut(200, function() {
            $(this).remove();
            if ($list.children().length === 0) {
                $('#moderation-empty').show();
            }
        });
    }

    function ajaxErrorMessage(xhr) {
        return (xhr.responseJSON && xhr.responseJSON.error) || 'Xatolik yuz berdi.';
    }

    // Ekspert tur nomini o'zgartira boshlaganda (yangi tanlov qilmaguncha)
    // eski plant_id endi ko'rsatilayotgan matnga mos kelmaydi — shuning
    // uchun "Biriktirish" tugmasi qayta tanlanguncha o'chirib qo'yiladi.
    $list.on('input', '.plant-autocomplete-input', function() {
        var $card = $(this).closest('.moderation-card');
        $card.find('.moderation-plant-id').val('');
        $card.find('.moderation-assign-plant').prop('disabled', true);
        $card.find('.moderation-assign-feedback').text('');
    });

    $list.on('click', '.moderation-assign-plant', function(event) {
        event.preventDefault();
        var $btn = $(this);
        var id = $btn.data('id');
        var $card = $('#sighting-' + id);
        var plantId = $card.find('.moderation-plant-id').val();
        if (!plantId) {
            return;
        }

        $btn.prop('disabled', true);
        $card.find('.moderation-assign-feedback').text('');

        $.post('/plant_sightings/' + id + '/assign_plant', { plant_id: plantId })
            .done(function() {
                $btn.prop('disabled', false);
                $card.find('.moderation-approve').prop('disabled', false);
                $card.find('.moderation-plant-warning[data-warning-for="' + id + '"]').hide();
                $card.find('.moderation-assign-feedback[data-id="' + id + '"]').text('✓');
            })
            .fail(function(xhr) {
                $btn.prop('disabled', false);
                alert(ajaxErrorMessage(xhr));
            });
    });

    $list.on('click', '.moderation-approve', function(event) {
        event.preventDefault();
        var $btn = $(this);
        var id = $btn.data('id');
        $.post('/plant_sightings/' + id + '/approve', function() {
            removeCard(id);
        }).fail(function(xhr) {
            alert(ajaxErrorMessage(xhr));
        });
    });

    $list.on('click', '.moderation-reject', function(event) {
        event.preventDefault();
        var id = $(this).data('id');
        var reason = prompt("Nega rad etyapsiz? (ixtiyoriy, foydalanuvchiga ko'rinadi, eng ko'pi bilan 100 belgi)");
        if (reason === null) {
            return;
        }
        $.post('/plant_sightings/' + id + '/reject', { moderation_note: reason.slice(0, 100) }, function() {
            removeCard(id);
        });
    });
});
