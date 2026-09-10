# frozen_string_literal: true
#
# O'zbekcha nomi (`species_uz`) BO'SH turlarni qo'lda to'ldirish uchun CSV.
# BITTA manba — `plants:export_missing_uz_names` rake task VA ActiveAdmin
# "O'zbekcha nomlar CSV" tugmasi (collection_action) shu yerni chaqiradi,
# shuning uchun ustunlar/tartib har ikkalasida bir xil.
require 'csv'

module UzNamesExport
  HEADERS = %w[
    id lotincha_nom qabul_qilingan_nom oila ruscha_nom qoraqalpoqcha_nom
    qizil_kitob kuzatuvlar_soni species_uz
  ].freeze

  module_function

  # TARTIB (topshiriq 3a): (1) kuzatuvi bor turlar — kuzatuvlar_soni
  # kamayish bo'yicha, (2) Qizil kitob turlari, (3) qolganlari — oila,
  # keyin lotincha (accepted) nom alifbo bo'yicha.
  def rows(scope = Plant.without_species_uz)
    counts = PlantSighting.approved.published.where.not(plant_id: nil).group(:plant_id).count
    scope.to_a
         .map { |p| { plant: p, n: counts[p.id].to_i, family: p.display_family_lat.to_s } }
         .sort_by { |r|
           [
             r[:n].positive? ? 0 : 1,
             -r[:n],
             r[:plant].red_book? ? 0 : 1,
             r[:family].downcase,
             r[:plant].display_sci_name.to_s.downcase
           ]
         }
  end

  def to_csv(scope = Plant.without_species_uz)
    CSV.generate(encoding: 'UTF-8') do |csv|
      csv << HEADERS
      rows(scope).each do |r|
        p = r[:plant]
        csv << [
          p.id, p.species_sci, p.accepted_name, r[:family], p.species_ru,
          p.species_kaa, (p.red_book? ? 'ha' : ''), r[:n], nil
        ]
      end
    end
  end
end
