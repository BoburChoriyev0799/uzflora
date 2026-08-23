# frozen_string_literal: true
#
# WCVP (Kew/POWO) solishtiruv natijasini `plants` jadvaliga YOZADI (yangi
# `wcvp_*`/`accepted_*`/`powo_*` ustunlar — 20260823135843_add_powo_fields
# _to_plants.rb migratsiyasiga qarang).
#
# BU TASK ENDI WCVP FAYLINI HAM, `Powo::Matcher`NI HAM O'QIMAYDI — faqat
# `db/powo_mapping.csv` (commit qilingan, kichik fayl,
# `plants:powo_export_mapping` orqali oldindan tayyorlanadi) dan o'qiydi.
# Buning uch sababi bor:
#   1. Serverda (Render) `db/external/wcvp_names.csv` YO'Q — u .gitignore'da,
#      ~287MB, hech qachon commit qilinmaydi. Agar bu task to'g'ridan-to'g'ri
#      WCVP'ni o'qishga urinsa, prod'da shunchaki ISHLAMAYDI.
#   2. Qo'llash amali shu bilan TAKRORLANADIGAN (reproducible) bo'ladi:
#      bazaga nima yozilishi — commit qilingan CSV faylda oldindan ko'rinib
#      turadi, "qora quti" emas (kod o'qiganlar aynan qaysi qiymat qaysi
#      o'simlikka yozilishini fayldan ko'ra oladi, kodni ishga tushirmasdan).
#   3. Moslik mantiqi (`lib/powo/matcher.rb`) o'zgarsa, avval
#      `plants:powo_export_mapping` bilan mapping fayli QAYTA yaratiladi va
#      shu o'zgarishning o'zi git diff'da alohida, ko'rinadigan qadam
#      bo'ladi — WCVP tahlili va bazaga yozish ENDI ikkita mustaqil qadam.
#
# `species_sci` ustuniga UMUMAN TEGILMAYDI — u CSV importining (
# lib/tasks/import_plants.rake) tabiiy kaliti bo'lib qoladi, shu bilan
# birga mapping faylida ham QIDIRUV KALITI sifatida ishlatiladi.
#
# Faqat XAVFSIZ deb topilgan match_type'lar yoziladi:
#   exact_full, exact_name_unique, name_multi_author_ok, canon_exact,
#   canon_fuzzy1
# Qolganlari (name_ambiguous, canon_ambiguous, not_found,
# name_multi_family_ok) uchun ustunlar BO'SH qoladi — keyinroq qo'lda
# ko'rib chiqiladi.
#
# Sukut bo'yicha DRY RUN: nima yozilishi ekranga chiqariladi, bazaga HECH
# NARSA yozilmaydi. Haqiqiy yozish uchun:
#   rails plants:powo_apply APPLY=true
#
# Qayta-qayta yugurtirilsa BIR XIL natija beradi (idempotent) — chunki har
# safar mapping faylidan qaytadan hisoblanadi va bir xil ustunlar ustidan
# to'liq YOZIB QO'YILADI (accumulate qilinmaydi).
require 'csv'

MAPPING_PATH = Rails.root.join('db', 'powo_mapping.csv')
POWO_SAFE_MATCH_TYPES = %w[exact_full exact_name_unique name_multi_author_ok canon_exact canon_fuzzy1].freeze
POWO_APPLY_COLUMNS = %i[
  wcvp_matched_name wcvp_status accepted_name accepted_authors
  accepted_family accepted_genus accepted_rank powo_id powo_match_type
].freeze

