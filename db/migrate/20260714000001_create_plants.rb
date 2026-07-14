# frozen_string_literal: true
#
# Bu migration `plants` (o'simliklar) jadvalini yaratadi.
# Excel jadvalidagi barcha ustunlar shu yerda saqlanadi.
#
# Ishga tushirish (Claude Code / terminalda):
#   rails db:migrate
#
class CreatePlants < ActiveRecord::Migration[6.1]
  def change
    create_table :plants do |t|
      # --- TAKSONOMIYA (ilmiy tasnif) ---
      t.string :otdel_sci        # Bo'lim (ilmiy)      masalan: MAGNOLIOPHYTA
      t.string :otdel_ru         # Bo'lim (ruscha)
      t.string :class_sci        # Sinf (ilmiy)
      t.string :class_ru         # Sinf (ruscha)
      t.string :order_sci        # Tartib (ilmiy)
      t.string :order_ru         # Tartib (ruscha)
      t.string :family_apg_sci   # Oila APG IV (ilmiy) — asosiy oila
      t.string :family_apg_ru    # Oila APG IV (ruscha)
      t.string :family_tax_sci   # Oila Taxtadjyan (ilmiy)
      t.string :family_tax_ru    # Oila Taxtadjyan (ruscha)
      t.string :genus_sci        # Turkum (ilmiy)
      t.string :genus_ru         # Turkum (ruscha)

      # --- TUR (species) ---
      t.string :species_sci      # Tur ilmiy nomi — ENG MUHIM maydon
      t.string :species_ipni     # Tur nomi (IPNI bazasi bo'yicha)
      t.string :species_ru       # Tur ruscha nomi
      t.string :species_uz       # Tur o'zbekcha nomi
      t.string :plantlist_status # The Plant List statusi (accepted/synonym)
      t.text   :synonyms         # Sinonimlar
      t.text   :first_desc       # Birinchi tavsif manbasi
      t.string :plantlist_url    # The Plant List sahifasi havolasi
      t.string :plantarium_url   # Plantarium.ru fotosuratlar havolasi

      # --- BIOLOGIYA / EKOLOGIYA ---
      t.string :life_form        # Hayot shakli (bir yillik, ko'p yillik...)
      t.text   :habitat          # Yashash muhiti
      t.string :altitude         # Balandlik mintaqasi
      t.text   :economic         # Xo'jalik ahamiyati (dorivor, oziq-ovqat...)

      # --- GEOGRAFIYA / TARQALISH ---
      t.text   :areal            # Umumiy areal
      t.text   :distr_ca         # O'rta Osiyoda tarqalishi
      t.text   :distr_uz         # O'zbekistonda tarqalishi
      t.string :province         # Provinsiya
      t.string :okrug            # Okrug
      t.string :rayon            # Rayon
      t.text   :admin_regions    # Ma'muriy viloyatlar
      t.string :endemism         # Endemizm
      t.text   :opt              # Muhofaza etiladigan hududlarda mavjudligi (OPT)

      # --- STATUS ---
      t.string  :status          # Umumiy status
      t.boolean :red_book, default: false, null: false  # Qizil kitobda-yo'qligi

      # --- IDENTIFIKATORLAR (asl bazadagi ID'lar) ---
      t.string :species_id       # Excel'dagi tur ID (masalan 0322001)
      t.string :genus_id         # Excel'dagi turkum ID

      t.timestamps
    end

    # Qidiruv va filtrlashni tezlashtirish uchun indekslar
    add_index :plants, :species_sci
    add_index :plants, :species_uz
    add_index :plants, :family_apg_sci
    add_index :plants, :genus_sci
    add_index :plants, :red_book
    add_index :plants, :species_id, unique: true
  end
end
