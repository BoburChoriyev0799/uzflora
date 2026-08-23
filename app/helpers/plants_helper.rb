# frozen_string_literal: true
module PlantsHelper
  # Botanik taksonomiya zanjiri, yuqoridan pastga: bo'lim -> sinf ->
  # tartib -> oila -> turkum -> tur. Har biri [label_key, qiymat_metodi].
  # Faqat lotincha (ilmiy) nom ko'rsatiladi — bazadagi *_ru ustunlari
  # (qavs ichidagi ruscha tarjima, masalan "Однодольные") uch tilda ham
  # keraksiz hisoblanib chiqarib tashlangan. Oila/turkum/tur POWO
  # moslashtirilgan bo'lsa accepted_* qiymatlardan olinadi (Plant#display_
  # family_lat/display_genus_lat/display_sci_name), bo'lmasa eskisidan —
  # bo'lim/sinf/tartib uchun POWO ustuni yo'q, o'zgarishsiz qoladi.
  PLANT_TAXONOMY_LEVELS = [
    [:division, :division_lat],
    [:class_name, :class_lat],
    [:order, :order_lat],
    [:family, :display_family_lat],
    [:genus, :display_genus_lat],
    [:species, :display_sci_name]
  ].freeze

  # plants/show'даgi taksonomiya jadvali uchun qatorlar: [label_key, lat]
  # — lotincha nomi bo'sh bo'lgan daraja butunlay chiqarib tashlanadi.
  def plant_taxonomy_rows(plant)
    PLANT_TAXONOMY_LEVELS.filter_map do |label_key, method_name|
      lat = plant.public_send(method_name)
      [label_key, lat] if lat.present?
    end
  end

  # plants/show'даgi "uch nom" bloki uchun qatorlar: [label_key, value].
  # Til bo'yicha tartib va yorliqlar farq qiladi (uz/ru/en), lekin har
  # birida bo'sh qiymatli qator chiqarib tashlanadi. species_en ustuni
  # bazada yo'q — "Common name:" shu sabab hozircha doim yashiringan.
  def plant_name_rows(plant, locale)
    sci_name = plant.display_sci_name
    rows = case locale.to_sym
           when :ru
             [
               [:name_ru, plant.species_ru],
               [:name_lat, sci_name],
               [:name_local, plant.species_uz]
             ]
           when :en
             [
               [:name_lat, sci_name],
               [:name_ru, plant.species_ru],
               [:name_local, plant.species_uz]
             ]
           else
             [
               [:name_uz, plant.species_uz],
               [:name_lat, sci_name],
               [:name_ru, plant.species_ru]
             ]
           end
    rows.select { |_, value| value.present? }
  end

  # plants#index kartochkasida "= eski nom" qatori uchun: shu yozuvning
  # eski nomi (species_sci) — FAQAT accepted_name @duplicate_accepted_names
  # to'plamida bo'lsa (ya'ni butun jadval bo'yicha 2+ Plant yozuviga
  # tegishli) VA plant.alt_name mavjud bo'lsa (ya'ni bu YOZUVNING o'zi
  # qayta nomlangan). Guruhning "asl" a'zosi uchun (masalan Calligonum
  # aphyllum guruhida species_sci allaqachon accepted_name bilan bir xil
  # bo'lgan yozuv) alt_name nil bo'ladi va qator chiqmaydi — o'zining
  # nomini o'ziga qaytarib ko'rsatish keraksiz bo'lardi, chunki yuqorida
  # ko'rsatilgan ilmiy nom bilan farqi yo'q.
  def plant_duplicate_alt_name(plant, duplicate_accepted_names)
    return nil unless plant.accepted_name.present? && duplicate_accepted_names.include?(plant.accepted_name)

    plant.alt_name
  end

  # Tashqi manba tugmalarida ko'rsatiladigan rasmiy logo fayllari
  # (app/assets/images/external_sources/). Har biri o'z nomini o'zida
  # tashiydi (wordmark), shuning uchun tugmada alohida matn label
  # kerak emas — logo yonida faqat img bor.
  PLANT_EXTERNAL_LINK_LOGOS = {
    'inaturalist' => 'external_sources/inaturalist-logo.svg',
    'gbif' => 'external_sources/gbif-logo.svg',
    'powo' => 'external_sources/powo-logo.png',
    'plantarium' => 'external_sources/plantarium-logo.svg',
    'iucn' => 'external_sources/iucn-logo.png'
  }.freeze

  # Tashqi ilmiy manbalar (iNaturalist, GBIF, POWO, Plantarium, IUCN Red
  # List) uchun havolalar: [key, label, logo_path, url] ro'yxati. Tur
  # nomi bo'lmasa bo'sh massiv qaytadi — bu holda blok umuman
  # ko'rsatilmaydi.
  def plant_external_links(plant)
    name = plant.external_search_name
    return [] if name.blank?

    # ERB::Util.url_encode bo'shliqni "%20" bilan kodlaydi ("+" emas) —
    # GBIF'ning qidiruv sahifasi "+" ni to'g'ri dekodlamas edi.
    q = ERB::Util.url_encode(name)
    [
      ['inaturalist', 'iNaturalist', "https://www.inaturalist.org/observations?taxon_name=#{q}"],
      # "/species/search" GBIF'da "/taxon/search"ga redirect bo'ladi va
      # shu jarayonda ?q= parametri tushib qolib, butun bazani ko'rsatib
      # yuboradi — shuning uchun to'g'ridan-to'g'ri "/taxon/search".
      ['gbif', 'GBIF', "https://www.gbif.org/taxon/search?q=#{q}"],
      ['powo', 'POWO', "https://powo.science.kew.org/results?q=#{q}"],
      # Qidiruv formasining haqiqiy maydon nomlari (sample/match/type/
      # mode) plantarium.ru'ning o'z HTML formasidan olindi — "query"
      # kabi taxmin qilingan nom natija bermas edi.
      ['plantarium', 'Plantarium', "https://www.plantarium.ru/page/search.html?match=begins&type=0&mode=full&sample=#{q}"],
      ['iucn', 'IUCN Red List', "https://www.iucnredlist.org/search?query=#{q}&searchType=species"]
    ].map { |key, label, url| [key, label, PLANT_EXTERNAL_LINK_LOGOS[key], url] }
  end
end
