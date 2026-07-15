$(function () {
    var $row = $('.welcome-gallery-row[data-sightings]');
    if ($row.length === 0) {
        return;
    }

    var sightings = $row.data('sightings') || [];
    var cells = $row.find('.welcome-gallery-cell');
    if (sightings.length === 0 || cells.length === 0) {
        return;
    }

    var cellCount = cells.length;
    var offset = 0;

    function render() {
        cells.each(function (i) {
            var sighting = sightings[(offset + i) % sightings.length];
            var $cell = $(this);
            var $img = $cell.find('.welcome-gallery-img');

            $img.removeClass('loaded');
            $img.attr('src', sighting.photo);
            $img.one('load', function () {
                $img.addClass('loaded');
            });
            $cell.find('.welcome-gallery-caption').text(sighting.name || '');
        });
    }

    render();

    if (sightings.length > cellCount) {
        setInterval(function () {
            offset = (offset + cellCount) % sightings.length;
            render();
        }, 5000);
    }
});
