# frozen_string_literal: true
#
# O'simliklarni CSV faylidan bazaga import qiladi.
#
# Ishga tushirish (Claude Code / terminalda, loyiha ildizida):
#   rails plants:import
#
# CSV fayli `db/uzflora_plants_v8.csv` da bo'lishi kerak. CSV
# ustunlari `plants` jadvali ustunlari bilan BIR XIL nomlangan (masalan
# `family_lat`, `habitat_env`) — qo'shimcha moslashtirish shart emas.
#
# Idempotent: `species_sci` (lotincha ilmiy nom) — tabiiy kalit.
# Mavjud yozuv shu nom bo'yicha topilib YANGILANADI (id, demak
# plant_sighting.plant_id, O'ZGARMAYDI), topilmasa yangi yaratiladi.
# CSV'da yo'q eski yozuvlarga tegilmaydi — ularга bog'langan kuzatuvlar
# ham buzilmaydi.
#
# Har deploy'da barcha qatorlarni qayta o'qib o'tirmaslik uchun: CSV fayl
# checksum'i (PlantImportState) bilan solishtiriladi — o'zgarmagan bo'lsa
# import O'TKAZIB YUBORILADI. Majburiy qayta import uchun:
#   rails plants:import FORCE=true
#
require 'csv'
require 'digest'
require Rails.root.join('lib', 'powo', 'matcher')

# species_sci'ni bazaga yozishdan OLDIN va find_or_initialize_by uchun
# kalit sifatida ishlatishdan OLDIN normallashtiradi:
#   - kirill homoglif harflarni (masalan "Bungе" dagi kirill "е") lotinchaga
#     tuzatadi (Powo::Matcher — WCVP solishtiruvida ham xuddi shu jadval
#     ishlatiladi, ikkalasi ORASIDA FARQ bo'lmasligi uchun bitta manba)
#   - qiyshiq/tipografik apostroflarni (’ ‘ ʼ ´) to'g'ri apostrofga (') aylantiradi
#   - ketma-ket bo'shliqlarni bittaga tushiradi
#   - chetdagi bo'shliqlarni olib tashlaydi
# Manba: CSV va bazada bir xil o'simlik turli ko'rinishda yozilgan bo'lishi
# mumkin (masalan ikkilangan bo'shliq yoki apostrof varianti) — shu sabab
# find_or_initialize_by mavjud yozuvni topa olmay dublikat yaratardi.
def normalize_species_sci(value)
  Powo::Matcher.fix_cyrillic_homoglyphs(value.to_s).tr('’‘ʼ´', "'").gsub(/\s+/, ' ').strip
end

