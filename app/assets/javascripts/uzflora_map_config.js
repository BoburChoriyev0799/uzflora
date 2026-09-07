// ============================================================
// SAYTDAGI BARCHA XARITALAR UCHUN YAGONA KONFIGURATSIYA (4-ish)
// ------------------------------------------------------------
// Xarita kutubxonasi: Leaflet 1.9.4 — layouts/plant_map.html.haml va
// plants/welcome.html.haml'да unpkg CDN orqali yuklanadi (API kalit
// shart emas). Bu fayl kutubxonani ALMASHTIRMAYDI — faqat tile (plitka)
// manbalarini va qatlam almashtirgichni BIR JOYDA saqlaydi. Kelajakda
// manbani o'zgartirish uchun faqat shu faylni tahrirlash kifoya.
//
// Uchta qatlam:
//   1. "Oddiy"           — OpenStreetMap (raster).
//        4-ish "Oddiy" uchun OpenFreeMap (tiles.openfreemap.org/styles/
//        liberty) ni so'ragan, lekin u VEKTOR uslub JSON'i — uni
//        ko'rsatish uchun MapLibre GL kerak, Leaflet core buni
//        qo'llab-quvvatlamaydi. Spetsifikatsiyaning o'zi shu holat
//        uchun "o'rniga raster OSM ishlat" deb ko'rsatgan.
//   2. "Relyef"          — OpenTopoMap (raster, maxZoom 17).
//   3. "Sun'iy yo'ldosh" — Esri World Imagery (raster).
//
// Atributlar (© ...) — LITSENZIYA TALABI, ixtiyoriy emas: har bir
// tileLayer'ning `attribution` opsiyasi orqali xaritada (pastki o'ng
// burchak — Leaflet'ning standart attribution control'i, hech qayerda
// o'chirilmagan) doim ko'rinadi.
//
// Barcha tile manzillari 2026-09-07'да curl bilan tekshirildi:
//   OSM              -> 200 image/png
//   OpenTopoMap      -> 200 image/png
//   Esri WorldImagery-> 200 image/jpeg
// ============================================================
(function (window, document) {
  'use strict';

  var LOCALE_LABELS = {
    uz: { plain: 'Oddiy',    relief: 'Relyef', satellite: "Sun'iy yo'ldosh" },
    ru: { plain: 'Обычная',  relief: 'Рельеф', satellite: 'Спутник' },
    en: { plain: 'Standard', relief: 'Relief', satellite: 'Satellite' }
  };

  var OSM_ATTRIBUTION =
    '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';

  // Qatlamlar ro'yxati — YAGONA MANBA. Har biri: label kaliti +
  // Leaflet tileLayer yaratuvchi funksiya (`L` global bo'lgach chaqiriladi).
  // Ro'yxatdagi BIRINCHI element standart (yoqilgan) qatlam.
  var LAYERS = [
    {
      key: 'plain',
      build: function (L) {
        return L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
          maxZoom: 19,
          attribution: OSM_ATTRIBUTION
        });
      }
    },
    {
      key: 'relief',
      build: function (L) {
        return L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
          maxZoom: 17,
          attribution: OSM_ATTRIBUTION +
            ', SRTM | &copy; <a href="https://opentopomap.org">OpenTopoMap</a> (CC-BY-SA)'
        });
      }
    },
    {
      key: 'satellite',
      build: function (L) {
        return L.tileLayer(
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          {
            maxZoom: 19,
            attribution: '&copy; Esri, Maxar, Earthstar Geographics'
          }
        );
      }
    }
  ];

  function currentLocale() {
    var match = document.cookie.match(/(?:^|; )locale=([^;]+)/);
    var loc = match ? decodeURIComponent(match[1]) : 'uz';
    return LOCALE_LABELS[loc] ? loc : 'uz';
  }

  function labels() {
    return LOCALE_LABELS[currentLocale()];
  }

  window.UzfloraMap = {
    // O'zbekiston markazi (Toshkent yaqinida) va standart zoom.
    DEFAULT_CENTER: [41.27, 69.23],
    DEFAULT_ZOOM: 6,

    // `L.control.layers(baseLayers)` uchun { "Label": layer } obyekti.
    baseLayers: function (L) {
      var lbl = labels();
      var result = {};
      LAYERS.forEach(function (entry) {
        result[lbl[entry.key]] = entry.build(L);
      });
      return result;
    },

    // Standart (birinchi) qatlam label'i — chaqiruvchi
    // `baseLayers[defaultLayerLabel()]` ni `.addTo(map)` qiladi.
    defaultLayerLabel: function () {
      return labels()[LAYERS[0].key];
    }
  };
})(window, document);
