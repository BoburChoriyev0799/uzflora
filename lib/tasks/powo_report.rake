# frozen_string_literal: true
#
# WCVP (World Checklist of Vascular Plants — Kew/POWO manba bazasi) bilan
# solishtiruv HISOBOTI. FAQAT O'QIYDI — bazaga (Plant va h.k.) hech qanday
# yozish amali (update/delete/insert) yo'q. Solishtirish MEXANIZMI (nom
# normallashtirish, aniq/kanonik/fuzzy moslik) `lib/powo/matcher.rb` da —
# bu yerda FAQAT hisobot fayllarini (tmp/powo_*.csv) yozish va statistika
# chiqarish bor. `plants:powo_apply` (lib/tasks/powo_apply.rake, bazaga
# YOZADI) ham xuddi shu `Powo::Matcher.run` ni chaqiradi — shu sabab
# ikkalasi HAR DOIM bir xil natijani ko'rsatadi.
#
# Ishga tushirish:
#   rails plants:powo_report
#
# Talab: db/external/wcvp_names.csv (WCVP arxividan chiqarilgan, `|`
# ajratgichli, ~287MB, ~1.45 million qator). Bu fayl COMMIT QILINMAYDI
# (.gitignore'da /db/external/).
#
require 'csv'
require Rails.root.join('lib', 'powo', 'matcher')

# Avtomatik ravishda "nomi o'zgaradi" deb hisoblanmaydigan (qabul
# qilingan/sinonim bo'lmagan) WCVP holatlari uchun o'zbekcha izoh.
POWO_STATUS_NOTES_UZ = {
  'Misapplied' => "Noto'g'ri qo'llangan nom (Misapplied) — boshqa turga ishora qilishi mumkin, AVTOMATIK ALMASHTIRILMAYDI, qo'lda tekshirilsin.",
  'Illegitimate' => 'WCVP holati: Illegitimate (nomenklatura qoidalariga zid chop etilgan) — qo\'lda ko\'rib chiqilsin.',
  'Invalid' => "WCVP holati: Invalid (yaroqsiz chop etilgan) — qo'lda ko'rib chiqilsin.",
  'Orthographic' => "WCVP holati: Orthographic (imlo varianti) — qo'lda ko'rib chiqilsin.",
  'Unplaced' => "WCVP holati: Unplaced (taksonomik joyi aniqlanmagan) — qo'lda ko'rib chiqilsin.",
  'Local Biotype' => "WCVP holati: Local Biotype — qo'lda ko'rib chiqilsin.",
  'Artificial Hybrid' => "WCVP holati: Artificial Hybrid (sun'iy duragay) — qo'lda ko'rib chiqilsin."
}.freeze

# "topilmadi" deb chiqqan o'simliklar uchun — shu o'simlikning turkumi
# bo'yicha WCVP'dagi barcha "Species" darajali nomlarni yig'ib beradi
# (eng yaqin nomzodlarni taklif qilish uchun, FAQAT hisobot uchun,
# avtomatik qo'llanmaydi).
def powo_collect_genus_candidates(genera_needed)
  buckets = Hash.new { |h, k| h[k] = [] }
  return buckets if genera_needed.empty?

  File.open(Powo::Matcher::WCVP_PATH, 'r:UTF-8') do |io|
    col = Powo::Matcher.read_wcvp_header(io)
    io.each_line do |line|
      fields = line.chomp.split('|', -1)
      next unless fields[col['taxon_rank']] == 'Species'

      genus_norm = Powo::Matcher.normalize_name_for_match(fields[col['genus']].to_s)
      next unless genera_needed.include?(genus_norm)

      buckets[genus_norm] << {
        name: fields[col['taxon_name']],
        authors: fields[col['taxon_authors']],
        status: fields[col['taxon_status']]
      }
    end
  end
  buckets
end

def powo_nearest_candidates_for(norm_name, pool, limit: 3)
  return [] if pool.blank?

  # Arzon oldindan filtr: uzunlik farqi katta bo'lganlarni Levenshtein
  # hisoblashdan oldin chetlab o'tamiz (katta turkumlarda tezlik uchun).
  scored = pool.filter_map { |cand|
    cand_norm = Powo::Matcher.normalize_name_for_match(cand[:name])
    next if (cand_norm.length - norm_name.length).abs > 10

    [ Powo::Matcher.levenshtein(norm_name, cand_norm), cand ]
  }
  scored.sort_by { |dist, _| dist }.first(limit).map { |dist, cand| cand.merge(distance: dist) }
end

def powo_csv_write_with_bom(path, headers, rows)
  File.open(path, 'wb') do |f|
    f.write("\xEF\xBB\xBF".b)
    csv = CSV.new(f)
    csv << headers
    rows.each { |row| csv << row }
  end
