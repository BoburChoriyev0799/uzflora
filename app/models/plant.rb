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
  scope :by_family, ->(fam) { where(family_apg_sci: fam) }

  # Nom bo'yicha qidiruv (ilmiy, ruscha yoki o'zbekcha):
  #   Plant.search("lola")
  scope :search, lambda { |q|
    term = "%#{q.to_s.strip.downcase}%"
    where(
      'LOWER(species_sci) LIKE :t OR LOWER(species_ru) LIKE :t OR ' \
      'LOWER(species_uz) LIKE :t OR LOWER(genus_sci) LIKE :t',
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
end
