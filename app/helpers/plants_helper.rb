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

  # Tashqi ilmiy manbalar (iNaturalist, GBIF, POWO) uchun havolalar:
  # [key, label, url] ro'yxati. Tur nomi bo'lmasa bo'sh massiv qaytadi —
  # bu holda blok umuman ko'rsatilmaydi.
  def plant_external_links(plant)
    name = plant.external_search_name
    return [] if name.blank?

    q = CGI.escape(name)
    [
      ['inaturalist', 'iNaturalist', "https://www.inaturalist.org/observations?taxon_name=#{q}"],
      ['gbif', 'GBIF', "https://www.gbif.org/species/search?q=#{q}"],
      ['powo', 'POWO', "https://powo.science.kew.org/results?q=#{q}"]
    ]
  end
end
