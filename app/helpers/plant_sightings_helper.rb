module PlantSightingsHelper
  # Xom manzil matnidan lug'at kalitini hosil qiladi. Registr/bo'shliq/
  # apostrof/tinish belgisi farqlariga qaramay bir xil kalitga tushishi
  # uchun ketma-ket:
  #   1. Unicode NFKC normalizatsiya (turli ko'rinishdagi bir xil belgilar
  #      bitta shaklga keladi);
  #   2. kichik harfga o'tkazish — Ruby `String#downcase` kirill uchun ham
  #      to'g'ri ishlaydi;
  #   3. apostrofning BARCHA ko'rinishlarini olib tashlash: ʻ ʼ ‘ ’ ' ` ´;
  #   4. harf va raqamdan boshqa hamma narsani (bo'shliq, tire, nuqta,
  #      vergul, qavs...) olib tashlash.
  # Masalan "Toshkent", "Toshkent ", "toshkent", " TOSHKENT " — hammasi
  # "toshkent" kalitiga; "Farg'ona", "Fargʻona", "Farg‘ona" — "fargona"ga.
  LOCATION_APOSTROPHES = /[ʻʼ‘’'`´]/.freeze

  def normalize_location_key(value)
    value.to_s
         .unicode_normalize(:nfkc)
         .downcase
         .gsub(LOCATION_APOSTROPHES, '')
         .gsub(/[[:^alnum:]]/, '')
  end

  # Markaziy helper — JOY NOMI chiqadigan HAMMA joyda shu ishlatiladi
  # (kuzatuv sahifasi, kartochkalar, profil, tasdiqlash paneli, xarita
  # izohlari). `config/locales/views/locations.*.yml` lug'atidan joriy
  # tildagi nomni qaytaradi (masalan bazada "toshkent" yoki "Toshkent"
  # deb yozilgan bo'lsa ham — ruschada "Ташкент", inglizchada "Tashkent").
  #
  # MAJBURIY QOIDALAR:
  #  - lug'atda topilmasa — xom matnning O'ZI qaytadi, faqat birinchi harfi
  #    bosh harfga aylanadi (`capitalize_first`), chetki bo'shliqlar kesiladi;
  #  - HECH QACHON "translation missing", bo'sh joy yoki kalit nomi
  #    ("locations.toshkent") ko'rinmaydi — shuning uchun `I18n.t` ga
  #    har doim `default:` beriladi;
  #  - xom matn bo'sh bo'lsa "" qaytadi (chaqiruvchi joy blokini
  #    umuman ko'rsatmasin).
  def translate_location(raw)
    return '' if raw.blank?

    key = normalize_location_key(raw)
    I18n.t("locations.#{key}", default: capitalize_first(raw.to_s.strip))
  end

  # Eski nom — chaqiruvchi kodda hali ishlatiladi, `translate_location`
  # bilan bir xil.
  alias_method :location_name, :translate_location

  # Kuzatuvning "joylashuv" matni — koordinata (manzil yo'q holatda
  # `PlantSighting#address_string`ning o'zi qaytaradigan "lat; lng")
  # TARJIMA/BOSH HARFGA URINILMAYDI (bu raqam, joy nomi emas), faqat
  # haqiqiy manzil matni bo'lsa `location_name` orqali o'tadi.
  def plant_sighting_location(sighting)
    return sighting.address_string if sighting.address.blank?

    location_name(sighting.address)
  end

  # `plant_sighting_location` bilan bir xil, LEKIN xom koordinata
  # (manzil matni bo'lmagan holat) KO'RUVCHIGA qarab SightingCoordinates
  # orqali o'tadi — Qizil kitob turlari uchun egasi/ekspertdan boshqaga
  # 0.1 gradusga yaxlitlangan holda ko'rinadi. Manzil matni (shahar nomi)
  # aniq nuqta emas, shuning uchun o'zgartirilmaydi. HAMMA kartochka/
  # sahifa shu metodni ishlatadi (aniq koordinata sizib chiqmasin).
  def plant_sighting_display_location(sighting, viewer)
    return location_name(sighting.address) if sighting.address.present?

    coords = SightingCoordinates.for(sighting, viewer)
    return '' unless coords

    # Manzil matni yo'q — XOM koordinatani ko'rsatmaymiz: 3 xonagacha
    # yaxlitlangan chiroyli format. Himoyalangan turda `coords` allaqachon
    # 0.1 gradusga yaxlitlangan (SightingCoordinates).
    "#{format('%.3f', coords[:lat])}, #{format('%.3f', coords[:lon])}"
  end

  # Formadagi viloyat tanlash ro'yxati (joriy til): [[ko'rinadigan nom,
  # kalit], ...]. Kalit BAZAGA yoziladi, ko'rinadigan nom faqat ekranда.
  def region_select_options
    RegionLookup.keys.map { |k| [ RegionLookup.display_name(k), k ] }
  end

  # Kuzatuv sahifasi uchun to'liq joylashuv: "Viloyat — aniq joy"
  # (joriy til). Faqat bittasi bo'lsa — o'sha; ikkalasi bo'sh bo'lsa ""
  # (chaqiruvchi qatorni umuman ko'rsatmasin).
  def sighting_location_full(sighting)
    [
      (sighting.region_name if sighting.region.present?),
      (location_name(sighting.address) if sighting.address.present?)
    ].compact.join(' — ')
  end

  # Tashqi OSM xaritasiga havola — koordinata ham KO'RUVCHIGA qarab
  # (SightingCoordinates): Qizil kitob turida egasi/ekspertdan boshqaga
  # yaxlitlangan nuqta va uzoqroq zoom (aniq joy sizib chiqmasin).
  def plant_sighting_osm_url(sighting, viewer)
    coords = SightingCoordinates.for(sighting, viewer)
    return nil unless coords

    zoom = coords[:obscured] ? 11 : 15
    "https://www.openstreetmap.org/?mlat=#{coords[:lat]}&mlon=#{coords[:lon]}" \
      "#map=#{zoom}/#{coords[:lat]}/#{coords[:lon]}"
  end

  def plant_sighting_status_badge(sighting)
    content_tag(:span, I18n.t(sighting.status, scope: 'plant_sightings.status'),
                class: "sighting-status-badge status-#{sighting.status}")
  end

  # Navbar'dagi "Tasdiqlash uchun" tugmasidagi son belgisi uchun —
  # PlantSightingsController#pending bilan bir xil scope (o'sha yerdagi
  # `.known` bug shu yerda ham bor edi — birga tuzatildi).
  def pending_plant_sightings_count
    PlantSighting.published.pending.count
  end

  # Rasm versiyalarini yaratish + R2'ga yuklash fon jarayonida
  # (ProcessSightingImageJob) ketayotgan bo'lsa, `sighting.photo.small.url`
  # kabi chaqiruvlar hali mavjud bo'lmagan faylga ishora qiladi (siniq
  # rasm). Shu o'rniga bu yerda "ishlanmoqda"/"xatolik" placeholder
  # ko'rsatiladi — sighting egasi/kim bo'lmasin, har doim shu bitta
  # metod orqali (barcha galereya/kuzatuv sahifalarida bir xil ko'rinish).
  #
  # `sighting.photo.present?` EMAS, xom DB ustuni tekshiriladi: CarrierWave
  # (Fog storage bilan) `.present?`ni chaqirilganda R2'ga HAQIQIY tarmoq
  # so'rovi (fayl mavjudligini tekshirish) yuboradi — galereyada o'nlab
  # kuzatuv bo'lsa, bu o'nlab keraksiz tarmoq so'rovi degani. Ustun
  # bo'shmi-yo'qmi tekshirish uchun tarmoq shart emas.
  def plant_sighting_photo_tag(sighting, version = :small, html_options = {})
    return ''.html_safe if sighting[:photo].blank?

    if sighting.photo_status_failed?
      plant_sighting_photo_status_tag(:failed, html_options)
    elsif !sighting.photo_status_ready?
      plant_sighting_photo_status_tag(:processing, html_options)
    else
      url = version == :original ? sighting.photo.url : sighting.photo.public_send(version).url
      image_tag(url, html_options)
    end
  end

  def plant_sighting_photo_status_tag(kind, html_options = {})
    classes = ['plant-sighting-photo-status', "plant-sighting-photo-#{kind}", html_options[:class]].compact.join(' ')
    text = I18n.t(kind == :failed ? 'plant_sightings.photo_failed' : 'plant_sightings.photo_processing')
    content_tag(:div, text, class: classes)
  end
end
