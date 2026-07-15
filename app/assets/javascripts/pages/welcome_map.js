$(function () {
    var $canvas = $('#welcome_map_canvas');
    if ($canvas.length === 0) {
        return;
    }

    var points = $canvas.data('points') || [];

    // O'zbekiston markazi (Toshkent yaqinida)
    var uzbekistanCenter = [41.27, 69.23];
    var map = L.map($canvas.attr('id')).setView(uzbekistanCenter, 6);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(map);

    // Mehmon rejimi: marker faqat nom ko'rsatadi, hech qayerga havola qilmaydi.
    points.forEach(function (point) {
        var marker = L.marker([point.lat, point.lng]).addTo(map);
        if (point.name) {
            marker.bindTooltip(point.name);
        }
    });
});
