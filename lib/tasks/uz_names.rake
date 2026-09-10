# frozen_string_literal: true
#
# O'zbekcha nom (`plants.species_uz`) BO'SH turlar uchun QO'LDA to'ldirish
# vositasi. Nomlar O'YLAB TOPILMAYDI — foydalanuvchi (Bobur) qo'lda
# to'ldiradi, keyin import qiladi.
#
# ASOSIY YO'L — ActiveAdmin > O'simliklar:
#   - "O'zbekcha nomlar CSV" tugmasi (eksport)
#   - "O'zbekcha nomlarni yuklash" sahifasi (ko'rib chiqish + tasdiqlash)
#
# Rake (dev muhitда yoki repoga commit qilib import qilish uchun):
#   rails plants:export_missing_uz_names
#     -> tmp/ozbekcha_nomlar_toldirish.csv
#   rails plants:import_uz_names                          # dry-run
#   rails plants:import_uz_names APPLY=true               # yozadi
#   rails plants:import_uz_names FILE=db/ozbekcha_nomlar.csv APPLY=true
#     -> tmp/ o'rniga boshqa fayldan (repoga commit qilinganдан ham)
#
# MANTIQ `app/services/uz_names_import.rb` (UzNamesImport) da — admin
# sahifasi bilan BITTA manba. Eksport tartibi `UzNamesExport` da.
require 'csv'

module UzNamesTool
  EXPORT_PATH = Rails.root.join('tmp', 'ozbekcha_nomlar_toldirish.csv')
  EXPORT_HEADERS = UzNamesExport::HEADERS
end

namespace :plants do
  desc "O'zbekcha nomi BO'SH turlarni CSV'ga chiqarish (odatiy yo'l — ActiveAdmin 'O'zbekcha nomlar CSV' tugmasi)"
  task export_missing_uz_names: :environment do
    m = UzNamesTool
    rows = UzNamesExport.rows

    FileUtils.mkdir_p(File.dirname(m::EXPORT_PATH))
    File.write(m::EXPORT_PATH, UzNamesExport.to_csv)

    with_sightings = rows.count { |r| r[:n].positive? }
    red_book = rows.count { |r| r[:plant].red_book? }
    puts "#{m::EXPORT_PATH} yozildi: #{rows.size} tur (species_uz bo'sh)."
    puts "  kuzatuvi bor: #{with_sightings}, Qizil kitob: #{red_book}"
    puts "\nEndi CSV'даgi `species_uz` ustunini qo'lda to'ldiring, so'ng:"
    puts "  rails plants:import_uz_names            # dry-run"
    puts "  rails plants:import_uz_names APPLY=true # yozish"
  end

  desc "To'ldirilgan CSV'дан species_uz import (sukut: dry-run; APPLY=true; FILE=... — boshqa fayl)"
  task import_uz_names: :environment do
    path = ENV['FILE'].presence ? Pathname.new(ENV['FILE']) : UzNamesTool::EXPORT_PATH
    path = Rails.root.join(path) unless path.absolute?

    unless File.exist?(path)
      abort "XATO: #{path} topilmadi. Avval `rails plants:export_missing_uz_names` yoki FILE=... bering."
    end

    apply = ActiveModel::Type::Boolean.new.cast(ENV['APPLY'])
    puts(apply ? "APPLY=true — bazaga YOZILADI." : 'DRY RUN — hech narsa o`zgartirilmaydi (APPLY=true bilan yoziladi).')
    puts "Fayl: #{path}"
    puts '=' * 60

    begin
      plan = UzNamesImport.plan(File.read(path))
    rescue UzNamesImport::InvalidFile => e
      abort "XATO: #{e.message}"
    end

    puts "QO'SHILADI (tur):       #{plan.added}"
    puts "ALLAQACHON_BOR:         #{plan.already}"
    puts "ZIDDIYAT:               #{plan.conflicts.size}"
    puts "TOPILMADI (id yo'q):    #{plan.not_found_ids.size}"
    puts "Bo'sh qator (o'tkazildi): #{plan.skipped_blank}"
    puts "Yoziladigan yozuvlar (guruh a'zolari bilan): #{plan.write_count}"

    if plan.conflicts.any?
      puts "\nZIDDIYAT (ustiga yozilmadi) — id | species_sci | bazada | CSV:"
      plan.conflicts.each { |c| puts "  #{c[:id]} | #{c[:species_sci]} | #{c[:existing]} | #{c[:csv]}" }
    end
    puts "\nid topilmadi: #{plan.not_found_ids.join(', ')}" if plan.not_found_ids.any?

    if apply
      n = UzNamesImport.apply!(plan)
      puts(n.positive? ? "\nBajarildi — #{n} ta yozuv yangilandi." : "\nYoziladigan narsa yo'q.")
    else
      puts "\nBu DRY RUN edi. Haqiqiy yozish: APPLY=true"
    end
  end
end
