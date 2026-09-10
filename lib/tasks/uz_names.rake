# frozen_string_literal: true
#
# O'zbekcha nom (`plants.species_uz`) BO'SH turlar uchun QO'LDA to'ldirish
# vositasi. Nomlar O'YLAB TOPILMAYDI — foydalanuvchi (Bobur) CSV'да qo'lda
# to'ldiradi, keyin import qiladi.
#
#   1) rails plants:export_missing_uz_names
#        -> tmp/ozbekcha_nomlar_toldirish.csv (species_uz ustuni BO'SH)
#   2) (foydalanuvchi CSV'ni to'ldiradi)
#   3) rails plants:import_uz_names             # dry-run
#      rails plants:import_uz_names APPLY=true  # yozadi
#
# IMPORT QOIDALARI:
#   - moslashtirish FAQAT `id` bo'yicha (nom bo'yicha emas — xavfsiz)
#   - species_uz bo'sh qatorlar o'tkazib yuboriladi (xato emas)
#   - mavjud species_uz bo'sh BO'LMASA va yangi qiymat farq qilsa —
#     USTIGA YOZILMAYDI, "ZIDDIYAT" deb hisobotга yoziladi
#   - guruhga qo'llash: qiymat accepted_name guruhining BARCHA a'zolariga
#     (qoraqalpoqcha import bilan bir xil — kelajakda primary o'zgarsa
#     ham ma'lumot yo'qolmaydi)
#   - idempotent
require 'csv'

module UzNamesTool
  EXPORT_PATH = Rails.root.join('tmp', 'ozbekcha_nomlar_toldirish.csv')
  EXPORT_HEADERS = %w[
    id lotincha_nom qabul_qilingan_nom oila ruscha_nom qoraqalpoqcha_nom
    qizil_kitob kuzatuvlar_soni species_uz
  ].freeze

  module_function

  def sightings_count_by_plant
    @sightings_count_by_plant ||=
      PlantSighting.approved.published.where.not(plant_id: nil).group(:plant_id).count
  end

  # Guruh a'zolari (accepted_name bo'yicha) — id'lar.
  def group_ids(plant, by_accepted_name)
    plant.accepted_name.present? ? (by_accepted_name[plant.accepted_name] || [ plant.id ]) : [ plant.id ]
  end
end

