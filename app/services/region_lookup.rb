# frozen_string_literal: true
#
# Koordinatadan (lat, lon) O'zbekiston viloyatining KALITINI aniqlaydi —
# sof Ruby "nuqta ko'pburchak ichidami" (ray-casting), YANGI GEM YO'Q
# (rgeo/geos Render'da native build talab qiladi — xavf).
#
# CHEGARA MA'LUMOTI: db/geo/uzbekiston_viloyatlari.geojson —
#   Natural Earth admin-1 (10m), public domain (CC0), Douglas-Peucker
#   bilan soddalashtirilgan (~30 KB). Chegaralar ~500 m aniqlikda —
#   viloyat darajasidagi tasnif uchun yetarli (viloyatning o'zi ~100 km).
#
# QOIDA: nuqta AYNAN BITTA viloyatga tushsa — o'sha kalit; hech qaysiga
# yoki (soddalashtirish tufayli) bir nechtasiga tushsa — nil. TAXMIN
# QILINMAYDI.
require 'json'

module RegionLookup
  GEOJSON_PATH = Rails.root.join('db', 'geo', 'uzbekiston_viloyatlari.geojson')

  # config/locales/views/locations.*.yml dagi mavjud lug'at kalitiga
  # (`PlantSightingsHelper#normalize_location_key` normallashtirgan) moslash —
  # yangi lug'at yaratilmaydi.
  DISPLAY_SOURCE = {
    'toshkent_shahri' => 'toshkent shahri',
    'toshkent_viloyati' => 'toshkent viloyati',
    'qoraqalpogiston' => 'qoraqalpogiston respublikasi'
  }.freeze

  # Modeldagi inclusion validatsiyasi va formadagi ro'yxat shu ro'yxatdan.
  def self.keys
    @keys ||= regions.map { |r| r[:region] }.freeze
  end

  module_function

  # lat, lon -> viloyat kaliti (String) yoki nil.
  def region_for(lat, lon)
    return nil if lat.nil? || lon.nil?

    lat = lat.to_f
    lon = lon.to_f
    matched = regions.select { |r|
      next false unless in_bbox?(lon, lat, r[:bbox])

      r[:polygons].any? { |rings| point_in_polygon?(lon, lat, rings) }
    }
    return matched.first[:region] if matched.size == 1

    if matched.size > 1
      Rails.logger.info("[RegionLookup] noaniq: (#{lat}, #{lon}) -> #{matched.map { |m| m[:region] }.join(', ')} — nil qaytarildi")
    end
    nil
  end

  # KO'RSATISH nomi (joriy til) — mavjud `translate_location` lug'ati orqali.
  # Helperdan tashqarida ham ishlashi uchun I18n bevosita chaqiriladi.
  def display_name(key, locale: I18n.locale)
    return '' if key.blank?

    raw = DISPLAY_SOURCE[key] || "#{key} viloyati"
    norm = raw.gsub(/[^a-z0-9]/, '')
    I18n.t("locations.#{norm}", locale: locale, default: key.tr('_', ' ').split.map(&:capitalize).join(' '))
  end

  # --- ichki ---

  def regions
    @regions ||= load_regions
  end

  def load_regions
    data = JSON.parse(File.read(GEOJSON_PATH))
    data['features'].map do |f|
      geom = f['geometry']
      # Har element: ko'pburchaklar ro'yxati; har ko'pburchak — halqalar
      # ro'yxati ([tashqi, teshik1, ...]).
      polygons = geom['type'] == 'Polygon' ? [geom['coordinates']] : geom['coordinates']
      { region: f['properties']['region'], polygons: polygons, bbox: bbox_of(polygons) }
    end
  end

  def bbox_of(polygons)
    xs = []
    ys = []
    polygons.each { |rings| rings.each { |ring| ring.each { |x, y| xs << x; ys << y } } }
    [ xs.min, ys.min, xs.max, ys.max ]
  end

  def in_bbox?(x, y, bbox)
    x >= bbox[0] && x <= bbox[2] && y >= bbox[1] && y <= bbox[3]
  end

  # rings — [tashqi_halqa, teshik1, ...]. Nuqta tashqi halqada VA hech bir
  # teshikda emas bo'lsa — true.
  def point_in_polygon?(x, y, rings)
    return false unless point_in_ring?(x, y, rings[0])

    rings[1..].to_a.none? { |hole| point_in_ring?(x, y, hole) }
  end

  # Ray-casting (Jordan): halqa yopiq deb qabul qilinadi.
  def point_in_ring?(x, y, ring)
    inside = false
    j = ring.size - 1
    ring.each_with_index do |(xi, yi), i|
      xj, yj = ring[j]
      if (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi
        inside = !inside
      end
      j = i
    end
    inside
  end
end
