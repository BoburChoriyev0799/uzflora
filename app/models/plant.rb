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
  # Qizil kitobdagi o'simliklar:  Plant.red_listed
  scope :red_listed, -> { where(red_book: true) }

  # Oila bo'yicha filtr:  Plant.by_family("Asteraceae")
  scope :by_family, ->(fam) { where(family_lat: fam) }

  # Nom bo'yicha qidiruv (ilmiy, ruscha yoki o'zbekcha):
  #   Plant.search("lola")
  # Nom BOSHIDAN mos kelganlar (masalan "Rosa..." so'rovi "lola" so'ziga
  # emas, "Rosa"ga) natijalar ro'yxatida yuqorida chiqadi — autocomplete
  # uchun muhim, foydalanuvchi odatda so'z boshini yozadi.
  # POWO/WCVP moslashtirilgandan keyin foydalanuvchi eski nomni ham
  # (species_sci/genus_lat), qabul qilingan yangi nomni ham
  # (accepted_name/accepted_genus) yozishi mumkin — ikkalasi ham bir xil
  # natijaga olib kelishi kerak.
  scope :search, lambda { |q|
    raw = q.to_s.strip.downcase
    term = "%#{raw}%"
    prefix = "#{raw}%"
    where(
      'LOWER(species_sci) LIKE :t OR LOWER(species_ru) LIKE :t OR ' \
      'LOWER(species_uz) LIKE :t OR LOWER(genus_lat) LIKE :t OR ' \
      'LOWER(accepted_name) LIKE :t OR LOWER(accepted_genus) LIKE :t',
      t: term
    ).order(
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

  # --- Ko'rsatiladigan nom ---
  # Saytda o'simlik nomini chiroyli chiqarish uchun.
  # O'zbekcha nom bo'lsa o'sha, bo'lmasa ilmiy nom.
  def display_name(locale = :uz)
    case locale.to_sym
    when :uz then species_uz.presence || species_sci
    when :ru then species_ru.presence || species_sci
    else species_sci
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