end

namespace :plants do
  desc "Bazadagi o'simlik nomlarini WCVP (Kew/POWO) bilan solishtirib hisobot chiqarish (FAQAT o'qiydi, bazaga yozmaydi)"
  task powo_report: :environment do
    begin
      results = Powo::Matcher.run(log: ->(msg) { puts msg })
    rescue RuntimeError => e
      puts "XATO: #{e.message}"
      next
    end

    not_found_results = results.select { |r| r[:match_type] == :not_found }
    ambiguous_results = results.select { |r| r[:match_type] == :name_ambiguous }
    canon_ambiguous_results = results.select { |r| r[:match_type] == :canon_ambiguous }
    cyrillic_results = results.select { |r| r[:has_cyrillic] }

    puts "\n'Topilmadi' uchun turkum bo'yicha eng yaqin nomzodlar qidirilmoqda..."
    genera_needed = not_found_results.map { |r| Powo::Matcher.normalize_name_for_match(Powo::Matcher.bare_genus(r[:csv_genus])) }.reject(&:blank?).to_set
    genus_candidates = powo_collect_genus_candidates(genera_needed)

    puts 'Hisobot fayllari yozilmoqda...'

    # --- A) tmp/powo_report_full.csv -----------------------------------
    full_headers = %w[
      id species_sci species_uz species_ru csv_family csv_genus
      match_type wcvp_status accepted_name accepted_authors
      accepted_family accepted_genus accepted_rank powo_id powo_url
      genus_changed family_changed izoh
    ]

    full_rows = results.map { |r|
      final = r[:final]
      genus_changed = family_changed = ''
      if final
        genus_changed = (Powo::Matcher.bare_genus(r[:csv_genus]).downcase == Powo::Matcher.bare_genus(final[:genus]).downcase) ? "yo'q" : 'ha' if r[:csv_genus].present? && final[:genus].present?
        family_changed = (Powo::Matcher.bare_family(r[:csv_family]).downcase == Powo::Matcher.bare_family(final[:family]).downcase) ? "yo'q" : 'ha' if r[:csv_family].present? && final[:family].present?
      end

      izoh =
        case r[:match_type]
        when :not_found
          "WCVP'da bunday tur nomi topilmadi" + (r[:canon_excluded] ? " (xavfsizlik chegarasi tufayli kanonik/fuzzy urinish QILINMADI — sp./aff./cf./ined./nom. nud. yoki juda qisqa epitet)" : ' (kanonik/fuzzy urinishdan keyin ham)')
        when :name_ambiguous
          "Nomi WCVP'da #{r[:candidates].size} ta yozuvga mos keldi, muallif va oila orqali ham hal qilib bo'lmadi (omonim)"
        when :canon_ambiguous
          "Kanonik/fuzzy qidiruv bir nechta TURLI qabul qilingan nomga olib keldi — qo'lda hal qilinsin"
        else
          case r[:outcome]
          when :accepted then "WCVP'da 'Accepted' — nom to'g'ri, o'zgarish kerak emas"
          when :synonym_resolved then "Sinonim — qabul qilingan nomga o'tkazish TAVSIYA ETILADI"
          when :defective_resolved
            "WCVP holati: #{r[:chosen_row][:status]} (nomenklatura nuqsoni), lekin 'accepted_plant_name_id' " \
            "orqali qabul qilingan nomga zanjir topildi — o'tkazish TAVSIYA ETILADI"
          when :ambiguous_same_target
            "Omonim edi, lekin BARCHA nomzodlar bir xil accepted turga borgani aniqlandi — noaniqlik yo'q, TAVSIYA ETILADI"
          when :distribution_resolved
            introduced_note = r[:distribution_introduced_only] ? " [FAQAT introduced — Bobur ko'zdan kechirsin]" : ''
            "Omonim edi, lekin FAQAT bitta nomzod O'zbekistonda (WCVP tarqalish ma'lumoti) uchraydi — " \
            "o'tkazish TAVSIYA ETILADI#{introduced_note}"
          when :canon_recovered then "IMLO farqi tufayli avvalgi bosqichda topilmagan edi — kanonik kalit orqali TIKLANDI (#{r[:match_type]}), nom TAVSIYA ETILADI"
          when :unresolved then "Sinonim, lekin 'accepted' yozuv topilmadi/aniqlanmadi — qo'lda tekshirilsin"
          when :chain_loop then "WCVP holati: #{r[:chosen_row][:status]}, lekin accepted_plant_name_id zanjirida HALQA topildi — qo'lda tekshirilsin"
          else POWO_STATUS_NOTES_UZ[r[:chosen_row]&.fetch(:status, nil)] || (r[:chosen_row] ? "WCVP holati: #{r[:chosen_row][:status]}" : '')
          end
        end
      izoh += ' [MANBADA KIRILL HARF BOR — tmp/powo_cyrillic.csv ga qarang]' if r[:has_cyrillic]

      wcvp_status = r[:chosen_row]&.fetch(:status, nil)

      [
        r[:id], r[:species_sci], r[:species_uz], r[:species_ru], r[:csv_family], r[:csv_genus],
        r[:match_type], wcvp_status,
        final&.fetch(:taxon_name, nil), final&.fetch(:taxon_authors, nil),
        final&.fetch(:family, nil), final&.fetch(:genus, nil), final&.fetch(:rank, nil),
        final&.fetch(:powo_id, nil), Powo::Matcher.powo_url_for(final&.fetch(:powo_id, nil)),
        genus_changed, family_changed, izoh
      ]
    }
    powo_csv_write_with_bom(Rails.root.join('tmp', 'powo_report_full.csv'), full_headers, full_rows)
    puts "  tmp/powo_report_full.csv yozildi (#{full_rows.size} qator)"

    # --- B) tmp/powo_not_found.csv --------------------------------------
    nf_headers = %w[id species_sci species_uz csv_family csv_genus sabab nomzod_1 nomzod_2 nomzod_3]
    nf_rows = []

    not_found_results.each do |r|
      genus_norm = Powo::Matcher.normalize_name_for_match(Powo::Matcher.bare_genus(r[:csv_genus]))
      pool = genus_candidates[genus_norm]
      top3 = powo_nearest_candidates_for(r[:norm_name], pool)
      cand_strs = top3.map { |c| "#{c[:name]} #{c[:authors]} [#{c[:status]}] (masofa=#{c[:distance]})" }
      sabab = "WCVP'da bunday tur nomi topilmadi (aniq va kanonik/fuzzy qidiruvdan keyin ham)"
      sabab = "Xavfsizlik chegarasi tufayli kanonik/fuzzy urinish qilinmadi (sp./aff./cf./ined./nom. nud. yoki juda qisqa epitet) — qo'lda tekshirilsin" if r[:canon_excluded]
      nf_rows << [
        r[:id], r[:species_sci], r[:species_uz], r[:csv_family], r[:csv_genus],
        sabab,
        cand_strs[0], cand_strs[1], cand_strs[2]
      ]
    end

    ambiguous_results.each do |r|
      top3 = r[:ambiguous_options] || []
      nf_rows << [
        r[:id], r[:species_sci], r[:species_uz], r[:csv_family], r[:csv_genus],
        "Nomi #{r[:candidates].size} ta WCVP yozuviga mos keldi, muallif va oila orqali hal qilinmadi (omonim)",
        top3[0], top3[1], top3[2]
      ]
    end

    canon_ambiguous_results.each do |r|
      top3 = r[:canon_ambiguous_options] || []
      nf_rows << [
        r[:id], r[:species_sci], r[:species_uz], r[:csv_family], r[:csv_genus],
        "Kanonik/fuzzy kalit bir nechta TURLI qabul qilingan nomga olib keldi (omonim) — kalit: #{r[:canon_key]}",
        top3[0], top3[1], top3[2]
      ]
    end
    powo_csv_write_with_bom(Rails.root.join('tmp', 'powo_not_found.csv'), nf_headers, nf_rows)
    puts "  tmp/powo_not_found.csv yozildi (#{nf_rows.size} qator)"

    # --- C) tmp/powo_changes.csv -----------------------------------------
    ch_headers = %w[id species_uz eski_nom yangi_nom eski_turkum yangi_turkum turkum_ozgardi eski_oila yangi_oila oila_ozgardi powo_url]
    change_results = results.select { |r| r[:outcome] == :synonym_resolved }
    ch_rows = change_results.map { |r|
      final = r[:final]
      eski_turkum = Powo::Matcher.bare_genus(r[:csv_genus])
      eski_oila = Powo::Matcher.bare_family(r[:csv_family])
      turkum_ozgardi = eski_turkum.downcase == final[:genus].to_s.downcase ? "yo'q" : 'ha'
      oila_ozgardi = eski_oila.downcase == final[:family].to_s.downcase ? "yo'q" : 'ha'
      [
        r[:id], r[:species_uz], r[:species_sci], "#{final[:taxon_name]} #{final[:taxon_authors]}",
        eski_turkum, final[:genus], turkum_ozgardi,
        eski_oila, final[:family], oila_ozgardi,
        Powo::Matcher.powo_url_for(final[:powo_id])
      ]
    }
    powo_csv_write_with_bom(Rails.root.join('tmp', 'powo_changes.csv'), ch_headers, ch_rows)
    puts "  tmp/powo_changes.csv yozildi (#{ch_rows.size} qator)"

    # --- D) tmp/powo_cyrillic.csv -----------------------------------------
    cyr_headers = %w[id species_sci kirill_harflar tuzatilgan_nom]
    cyr_rows = cyrillic_results.map { |r|
      chars_str = r[:cyrillic_chars].map { |ch| "#{ch} (U+#{ch.ord.to_s(16).upcase.rjust(4, '0')})" }.join(', ')
      [ r[:id], r[:species_sci], chars_str, Powo::Matcher.fix_cyrillic_homoglyphs(r[:species_sci]) ]
    }
    powo_csv_write_with_bom(Rails.root.join('tmp', 'powo_cyrillic.csv'), cyr_headers, cyr_rows)
    puts "  tmp/powo_cyrillic.csv yozildi (#{cyr_rows.size} qator)"

    # --- E) tmp/powo_orthographic.csv -------------------------------------
    orth_headers = %w[id species_uz eski_imlo yangi_imlo qabul_qilingan_nom match_type masofa powo_url]
    orth_results = results.select { |r| %i[canon_exact canon_fuzzy1].include?(r[:match_type]) }
    orth_rows = orth_results.map { |r|
      matched = r[:chosen_row]
      final = r[:final]
      [
        r[:id], r[:species_uz], r[:species_sci],
        "#{matched[:taxon_name]} #{matched[:taxon_authors]}",
        "#{final[:taxon_name]} #{final[:taxon_authors]}",
        r[:match_type], r[:canon_distance], Powo::Matcher.powo_url_for(final[:powo_id])
      ]
    }
    powo_csv_write_with_bom(Rails.root.join('tmp', 'powo_orthographic.csv'), orth_headers, orth_rows)
    puts "  tmp/powo_orthographic.csv yozildi (#{orth_rows.size} qator)"

    # --- Xulosa statistikasi -----------------------------------------------
    puts "\n#{'=' * 60}"
    puts 'XULOSA'
    puts '=' * 60

    puts "\nmatch_type bo'yicha:"
    results.group_by { |r| r[:match_type] }.sort_by { |_k, v| -v.size }.each do |type, rows|
      puts "  #{type}: #{rows.size}"
    end

    puts "\nWCVP taxon_status bo'yicha (topilgan yozuvlarniki):"
    results.filter_map { |r| r[:chosen_row]&.fetch(:status, nil) }.tally.sort_by { |_, v| -v }.each do |status, n|
      puts "  #{status}: #{n}"
    end

    genus_changed_count = change_results.count { |r| Powo::Matcher.bare_genus(r[:csv_genus]).downcase != r[:final][:genus].to_s.downcase }
    family_changed_count = change_results.count { |r| Powo::Matcher.bare_family(r[:csv_family]).downcase != r[:final][:family].to_s.downcase }

    puts "\nNomi O'ZGARADI (sinonim → qabul qilingan, aniq nom bosqichidan): #{change_results.size}"
    puts "  ...shundan TURKUM ham o'zgaradi: #{genus_changed_count}"
    puts "  ...shundan OILA ham o'zgaradi: #{family_changed_count}"

    puts "\nIMLO orqali TIKLANGAN (avval topilmagan, endi kanonik/fuzzy bilan topilgan): #{orth_results.size}"
    puts "Endi 'topilmadi': #{not_found_results.size}"
    puts "Omonim (aniq nom bosqichida hal qilinmagan): #{ambiguous_results.size}"
    puts "Omonim (kanonik/fuzzy bosqichida hal qilinmagan): #{canon_ambiguous_results.size}"

    puts "\n5 ta misol (eski nom → yangi nom, sinonim→qabul qilingan):"
    change_results.first(5).each do |r|
      puts "  #{r[:species_sci]}  →  #{r[:final][:taxon_name]} #{r[:final][:taxon_authors]}"
    end

    puts "\n10 ta misol (canon_fuzzy1 — eski imlo → yangi imlo, XAVFSIZLIGINI BAHOLANG):"
    orth_results.select { |r| r[:match_type] == :canon_fuzzy1 }.first(10).each do |r|
      puts "  #{r[:species_sci]}  →  #{r[:chosen_row][:taxon_name]} #{r[:chosen_row][:taxon_authors]}  (masofa=#{r[:canon_distance]}, qabul qilingan: #{r[:final][:taxon_name]})"
    end

    puts "\nFayllar: tmp/powo_report_full.csv, tmp/powo_not_found.csv, tmp/powo_changes.csv, tmp/powo_cyrillic.csv, tmp/powo_orthographic.csv"
  end
end
