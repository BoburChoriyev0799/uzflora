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

# PPG I ni saqlaymiz: WCVP paporotniklarni Polypodiaceae/Aspleniaceae s.l.
# ichiga lumping qiladi (Christenhusz & Chase 2014) — bu zamonaviy PPG I
# (2016) tasnifiga zid. Agar WCVP bergan accepted_family shu ro'yxatdagi
# qiymatlardan biri bo'lsa VA bazadagi mavjud family_lat undan (katta-
# kichik harf/bo'shliqni hisobga olmasdan) farq qilsa VA family_lat bo'sh
# bo'lmasa — accepted_family O'RNIGA bazadagi family_lat yoziladi. FAQAT
# accepted_family'ga tegishli — accepted_name/accepted_genus/
# accepted_authors/powo_id O'ZGARMAYDI (aynan shu nom WCVP'da shu id bilan
# tasdiqlangan, faqat oila tasnifi qaysi tizimga amal qilishimiz haqidagi
# masala).
WCVP_KENG_PAPOROTNIK_OILALARI = %w[Polypodiaceae Aspleniaceae].freeze

def bare_family_for_compare(value)
  Powo::Matcher.bare_family(value).to_s.strip.downcase
end

OVERRIDES_PATH = Rails.root.join('db', 'powo_overrides.csv')
OVERRIDE_VALUE_COLUMNS = %w[accepted_name accepted_authors accepted_family accepted_genus powo_id].freeze