namespace :plants do
  desc "db/powo_mapping.csv asosida plants jadvaliga WCVP moslik ma'lumotini yozish (sukut: dry-run, APPLY=true — haqiqiy yozish)"
  task powo_apply: :environment do
    unless File.exist?(MAPPING_PATH)
      puts "XATO: #{MAPPING_PATH} topilmadi."
      puts "Avval `rails plants:powo_export_mapping` ni yugurtiring (bu WCVP faylini talab qiladi)."
      next
    end

    apply = ActiveModel::Type::Boolean.new.cast(ENV['APPLY'])
    puts(apply ? "APPLY=true — o'zgarishlar HAQIQATAN bazaga yoziladi." : "DRY RUN — hech narsa o'zgartirilmaydi (haqiqiy yozish uchun APPLY=true bering).")
    puts '=' * 60

    mapping_by_sci = {}
    CSV.foreach(MAPPING_PATH, headers: true) do |row|
      mapping_by_sci[row['species_sci']] = row
    end
    puts "Mapping fayl o'qildi: #{mapping_by_sci.size} qator."

    plants = Plant.select(:id, :species_sci, *POWO_APPLY_COLUMNS).order(:id).to_a
    now = Time.zone.now
    to_write = []
    blank_count = 0
    no_accepted_count = 0
    unmapped_count = 0

    plants.each do |plant|
      row = mapping_by_sci[plant.species_sci]
      if row.nil?
        # Mapping fayl bazadan eskirgan bo'lishi mumkin (masalan CSV
        # import'dan keyingi yangi tur qo'shilgan, lekin mapping hali
        # qayta eksport qilinmagan) — bu yozuvga tegmaymiz, xavfsiz
        # tomonga og'amiz.
        unmapped_count += 1
        next
      end

      match_type = row['powo_match_type'].to_s
      unless POWO_SAFE_MATCH_TYPES.include?(match_type)
        blank_count += 1
        next
      end

      no_accepted_count += 1 if row['accepted_name'].blank?

      new_attrs = {
        wcvp_matched_name: row['wcvp_matched_name'],
        wcvp_status: row['wcvp_status'],
        accepted_name: row['accepted_name'],
        accepted_authors: row['accepted_authors'],
        accepted_family: row['accepted_family'],
        accepted_genus: row['accepted_genus'],
        accepted_rank: row['accepted_rank'],
        powo_id: row['powo_id'],
        powo_match_type: match_type
      }

      changed = POWO_APPLY_COLUMNS.any? { |col| plant.public_send(col).to_s != new_attrs[col].to_s }

      to_write << { id: plant.id, changed: changed, attrs: new_attrs.merge(powo_matched_at: now) }
    end

    changed_count = to_write.count { |w| w[:changed] }
    unchanged_count = to_write.count { |w| !w[:changed] }

    puts "\n#{'=' * 60}"
    puts "match_type bo'yicha (mapping fayldagi, yoziladigan turlar):"
    POWO_SAFE_MATCH_TYPES.each do |type|
      n = mapping_by_sci.values.count { |row| row['powo_match_type'] == type }
      puts "  #{type}: #{n}"
    end

    puts "\nYoziladi (jami, xavfsiz match_type): #{to_write.size}"
    puts "  ...Yangilanadi (qiymat o'zgaradi): #{changed_count}"
    puts "  ...O'zgarishsiz qoladi (qiymat allaqachon bir xil): #{unchanged_count}"
    puts "  ...shundan #{no_accepted_count} tasida wcvp_matched_name/wcvp_status BOR, lekin accepted_* BO'SH (WCVP'da topilgan, lekin holati Accepted/Synonym emas)"
    puts "Bo'sh qoladi (match_type xavfsiz ro'yxatda emas — #{POWO_SAFE_MATCH_TYPES.join(', ')} dan tashqari): #{blank_count}"
    puts "Mapping faylda topilmadi (eskirgan bo'lishi mumkin, tegilmadi): #{unmapped_count}" if unmapped_count.positive?
    puts "Jami: #{to_write.size + blank_count + unmapped_count} (bazadagi #{plants.size} taga teng bo'lishi kerak)"

    if apply
      rows_to_upsert = to_write.select { |w| w[:changed] }.map { |w| w[:attrs].merge(id: w[:id]) }

      if rows_to_upsert.any?
        ActiveRecord::Base.transaction do
          Plant.upsert_all(rows_to_upsert, unique_by: :id, update_only: [ *POWO_APPLY_COLUMNS, :powo_matched_at ])
        end
        puts "\nBajarildi — #{rows_to_upsert.size} ta yozuv bazaga yozildi (bitta transaction ichida)."
      else
        puts "\nYozadigan hech narsa yo'q — hammasi allaqachon bir xil."
      end
    else
      puts "\nBu DRY RUN edi — hech narsa o'zgarmadi. Haqiqiy yozish uchun: rails plants:powo_apply APPLY=true"
    end
  end
end
