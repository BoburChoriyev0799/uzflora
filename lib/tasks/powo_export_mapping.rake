# frozen_string_literal: true
#
# `Powo::Matcher` (lib/powo/matcher.rb) yordamida WCVP bilan solishtiruv
# natijasini `db/powo_mapping.csv` fayliga yozadi. FAQAT O'QIYDI — bazaga
# hech narsa yozmaydi.
#
# NEGA FAYLGA CHIQARAMIZ: `db/external/wcvp_names.csv` (WCVP manba fayli,
# ~287MB) .gitignore'da — u Render serverida YO'Q. Shuning uchun
# `plants:powo_apply` prod serverida to'g'ridan-to'g'ri WCVP'ni o'qiy
# olmaydi. Yechim: bu task WCVP bilan solishtirishni FAQAT lokalda (yoki
# WCVP fayli bor har qanday muhitda) bir marta bajaradi, natijani kichik
# CSV'ga yozadi, shu CSV COMMIT QILINADI va `plants:powo_apply` endi
# FAQAT shu CSV'ni o'qiydi — WCVP yoki Powo::Matcher'ga umuman muhtoj
# emas.
#
# Ishga tushirish:
#   rails plants:powo_export_mapping
require 'csv'
require Rails.root.join('lib', 'powo', 'matcher')

MAPPING_HEADERS = %w[
  species_sci wcvp_matched_name wcvp_status accepted_name accepted_authors
  accepted_family accepted_genus accepted_rank powo_id powo_match_type
].freeze

OVERRIDES_PATH = Rails.root.join('db', 'powo_overrides.csv')
OVERRIDE_VALUE_COLUMNS = %w[accepted_name accepted_authors accepted_family accepted_genus powo_id].freeze

# db/powo_overrides.csv (commit qilinadigan, qo'lda tahrirlanadigan fayl) —
# WCVP zanjiri botanik jihatdan noto'g'ri natija bergan yoki hali qaror
# qilinmagan (accepted_name ATAYLAB bo'sh) holatlar uchun Boburning qo'lda
# qabul qilgan qarorlarini USTIDAN yozadi. `mapping_rows` — species_sci =>
# row Hash (yuqoridagi `rows`dan `index_by` bilan) — JOYIDA (in-place)
# o'zgartiriladi. `wcvp_matched_name`/`wcvp_status`ga TEGILMAYDI — ular
# WCVP'dan qanday hisoblangan bo'lsa, shundayligicha qoladi.
def apply_powo_overrides!(mapping_rows_by_sci)
  return unless File.exist?(OVERRIDES_PATH)

  applied = 0
  CSV.foreach(OVERRIDES_PATH, headers: true, skip_lines: /\A#/) do |orow|
    sci = orow['species_sci']
    target = mapping_rows_by_sci[sci]
    if target.nil?
      puts "OGOHLANTIRISH: db/powo_overrides.csv da '#{sci}' bazada topilmadi " \
           "(species_sci mos kelmadi — imlo xatosi bo'lishi mumkin), o'tkazib yuborildi."
      next
    end

    OVERRIDE_VALUE_COLUMNS.each { |col| target[col] = orow[col] }
    # accepted_name bo'sh (hali qaror qilinmagan, "kutib turibdi") bo'lsa,
    # accepted_rank ham bo'sh qoladi — mazmunsiz "Species" yozib
    # qo'yilmaydi. To'ldirilgan bo'lsa, standart WCVP formatiga mos
    # ravishda Bosh-harf bilan ("Species"/"Subspecies"/...), bo'sh
    # qoldirilgan bo'lsa "Species" deb olinadi (spetsifikatsiya bo'yicha).
    target['accepted_rank'] =
      if orow['accepted_name'].present?
        rank = orow['accepted_rank'].to_s.strip
        rank.present? ? rank.capitalize : 'Species'
      end
    target['powo_match_type'] = 'manual_override'
    applied += 1
  end
  puts "\ndb/powo_overrides.csv qo'llanildi: #{applied} ta qator qo'lda tuzatilgan qiymat bilan almashtirildi."
end

namespace :plants do
  desc "Powo::Matcher natijasini db/powo_mapping.csv ga yozish (commit qilinadigan, kichik fayl)"
  task powo_export_mapping: :environment do
    begin
      results = Powo::Matcher.run(log: ->(msg) { puts msg })
    rescue RuntimeError => e
      puts "XATO: #{e.message}"
      next
    end

    puts "\nMapping fayli tuzilmoqda..."
    rows = results.map { |r|
      matched = r[:chosen_row]
      final = r[:final]
      {
        'species_sci' => r[:species_sci],
        'wcvp_matched_name' => matched ? "#{matched[:taxon_name]} #{matched[:taxon_authors]}".strip : nil,
        'wcvp_status' => matched&.fetch(:status, nil),
        'accepted_name' => final&.fetch(:taxon_name, nil),
        'accepted_authors' => final&.fetch(:taxon_authors, nil),
        'accepted_family' => final&.fetch(:family, nil),
        'accepted_genus' => final&.fetch(:genus, nil),
        'accepted_rank' => final&.fetch(:rank, nil),
        'powo_id' => final&.fetch(:powo_id, nil),
        'powo_match_type' => r[:match_type].to_s
      }
    }

    apply_powo_overrides!(rows.index_by { |row| row['species_sci'] })

    # Alifbo tartibi: fayl qayta yaratilganda git diff toza/qisqa bo'lishi
    # uchun (aks holda Plant.order(:id) tartibida ham chiqishi mumkin edi,
    # lekin id o'zi ma'nosiz ma'lumot — species_sci esa barqaror kalit).
    rows.sort_by! { |row| row['species_sci'].to_s }

    path = Rails.root.join('db', 'powo_mapping.csv')
    CSV.open(path, 'w', encoding: 'UTF-8') do |csv|
      csv << MAPPING_HEADERS
      rows.each { |row| csv << MAPPING_HEADERS.map { |h| row[h] } }
    end

    size_kb = (File.size(path) / 1024.0).round(1)
    puts "\n#{'=' * 60}"
    puts "db/powo_mapping.csv yozildi: #{rows.size} qator, #{size_kb} KB"
    puts "  match_type bo'yicha:"
    rows.group_by { |row| row['powo_match_type'] }.sort_by { |_k, v| -v.size }.each do |type, group|
      puts "    #{type}: #{group.size}"
    end
  end
end
