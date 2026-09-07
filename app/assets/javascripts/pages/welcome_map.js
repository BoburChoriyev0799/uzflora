//= require uzflora_map_config

// Mehmon (bosh) sahifasidagi xarita — qatlamlar YAGONA konfiguratsiyadan
// (uzflora_map_config.js). Bu fayl application.js'ning `require_tree ./pages`
// orqali yuklanadi.

$(function () {
    var $canvas = $('#welcome_map_canvas');
    if ($canvas.length === 0) {
        return;
    }

    var points = $canvas.data('points') || [];

    var map = L.map($canvas.attr('id')).setView(UzfloraMap.DEFAULT_CENTER, UzfloraMap.DEFAULT_ZOOM);

    var baseLayers = UzfloraMap.baseLayers(L);
    baseLayers[UzfloraMap.defaultLayerLabel()].addTo(map);
    L.control.layers(baseLayers).addTo(map);

    // Mehmon rejimi: marker faqat nom ko'rsatadi, hech qayerga havola qilmaydi.
    points.forEach(function (point) {
        var marker = L.marker([point.lat, point.lng]).addTo(map);
        if (point.name) {
            marker.bindTooltip(point.name);
        }
    });
});
