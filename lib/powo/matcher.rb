# frozen_string_literal: true
#
# WCVP (World Checklist of Vascular Plants — Kew/POWO) solishtirish
# MEXANIZMI: nom normallashtirish, aniq-nom hash-indeks, kanonik
# ("skelet") kalit orqali imlo-xato tiklash va tasniflash mantig'i.
#
# NEGA ALOHIDA FAYL: bu mantiqni ikkita rake task ishlatadi —
# `plants:powo_report` (faqat hisobot, tmp/*.csv) va `plants:powo_apply`
# (bazaga yozadi, lib/tasks/powo_apply.rake). Agar har biri o'z nusxasini
# saqlasa, vaqt o'tishi bilan ikkalasi bir-biridan uzoqlashib ketishi
# mumkin edi — natijada hisobot bitta narsani, bazaga yozilgan natija esa
# BOSHQA narsani ko'rsatgan bo'lardi (bu eng yomon turdagi xato: sokin
# va sezilmaydigan). Shuning uchun IKKALASI ham shu bitta
# `Powo::Matcher.run` metodini chaqiradi.
#
# BU FAYL BAZAGA HECH NARSA YOZMAYDI. `run` faqat Plant yozuvlarini
# O'QIYDI va tasniflangan natijalar massivini qaytaradi — yozish
# qaror qilish chaqiruvchining ishi (`plants:powo_apply`).
#
# `lib/` katalogi bu loyihada Zeitwerk tomonidan avtomatik yuklanmaydi
# (faqat app/ kuzatiladi) — shuning uchun chaqiruvchi rake fayllar buni
# `require Rails.root.join('lib', 'powo', 'matcher')` bilan qo'lda
# yuklaydi.
require 'set'

