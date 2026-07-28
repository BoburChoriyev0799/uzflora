# frozen_string_literal: true
module PlantsHelper
  # Botanik taksonomiya zanjiri, yuqoridan pastga: bo'lim -> sinf ->
  # tartib -> oila -> turkum -> tur. Har biri [label_key, lat_ustun, ru_ustun].
  PLANT_TAXONOMY_LEVELS = [
    [:division, :division_lat, :division_ru],
    [:class_name, :class_lat, :class_ru],
    [:order, :order_lat, :order_ru],
    [:family, :family_lat, :family_ru],
    [:genus, :genus_lat, :genus_ru],
    [:species, :species_sci, :species_ru]
  ].freeze

  # plants/show'даgi taksonomiya jadvali uchun qatorlar: [label_key, lat, ru]
  # — ikkalasi ham bo'sh bo'lgan daraja butunlay chiqarib tashlanadi.
  def plant_taxonomy_rows(plant)
    PLANT_TAXONOMY_LEVELS.filter_map do |label_key, lat_attr, ru_attr|
      lat = plant.public_send(lat_attr)
      ru = plant.public_send(ru_attr)
      [label_key, lat, ru] if lat.present? || ru.present?
    end
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
