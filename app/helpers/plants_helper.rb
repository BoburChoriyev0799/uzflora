# frozen_string_literal: true
module PlantsHelper
  # Botanik taksonomiya zanjiri, yuqoridan pastga: bo'lim -> sinf ->
  # tartib -> oila -> turkum -> tur. Har biri [label_key, lat_ustun].
  # Faqat lotincha (ilmiy) nom ko'rsatiladi — bazadagi *_ru ustunlari
  # (qavs ichidagi ruscha tarjima, masalan "Однодольные") uch tilda ham
  # keraksiz hisoblanib chiqarib tashlangan.
  PLANT_TAXONOMY_LEVELS = [
    [:division, :division_lat],
    [:class_name, :class_lat],
    [:order, :order_lat],
    [:family, :family_lat],
    [:genus, :genus_lat],
    [:species, :species_sci]
  ].freeze

  # plants/show'даgi taksonomiya jadvali uchun qatorlar: [label_key, lat]
  # — lotincha nomi bo'sh bo'lgan daraja butunlay chiqarib tashlanadi.
  def plant_taxonomy_rows(plant)
    PLANT_TAXONOMY_LEVELS.filter_map do |label_key, lat_attr|
      lat = plant.public_send(lat_attr)
      [label_key, lat] if lat.present?
    end
  end

  # plants/show'даgi "uch nom" bloki uchun qatorlar: [label_key, value].
  # Til bo'yicha tartib va yorliqlar farq qiladi (uz/ru/en), lekin har
  # birida bo'sh qiymatli qator chiqarib tashlanadi. species_en ustuni
  # bazada yo'q — "Common name:" shu sabab hozircha doim yashiringan.
  def plant_name_rows(plant, locale)
    rows = case locale.to_sym
           when :ru
             [
               [:name_ru, plant.species_ru],
               [:name_lat, plant.species_sci],
               [:name_local, plant.species_uz]
             ]
           when :en
             [
               [:name_lat, plant.species_sci],
               [:name_ru, plant.species_ru],
               [:name_local, plant.species_uz]
             ]
           else
             [
               [:name_uz, plant.species_uz],
               [:name_lat, plant.species_sci],
               [:name_ru, plant.species_ru]
             ]
           end
    rows.select { |_, value| value.present? }
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
