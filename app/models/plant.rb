# frozen_string_literal: true
#
# Plant (O'simlik) modeli.
# Bu birds.uz'dagi Bird modelining o'simliklarga moslashtirilgan variantidir.
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
  scope :search, lambda { |q|
    term = "%#{q.to_s.strip.downcase}%"
    where(
      'LOWER(species_sci) LIKE :t OR LOWER(species_ru) LIKE :t OR ' \
      'LOWER(species_uz) LIKE :t OR LOWER(genus_lat) LIKE :t',
      t: term
    )
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

  private

  def localized_field(uz_value, ru_value, en_value, locale)
    case locale.to_sym
    when :ru then ru_value.presence || uz_value
    when :en then en_value.presence || uz_value
    else uz_value
    end
  end
end
