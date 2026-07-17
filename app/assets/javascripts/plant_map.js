// Xarita/Sputnik qatlamlari — welcome_map.js'даgi bir xil naqsh (bu fayl
// alohida asset bundle'да yuklangani uchun takrorlangan).
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

var plantMap = {
    map: null,
    marker: null
};

plantMap.init = function (selector, latLng, zoom) {
    this.map = L.map($(selector).attr('id')).setView(latLng, zoom);
    var baseLayers = uzfloraBaseLayers();
    baseLayers[uzfloraLayerLabels().map].addTo(this.map);
    L.control.layers(baseLayers).addTo(this.map);
};

plantMap.placeMarker = function (latLng) {
    if (this.marker) {
        this.map.removeLayer(this.marker);
    }
    this.marker = L.marker(latLng).addTo(this.map);
    return this.marker;
};

$(document).ready(function () {
    var map_element = $('#map_canvas');
    if (map_element.length === 0) {
        return;
    }

    // O'zbekiston markazi (Toshkent yaqinida)
    var uzbekistanCenter = [41.27, 69.23];

    plantMap.init(map_element, uzbekistanCenter, 6);

    plantMap.map.on('click', function (event) {
        plantMap.placeMarker(event.latlng);
        $('#plant_sighting_latitude').val(event.latlng.lat);
        $('#plant_sighting_longitude').val(event.latlng.lng);
    });
});

// plant_sightings#show — "Joylashuv" matnini bosganda kuzatuv joyini
// xaritada ko'rsatish (lazy init — bosilmasa xarita yuklanmaydi).
$(document).ready(function () {
    var $toggle = $('.sighting-map-toggle');
    if ($toggle.length === 0) {
        return;
    }

    var $canvas = $('#sighting_map_canvas');
    var initialized = false;

    $toggle.on('click', function (event) {
        event.preventDefault();

        $canvas.slideToggle(200, function () {
            if (!initialized && $canvas.is(':visible')) {
                var latLng = [parseFloat($toggle.data('lat')), parseFloat($toggle.data('lng'))];
                plantMap.init($canvas, latLng, 13);
                plantMap.placeMarker(latLng);
                initialized = true;
            }

            if (initialized) {
                plantMap.map.invalidateSize();
            }
        });
    });
});
