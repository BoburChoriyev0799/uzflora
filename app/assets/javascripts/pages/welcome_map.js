// Xarita/Sputnik qatlamlari uchun umumiy funksiyalar — plant_map.js'даgi
// bir xil naqsh (bu fayl alohida asset bundle'да yuklangani uchun
// takrorlangan, umumiy modul ajratish shart emas).
function uzfloraMapLocale() {
    var match = document.cookie.match(/(?:^|; )locale=([^;]+)/);
    return match ? decodeURIComponent(match[1]) : 'uz';
}

function uzfloraLayerLabels() {
    var labels = {
        uz: { map: 'Xarita', satellite: 'Sputnik' },
        ru: { map: 'Карта', satellite: 'Спутник' },
        en: { map: 'Map', satellite: 'Satellite' }
    };
    return labels[uzfloraMapLocale()] || labels.uz;
}

function uzfloraBaseLayers() {
    var labels = uzfloraLayerLabels();
    var layers = {};
    layers[labels.map] = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    });
    layers[labels.satellite] = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19,
        attribution: 'Tiles &copy; Esri &mdash; Esri, Maxar, Earthstar Geographics'
    });
    return layers;
}

$(function () {
    var $canvas = $('#welcome_map_canvas');
    if ($canvas.length === 0) {
        return;
    }

    var points = $canvas.data('points') || [];

    // O'zbekiston markazi (Toshkent yaqinida)
    var uzbekistanCenter = [41.27, 69.23];
    var map = L.map($canvas.attr('id')).setView(uzbekistanCenter, 6);

    var baseLayers = uzfloraBaseLayers();
    baseLayers[uzfloraLayerLabels().map].addTo(map);
    L.control.layers(baseLayers).addTo(map);

    // Mehmon rejimi: marker faqat nom ko'rsatadi, hech qayerga havola qilmaydi.
    points.forEach(function (point) {
        var marker = L.marker([point.lat, point.lng]).addTo(map);
        if (point.name) {
            marker.bindTooltip(point.name);
        }
    });
});