# db/powo_overrides.csv (commit qilinadigan, qo'lda tahrirlanadigan fayl) —
# WCVP zanjiri botanik jihatdan noto'g'ri natija bergan yoki hali qaror
# qilinmagan holatlar uchun Boburning qo'lda qabul qilgan qarorlarini
# USTIDAN yozadi. `mapping_rows` — species_sci => row Hash (yuqoridagi
# `rows`dan `index_by` bilan) — JOYIDA (in-place) o'zgartiriladi.
#
# Har bir qator UCH holatdan BIRIGA to'g'ri keladi (ustuvorlik tartibida):
#   1. `accepted_name` TO'LDIRILGAN — to'g'ridan-to'g'ri qo'lda tuzatish
#      (`manual_override`): accepted_*/powo_id shu qatordagi qiymatlar
#      bilan USTIDAN yoziladi. `wcvp_matched_name`/`wcvp_status`ga
#      TEGILMAYDI — ular WCVP'dan qanday hisoblangan bo'lsa, shundayligicha
#      qoladi.
#   2. `accepted_name` BO'SH, lekin `wcvp_name` TO'LDIRILGAN — TAXALLUS
#      (`manual_alias`): "bazadagi bu species_sci aslida WCVP'da ANA U nom"
#      degani (masalan bazada turkum nomi xato terilgan). `wcvp_name`
#      WCVP faylida qidiriladi (`Powo::Matcher.resolve_wcvp_name_aliases`),
#      topilsa — wcvp_matched_name/wcvp_status/accepted_*/powo_id HAMMASI
#      shu natijadan AVTOMATIK to'ldiriladi, qo'lda yozish shart emas.
#      Agar `wcvp_name` WCVP'da topilmasa yoki bir nechta yozuvga mos kelib
#      muallif orqali ham ajratib bo'lmasa — OGOHLANTIRISH chiqariladi va
#      qator TEGILMAY, avvalgi (asosiy quvurdan kelgan) holatida qoladi.
#   3. Ikkalasi ham BO'SH — "hali qaror qilinmagan, kutib turibdi": faqat
#      `powo_match_type` "manual_override" bo'lib belgilanadi (WCVP'ning
#      o'z, ehtimol noto'g'ri, avtomatik xulosasi ustidan bo'sh bilan
#      YOZILADI), accepted_* bazaga bo'sh yoziladi — POWO'siz holat.
def apply_powo_overrides!(mapping_rows_by_sci)
  return unless File.exist?(OVERRIDES_PATH)

  override_rows = CSV.read(OVERRIDES_PATH, headers: true, skip_lines: /\A#/)

  alias_wcvp_names = override_rows.filter_map { |r| r['wcvp_name'] if r['accepted_name'].blank? && r['wcvp_name'].present? }
  alias_results = Powo::Matcher.resolve_wcvp_name_aliases(alias_wcvp_names, log: ->(msg) { puts msg })

  applied = 0
  override_rows.each do |orow|
    sci = orow['species_sci']
    target = mapping_rows_by_sci[sci]
    if target.nil?
      puts "OGOHLANTIRISH: db/powo_overrides.csv da '#{sci}' bazada topilmadi " \
           "(species_sci mos kelmadi — imlo xatosi bo'lishi mumkin), o'tkazib yuborildi."
      next
    end

    wcvp_name = orow['wcvp_name']

    if orow['accepted_name'].present?
      OVERRIDE_VALUE_COLUMNS.each { |col| target[col] = orow[col] }
      rank = orow['accepted_rank'].to_s.strip
      target['accepted_rank'] = rank.present? ? rank.capitalize : 'Species'
      target['powo_match_type'] = 'manual_override'
      applied += 1
    elsif wcvp_name.present?
      result = alias_results[wcvp_name]
      case result&.fetch(:status, nil)
      when :resolved
        chosen = result[:chosen_row]
        final = result[:final]
        target['wcvp_matched_name'] = "#{chosen[:taxon_name]} #{chosen[:taxon_authors]}".strip
        target['wcvp_status'] = chosen[:status]
        target['accepted_name'] = final&.fetch(:taxon_name, nil)
        target['accepted_authors'] = final&.fetch(:taxon_authors, nil)
        target['accepted_family'] = final&.fetch(:family, nil)
        target['accepted_genus'] = final&.fetch(:genus, nil)
        target['accepted_rank'] = final&.fetch(:rank, nil)
        target['powo_id'] = final&.fetch(:powo_id, nil)
        target['powo_match_type'] = 'manual_alias'
        applied += 1
      when :ambiguous
        puts "OGOHLANTIRISH: '#{sci}' uchun wcvp_name '#{wcvp_name}' WCVP'da bir nechta yozuvga mos keldi " \
             "(#{result[:options].join('; ')}) — hal qilinmadi, qator TEGILMADI."
      else
        puts "OGOHLANTIRISH: '#{sci}' uchun wcvp_name '#{wcvp_name}' WCVP'da topilmadi — hal qilinmadi, qator TEGILMADI."
      end
    else
      # Ikkalasi ham bo'sh — "kutib turibdi". Asosiy quvur (Powo::Matcher.run)
      # bu yozuv uchun allaqachon o'z automatik xulosasini (masalan
      # distribution_resolved) `target`ga yozib qo'ygan bo'lishi mumkin —
      # OVERRIDE_VALUE_COLUMNS'ni ATAYLAB bo'sh qiymat bilan USTIDAN yozib,
      # o'sha automatik xulosani bekor qilamiz (aks holda "kutib turibdi"
      # deb belgilangan qator baribir avtomatik nom bilan chiqib qolardi).
      OVERRIDE_VALUE_COLUMNS.each { |col| target[col] = nil }
      target['accepted_rank'] = nil
      target['powo_match_type'] = 'manual_override'
      applied += 1
    end
  end
  puts "\ndb/powo_overrides.csv qo'llanildi: #{applied} ta qator qo'lda tuzatilgan/taxallus qiymati bilan almashtirildi."
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
      wcvp_family = final&.fetch(:family, nil)
      db_family = r[:csv_family]
      accepted_family =
        if WCVP_KENG_PAPOROTNIK_OILALARI.include?(wcvp_family.to_s) &&
           db_family.present? &&
           bare_family_for_compare(db_family) != bare_family_for_compare(wcvp_family)
          db_family
        else
          wcvp_family
        end
      {
        'species_sci' => r[:species_sci],
        'wcvp_matched_name' => matched ? "#{matched[:taxon_name]} #{matched[:taxon_authors]}".strip : nil,
        'wcvp_status' => matched&.fetch(:status, nil),
        'accepted_name' => final&.fetch(:taxon_name, nil),
        'accepted_authors' => final&.fetch(:taxon_authors, nil),
        'accepted_family' => accepted_family,
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