namespace :plants do
  desc 'CSV faylidan o\'simliklarni bazaga import qilish (kerak bo\'lgandagina)'
  task import: :environment do
    path = Rails.root.join('db', 'uzflora_plants_v8.csv')
    unless File.exist?(path)
      puts "XATO: #{path} topilmadi. uzflora_plants_v8.csv ni db/ papkasiga joylang."
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

    # --- O'z-o'zini davolash indeksi ------------------------------------
    #
    # NEGA KERAK: `normalize_species_sci` mantig'i o'zgarganda (masalan
    # kirill homoglif tuzatish shu commit'da qo'shildi) — bazada ESKI
    # importlardan qolgan yozuvlarning species_sci'si HALI ESKI (masalan
    # kirillcha) shaklda turishi mumkin, CSV esa (agar manba fayl ham
    # tuzatilgan bo'lsa) endi TOZA qiymat beradi. Oddiy
    # `find_by(species_sci: sci)` bunday eski yozuvni TOPMAYDI (chunki
    # bazadagi qiymat boshqacha matn) va noto'g'ri ravishda YANGI
    # (dublikat) yozuv yaratib yuborardi.
    #
    # Yechim: bazadagi HAR BIR yozuvning JORIY qiymatini SHU (yangi)
    # `normalize_species_sci` orqali qayta hisoblab, natija => id xaritasi
    # tuzamiz. Bu xaritada "agar shu bazadagi yozuvni HOZIR qayta
    # normallashtirsak nima chiqadi" javobi bor. Aksariyat yozuvlar uchun
    # natija o'zgarmaydi (allaqachon toza) — bu HECH QANDAY zarar
    # keltirmaydi, faqat "eskirgan" (drift'ga uchragan) yozuvlar uchun
    # foydali bo'ladi. Shu tarzda kod BIR MARTA yoziladi va normalize_
    # species_sci'ga kelajakda YANA biror tuzatish qo'shilsa (masalan
    # yangi homoglif turi topilsa) ham AVTOMATIK ishlab, dublikat
    # yaratmasdan mavjud yozuvni qayta nomlaydi.
    renormalized_index = {}
    Plant.pluck(:id, :species_sci).each do |id, sci_in_db|
      renormalized_index[normalize_species_sci(sci_in_db)] = id
    end

    created = 0
    updated = 0
    renamed = 0
    skipped_dup = 0
    skipped_conflict = 0
    row_num = 0
    seen_species_sci = {}

    CSV.foreach(path, headers: true) do |row|
      row_num += 1
      attrs = row.to_h
      raw_sci = attrs['species_sci']

      sci = normalize_species_sci(raw_sci)

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

      # Qidiruv ketma-ketligi (birinchi mos kelgani ishlatiladi):
      #   1) normallashtirilgan nom bo'yicha — oddiy, aksariyat holatlar
      #   2) CSV'dagi XOM (normallashtirishdan oldingi) qiymat bo'yicha —
      #      manba fayl hali tuzatilmagan bosqichda ham ishlashi uchun
      #   3) yuqoridagi "qayta normallashtirish" indeksi bo'yicha — manba
      #      fayl ALLAQACHON tuzatilgan, lekin baza hali eskirgan holatda
      #      qolgan bo'lsa (aynan shu migratsiyadagi holat)
      plant = Plant.find_by(species_sci: sci)
      plant ||= Plant.find_by(species_sci: raw_sci) if raw_sci != sci
      if plant.nil? && (legacy_id = renormalized_index[sci])
        candidate = Plant.find(legacy_id)
        # Xavfsizlik: qayta nomlashdan OLDIN, `sci` boshqa (turli id'li)
        # biron yozuvda ALLAQACHON ishlatilmaganini tekshiramiz — unique
        # indeks bor endi, shuning uchun tekshirmasdan saqlasak
        # tushunarsiz PG::UniqueViolation bilan BUTUN import yiqilishi
        # mumkin edi. Bu yerda esa aniq xabar bilan FAQAT shu qatorni
        # o'tkazib yuboramiz, import davom etadi.
        if Plant.where(species_sci: sci).where.not(id: candidate.id).exists?
          puts "XATO: id=#{candidate.id} (#{candidate.species_sci.inspect}) ni " \
               "#{sci.inspect}ga qayta nomlab bo'lmadi — bu nom ALLAQACHON boshqa " \
               "yozuvda ishlatilgan (unique cheklov buzilardi). Qo'lda tekshirilsin " \
               "— o'tkazib yuborildi."
          skipped_conflict += 1
          next
        end
        plant = candidate
      end

      attrs.delete('id')
      attrs.each { |k, v| attrs[k] = nil if v.nil? || v.to_s.strip.empty? }
      attrs['red_book'] = %w[true True TRUE 1].include?(attrs['red_book'].to_s)
      attrs['species_sci'] = sci

      plant ||= Plant.new
      was_new = plant.new_record?
      old_sci = plant.species_sci
      plant.assign_attributes(attrs)

      if plant.save
        if was_new
          created += 1
        elsif old_sci != sci
          puts "Qayta nomlandi: #{old_sci.inspect} → #{sci.inspect} (id=#{plant.id})"
          renamed += 1
        else
          updated += 1
        end
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
    puts "  Qayta nomlangan:  #{renamed}" if renamed.positive?
    puts "  Takror/xato sabab o'tkazib yuborilgan: #{skipped_dup}" if skipped_dup.positive?
    puts "  Unique to'qnashuv sababli o'tkazib yuborilgan: #{skipped_conflict}" if skipped_conflict.positive?
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
