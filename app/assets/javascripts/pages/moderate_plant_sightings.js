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

    $list.on('click', '.moderation-approve', function(event) {
        event.preventDefault();
        var id = $(this).data('id');
        $.post('/plant_sightings/' + id + '/approve', function() {
            removeCard(id);
        });
    });

    $list.on('click', '.moderation-reject', function(event) {
        event.preventDefault();
        var id = $(this).data('id');
        if (!confirm("Rostdan ham bu kuzatuvni rad etmoqchimisiz?")) {
            return;
        }
        $.post('/plant_sightings/' + id + '/reject', function() {
            removeCard(id);
        });
    });
});
