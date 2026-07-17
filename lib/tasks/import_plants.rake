# frozen_string_literal: true
#
# O'simliklarni CSV faylidan bazaga import qiladi.
#
# Ishga tushirish (Claude Code / terminalda, loyiha ildizida):
#   rails plants:import
#
# CSV fayli `db/uzflora_plants_v3.csv` da bo'lishi kerak. CSV
# ustunlari `plants` jadvali ustunlari bilan BIR XIL nomlangan (masalan
# `family_lat`, `habitat_env`) — qo'shimcha moslashtirish shart emas.
#
# Idempotent: `species_sci` (lotincha ilmiy nom) — tabiiy kalit.
# Mavjud yozuv shu nom bo'yicha topilib YANGILANADI (id, demak
# plant_sighting.plant_id, O'ZGARMAYDI), topilmasa yangi yaratiladi.
# CSV'da yo'q eski yozuvlarga tegilmaydi — ularга bog'langan kuzatuvlar
# ham buzilmaydi.
#
# Har deploy'da 4412 qatorni qayta o'qib o'tirmaslik uchun: CSV fayl
# checksum'i (PlantImportState) bilan solishtiriladi — o'zgarmagan bo'lsa
# import O'TKAZIB YUBORILADI. Majburiy qayta import uchun:
#   rails plants:import FORCE=true
#
require 'csv'
require 'digest'

namespace :plants do
  desc 'CSV faylidan o\'simliklarni bazaga import qilish (kerak bo\'lgandagina)'
  task import: :environment do
    path = Rails.root.join('db', 'uzflora_plants_v3.csv')
    unless File.exist?(path)
      puts "XATO: #{path} topilmadi. uzflora_plants_v3.csv ni db/ papkasiga joylang."
      next
    end

    checksum = Digest::SHA256.file(path).hexdigest
    state = PlantImportState.singleton
    force = ActiveModel::Type::Boolean.new.cast(ENV['FORCE'])

    if !force && Plant.any? && state.csv_checksum == checksum
      puts "CSV o'zgarmagan (checksum bir xil) — import o'tkazib yuborildi."
      puts "  Bazada: #{Plant.count} ta o'simlik (oxirgi import: #{state.imported_at})"
      next
    end

    puts(Plant.none? ? 'Baza bo\'sh — birinchi import boshlanmoqda...' : 'CSV o\'zgargan (yoki FORCE=true) — qayta import boshlanmoqda...')

    created = 0
    updated = 0
    skipped_dup = 0
    row_num = 0
    seen_species_sci = {}

    CSV.foreach(path, headers: true) do |row|
      row_num += 1
      attrs = row.to_h

      sci = attrs['species_sci'].to_s.strip

      if sci.blank?
        puts "Qator #{row_num}: species_sci bo'sh, o'tkazib yuborildi."
        next
      end

      # Manba CSV'da bir xil species_sci ikki xil o'simlikка tegishli
      # bo'lishi mumkin (ma'lum holat: "Exochorda albertii Regel").
      # Buni jim birlashtirib yubormaymiz — ikkinchi uchrashni SKIP qilib,
      # aniq ogohlantiramiz, shunda manba xatosi ko'rinib turadi.
      if (first_row = seen_species_sci[sci])
        puts "OGOHLANTIRISH: qator #{row_num} (#{attrs['species_uz']}) — " \
             "species_sci \"#{sci}\" allaqachon #{first_row}-qatorda ishlatilgan, " \
             "o'tkazib yuborildi (manba CSV'da takror/xato bo'lishi mumkin)."
        skipped_dup += 1
        next
      end
      seen_species_sci[sci] = row_num

      attrs.delete('id')
      attrs.each { |k, v| attrs[k] = nil if v.nil? || v.to_s.strip.empty? }
      attrs['red_book'] = %w[true True TRUE 1].include?(attrs['red_book'].to_s)

      plant = Plant.find_or_initialize_by(species_sci: sci)
      was_new = plant.new_record?
      plant.assign_attributes(attrs)

      if plant.save
        was_new ? (created += 1) : (updated += 1)
      else
        puts "Qator #{row_num} saqlanmadi: #{plant.errors.full_messages.join(', ')}"
      end

      puts "  ...#{row_num} qator ishlandi" if (row_num % 500).zero?
    end

    state.update!(csv_checksum: checksum, row_count: row_num, imported_at: Time.zone.now)

    puts '=' * 50
    puts 'Import tugadi!'
    puts "  Yangi qo'shilgan: #{created}"
    puts "  Yangilangan:      #{updated}"
    puts "  Takror/xato sabab o'tkazib yuborilgan: #{skipped_dup}" if skipped_dup.positive?
    puts "  Jami bazada:      #{Plant.count}"
    puts "  Qizil kitobda:    #{Plant.where(red_book: true).count}"
  end

  desc 'Barcha o\'simliklarni bazadan o\'chirish (ehtiyot bo\'ling!)'
  task clear: :environment do
    count = Plant.count
    Plant.delete_all
    PlantImportState.delete_all
    puts "#{count} ta o'simlik o'chirildi."
  end
end
