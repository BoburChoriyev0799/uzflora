# frozen_string_literal: true
#
# `db/qoraqalpoq_nomlari.csv` (lotincha_nom, qoraqalpoqcha_nom, manba —
# 397 qator, nomlar KIRILL alifbosida) asosida `plants.species_kaa` /
# `plants.species_kaa_source` ustunlarini to'ldiradi.
#
# MANBA — Ережепов 1978 va Шербаев 1988 (1970-80 yillar, ESKI TAKSONOMIYA).
# Turkumlarning ko'pi POWO'da o'zgargan (Climacoptera, Halimocnemis,
# Aellenia, Acroptilon, Kochia, Girgensohnia, Nanophyton, Petrosimonia,
# Horaninowia, Gamanthus, Scirpus, Erianthus ...). Shuning uchun SINONIM
# ORQALI qidirish shart — busiz ~40 ta tur topilmay qoladi.
#
# MOSLASHTIRISH BOSQICHMA-BOSQICH (birinchi topilgan g'olib):
#   1) species_sci ning kanonik kaliti bo'yicha aniq moslik
#   2) accepted_name ning kanonik kaliti bo'yicha
#   3) bazadagi sinonimlar (wcvp_matched_name — POWO ishida saqlangan)
#      kanonik kaliti bo'yicha
#   4) sinonim -> zamonaviy qabul qilingan nom, keyin shu nom bo'yicha
#      2/1-bosqich indekslarida qidirish. Zamonaviy nom IKKI manbadan
#      kelishi mumkin:
#        - db/qoraqalpoq_nomlari_hal_qilingan.csv (`hal_qilingan_nom`
#          ustuni) — OLDINDAN hisoblangan, COMMIT QILINGAN. PRODUCTIONDA
#          (Render) shu ishlatiladi: WCVP fayli va POWO=true KERAK EMAS.
#        - POWO=true: db/external/wcvp_names.csv orqali JONLI hisoblash
#          (`Powo::Matcher.resolve_wcvp_name_aliases` — POWO/WCVP
#          mexanizmi). Sekin (~300MB fayl), FAQAT lokalda ishlaydi.
#          POWO=true bilan yugurtirilganda natija yuqoridagi
#          `..._hal_qilingan.csv` fayliga YOZIB QO'YILADI (commit uchun).
#
#   db/external/ butunlay .gitignore'da (`/db/external/`) — WCVP fayli
#   repoda YO'Q, Render'da ham yo'q. Shuning uchun `hal_qilingan.csv`
#   indirekti: powo_export_mapping.rake bilan bir xil naqsh (WCVP tahlili
#   va bazaga yozish — ikkita mustaqil, takrorlanadigan qadam).
#
# KANONIK KALIT: lib/powo/matcher.rb#canonical_key — MAVJUD mantiq
# (turkum+epitet, muallif tashlanadi, diakritika/registr olib tashlanadi,
# ikkilangan harf bittaga, cz=c/sz=s, suffiks BIR MARTA kesiladi —
# "caligonum -> caligon" xatosi allaqachon tuzatilgan).
#
# XAVFSIZLIK:
#   - Turkum bo'yicha YAKKA moslik yo'q — kanonik kalit turkum+epitet
#     ikkalasini oladi, kalit 2 so'zdan kam bo'lsa moslashtirilmaydi.
#   - Bitta lotincha nom bir NECHTA guruhga (turli accepted_name) mos
#     kelsa — avval NOANIQ qoidasi qo'llanadi (epiteti mos infratur
#     takson bo'lsa -> o'sha; aks holda -> TUR darajasidagi yozuv);
#     qoida ham AYNAN BITTA guruh bermasa — "NOANIQ" deb belgilanadi
#     (QoraqalpoqImport.disambiguate_groups).
#   - Mavjud species_kaa bo'sh bo'lmasa va yangi qiymat undan farq qilsa —
#     ustiga YOZILMAYDI, "ZIDDIYAT" deb belgilanadi.
#
# ASL MANBA FAYLI (db/qoraqalpoq_nomlari.csv) HECH QACHON O'ZGARTIRILMAYDI.
#   - 1978-88 kitoblaridagi terish xatolari: db/qoraqalpoq_imlo_tuzatishlari.csv
#     (fayldagi_nom, tuzatilgan_nom, izoh) — moslashtirishdan OLDIN qo'llanadi,
#     audit'da ko'rinadi.
#   - Madaniy (ekma) turlar: db/qoraqalpoq_madaniy_turlar.csv — bazada
#     yovvoyi flora bo'lgani uchun YO'Q, audit'da MADANIY_TUR (TOPILMADI emas).
#
# GURUHGA QO'LLASH: qoraqalpoqcha nom accepted_name guruhining BARCHA
# a'zolariga yoziladi (faqat primary'ga emas) — kelajakda primary o'zgarsa
# ham ma'lumot yo'qolmaydi.
#
# QIYMAT: CSV matni AYNAN ko'chiriladi (kirill, vergul, kichik harf
# o'zgartirilmaydi). Bosh harfga aylantirish FAQAT ko'rsatishda.
#
# Sukut bo'yicha DRY RUN. Haqiqiy yozish: APPLY=true. Qayta ishga
# tushirilsa xavfsiz (idempotent).
#
#   rails plants:import_qoraqalpoq                 # dry-run (prod ham shu)
#   rails plants:import_qoraqalpoq APPLY=true      # yozadi
#   rails plants:import_qoraqalpoq POWO=true       # lokal: 4-bosqichni jonli
#                                                  # hisoblab, hal_qilingan.csv
#                                                  # ni qayta yozadi
#
# AUDIT: tmp/qoraqalpoq_import_hisobot.csv
require 'csv'
require Rails.root.join('lib', 'powo', 'matcher')