namespace :plants do
  desc "O'zbekcha nomi BO'SH turlarni CSV'ga chiqarish (tmp/ozbekcha_nomlar_toldirish.csv)"
  task export_missing_uz_names: :environment do
    m = UzNamesTool
    counts = m.sightings_count_by_plant

    rows = Plant.where("species_uz IS NULL OR species_uz = ''").to_a.map do |p|
      {
        plant: p,
        n: counts[p.id].to_i,
        family: p.display_family_lat.to_s
      }
    end

    # TARTIB: (1) kuzatuvi bor turlar (kuzatuvlar_soni kamayish),
    #         (2) Qizil kitob turlari, (3) qolganlari (oila, keyin lotincha).
    rows.sort_by! do |r|
      [
        r[:n].positive? ? 0 : 1,
        -r[:n],
        r[:plant].red_book? ? 0 : 1,
        r[:family].downcase,
        r[:plant].display_sci_name.to_s.downcase
      ]
    end

    FileUtils.mkdir_p(File.dirname(m::EXPORT_PATH))
    CSV.open(m::EXPORT_PATH, 'w', encoding: 'UTF-8') do |csv|
      csv << m::EXPORT_HEADERS
      rows.each do |r|
        p = r[:plant]
        csv << [ p.id, p.species_sci, p.accepted_name, r[:family], p.species_ru,
                 p.species_kaa, (p.red_book? ? 'ha' : ''), r[:n], nil ]
      end
    end

    with_sightings = rows.count { |r| r[:n].positive? }
    red_book = rows.count { |r| r[:plant].red_book? }
    puts "#{m::EXPORT_PATH} yozildi: #{rows.size} tur (species_uz bo'sh)."
    puts "  kuzatuvi bor: #{with_sightings}, Qizil kitob: #{red_book}"
    puts "\nEndi CSV'даgi `species_uz` ustunini qo'lda to'ldiring, so'ng:"
    puts "  rails plants:import_uz_names            # dry-run"
    puts "  rails plants:import_uz_names APPLY=true # yozish"
  end

  desc "To'ldirilgan tmp/ozbekcha_nomlar_toldirish.csv dan species_uz ni import qilish (sukut: dry-run; APPLY=true)"
  task import_uz_names: :environment do
    m = UzNamesTool

    unless File.exist?(m::EXPORT_PATH)
      abort "XATO: #{m::EXPORT_PATH} topilmadi. Avval `rails plants:export_missing_uz_names`."
    end

    apply = ActiveModel::Type::Boolean.new.cast(ENV['APPLY'])
    puts(apply ? "APPLY=true — bazaga YOZILADI." : 'DRY RUN — hech narsa o`zgartirilmaydi (APPLY=true bilan yoziladi).')
    puts '=' * 60

    plants = Plant.select(:id, :species_sci, :accepted_name, :species_uz).to_a
    by_id = plants.index_by(&:id)
    by_accepted_name = plants.select { |p| p.accepted_name.present? }.group_by(&:accepted_name).transform_values { |ps| ps.map(&:id) }

    counts = Hash.new(0)
    conflicts = []
    to_write = {} # plant_id => species_uz
    missing_ids = []

    CSV.foreach(m::EXPORT_PATH, headers: true) do |row|
      name = row['species_uz'].to_s.strip
      next if name.blank? # to'ldirilmagan qator — jim o'tkaziladi

      id = row['id'].to_i
      anchor = by_id[id]
      if anchor.nil?
        missing_ids << row['id']
        counts[:TOPILMADI] += 1
        next
      end

      group = m.group_ids(anchor, by_accepted_name).map { |gid| by_id[gid] }.compact
      existing = group.filter_map { |p| p.species_uz.presence }.uniq

      if existing.any? && existing != [ name ]
        conflicts << [ id, anchor.species_sci, existing.join(' / '), name ]
        counts[:ZIDDIYAT] += 1
        next
      end

      pending = group.reject { |p| p.species_uz == name }
      if pending.empty?
        counts[:ALLAQACHON] += 1
        next
      end

      pending.each { |p| to_write[p.id] = name }
      counts[:QOSHILDI] += 1
    end

    if apply && to_write.any?
      now = Time.zone.now
      Plant.transaction do
        to_write.group_by { |_, name| name }.each do |name, pairs|
          Plant.where(id: pairs.map(&:first)).update_all(species_uz: name, updated_at: now)
        end
      end
    end

    puts "QO'SHILDI (tur):        #{counts[:QOSHILDI]}"
    puts "ALLAQACHON_BOR:         #{counts[:ALLAQACHON]}"
    puts "ZIDDIYAT:               #{counts[:ZIDDIYAT]}"
    puts "TOPILMADI (id yo'q):    #{counts[:TOPILMADI]}"
    puts "Yoziladigan yozuvlar (guruh a'zolari bilan): #{to_write.size}"

    if conflicts.any?
      puts "\nZIDDIYAT (ustiga yozilmadi) — id | species_sci | bazada | CSV:"
      conflicts.each { |id, sci, old, new| puts "  #{id} | #{sci} | #{old} | #{new}" }
    end
    puts "\nid topilmadi: #{missing_ids.join(', ')}" if missing_ids.any?

    if apply
      puts(to_write.any? ? "\nBajarildi — #{to_write.size} ta yozuv yangilandi." : "\nYoziladigan narsa yo'q.")
    else
      puts "\nBu DRY RUN edi. Haqiqiy yozish: rails plants:import_uz_names APPLY=true"
    end
  end
end