module Powo
  module Matcher
    WCVP_PATH = Rails.root.join('db', 'external', 'wcvp_names.csv')

    # Ixtiyoriy: WCVP arxivining o'zida keladigan tarqalish fayli (TDWG
    # hududlar bo'yicha, "|" ajratgichli). Faqat omonimlarni O'zbekistonda
    # tarqalishi orqali hal qilish uchun ishlatiladi (`resolve_ambiguous_
    # entries!`) — fayl yo'q bo'lsa, shu bosqich jim o'tkazib yuboriladi
    # (WCVP_PATH kabi majburiy emas).
    WCVP_DISTRIBUTION_PATH = Rails.root.join('db', 'external', 'wcvp_distribution.csv')

    # WCVP har doim "ssp." emas "subsp." ishlatadi (tekshirib ko'rilgan) —
    # bazamizda "ssp." uchrasa shu tarzda bir xillashtiriladi. `var.`, `f.`,
    # `subvar.` uchun sinonimi yo'q, o'zgarishsiz qoladi.
    RANK_ABBREV_UNIFY = { 'ssp.' => 'subsp.' }.freeze

    # Manba CSV'da bir nechta yozuvda lotincha so'z ICHIDA kirill harflari
    # bor (ko'z bilan farqlab bo'lmaydi — masalan "Hippophaе" so'zidagi
    # oxirgi "е" aslida kirill U+0435, lotincha "e" U+0065 emas).
    CYRILLIC_HOMOGLYPHS = {
      'а' => 'a', 'е' => 'e', 'с' => 'c', 'о' => 'o', 'р' => 'p', 'х' => 'x',
      'у' => 'y', 'к' => 'k', 'м' => 'm', 'т' => 't', 'н' => 'h', 'в' => 'b', 'ё' => 'e',
      'А' => 'A', 'Е' => 'E', 'С' => 'C', 'О' => 'O', 'Р' => 'P', 'Х' => 'X',
      'У' => 'Y', 'К' => 'K', 'М' => 'M', 'Т' => 'T', 'Н' => 'H', 'В' => 'B', 'Ё' => 'E'
    }.freeze
    CYRILLIC_PATTERN = Regexp.union(CYRILLIC_HOMOGLYPHS.keys).freeze

    # Kanonik kalit qadam (b): eng uzunidan boshlab, keyin qisqarog'i —
    # tartib MUHIM (masalan "sch" dan oldin "tsch" sinalishi kerak).
    CANON_CLUSTER_PATTERNS = %w[schtsch stsch zsch tsch sch sh cz cs].freeze
    # Kanonik kalit qadam (i): ro'yxatdagi BIRINCHI mos kelgan qo'shimcha
    # BIR MARTA kesiladi (pastda `canonical_key` izohiga qarang — nega
    # "takror-takror emas, bir marta" ekanligi izohlangan).
    CANON_SUFFIX_RE = /(us|um|is|es|os|on|ae|a|e|i|o)\z/

    module_function

    # --- Kirill homoglif -----------------------------------------------

    def fix_cyrillic_homoglyphs(value)
      value.to_s.gsub(CYRILLIC_PATTERN) { |ch| CYRILLIC_HOMOGLYPHS.fetch(ch) }
    end

    def cyrillic_chars_in(value)
      value.to_s.scan(CYRILLIC_PATTERN).uniq
    end

    # --- Asosiy tozalash/normallashtirish -------------------------------

    # `lib/tasks/import_plants.rake`dagi `normalize_species_sci` bilan bir
    # xil (apostrof/bo'shliq tozalash), lekin ATAYLAB shu yerda alohida
    # takrorlangan: matcher.rb'ni boshqa rake fayl qachon yuklanishiga
    # (Rake yuklash tartibiga) bog'liq QILMASLIK uchun — kutubxona fayli
    # o'z-o'zidan to'liq ishlashi kerak.
    def basic_clean(value)
      value.to_s.tr('’‘ʼ´', "'").gsub(/\s+/, ' ').strip
    end

    # Apostrof/bo'shliqni tozalaydi va kirill homoglifni tuzatadi, LEKIN
    # harf registrini SAQLAYDI — nom va muallifni ajratish uchun bosh
    # harf farqi kerak. Solishtirishning IKKALA tomoni (bazamiz VA WCVP)
    # ham shu funksiya orqali o'tadi.
    def wcvp_clean(value)
      fix_cyrillic_homoglyphs(value.to_s).tr('’‘ʼ´', "'").gsub(/\s+/, ' ').strip
    end

    # `species_sci`ni ["tur nomi", "muallif"] ga ajratadi.
    #
    # Qoida: birinchi so'z (turkum, doim bosh harfli) — har doim NOMga
    # kiradi. Undan keyingi so'zlarni ketma-ket ko'rib chiqamiz: kichik
    # harf bilan boshlangan (yoki duragay belgisi "×"/"x") bo'lsa — hali
    # ham NOM qismi (tur epiteti, infraspecifik daraja "subsp./var./f."
    # va infraspecifik epitet — bularning HAMMASI botanik nomenklaturada
    # doim kichik harfli yoziladi). Birinchi BOSH HARFLI yoki "(" bilan
    # boshlangan so'zdan — MUALLIF qismi boshlanadi.
    def split_scientific_name(cleaned_sci)
      tokens = cleaned_sci.split(' ')
      return [ cleaned_sci, '' ] if tokens.size <= 1

      name_tokens = [ tokens[0] ]
      i = 1
      while i < tokens.size
        tok = tokens[i]
        break unless tok =~ /\A[a-z]/ || tok == '×'

        name_tokens << tok
        i += 1
      end
      [ name_tokens.join(' '), tokens[i..].join(' ') ]
    end

    def normalize_name_for_match(name)
      wcvp_clean(name).downcase.split(' ').map { |t|
        RANK_ABBREV_UNIFY[t] || (t == '×' ? 'x' : t)
      }.join(' ')
    end

    def normalize_author_for_match(author)
      s = wcvp_clean(author).downcase
      s = s.gsub(/\(\s+/, '(').gsub(/\s+\)/, ')')
      s = s.gsub(/\s*\.\s*/, '.')
      s = s.gsub(/\s*,\s*/, ', ')
      s.gsub(/\s+/, ' ').strip
    end

    # Bazamizda `genus_lat`/`family_lat` MUALLIF/qo'shimcha bilan
    # saqlanadi (masalan "Ophioglossum L.", "Cystopteridaceae
    # (Woodsiaceae, Athyriaceae)"), WCVP esa toza nom beradi.
    def bare_genus(value)
      fix_cyrillic_homoglyphs(value.to_s).strip.split(/\s+/).first.to_s
    end

    def bare_family(value)
      fix_cyrillic_homoglyphs(value.to_s).strip.split(/[\s(]/).first.to_s
    end

    def powo_url_for(powo_id)
      return nil if powo_id.blank?

      "https://powo.science.kew.org/taxon/urn:lsid:ipni.org:names:#{powo_id}"
    end

    def levenshtein(a, b)
      return b.length if a.empty?
      return a.length if b.empty?

      prev = (0..b.length).to_a
      a.each_char.with_index(1) do |ca, i|
        cur = [ i ]
        b.each_char.with_index(1) do |cb, j|
          cost = ca == cb ? 0 : 1
          cur << [ prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost ].min
        end
        prev = cur
      end
      prev.last
    end

    # --- Kanonik kalit ("skelet" shakl) ---------------------------------
    #
    # Ikki xil imloda yozilgan BIR XIL tur nomini bitta "skelet"ga
    # tushiradi (masalan "Calligonum × densum" va "Calligonum densum"
    # ikkalasi ham "caligon dens" beradi). FAQAT xavfsizlik zaxirasi
    # sifatida ishlatiladi — aniq nom moslik topa olmagan yozuvlar uchun.
    #
    # 9-qadam (oxiridagi qo'shimchani kesish) haqida ESLATMA: dastlabki
    # topshiriqda "O'ZGARMAY QOLGUNCHA takror-takror kes" deyilgan edi,
    # lekin buni so'zma-so'z (natija barqarorlashguncha qayta-qayta
    # kesish) qo'llasak berilgan misol ("Calligonum" → "caligon dens"
    # emas, "calig dens" chiqadi — "caligonum"dan "um" kesilgach qolgan
    # "caligon" so'zi HAM "on" bilan tugaydi va yana kesiladi) TO'G'RI
    # KELMAYDI. Sinab ko'rib, "qo'shimchalar RO'YXATINI TARTIB BILAN
    # sinab, BIRINCHI mos kelganini FAQAT BIR MARTA kesish" berilgan
    # misolni ANIQ takrorlashini aniqladim — shuni qo'lladim.
    def canonicalize_word(word)
      w = word.dup
      w = w.tr('w', 'v')                                          # a) w -> v
      CANON_CLUSTER_PATTERNS.each { |pat| w = w.gsub(pat, 's') }   # b) ...sch/sh/cz/cs -> s
      w = w.tr('kq', 'cc')                                         # c) k,q -> c
      w = w.tr('jy', 'ii')                                         # d) j,y -> i
      w = w.tr('z', 's')                                           # e) z -> s
      w = w.gsub('ae', 'e').gsub('oe', 'e')                        # f) ae,oe -> e
      w = w.delete('h')                                            # g) h olib tashlanadi
      w = w.gsub(/(.)\1+/, '\1')                                   # h) takror harflar -> bitta
      w.sub(CANON_SUFFIX_RE, '')                                   # i) oxirgi qo'shimcha (bir marta)
    end

    def canonical_key(raw_name)
      base = fix_cyrillic_homoglyphs(raw_name.to_s)
      base = base.unicode_normalize(:nfkd).gsub(/[̀-ͯ]/, '') # diakritika olib tashlash
      base = base.downcase
      base = base.gsub('×', ' ').gsub(/\bx\b/, ' ')                # duragay belgisi olib tashlanadi
      base = base.gsub(/[^a-z ]/, '')                              # faqat a-z va bo'shliq qoladi
      words = base.split(/\s+/).reject(&:empty?).first(2)          # turkum + tur epiteti
      words.map { |w| canonicalize_word(w) }.join(' ')
    end

    # Bu nomlarga kanonik/fuzzy moslik UMUMAN qo'llanmaydi — ataylab
    # noaniq yoki nashr etilmagan, yoki kalit juda qisqa (xato xavfi
    # katta).
    def canonical_excluded?(species_sci, raw_name)
      tokens = species_sci.to_s.downcase.split(/\s+/)
      return true if tokens.include?('sp.') || tokens.include?('ined.') || tokens.include?('aff.') || tokens.include?('cf.')
      return true if tokens.each_cons(2).any? { |a, b| "#{a} #{b}" == 'sp. nova' || "#{a} #{b}" == 'nom. nud.' }

      epithet = raw_name.to_s.split(/\s+/)[1]
      return true if epithet.blank? || epithet.length < 4

      false
    end

    # --- WCVP faylini o'qish yordamchilari -------------------------------

    def read_wcvp_header(io)
      io.readline.chomp.split('|', -1).each_with_index.to_h
    end

    def wcvp_row_to_record(fields, col)
      accepted_raw = fields[col['accepted_plant_name_id']]
      {
        id: fields[col['plant_name_id']].to_i,
        status: fields[col['taxon_status']],
        family: fields[col['family']],
        genus: fields[col['genus']],
        rank: fields[col['taxon_rank']],
        taxon_name: fields[col['taxon_name']],
        taxon_authors: fields[col['taxon_authors']],
        accepted_id: accepted_raw.to_s.strip.empty? ? nil : accepted_raw.to_i,
        powo_id: fields[col['powo_id']]
      }
    end

    # Berilgan id to'plamiga mos qatorlarni WCVP faylida QIDIRIB,
    # `records_by_id` ga qo'shadi (bir marta fayl bo'ylab o'tish).
    def fetch_wcvp_rows_by_id(ids_set, records_by_id)
      found = Set.new
      return found if ids_set.empty?

      File.open(WCVP_PATH, 'r:UTF-8') do |io|
        col = read_wcvp_header(io)
        io.each_line do |line|
          fields = line.chomp.split('|', -1)
          id = fields[col['plant_name_id']].to_i
          next unless ids_set.include?(id)

          records_by_id[id] = wcvp_row_to_record(fields, col)
          found << id
        end
      end
      found
    end

    # WCVP holatlari — Synonym'dan tashqari — qachonki
    # `accepted_plant_name_id` to'ldirilgan bo'lsa, baribir ergashib
    # bo'ladi: nom nomenklatura jihatidan nuqsonli (Illegitimate/Invalid/
    # Orthographic) yoki hali joylashtirilmagan (Unplaced) bo'lsa ham,
    # WCVP qaysi turga tegishli ekanini biladi. `Misapplied` ATAYLAB bu
    # ro'yxatda YO'Q — "noto'g'ri qo'llangan nom" boshqa turga ishora
    # qilishi mumkin, avtomatik ergashib bo'lmaydi, doim bo'sh qoladi.
    RESOLVABLE_DEFECTIVE_STATUSES = %w[Illegitimate Invalid Orthographic Unplaced].freeze
    MAX_CHAIN_HOPS = 5

    # Berilgan WCVP yozuvni "yakuniy" holatga keltiradi:
    #   - Accepted bo'lsa — o'zi
    #   - Synonym bo'lsa — accepted_plant_name_id zanjiri bo'ylab (2
    #     qadamgacha, O'ZGARISHSIZ — pastdagi kengaytirilgan zanjir bilan
    #     ATAYLAB ARALASHTIRILMAGAN, quyida sababi izohlangan)
    #   - RESOLVABLE_DEFECTIVE_STATUSES'dan biri bo'lsa —
    #     `resolve_defective_chain` orqali (5 qadamgacha, halqadan himoya
    #     bilan)
    #   - Misapplied va boshqa har qanday holat uchun avtomatik yechim yo'q
    #
    # NEGA Synonym'ning 2 qadamlik zanjiri kengaytirilmagan: bu funksiya
    # 4258 ta BOSHQA (allaqachon to'g'ri ishlagan) yozuv uchun ham
    # ishlatiladi — agar Synonym zanjirini ham 5 qadamga uzaytirsak, o'sha
    # yozuvlardan ba'zilari kutilmaganda YANGI ravishda tiklanib qolishi
    # mumkin edi (regressiya xavfi). Kengaytirilgan (5 qadam) zanjir FAQAT
    # yangi qo'shilgan 4 ta holat uchun — ular avval umuman avtomatik
    # yechilmagan, shu sabab bu yerda xavf yo'q.
    def resolve_outcome(row, records_by_id)
      return [ nil, nil ] if row.nil?

      case row[:status]
      when 'Accepted'
        [ :accepted, row ]
      when 'Synonym'
        target = row[:accepted_id] && records_by_id[row[:accepted_id]]
        if target.nil?
          [ :unresolved, nil ]
        elsif target[:status] == 'Accepted'
          [ :synonym_resolved, target ]
        else
          target2 = target[:accepted_id] && records_by_id[target[:accepted_id]]
          (target2 && target2[:status] == 'Accepted') ? [ :synonym_resolved, target2 ] : [ :unresolved, nil ]
        end
      when *RESOLVABLE_DEFECTIVE_STATUSES
        resolve_defective_chain(row, records_by_id)
      else
        [ row[:status].downcase.tr(' ', '_').to_sym, nil ]
      end
    end

    # Illegitimate/Invalid/Orthographic/Unplaced holat uchun:
    # `accepted_plant_name_id` zanjiri bo'ylab (maksimal MAX_CHAIN_HOPS
    # qadam) Accepted yozuvgacha yuradi. Har qadamda ko'rilgan id'lar
    # `visited`da saqlanadi — halqa (masalan A->B->A) uchraса, darhol
    # to'xtaydi va `:chain_loop` bilan bo'sh qaytadi (hisobotda alohida
    # ko'rinishi uchun). Zanjir Accepted'ga yetmasdan tugasa (accepted_id
    # yo'q, yozuv topilmadi yoki MAX_CHAIN_HOPS tugadi) — boshlang'ich
    # holatning o'z nomi bilan (masalan :illegitimate) bo'sh qaytadi, xuddi
    # avvalgi (ergashmaydigan) xatti-harakat kabi.
    def resolve_defective_chain(row, records_by_id)
      original = row[:status].downcase.tr(' ', '_').to_sym
      visited = Set.new([ row[:id] ])
      current = row

      MAX_CHAIN_HOPS.times do
        next_id = current[:accepted_id]
        return [ original, nil ] if next_id.nil?
        return [ :chain_loop, nil ] if visited.include?(next_id)

        visited << next_id
        nxt = records_by_id[next_id]
        return [ original, nil ] if nxt.nil?
        return [ :defective_resolved, nxt ] if nxt[:status] == 'Accepted'

        current = nxt
      end
      [ original, nil ]
    end

    # Bir nechta WCVP id (bir xil/yaqin kanonik kalitga ega nomzodlar)
    # berilganda, ularning har biri qaysi ACCEPTED yozuvga borishini
    # aniqlaydi. HAMMASI bitta xil accepted yozuvga borsa — o'shani
    # qaytaradi. Hech biri aniqlanmasa — :none. Ikki yoki undan ortiq
    # TURLI accepted yozuvga borsa — :ambiguous.
    def resolve_candidate_group(ids, records_by_id)
      resolved_pairs = ids.uniq.filter_map { |id|
        row = records_by_id[id]
        next unless row

        outcome, final = resolve_outcome(row, records_by_id)
        next unless %i[accepted synonym_resolved].include?(outcome)

        [ row, final ]
      }
      return :none if resolved_pairs.empty?

      distinct_finals = resolved_pairs.map { |_, f| f[:id] }.uniq
      return :ambiguous if distinct_finals.size > 1

      representative = resolved_pairs.find { |row, _| row[:status] == 'Accepted' } || resolved_pairs.first
      { matched_row: representative[0], final: representative[1] }
    end

    # --- Bazadagi bitta Plant'dan "so'rov yozuvi" tuzish ------------------

    def build_plant_entry(plant)
      original_sci = plant.species_sci
      cyrillic_found = cyrillic_chars_in(original_sci)
      fixed_sci = fix_cyrillic_homoglyphs(original_sci)
      cleaned = basic_clean(fixed_sci)
      raw_name, raw_author = split_scientific_name(cleaned)
      {
        id: plant.id,
        species_sci: original_sci,
        species_uz: plant.species_uz,
        species_ru: plant.species_ru,
        csv_family: plant.family_lat,
        csv_genus: plant.genus_lat,
        raw_name: raw_name,
        raw_author: raw_author,
        norm_name: normalize_name_for_match(raw_name),
        norm_author: normalize_author_for_match(raw_author),
        cyrillic_chars: cyrillic_found,
        has_cyrillic: cyrillic_found.any?
      }
    end

    # Dastlabki (aniq nom) tasniflash: exact_full / exact_name_unique /
    # name_multi_author_ok / name_multi_family_ok / name_ambiguous /
    # not_found.
    def classify_exact(entry, name_index, records_by_id)
      candidates = name_index[entry[:norm_name]] || []

      match_type, chosen_id =
        if candidates.empty?
          [ :not_found, nil ]
        elsif candidates.size == 1
          id = candidates.first
          author_match = normalize_author_for_match(records_by_id[id][:taxon_authors]) == entry[:norm_author]
          [ author_match ? :exact_full : :exact_name_unique, id ]
        else
          author_matches = candidates.select { |id| normalize_author_for_match(records_by_id[id][:taxon_authors]) == entry[:norm_author] }
          if author_matches.size == 1
            [ :name_multi_author_ok, author_matches.first ]
          else
            # Omonimni oila orqali hal qilishga urinish — agar
            # nomzodlardan FAQAT bittasining oilasi bizning
            # `family_lat` bilan mos kelsa, o'shani tanlaymiz.
            family_matches = candidates.select { |id|
              bare_family(records_by_id[id][:family]).downcase == bare_family(entry[:csv_family]).downcase
            }
            family_matches.size == 1 ? [ :name_multi_family_ok, family_matches.first ] : [ :name_ambiguous, nil ]
          end
        end

      chosen_row = chosen_id && records_by_id[chosen_id]
      outcome, final = resolve_outcome(chosen_row, records_by_id)

      # `records_by_id` bu metoddan tashqarida (hisobot task'ida) mavjud
      # emas — omonim holatida ko'rsatiladigan nomzodlarning o'qishga
      # qulay yorlig'ini shu yerda, hali indeks qo'lda bo'lganida,
      # tayyorlab qo'yamiz.
      ambiguous_options =
        if match_type == :name_ambiguous
          candidates.first(3).filter_map { |id|
            row = records_by_id[id]
            row && "#{row[:taxon_name]} #{row[:taxon_authors]} [#{row[:status]}, oila=#{row[:family]}]"
          }
        end

      entry.merge(
        candidates: candidates, chosen_row: chosen_row, match_type: match_type,
        outcome: outcome, final: final, ambiguous_options: ambiguous_options
      )
    end

    # Faqat "not_found" qolganlar uchun: kanonik kalit orqali WCVP
    # faylini yana bir marta o'qib (har qator uchun "skelet" hisoblanadi),
    # keyin turkum/epitet bo'yicha ikkita yordamchi indeks orqali
    # (Levenshtein masofasi <= 1) fuzzy moslikka urinadi. `results`
    # ichidagi tegishli hash'larni JOYIDA (in-place) yangilaydi.
    def canon_retry!(not_found_entries, log: ->(_msg) {})
      not_found_entries.each do |r|
        r[:canon_excluded] = canonical_excluded?(r[:species_sci], r[:raw_name])
        r[:canon_key] = r[:canon_excluded] ? nil : canonical_key(r[:raw_name])
      end
      retry_candidates = not_found_entries.reject { |r| r[:canon_excluded] || r[:canon_key].blank? || r[:canon_key].split(' ').size < 2 }
      log.call("  Xavfsizlik chegarasi tufayli chetlab o'tildi: #{not_found_entries.size - retry_candidates.size} ta")
      log.call("  Kanonik urinish uchun qoldi: #{retry_candidates.size} ta")

      return if retry_candidates.empty?

      canon_key_to_ids = Hash.new { |h, k| h[k] = [] }
      canon_genus_index = Hash.new { |h, k| h[k] = Set.new }
      canon_epithet_index = Hash.new { |h, k| h[k] = Set.new }
      canon_line_no = 0

      log.call("  WCVP faylini kanonik kalit uchun to'liq o'qish...")
      File.open(WCVP_PATH, 'r:UTF-8') do |io|
        col = read_wcvp_header(io)
        io.each_line do |line|
          canon_line_no += 1
          fields = line.chomp.split('|', -1)
          taxon_name = fields[col['taxon_name']]
          next if taxon_name.blank?

          ck = canonical_key(taxon_name)
          parts = ck.split(' ')
          next if parts.size < 2

          id = fields[col['plant_name_id']].to_i
          canon_key_to_ids[ck] << id
          canon_genus_index[parts[0]] << ck
          canon_epithet_index[parts[1]] << ck

          log.call("  ...#{canon_line_no} qator (kanonik indeks)") if (canon_line_no % 300_000).zero?
        end
      end
      log.call("  Kanonik indeks tayyor: #{canon_key_to_ids.size} ta noyob kalit.")

      # Har bir so'rov uchun fuzzy (masofa <= 1) nomzod kalitlarni,
      # FAQAT bir xil kanonik TURKUM yoki bir xil kanonik EPITET bo'lgan
      # yozuvlar orasidan qidiramiz (hammasini aylanib chiqmaymiz).
      retry_candidates.each do |r|
        g, e = r[:canon_key].split(' ')
        pool = canon_genus_index[g] | canon_epithet_index[e]
        r[:fuzzy_keys] = pool.select { |k| k != r[:canon_key] && levenshtein(k, r[:canon_key]) <= 1 }
      end

      needed_ids = Set.new
      retry_candidates.each do |r|
        needed_ids.merge(canon_key_to_ids[r[:canon_key]])
        r[:fuzzy_keys].each { |k| needed_ids.merge(canon_key_to_ids[k]) }
      end

      log.call("  #{needed_ids.size} ta nomzod WCVP yozuvining to'liq ma'lumoti yuklanmoqda...")
      canon_records_by_id = {}
      fetch_wcvp_rows_by_id(needed_ids, canon_records_by_id)

      5.times do |hop|
        missing = canon_records_by_id.values
                                      .select { |r| r[:status] == 'Synonym' && r[:accepted_id] && !canon_records_by_id.key?(r[:accepted_id]) }
                                      .map { |r| r[:accepted_id] }
                                      .uniq
        break if missing.empty?

        log.call("  (kanonik) #{hop + 1}-qo'shimcha pass: #{missing.size} ta 'accepted' id qidirilmoqda...")
        fetch_wcvp_rows_by_id(missing.to_set, canon_records_by_id)
      end

      retry_candidates.each do |r|
        exact_ids = canon_key_to_ids[r[:canon_key]] || []
        exact_res = resolve_candidate_group(exact_ids, canon_records_by_id)

        if exact_res.is_a?(Hash)
          r[:match_type] = :canon_exact
          r[:chosen_row] = exact_res[:matched_row]
          r[:final] = exact_res[:final]
          r[:outcome] = :canon_recovered
          r[:canon_distance] = 0
        elsif exact_res == :ambiguous
          r[:match_type] = :canon_ambiguous
          r[:canon_candidates] = exact_ids
          r[:canon_ambiguous_options] = ambiguous_option_labels(exact_ids, canon_records_by_id)
        else
          fuzzy_ids = r[:fuzzy_keys].flat_map { |k| canon_key_to_ids[k] || [] }.uniq
          fuzzy_res = resolve_candidate_group(fuzzy_ids, canon_records_by_id)

          if fuzzy_res.is_a?(Hash)
            r[:match_type] = :canon_fuzzy1
            r[:chosen_row] = fuzzy_res[:matched_row]
            r[:final] = fuzzy_res[:final]
            r[:outcome] = :canon_recovered
            r[:canon_distance] = levenshtein(r[:canon_key], canonical_key(fuzzy_res[:matched_row][:taxon_name]))
          elsif fuzzy_res == :ambiguous
            r[:match_type] = :canon_ambiguous
            r[:canon_candidates] = fuzzy_ids
            r[:canon_ambiguous_options] = ambiguous_option_labels(fuzzy_ids, canon_records_by_id)
          end
          # aks holda r[:match_type] :not_found bo'lib qoladi
        end
      end

      recovered = retry_candidates.count { |r| %i[canon_exact canon_fuzzy1].include?(r[:match_type]) }
      still_ambiguous = retry_candidates.count { |r| r[:match_type] == :canon_ambiguous }
      log.call("  Kanonik/fuzzy orqali TIKLANDI: #{recovered} ta")
      log.call("  Kanonik/fuzzy orqali OMONIM chiqdi: #{still_ambiguous} ta")
    end

    def ambiguous_option_labels(ids, records_by_id)
      ids.filter_map { |id|
        row = records_by_id[id]
        next unless row

        _outcome, final = resolve_outcome(row, records_by_id)
        final ? "#{final[:taxon_name]} #{final[:taxon_authors]} [#{row[:status]}]" : nil
      }.uniq.first(3)
    end

    # --- Omonimlarni (name_ambiguous/canon_ambiguous) qo'shimcha hal qilish -
    #
    # Omonim — nomzodlar bir nechta WCVP yozuviga mos kelib, muallif/oila
    # orqali ham ajratib bo'lmagan holat. Ikkita QO'SHIMCHA (ixtiyoriy)
    # qoida bilan ba'zilarini xavfsiz hal qilamiz, `results` massivini
    # JOYIDA (in-place) o'zgartirib:
    #
    #   A) BIR XIL NISHON qoidasi (`:ambiguous_same_target`) — nomzodlarning
    #      HAMMASI (qaysi biri tanlanishidan qat'i nazar) bitta xil
    #      accepted yozuvga olib borsa, aslida noaniqlik YO'Q. Bu qoida
    #      NOL XAVFLI — nomzodlar soniga cheklov yo'q.
    #
    #   B) TARQALISH qoidasi (`:distribution_resolved`) — nomzodlar
    #      soni <= MAX_AMBIGUOUS_CANDIDATES_FOR_DISTRIBUTION bo'lganda,
    #      har birining accepted turi WCVP_DISTRIBUTION_PATH faylida
    #      O'ZBEKISTONDA (`area_code_l3 == "UZB"`, faqat shu daraja —
    #      Markaziy Osiyoning qolgan 4 davlati HISOBGA OLINMAYDI, chunki
    #      qo'shni davlat dalili O'zbekiston florasi ro'yxati uchun juda
    #      zaif) qayd etilganmi tekshiriladi. FAQAT AYNAN BITTA nomzod
    #      UZB'da uchrasa — o'sha tanlanadi. `location_doubtful=1` bo'lgan
    #      qatorlar HISOBGA OLINMAYDI (shubhali). `introduced=1` HISOBGA
    #      OLINADI (o'simlik baribir bor), lekin natijada
    #      `:distribution_introduced_only` bilan alohida belgilanadi —
    #      Bobur bunday holatlarni bir marta ko'zdan kechirishi uchun.
    #
    #      DIQQAT: "boshqa nomzodda tarqalish topilmadi" — bu ko'pincha
    #      o'sha nomzod umuman tarqalish ma'lumotiga ega emas DEGANI EMAS
    #      (masalan Shimoliy Amerika yoki Yevropada keng tarqalgan tur
    #      bo'lishi mumkin, faqat O'ZBEKISTONDA yo'q) — biz FAQAT UZB
    #      ustunini tekshiramiz, dunyo bo'yicha emas. Shu sabab bu yerda
    #      "malumot yo'q" emas, "UZB'da yo'q" deb yozilishi kerak.
    MAX_AMBIGUOUS_CANDIDATES_FOR_DISTRIBUTION = 5
    AMBIGUOUS_MATCH_TYPES = %i[name_ambiguous canon_ambiguous].freeze

    def resolve_ambiguous_entries!(results, records_by_id, log: ->(_msg) {})
      ambiguous = results.select { |r| AMBIGUOUS_MATCH_TYPES.include?(r[:match_type]) }
      return if ambiguous.empty?

      ambiguous.each do |r|
        r[:candidate_ids] = (r[:match_type] == :name_ambiguous ? r[:candidates] : r[:canon_candidates]).to_a.uniq
      end

      all_ids = ambiguous.flat_map { |r| r[:candidate_ids] }.uniq.to_set
      log.call("Omonimlarni qo'shimcha hal qilish: #{ambiguous.size} guruh, #{all_ids.size} noyob nomzod...")
      fetch_wcvp_rows_by_id(all_ids, records_by_id)
      5.times do
        missing = records_by_id.values
                                .select { |r| r[:accepted_id] && !records_by_id.key?(r[:accepted_id]) }
                                .map { |r| r[:accepted_id] }.uniq
        break if missing.empty?

        fetch_wcvp_rows_by_id(missing.to_set, records_by_id)
      end

      final_for = {}
      ambiguous.each do |r|
        r[:candidate_ids].each do |cid|
          next if final_for.key?(cid)

          _outcome, final = resolve_outcome(records_by_id[cid], records_by_id)
          final_for[cid] = final
        end
      end

      resolve_ambiguous_same_target!(ambiguous, records_by_id, final_for)
      resolve_ambiguous_by_distribution!(ambiguous, records_by_id, final_for, log: log)
    end

    def resolve_ambiguous_same_target!(ambiguous, records_by_id, final_for)
      same_target_count = 0
      ambiguous.each do |r|
        next unless AMBIGUOUS_MATCH_TYPES.include?(r[:match_type])

        finals = r[:candidate_ids].map { |cid| final_for[cid] }
        next if finals.any?(&:nil?)

        distinct_final_ids = finals.map { |f| f[:id] }.uniq
        next unless distinct_final_ids.size == 1

        representative_id = r[:candidate_ids].find { |cid| records_by_id[cid][:status] == 'Accepted' } || r[:candidate_ids].first
        r[:match_type] = :ambiguous_same_target
        r[:chosen_row] = records_by_id[representative_id]
        r[:final] = finals.first
        r[:outcome] = :ambiguous_same_target
        same_target_count += 1
      end
      same_target_count
    end

    def resolve_ambiguous_by_distribution!(ambiguous, records_by_id, final_for, log: ->(_msg) {})
      remaining = ambiguous.select { |r| AMBIGUOUS_MATCH_TYPES.include?(r[:match_type]) }
      remaining = remaining.select { |r| r[:candidate_ids].size <= MAX_AMBIGUOUS_CANDIDATES_FOR_DISTRIBUTION }
      return if remaining.empty?

      unless File.exist?(WCVP_DISTRIBUTION_PATH)
        log.call("  OGOHLANTIRISH: #{WCVP_DISTRIBUTION_PATH} topilmadi — tarqalish orqali hal qilish o'tkazib yuborildi.")
        return
      end

      needed_final_ids = remaining.flat_map { |r| r[:candidate_ids].map { |cid| final_for[cid]&.fetch(:id, nil) } }.compact.to_set
      log.call("  wcvp_distribution.csv o'qilmoqda (#{needed_final_ids.size} ta accepted id, faqat UZB)...")

      uzb_rows_by_id = {}
      File.open(WCVP_DISTRIBUTION_PATH, 'r:UTF-8') do |io|
        header = io.readline.chomp.split('|', -1).each_with_index.to_h
        io.each_line do |line|
          fields = line.chomp.split('|', -1)
          next unless fields[header['area_code_l3']] == 'UZB'

          id = fields[header['plant_name_id']].to_i
          next unless needed_final_ids.include?(id)

          (uzb_rows_by_id[id] ||= []) << {
            introduced: fields[header['introduced']] == '1',
            doubtful: fields[header['location_doubtful']] == '1'
          }
        end
      end

      resolved_count = 0
      remaining.each do |r|
        candidate_infos = r[:candidate_ids].map do |cid|
          final = final_for[cid]
          uzb_rows = final ? (uzb_rows_by_id[final[:id]] || []).reject { |x| x[:doubtful] } : []
          row = records_by_id[cid]
          {
            cid: cid, final: final, uzb_present: uzb_rows.any?,
            introduced_only: uzb_rows.any? && uzb_rows.all? { |x| x[:introduced] },
            # Hisobot/CSV quruvchilari (masalan tmp/powo_tarqalish.csv)
            # uchun — `records_by_id` `run()`ga lokal, tashqaridan
            # ko'rinmaydi, shuning uchun nomzodning o'z nomi/muallifi/
            # holati shu yerda saqlab qo'yiladi.
            candidate_name: row && "#{row[:taxon_name]} #{row[:taxon_authors]}".strip,
            candidate_status: row && row[:status]
          }
        end

        uzb_hits = candidate_infos.select { |info| info[:uzb_present] }
        next unless uzb_hits.size == 1

        winner = uzb_hits.first
        r[:match_type] = :distribution_resolved
        r[:chosen_row] = records_by_id[winner[:cid]]
        r[:final] = winner[:final]
        r[:outcome] = :distribution_resolved
        r[:distribution_introduced_only] = winner[:introduced_only]
        r[:distribution_rejected_candidates] = candidate_infos.reject { |info| info[:cid] == winner[:cid] }
        resolved_count += 1
      end
      log.call("  Tarqalish orqali hal qilindi: #{resolved_count} ta")
    end

    # --- To'liq quvur ------------------------------------------------------
    #
    # Bazadagi Plant yozuvlaridan boshlab, tasniflangan natijalar
    # massivini qaytaradi. Har bir element — Hash: :id, :species_sci,
    # ..., :match_type, :outcome, :final, :chosen_row va h.k. (yuqoridagi
    # `classify_exact`/`canon_retry!` ga qarang). `log` — progress
    # xabarlarini chiqarish uchun (1 argumentli chaqiriladigan obyekt);
    # sukut bo'yicha jim ishlaydi.
    def run(log: ->(_msg) {})
      unless File.exist?(WCVP_PATH)
        raise "WCVP fayli topilmadi: #{WCVP_PATH}. Avval WCVP arxividan wcvp_names.csv ni db/external/ papkasiga joylang."
      end

      log.call("Bazadagi o'simliklarni o'qish, kirill tuzatish, nom/muallifga ajratish...")
      plants_data = Plant.order(:id).find_each.map { |plant| build_plant_entry(plant) }
      log.call("  #{plants_data.size} ta o'simlik tayyorlandi.")

      query_names = plants_data.map { |p| p[:norm_name] }.to_set

      log.call("WCVP faylini (#{File.basename(WCVP_PATH)}) 1-pass bilan o'qish (ANIQ nom indeksi qurish)...")
      name_index = Hash.new { |h, k| h[k] = [] }
      records_by_id = {}
      line_no = 0

      File.open(WCVP_PATH, 'r:UTF-8') do |io|
        col = read_wcvp_header(io)
        io.each_line do |line|
          line_no += 1
          fields = line.chomp.split('|', -1)
          taxon_name = fields[col['taxon_name']]
          next if taxon_name.blank?

          norm = normalize_name_for_match(taxon_name)
          next unless query_names.include?(norm)

          record = wcvp_row_to_record(fields, col)
          name_index[norm] << record[:id]
          records_by_id[record[:id]] = record

          log.call("  ...#{line_no} qator o'qildi (bazamizga mos #{records_by_id.size} ta WCVP yozuvi topildi)") if (line_no % 300_000).zero?
        end
      end
      log.call("  Jami WCVP qatorlari o'qildi: #{line_no}")
      log.call("  Bazamiz nomlariga mos WCVP yozuvlari: #{records_by_id.size}")

      # Faqat Synonym EMAS — RESOLVABLE_DEFECTIVE_STATUSES (Illegitimate/
      # Invalid/Orthographic/Unplaced) uchun ham nishon yozuvlar shu yerda
      # oldindan yuklanadi, aks holda `resolve_defective_chain` ularni
      # `records_by_id`da topa olmay, zanjir yeta oladigan holatlarda ham
      # bo'sh qaytarardi. DIQQAT: bu faqat ANIQ nom mosligi (`classify_exact`)
      # bosqichi uchun — pastdagi `canon_retry!`ning o'z (fuzzy/kanonik)
      # prefetch'i ATAYLAB o'zgartirilmagan (faqat Synonym'ni yuklaydi),
      # shunda bu kengaytirilgan zanjir faqat tahlil qilingan 47 ta aniq-mos
      # yozuvga ta'sir qiladi, "topilmadi" to'plamidagi boshqa yozuvlarga
      # emas.
      log.call("Sinonim va nuqsonli holatlarning 'accepted' nishon yozuvlarini qo'shimcha pass(lar) bilan yuklash...")
      chain_follow_statuses = ([ 'Synonym' ] + RESOLVABLE_DEFECTIVE_STATUSES).freeze
      5.times do |hop|
        missing = records_by_id.values
                                .select { |r| chain_follow_statuses.include?(r[:status]) && r[:accepted_id] && !records_by_id.key?(r[:accepted_id]) }
                                .map { |r| r[:accepted_id] }
                                .uniq
        break if missing.empty?

        log.call("  #{hop + 1}-qo'shimcha pass: #{missing.size} ta 'accepted' id qidirilmoqda...")
        fetch_wcvp_rows_by_id(missing.to_set, records_by_id)
      end

      log.call('Dastlabki tasniflash (aniq nom bo\'yicha)...')
      results = plants_data.map { |entry| classify_exact(entry, name_index, records_by_id) }

      stage1_not_found = results.select { |r| r[:match_type] == :not_found }
      log.call("  Aniq nom bo'yicha topilmadi: #{stage1_not_found.size} ta (endi kanonik/fuzzy bilan qayta uriniladi)")

      log.call('Kanonik kalit orqali qayta urinish...')
      canon_retry!(stage1_not_found, log: log)

      log.call("Omonimlarni qo'shimcha (bir xil nishon / tarqalish) hal qilish...")
      resolve_ambiguous_entries!(results, records_by_id, log: log)

      results
    end
  end
end