module QoraqalpoqImport
  CSV_PATH = Rails.root.join('db', 'qoraqalpoq_nomlari.csv')
  # ASL manba hujjati (db/qoraqalpoq_nomlari.csv) HECH QACHON o'zgartirilmaydi.
  # 1978-88 kitoblaridagi NOM tuzatishlari ALOHIDA faylda — terish xatolari
  # (filaformis -> filiformis), turkum imlosi (Sorgum -> Sorghum), va
  # noto'g'ri qo'llanilgan nomlar (Setaria glauca auct. -> S. pumila).
  # Ko'rinib turadi, tekshirilishi mumkin. Moslashtirishdan OLDIN qo'llanadi.
  SPELLING_CSV_PATH = Rails.root.join('db', 'qoraqalpoq_imlo_tuzatishlari.csv')
  # Madaniy (ekma) turlar — bazada yovvoyi flora bo'lgani uchun YO'Q va
  # bo'lishi ham shart emas. Alohida ro'yxat: kelajakda introdutsentlar
  # qo'shilsa nomlar tayyor turadi. Audit'da MADANIY_TUR (TOPILMADI emas).
  CULTIVATED_CSV_PATH = Rails.root.join('db', 'qoraqalpoq_madaniy_turlar.csv')
  RESOLVED_CSV_PATH = Rails.root.join('db', 'qoraqalpoq_nomlari_hal_qilingan.csv')
  RESOLVED_HEADERS = %w[lotincha_nom qoraqalpoqcha_nom manba hal_qilingan_nom qaysi_bosqich].freeze
  REPORT_PATH = Rails.root.join('tmp', 'qoraqalpoq_import_hisobot.csv')
  REPORT_HEADERS = %w[fayldagi_nom holat topilgan_plant_id topilgan_nom qaysi_bosqich izoh].freeze

  # holat qiymatlari
  QOSHILDI = "QO'SHILDI"
  TOPILMADI = 'TOPILMADI'
  NOANIQ = 'NOANIQ'
  ZIDDIYAT = 'ZIDDIYAT'
  ALLAQACHON = 'ALLAQACHON_BOR'
  MADANIY = 'MADANIY_TUR'

  # subsp./var./f. kabi infraspetsifik rang belgilari (PlantsHelper dagi
  # bilan bir xil ro'yxat).
  RANK_MARKER_RE = /\A(subsp|ssp|var|subvar|f|forma)\.?\z/i.freeze
  HYBRID_RE = /\A[x×]\z/i.freeze

  Match = Struct.new(:plants, :stage, keyword_init: true)

  module_function

  # Kanonik kalit — faqat turkum+epitet aniq bo'lganda (>= 2 so'z).
  # (lib/powo/matcher.rb dagi MAVJUD mantiq, yangisi yozilmaydi.)
  def canon_key(name)
    key = Powo::Matcher.canonical_key(name)
    key.to_s.split(' ').size >= 2 ? key : nil
  end

  # Bir xil accepted_name'ga ega BARCHA yozuvlar (primary_record'dan qat'i
  # nazar). accepted_name bo'sh bo'lsa — faqat shu yozuvning o'zi.
  def group_members_for(plant, by_accepted_name)
    plant.accepted_name.present? ? (by_accepted_name[plant.accepted_name] || [ plant ]) : [ plant ]
  end

  # Guruh identifikatori — NOANIQ tekshiruvi uchun. accepted_name bo'lsa
  # o'sha, bo'lmasa "id:N".
  def group_key_for(plant)
    plant.accepted_name.presence || "id:#{plant.id}"
  end

  def display_name_for(plant)
    plant.accepted_name.presence || plant.species_sci
  end

  # 1-3 bosqich: kanonik kalit bo'yicha uch indeksni ketma-ket sinaydi.
  def find_match(latin, sci_index, accepted_index, synonym_index)
    key = canon_key(latin)
    return nil if key.nil?

    if (hits = sci_index[key]).any?
      Match.new(plants: hits, stage: '1-species_sci')
    elsif (hits = accepted_index[key]).any?
      Match.new(plants: hits, stage: '2-accepted_name')
    elsif (hits = synonym_index[key]).any?
      Match.new(plants: hits, stage: '3-sinonim')
    end
  end

  # 4-bosqich: zamonaviy qabul qilingan nom bo'yicha 2/1-indekslarda.
  def find_match_by_resolved(accepted_name, sci_index, accepted_index)
    key = canon_key(accepted_name)
    return nil if key.nil?

    hits = (accepted_index[key] + sci_index[key]).uniq
    hits.any? ? Match.new(plants: hits, stage: "4-sinonim(#{accepted_name})") : nil
  end

  # Manbani KO'RSATISH darajasida formatlaydi (bazadagi qiymatga TEGILMAYDI):
  #   "Ережепов 1978 + Шербаев 1988" -> "(Ережепов, 1978; Шербаев, 1988)"
  def format_source(raw)
    return '' if raw.blank?

    parts = raw.to_s.split(' + ').map { |part| part.strip.sub(/\s+(\d{3,4})\z/, ', \1') }
    "(#{parts.join('; ')})"
  end

  # --- NOANIQ (bir nechta guruh) qoidasi ------------------------------
  #
  # Eski nomdagi TUR EPITETI (yoki infratur epiteti) nomzod guruhlardan
  # birining infraspetsifik epiteti bilan mos kelsa — o'sha guruh. Aks
  # holda — TUR darajasidagi (rang belgisisiz accepted_name) guruh. Ikkala
  # qoida ham AYNAN BITTA guruh bermasa — avvalgidek NOANIQ.
  #
  # Epitetlar `Powo::Matcher.canonicalize_word` orqali solishtiriladi —
  # jins tugashi (herbacea/herbaceus), ikkilangan harf (litoralis/
  # littoralis) farqi hisobga olinmaydi.

  # Nomdan barcha epitetlarni (tur + infratur) ajratib, kanonik shaklga
  # keltiradi.
  def epithets_of(name)
    toks = name.to_s.tr('()', ' ').split(/\s+/)
    return [] if toks.size < 2

    out = []
    sp_idx = toks[1].to_s.match?(HYBRID_RE) ? 2 : 1
    out << toks[sp_idx] if toks[sp_idx].to_s.match?(/\A[a-z-]+\z/i)
    toks.each_with_index { |t, i| out << toks[i + 1] if t.match?(RANK_MARKER_RE) && toks[i + 1] }
    out.filter_map { |e| Powo::Matcher.canonicalize_word(e.downcase.delete('-')).presence }.uniq
  end

  # accepted_name (guruh kaliti) -> [rank(:species/:infraspecific), kanonik infratur epiteti]
  def parse_group_rank(group_key)
    return [ :species, nil ] if group_key.to_s.start_with?('id:')

    toks = group_key.to_s.split(/\s+/)
    marker_idx = toks.rindex { |t| t.match?(RANK_MARKER_RE) }
    if marker_idx && toks[marker_idx + 1]
      [ :infraspecific, Powo::Matcher.canonicalize_word(toks[marker_idx + 1].downcase) ]
    else
      [ :species, nil ]
    end
  end

  # `groups` — { guruh_kaliti => [members] }. Qaytadi: tanlangan
  # [kalit, members] jufti yoki nil (hal qilib bo'lmadi -> NOANIQ).
  def disambiguate_groups(groups, latin)
    csv_eps = epithets_of(latin)
    parsed = groups.map { |key, members| { key: key, members: members, rank: parse_group_rank(key) } }

    infra = parsed.select { |g| g[:rank][0] == :infraspecific && csv_eps.include?(g[:rank][1]) }
    return [ infra.first[:key], infra.first[:members] ] if infra.size == 1

    species = parsed.select { |g| g[:rank][0] == :species }
    return [ species.first[:key], species.first[:members] ] if species.size == 1

    nil
  end
