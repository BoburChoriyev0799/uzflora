# frozen_string_literal: true
#
# Plant (O'simlik) modeli — o'simliklar katalogi.
#
class Plant < ApplicationRecord
  # --- Bog'lanishlar ---
  has_many :plant_sightings, dependent: :nullify

  # --- Validatsiyalar (ma'lumot to'g'riligini tekshirish) ---
  validates :species_sci, presence: true

  # --- Qidiruv (scope'lar) ---
  # Qizil kitobdagi o'simliklar (shu YOZUVNING o'zi):  Plant.red_listed
  scope :red_listed, -> { where(red_book: true) }

  # Qizil kitobdagi o'simliklar GURUH darajasida: shu yozuvning o'zi
  # YOKI accepted_name bo'yicha bir xil guruhdagi biror a'zosi Qizil
  # kitobda bo'lsa (`group_red_book`, `plants:mark_primary` tomonidan
  # oldindan hisoblab qo'yilgan — ko'rish: shu ustunning izohi
  # `db/migrate/*_add_group_red_book_to_plants.rb`da). Ro'yxat sahifasida
  # (`PlantsController#index`) FAQAT primary yozuvlar ko'rinadi, shuning
  # uchun Qizil kitob filtri ham GURUH darajasida ishlashi shart — aks
  # holda yashiringan (primary_record=false) Qizil kitob turi filtrga
  # umuman tushmay qolardi.
  scope :group_red_listed, -> { where(group_red_book: true) }

  # Oila bo'yicha filtr:  Plant.by_family("Asteraceae")
  scope :by_family, ->(fam) { where(family_lat: fam) }

  # Qidiruv qamrab oladigan ustunlar — BITTA "birlashtirilgan matn"ga
  # COALESCE bilan qo'shiladi (NULL'lar bo'sh satrga aylanadi, aks holda
  # Postgres'da NULL || '...' = NULL bo'lib, butun qatorni "topilmadi"
  # qilib qo'yardi). `accepted_authors` ATAYLAB qo'shilgan: sahifada
  # ko'rsatiladigan to'liq ilmiy nom (`display_sci_name`) = accepted_name +
  # accepted_authors, lekin ular BAZADA ikkita alohida ustunda — shu
  # ustun bo'lmasa foydalanuvchi ekrandagi nomni ("Colchicum robustum
  # (Bunge) Stef.") nusxalab qidirsa 0 natija chiqardi.
  SEARCH_COLUMNS = %w[
    species_sci accepted_name accepted_authors species_uz species_ru
    genus_lat accepted_genus
  ].freeze
  SEARCH_TEXT_SQL = SEARCH_COLUMNS.map { |c| "COALESCE(#{c}, '')" }.join(" || ' ' || ").freeze

  # Nom bo'yicha qidiruv (ilmiy — mualliflari bilan ham, ruscha yoki
  # o'zbekcha): Plant.search("Colchicum robustum (Bunge) Stef.")
  #
  # So'rov SO'ZLARGA (token) ajratiladi va HAR BIR so'z (AND mantiqi bilan)
  # yuqoridagi SEARCH_COLUMNS'ning BIRLASHTIRILGAN matnida qidiriladi.
  # Qavslar bo'sh joyga almashtiriladi ("(Bunge)" -> "Bunge") — foydalanuvchi
  # sahifada ko'rsatilgan to'liq nomni ("Colchicum robustum (Bunge) Stef.")
  # xuddi shundayligicha nusxalab qidirishi mumkin bo'lishi uchun. Har bir
  # so'z ALOHIDA ustunda emas, BITTA birlashtirilgan matnda qidirilgani
  # uchun so'zlar turli ustunlarga (masalan nom bitta, muallif boshqasida)
  # bo'linib ketgan bo'lsa ham barchasi topiladi — "Merendera robusta
  # Bunge" (eski nom + muallif, ikkalasi species_sci'ning o'zida) ham,
  # "robustum Stef" (aralash, bir-biriga bog'liq bo'lmagan bo'laklar) ham.
  #
  # Nom BOSHIDAN mos kelganlar tepada chiqadi — autocomplete uchun muhim
  # (foydalanuvchi odatda so'z boshini yozadi).
  #
  # Bo'sh/faqat bo'shliqli so'rovda — filtrsiz, hammasi qaytadi.
  scope :search, lambda { |q|
    cleaned = q.to_s.tr('()', ' ').squish
    tokens = cleaned.downcase.split(' ')
    next all if tokens.empty?

    relation = all
    tokens.each do |token|
      relation = relation.where("LOWER(#{SEARCH_TEXT_SQL}) LIKE ?", "%#{sanitize_sql_like(token)}%")
    end

    prefix = "#{sanitize_sql_like(cleaned.downcase)}%"
    relation.order(
      Arel.sql(
        sanitize_sql_array(
          ['CASE WHEN LOWER(species_sci) LIKE :p OR LOWER(species_ru) LIKE :p OR ' \
           'LOWER(species_uz) LIKE :p OR LOWER(genus_lat) LIKE :p OR ' \
           'LOWER(accepted_name) LIKE :p OR LOWER(accepted_genus) LIKE :p THEN 0 ELSE 1 END',
           p: prefix]
        )
      )
    ).order(:species_sci)
  }

  # `search`ni PLANTS ro'yxati (`PlantsController#index`) uchun "guruh
  # darajasida" ishlatadi: BUTUN jadval bo'yicha (`primary_record`dan
  # qat'i nazar) mos kelganlarni topadi, so'ng natijani ularning PRIMARY
  # vakillariga "ko'chiradi" — aks holda masalan "Merendera hissarica"
  # (o'zi primary emas) qidirilsa hech narsa topilmas edi, chunki uning
  # primary'si ("Merendera robusta") bu matnga mos kelmaydi.
  #
  # BITTA SQL so'rovi ichida ikkita quyi-so'rov sifatida qo'llaniladi
  # (`to_sql` — Ruby massividagi ID'larni katta IN ro'yxatiga aylantirib
  # o'tirmasdan). Xavfsizlik: `matched_sql` to'g'ridan-to'g'ri
  # foydalanuvchi kiritmasi EMAS — `search` allaqachon `sanitize_sql_like`/
  # bog'langan parametrlar orqali xavfsiz SQL hosil qiladi, `.to_sql` esa
  # shu (allaqachon qochirilgan/tirnoqlangan) YAKUNIY satrni qaytaradi;
  # `query`ning o'zi bu satrga TO'G'RIDAN-TO'G'RI HECH QACHON kirmaydi —
  # shuning uchun bu yerda in'ektsiya xavfi yo'q. (`sanitize_sql_array`
  # ATAYLAB ishlatilmagan: `matched_sql` o'z ichida LIKE naqshlaridan "%"
  # belgilarini olib yuradi, `sanitize_sql_array`ning bog'lanmagan-massiv
  # bosqichi esa satrni printf-uslubida ("%" operatori) qayta talqin qilib,
  # `ArgumentError` bilan yiqilar edi — tekshirib ko'rilgan.)
  def self.group_search(query)
    # `.reorder(nil)`: `search` o'zining saralashini (prefiks moslik +
    # species_sci) qo'shadi, lekin bu yerda faqat ID TO'PLAMI (a'zolik
    # tekshiruvi, `IN (...)`) kerak — saralashning o'zi ortiqcha (natija
    # tartibiga ta'sir qilmaydi) va bekorga hisoblash xarajati qo'shardi.
    matched_sql = search(query).reorder(nil).select(:id).to_sql
    where(
      "plants.id IN (#{matched_sql}) OR plants.accepted_name IN (" \
      "SELECT p2.accepted_name FROM plants p2 " \
      "WHERE p2.id IN (#{matched_sql}) AND p2.accepted_name IS NOT NULL)"
    )
  end

  # --- Ko'rsatiladigan nom ---
  # Saytda o'simlik nomini chiroyli chiqarish uchun. Tarjima (uz/ru)
  # bo'lsa o'sha, bo'lmasa ESKI species_sci EMAS, balki `display_sci_name`
  # (POWO moslashtirilgan bo'lsa — joriy qabul qilingan ilmiy nom) —
  # aks holda POWO orqali qayta nomlangan, lekin hali tarjimasi yo'q
  # o'simlik (masalan GBIF/WCVP orqali qo'shilgan yangi turlar) sahifada
  # ESKIRGAN nom bilan chiqib qolardi.
  def display_name_uz
    species_uz.presence || display_sci_name
  end

  def display_name(locale = :uz)
    case locale.to_sym
    when :uz then display_name_uz
    when :ru then species_ru.presence || display_sci_name
    else display_sci_name
    end
  end

  # Qizil kitob belgisi (frontendda ishlatish uchun)
  def red_book?
    red_book
  end

  # --- POWO/WCVP taksonomiyasi asosida ko'rsatiladigan nomlar ---
  # Qabul qilingan (accepted) ilmiy nom + muallif. POWO moslashtirilmagan
  # (accepted_name bo'sh) yozuvlarda eski species_sci'ga qaytadi — sahifa
  # avvalgidek ko'rinishda qoladi.
  def display_sci_name
    return species_sci if accepted_name.blank?

    [accepted_name, accepted_authors.presence].compact.join(' ')
  end

  # Bazadagi eski (species_sci) nom, FAQAT display_sci_name'dan haqiqatan
  # farq qilsa qaytadi — bo'shliq/qiyshiq apostrof farqi hisobga
  # olinmaydi (import_plants.rake'dagi normalize_species_sci bilan bir
  # xil mantiq). Farq bo'lmasa (yoki POWO moslashtirilmagan bo'lsa) nil.
  def alt_name
    return nil if accepted_name.blank?
    return nil if normalize_sci_name(display_sci_name) == normalize_sci_name(species_sci)

    species_sci
  end

  # alt_name uchun yorliq: wcvp_status TO'RT xil botanik holatni bildiradi,
  # bularni aralashtirib bo'lmaydi —
  #   "Synonym"                     — nom to'g'ri e'lon qilingan, lekin
  #                                    boshqa (qabul qilingan) turga
  #                                    qo'shilgan → :synonym ("Sinonimi")
  #   "Orthographic"                — bu O'SHA tur, faqat imlosi bazada
  #                                    boshqacha yozilgan → :spelling_variant
  #                                    ("Bazadagi imlo")
  #   "Illegitimate"/"Invalid"      — nom nomenklatura QOIDALARI bo'yicha
  #                                    yaroqsiz (noqonuniy yoki haqiqiy
  #                                    emas e'lon qilingan) — na sinonim, na
  #                                    imlo farqi, alohida holat →
  #                                    :rejected_name ("Rad etilgan nom")
  #   boshqa hammasi (shu jumladan BO'SH) — zaxira: qo'lda tuzatilgan
  #                                    (manual_override) yozuvda WCVP
  #                                    holati umuman bo'lmasligi mumkin —
  #                                    unda yuqoridagi uch aniq ma'nodan
  #                                    birini "taxmin qilib" ko'rsatish
  #                                    yolg'on bo'lardi, shuning uchun
  #                                    neytral :database_name ("Bazadagi
  #                                    nom")
  def alt_name_label_key
    case wcvp_status
    when 'Synonym' then :synonym
    when 'Orthographic' then :spelling_variant
    when 'Illegitimate', 'Invalid' then :rejected_name
    else :database_name
    end
  end

  # Taksonomiya jadvali uchun oila/turkum — accepted_family/accepted_genus
  # bor bo'lsa o'sha, bo'lmasa CSV manbadagi family_lat/genus_lat.
  #
  # DIQQAT: family_lat/genus_lat'da muallif qo'shimchasi bor (masalan
  # "Ophioglossum L."), accepted_family/accepted_genus'da esa yo'q — POWO
  # bu darajalar uchun alohida muallif ustuni bermaydi (faqat tur
  # darajasida accepted_authors bor). Muallifni sun'iy ravishda
  # accepted_family/accepted_genus'ga yopishtirib qo'yish noto'g'ri
  # bo'lardi (oila/turkumning o'z muallifi turniki bilan bir xil emas),
  # shuning uchun ular qasddan mualifsiz qoldirilgan — xuddi POWO'ning
  # o'zi ham yuqori darajalarni shunday ko'rsatadi.
  def display_family_lat
    accepted_family.presence || family_lat
  end

  def display_genus_lat
    accepted_genus.presence || genus_lat
  end

  # Tashqi ilmiy manbalar (iNaturalist, GBIF, POWO) qidiruvi uchun toza
  # tur nomi: muallif va boshqa qo'shimchalarsiz "Jins epitet" (masalan
  # "Tulipa korolkovii Regel" -> "Tulipa korolkovii"). Gibrid formulalar
  # ("Psylliostachys x androssovii Roshkova") uchun "x"/"×" belgisi ham
  # saqlanadi. species_sci bo'sh bo'lsa nil qaytadi.
  def external_search_name
    return nil if species_sci.blank?

    words = species_sci.split(/\s+/)
    take = words[1]&.match?(/\A[x×]\z/i) ? 3 : 2
    words.first(take).join(' ')
  end

  # Ransack 4+ xavfsizlik uchun ochiq ustunlarni talab qiladi — admin
  # paneldagi filter/qidiruv shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id species_sci species_ru species_uz genus_lat family_lat red_book created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[plant_sightings]
  end

  # --- 3 tilli tavsif maydonlari ---
  # `display_name`даgi naqsh bilan bir xil: tarjima bo'sh bo'lsa
  # o'zbekcha (asl) qiymatga qaytadi, umuman yo'qolib qolmaydi.
  def life_form_localized(locale = :uz)
    localized_field(life_form, life_form_ru, life_form_en, locale)
  end

  def usage_localized(locale = :uz)
    localized_field(usage, usage_ru, usage_en, locale)
  end

  def habitat_place_localized(locale = :uz)
    localized_field(habitat_place, habitat_place_ru, habitat_place_en, locale)
  end

  def habitat_env_localized(locale = :uz)
    localized_field(habitat_env, habitat_env_ru, habitat_env_en, locale)
  end

  def range_world_localized(locale = :uz)
    localized_field(range_world, range_world_ru, range_world_en, locale)
  end

  def range_central_asia_localized(locale = :uz)
    localized_field(range_central_asia, range_central_asia_ru, range_central_asia_en, locale)
  end

  def range_uzbekistan_localized(locale = :uz)
    localized_field(range_uzbekistan, range_uzbekistan_ru, range_uzbekistan_en, locale)
  end

  private

  # import_plants.rake'dagi normalize_species_sci bilan bir xil: faqat
  # qiyshiq apostrof va ortiqcha bo'shliqni tenglashtiradi, haqiqiy imlo
  # farqiga tegmaydi.
  def normalize_sci_name(value)
    value.to_s.tr('’‘ʼ´', "'").gsub(/\s+/, ' ').strip
  end

  def localized_field(uz_value, ru_value, en_value, locale)
    case locale.to_sym
    when :ru then ru_value.presence || uz_value
    when :en then en_value.presence || uz_value
    else uz_value
    end
  end
end
