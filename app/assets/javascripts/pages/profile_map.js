// Profil "Xarita" sahifasi (users/map.html.haml) — ALOHIDA sahifa
// (yashirin div emas), shuning uchun Leaflet o'lchamni to'g'ri hisoblaydi,
// invalidateSize() shart emas.
//
// Marker ma'lumotlari format:json endpoint'dan (users#map) keladi —
// koordinata u yerda allaqachon SightingCoordinates orqali o'tgan
// (Qizil kitob turlari uchun yaxlitlangan, aniq qiymat brauzerga
// umuman kelmaydi).
$(function () {
  var $canvas = $('#profile_map_canvas');
  if ($canvas.length === 0) {
    return;
  }

  var canvasId = $canvas.attr('id');
  var url = $canvas.data('url');
  var emptyText = $canvas.data('empty-text');
  var obscuredNote = $canvas.data('obscured-note');
  var viewLabel = $canvas.data('view-label');

  function escapeHtml(value) {
    return $('<div>').text(value == null ? '' : String(value)).html();
  }

  function showEmpty() {
    $canvas.replaceWith(
      $('<div class="profile-map-empty"></div>').text(emptyText)
    );
  }

  function pinIcon(pending) {
    return L.divIcon({
      className: 'pm-pin ' + (pending ? 'pm-pin--pending' : 'pm-pin--approved'),
      html: '<span></span>',
      iconSize: [18, 18],
      iconAnchor: [9, 9],
      popupAnchor: [0, -9]
    });
  }

  function popupHtml(s) {
    var html = '<div class="profile-map-popup">';
    if (s.thumb) {
      html += '<img src="' + escapeHtml(s.thumb) + '" alt="">';
    }
    if (s.name) {
      html += '<div class="pm-name">' + escapeHtml(s.name) + '</div>';
    }
    if (s.sci_name) {
      html += '<div class="pm-sci">' + escapeHtml(s.sci_name) + '</div>';
    }
    if (s.date) {
      html += '<div class="pm-date">' + escapeHtml(s.date) + '</div>';
    }
    if (s.obscured) {
      html += '<div class="pm-obscured">' + escapeHtml(obscuredNote) + '</div>';
    }
    html += '<div><a href="' + escapeHtml(s.url) + '">' + escapeHtml(viewLabel) + '</a></div>';
    html += '</div>';
    return html;
  }

  $.getJSON(url, function (data) {
    var sightings = (data && data.sightings) || [];
    if (sightings.length === 0) {
      showEmpty();
      return;
    }

    var map = L.map(canvasId).setView(UzfloraMap.DEFAULT_CENTER, UzfloraMap.DEFAULT_ZOOM);
    var baseLayers = UzfloraMap.baseLayers(L);
    baseLayers[UzfloraMap.defaultLayerLabel()].addTo(map);
    L.control.layers(baseLayers).addTo(map);

    // 50 tadan ko'p marker -> klasterlash (leaflet.markercluster).
    var layer = sightings.length > 50 ? L.markerClusterGroup() : L.featureGroup();
    var latLngs = [];

    sightings.forEach(function (s) {
      var marker = L.marker([s.lat, s.lon], { icon: pinIcon(s.pending) });
      marker.bindPopup(popupHtml(s));
      layer.addLayer(marker);
      latLngs.push([s.lat, s.lon]);
    });

    map.addLayer(layer);

    // Boshlang'ich ko'rinish — barcha markerlarni qamrasin.
    map.fitBounds(latLngs, { padding: [30, 30], maxZoom: 13 });
  }).fail(function () {
    showEmpty();
  });
});