end

namespace :plants do
  desc "db/qoraqalpoq_nomlari.csv asosida species_kaa/species_kaa_source ni to'ldirish (sukut: dry-run; APPLY=true — yozish; POWO=true — 4-bosqichni jonli hisoblash)"
  task import_qoraqalpoq: :environment do
    m = QoraqalpoqImport

    unless File.exist?(m::CSV_PATH)
      abort "XATO: #{m::CSV_PATH} topilmadi. Avval CSV faylni shu papkaga saqlang."
    end

    apply = ActiveModel::Type::Boolean.new.cast(ENV['APPLY'])
    use_powo = ActiveModel::Type::Boolean.new.cast(ENV['POWO'])

    puts(apply ? "APPLY=true — o'zgarishlar HAQIQATAN bazaga yoziladi." : "DRY RUN — hech narsa o'zgartirilmaydi (yozish uchun APPLY=true).")
    puts '=' * 64

    # --- Imlo tuzatishlari (asl manba fayli o'zgarmaydi) ---------------
    spelling_by_latin = {}
    if File.exist?(m::SPELLING_CSV_PATH)
      CSV.foreach(m::SPELLING_CSV_PATH, headers: true) do |row|
        spelling_by_latin[row['fayldagi_nom'].to_s.strip] = row['tuzatilgan_nom'].to_s.strip.presence
      end
      puts "Imlo tuzatishlari: #{m::SPELLING_CSV_PATH.basename} (#{spelling_by_latin.size} ta)."
    end

    # --- Madaniy (ekma) turlar ro'yxati -------------------------------
    cultivated_keys = {} # canon_key => lotincha_nom
    if File.exist?(m::CULTIVATED_CSV_PATH)
      CSV.foreach(m::CULTIVATED_CSV_PATH, headers: true) do |row|
        name = row['lotincha_nom'].to_s.strip
        (k = m.canon_key(name)) && (cultivated_keys[k] = name)
      end
      puts "Madaniy turlar ro'yxati: #{m::CULTIVATED_CSV_PATH.basename} (#{cultivated_keys.size} ta)."
    end

    # --- CSV o'qish -----------------------------------------------------
    csv_rows = CSV.read(m::CSV_PATH, headers: true).map do |row|
      latin = row['lotincha_nom'].to_s.strip
      { latin: latin,
        match_latin: spelling_by_latin[latin] || latin, # moslashtirish shu nom bo'yicha
        kaa: row['qoraqalpoqcha_nom'].to_s.strip,
        source: row['manba'].to_s.strip }
    end.reject { |r| r[:latin].blank? }
    corrected = csv_rows.count { |r| r[:match_latin] != r[:latin] }
    puts "CSV o'qildi: #{csv_rows.size} qator#{corrected.positive? ? " (#{corrected} tasida imlo tuzatildi)" : ''}."

    # --- Oldindan hal qilingan (commit qilingan) sinonim natijasi -----
    resolved_by_latin = {}
    if File.exist?(m::RESOLVED_CSV_PATH)
      CSV.foreach(m::RESOLVED_CSV_PATH, headers: true) do |row|
        resolved_by_latin[row['lotincha_nom'].to_s.strip] = row['hal_qilingan_nom'].to_s.strip.presence
      end
      puts "Oldindan hal qilingan sinonimlar fayli: #{m::RESOLVED_CSV_PATH.basename} " \
           "(#{resolved_by_latin.values.compact.size} ta zamonaviy nom)."
    else
      puts "Oldindan hal qilingan sinonimlar fayli yo'q (#{m::RESOLVED_CSV_PATH.basename}) — " \
           "4-bosqich uchun #{use_powo ? 'POWO=true jonli hisoblash ishlatiladi' : 'POWO=true kerak'}."
    end

    # --- Bazadagi indekslar ------------------------------------------
    plants = Plant.select(
      :id, :species_sci, :accepted_name, :wcvp_matched_name, :species_kaa, :species_kaa_source, :primary_record
    ).to_a
    plants_by_id = plants.index_by(&:id)
    by_accepted_name = plants.select { |p| p.accepted_name.present? }.group_by(&:accepted_name)

    sci_index = Hash.new { |h, k| h[k] = [] }
    accepted_index = Hash.new { |h, k| h[k] = [] }
    synonym_index = Hash.new { |h, k| h[k] = [] }

    plants.each do |p|
      (k = m.canon_key(p.species_sci)) && (sci_index[k] << p)
      p.accepted_name.present? && (k = m.canon_key(p.accepted_name)) && (accepted_index[k] << p)
      p.wcvp_matched_name.present? && (k = m.canon_key(p.wcvp_matched_name)) && (synonym_index[k] << p)
    end
    puts "Indekslar: species_sci #{sci_index.size} kalit, accepted_name #{accepted_index.size}, sinonim (wcvp_matched_name) #{synonym_index.size}."

    # --- 1-3 bosqich moslashtirish (imlo tuzatilgan nom bo'yicha) ------
    results = csv_rows.map do |row|
      { row: row, match: m.find_match(row[:match_latin], sci_index, accepted_index, synonym_index), resolved_name: nil }
    end

    # --- 4-bosqich (a): commit qilingan hal_qilingan_nom orqali -------
    results.each do |r|
      next if r[:match]

      accepted_name = resolved_by_latin[r[:row][:latin]]
      next if accepted_name.blank?

      match = m.find_match_by_resolved(accepted_name, sci_index, accepted_index)
      next unless match

      r[:match] = match
      r[:resolved_name] = accepted_name
    end

    # --- 4-bosqich (b): POWO=true — WCVP faylidan jonli hisoblash -----
    live_resolved = {} # asl_latin => zamonaviy accepted nom (yoki nil)
    if use_powo
      still_unresolved = results.select { |r| r[:match].nil? }
      if still_unresolved.any?
        puts "\n4-bosqich (jonli): #{still_unresolved.size} ta topilmagan nom uchun WCVP sinonim zanjiri yechilmoqda (sekin, ~300MB)..."
        begin
          aliases = Powo::Matcher.resolve_wcvp_name_aliases(still_unresolved.map { |r| r[:row][:match_latin] }, log: ->(x) { puts "  #{x}" })
        rescue RuntimeError => e
          puts "  OGOHLANTIRISH: 4-bosqich bajarilmadi — #{e.message}"
          aliases = {}
        end

        still_unresolved.each do |r|
          info = aliases[r[:row][:match_latin]]
          accepted_name = (info && info[:status] == :resolved && info[:final] && info[:final][:taxon_name]).presence
          live_resolved[r[:row][:latin]] = accepted_name
          next if accepted_name.blank?

          match = m.find_match_by_resolved(accepted_name, sci_index, accepted_index)
          next unless match

          r[:match] = match
          r[:resolved_name] = accepted_name
        end
        puts "  4-bosqich (jonli) orqali TIKLANDI: #{results.count { |r| r[:resolved_name] && live_resolved.key?(r[:row][:latin]) }} ta"
      end
    end

    # --- Har bir qatorni holatga ajratish + yoziladigan qiymatlar ----
    report = []
    to_write = {} # plant_id => { species_kaa:, species_kaa_source: }
    counts = Hash.new(0)
    not_found_names = []

    results.each do |res|
      row = res[:row]
      match = res[:match]
      spelling_note = row[:match_latin] != row[:latin] ? "imlo: -> #{row[:match_latin]}" : nil

      # Madaniy (ekma) tur — bazada yovvoyi flora bo'lgani uchun YO'Q.
      # Moslikdan OLDIN tekshiriladi: agar fuzzy moslik boshqa (yovvoyi)
      # taksonga tushib qolsa ham, ekma turning nomi o'sha yovvoyi turga
      # yozilmasin. Kelajakda introdutsent qo'shilsa — shu qatorni
      # db/qoraqalpoq_madaniy_turlar.csv dan olib tashlanadi.
      if cultivated_keys.key?(m.canon_key(row[:match_latin]))
        counts[m::MADANIY] += 1
        report << [ row[:latin], m::MADANIY, nil, nil, nil,
                    [ 'madaniy tur — bazada yovvoyi flora', spelling_note ].compact.join(' | ') ]
        next
      end

      unless match
        counts[m::TOPILMADI] += 1
        not_found_names << row[:latin]
        # WCVP nomni zamonaviy nomga yechgan, lekin bazada o'sha tur YO'Q —
        # audit'da ko'rsatiladi (kelajakda o'sha tur qo'shilsa bog'lanadi).
        wcvp_hint = (live_resolved[row[:latin]] || resolved_by_latin[row[:latin]]).presence
        note = [ spelling_note, wcvp_hint && "WCVP: -> #{wcvp_hint} (bazada yo'q)" ].compact.join(' | ')
        report << [ row[:latin], m::TOPILMADI, nil, nil, nil, note ]
        next
      end

      groups = match.plants
                    .flat_map { |p| m.group_members_for(p, by_accepted_name) }
                    .uniq(&:id)
                    .group_by { |p| m.group_key_for(p) }

      stage = match.stage
      if groups.size > 1
        chosen = m.disambiguate_groups(groups, row[:match_latin])
        unless chosen
          counts[m::NOANIQ] += 1
          opts = groups.keys.first(4).join(' | ')
          ids = groups.values.flatten.map(&:id).sort.join(';')
          report << [ row[:latin], m::NOANIQ, ids, opts, stage, "#{groups.size} ta turli guruhga mos keldi — taxmin qilinmadi" ]
          next
        end
        key, members = chosen
        stage = "#{stage}+noaniq-hal(#{key})"
      else
        members = groups.values.first
      end

      ids = members.map(&:id).sort
      existing = members.filter_map { |mm| mm.species_kaa.presence }.uniq
      found_name = m.display_name_for(members.min_by(&:id))

      if existing.any? && existing != [ row[:kaa] ]
        counts[m::ZIDDIYAT] += 1
        report << [ row[:latin], m::ZIDDIYAT, ids.join(';'), found_name, stage, "bazada: #{existing.join(' / ')} | CSV: #{row[:kaa]}" ]
        next
      end

      pending = members.reject { |mm| mm.species_kaa == row[:kaa] && mm.species_kaa_source == row[:source] }

      if pending.empty?
        counts[m::ALLAQACHON] += 1
        report << [ row[:latin], m::ALLAQACHON, ids.join(';'), found_name, stage, '' ]
        next
      end

      pending.each { |mm| to_write[mm.id] = { species_kaa: row[:kaa], species_kaa_source: row[:source] } }
      counts[m::QOSHILDI] += 1
      note = members.size > 1 ? "guruhning #{pending.size}/#{members.size} a'zosiga" : ''
      note = [ note, spelling_note, "manba: #{m.format_source(row[:source])}" ].compact.reject(&:blank?).join(' | ')
      report << [ row[:latin], m::QOSHILDI, ids.join(';'), found_name, stage, note ]
    end

    # --- Audit fayl --------------------------------------------------
    FileUtils.mkdir_p(File.dirname(m::REPORT_PATH))
    CSV.open(m::REPORT_PATH, 'w', encoding: 'UTF-8') do |csv|
      csv << m::REPORT_HEADERS
      report.each { |r| csv << r }
    end

    # --- POWO=true: hal_qilingan.csv ni qayta yozish (commit uchun) --
    if use_powo
      resolved_out = results.map do |res|
        latin = res[:row][:latin]
        stage_num = res[:match] ? res[:match].stage.to_s[/\A\d/] : nil
        # `hal_qilingan_nom` FAQAT 4-bosqich (sinonim -> zamonaviy nom)
        # uchun ma'noli. 1-3 bosqichda topilgan bo'lsa — bo'sh (eskirgan
        # qiymat ham tozalanadi). Topilmagan bo'lsa — shu yugurishning
        # (yoki avvalgi committed faylning) sinonim taxminidan.
        resolved_name =
          if stage_num == '4'
            (res[:resolved_name] || live_resolved[latin] || resolved_by_latin[latin]).presence
          elsif res[:match]
            nil
          else
            (live_resolved[latin] || resolved_by_latin[latin]).presence
          end
        # WCVP inputning o'zini (faqat muallif tashlab) qaytargan bo'lsa —
        # bu sinonim yechish emas, shovqin ("Alcea rosea L." -> "Alcea rosea").
        resolved_name = nil if resolved_name && m.canon_key(resolved_name) == m.canon_key(res[:row][:match_latin])
        [ latin, res[:row][:kaa], res[:row][:source], resolved_name, stage_num && "#{stage_num}-bosqich" ]
      end
      CSV.open(m::RESOLVED_CSV_PATH, 'w', encoding: 'UTF-8') do |csv|
        csv << m::RESOLVED_HEADERS
        resolved_out.each { |r| csv << r }
      end
      puts "\n#{m::RESOLVED_CSV_PATH} yozildi (#{resolved_out.count { |r| r[3] }} ta hal_qilingan_nom). Bu faylni COMMIT qiling."
    end

    # --- Yozish ----------------------------------------------------
    if apply && to_write.any?
      ActiveRecord::Base.transaction do
        to_write.each_slice(500) do |slice|
          rows = slice.map do |id, attrs|
            # `species_sci` upsert_all'ga baribir uzatiladi (NOT NULL —
            # Postgres ON CONFLICT nomzod qatorni konfliktdan OLDIN
            # tekshiradi), lekin `update_only` ro'yxatida YO'Q, demak
            # haqiqiy UPDATE'da hech qachon o'zgarmaydi. `updated_at`
            # avtomatik (upsert_all o'zi yangilaydi).
            { id: id, species_sci: plants_by_id[id].species_sci,
              species_kaa: attrs[:species_kaa], species_kaa_source: attrs[:species_kaa_source] }
          end
          Plant.upsert_all(rows, unique_by: :id, update_only: %i[species_kaa species_kaa_source])
        end
      end
    end

    # --- Yakuniy hisobot ----------------------------------------
    stage3 = report.count { |r| r[1] == m::QOSHILDI && r[4].to_s.start_with?('3-') }
    stage4 = report.count { |r| r[1] == m::QOSHILDI && r[4].to_s.start_with?('4-') }
    noaniq_hal = report.count { |r| r[1] == m::QOSHILDI && r[4].to_s.include?('+noaniq-hal') }

    puts "\n#{'=' * 64}"
    puts "Audit fayl: #{m::REPORT_PATH}"
    puts "\nHar bir holat bo'yicha:"
    [ m::QOSHILDI, m::ALLAQACHON, m::TOPILMADI, m::MADANIY, m::NOANIQ, m::ZIDDIYAT ].each do |status|
      puts "  #{status}: #{counts[status]}"
    end
    puts "\n3-bosqich (bazadagi sinonim, wcvp_matched_name) qutqargani: #{stage3} ta"
    puts "4-bosqich (sinonim -> zamonaviy nom) qutqargani: #{stage4} ta"
    puts "NOANIQ qoidasi bilan hal qilingani: #{noaniq_hal} ta"
    puts "\nYoziladigan yozuvlar (guruh a'zolari bilan): #{to_write.size}"

    if not_found_names.any?
      puts "\nTOPILMADI — birinchi #{[ 20, not_found_names.size ].min} tasi (qo'lda ko'rib chiqish uchun):"
      not_found_names.first(20).each_with_index { |n, i| puts "  #{i + 1}. #{n}" }
    end

    if apply
      puts(to_write.any? ? "\nBajarildi — #{to_write.size} ta yozuv yangilandi (bitta transaction)." : "\nYozadigan yangi narsa yo'q.")
    else
      puts "\nBu DRY RUN edi. Haqiqiy yozish: rails plants:import_qoraqalpoq APPLY=true"
    end
  end
end
