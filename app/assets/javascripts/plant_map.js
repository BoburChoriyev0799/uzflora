//= require uzflora_map_config

// Xarita qatlamlari (Oddiy / Relyef / Sun'iy yo'ldosh) va qatlam
// almashtirgich — YAGONA konfiguratsiyadan (uzflora_map_config.js).
// Bu fayl alohida asset bundle'да yuklanadi (layouts/plant_map.html.haml).

var plantMap = {
    map: null,
    marker: null
};

plantMap.init = function (selector, latLng, zoom) {
    this.map = L.map($(selector).attr('id')).setView(latLng, zoom);
    var baseLayers = UzfloraMap.baseLayers(L);
    baseLayers[UzfloraMap.defaultLayerLabel()].addTo(this.map);
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

    // 1-ish: kuzatuvni to'liq tahrirlashda xarita MAVJUD nuqta bilan
    // ochiladi (yangi kuzatuv yaratishda `data-lat`/`data-lng` bo'lmaydi
    // — avvalgidek bo'sh xarita, birinchi bosishda nuqta qo'yiladi).
    var initialLat = parseFloat(map_element.data('lat'));
    var initialLng = parseFloat(map_element.data('lng'));
    var hasInitial = !isNaN(initialLat) && !isNaN(initialLng);

    plantMap.init(
        map_element,
        hasInitial ? [initialLat, initialLng] : UzfloraMap.DEFAULT_CENTER,
        hasInitial ? 13 : UzfloraMap.DEFAULT_ZOOM
    );

    if (hasInitial) {
        plantMap.placeMarker([initialLat, initialLng]);
    }

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
