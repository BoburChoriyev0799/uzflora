module PlantSightingsHelper
  # Bo'shliq/registr/apostrof farqlariga qaramay bir xil kalitga tushishi
  # uchun: kichik harf, chetdagi bo'shliqlar kesiladi, ichkaridagi
  # bo'shliqlar va apostrofning turli ko'rinishlari (', ', ‘, ʻ, ʼ)
  # butunlay olib tashlanadi. Masalan "Farg'ona", "farg'ona ", "Farg’ona"
  # — hammasi "fargona" kalitiga tushadi.
  def normalize_location_key(value)
    value.to_s.strip.downcase.gsub(/['’‘ʻʼ`]/, '').gsub(/\s+/, '')
  end

  # Markaziy helper — JOY NOMI chiqadigan HAMMA joyda shu ishlatiladi
  # (kuzatuv sahifasi, kartochkalar, profil, tasdiqlash paneli, xarita
  # izohlari). `config/locales/views/locations.*.yml` lug'atidan joriy
  # tildagi nomni qaytaradi (masalan bazada "toshkent" yoki "Toshkent"
  # deb yozilgan bo'lsa ham — ruschada "Ташкент", inglizchada "Tashkent").
  # Lug'atda topilmasa — saqlangan matnning O'ZI qaytadi, lekin birinchi
  # harfi albatta BOSH HARF bo'ladi (`capitalize_first`) — bazadagi
  # "toshkent" kabi kichik harfli yozuvlar ham to'g'ri ko'rinsin.
  def location_name(raw)
    return raw.to_s if raw.blank?

    key = normalize_location_key(raw)
    translated = I18n.t(key, scope: 'locations', default: nil)
    return translated if translated.present?

    capitalize_first(raw)
  end

  # Kuzatuvning "joylashuv" matni — koordinata (manzil yo'q holatda
  # `PlantSighting#address_string`ning o'zi qaytaradigan "lat; lng")
  # TARJIMA/BOSH HARFGA URINILMAYDI (bu raqam, joy nomi emas), faqat
  # haqiqiy manzil matni bo'lsa `location_name` orqali o'tadi.
  def plant_sighting_location(sighting)
    return sighting.address_string if sighting.address.blank?

    location_name(sighting.address)
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
