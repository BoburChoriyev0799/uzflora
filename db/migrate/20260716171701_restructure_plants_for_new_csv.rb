# frozen_string_literal: true
#
# `db/uzflora_plants_final.csv` (4412 o'simlik, 25 ustun) eski CSV'дан
# boy va boshqacha nomlangan. Bu migratsiya `plants` jadvalini yangi
# CSV'ning ustun to'plamiga moslaydi:
#
#   1) Mazmuni bir xil, nomi o'zgargan ustunlar — RENAME (ma'lumot
#      yo'qolmaydi, faqat CSV'дagi yangi nomga mos keladi).
#   2) Yangi CSV'da umuman yo'q, hech narsaga mos kelmaydigan eski
#      ustunlar — DROP (ular allaqachon eskirgan, `plants:import` doim
#      to'liq qayta yozadi, shu sabab saqlab turishning foydasi yo'q).
#   3) Yangi CSV'da bor, eskisida analogi yo'q ustunlar — ADD.
#
class RestructurePlantsForNewCsv < ActiveRecord::Migration[7.1]
  def change
    # --- 1) RENAME: mazmuni bir xil, CSV'da nomi boshqacha ---
    rename_column :plants, :otdel_sci, :division_lat
    rename_column :plants, :otdel_ru, :division_ru
    rename_column :plants, :class_sci, :class_lat
    rename_column :plants, :order_sci, :order_lat
    rename_column :plants, :family_apg_sci, :family_lat
    rename_column :plants, :family_apg_ru, :family_ru
    rename_column :plants, :genus_sci, :genus_lat
    rename_column :plants, :economic, :usage
    rename_column :plants, :areal, :range_world
    rename_column :plants, :distr_ca, :range_central_asia
    rename_column :plants, :distr_uz, :range_uzbekistan
    rename_column :plants, :opt, :protected_areas

    # E'tibor: rename_column PostgreSQL'da bog'liq indexlarni (masalan
    # index_plants_on_family_apg_sci -> index_plants_on_family_lat) o'zi
    # avtomatik qayta nomlaydi — alohida rename_index shart emas.

    # --- 2) DROP: yangi CSV'da yo'q, hech narsaga rename qilinmagan ---
    remove_column :plants, :family_tax_sci, :string
    remove_column :plants, :family_tax_ru, :string
    remove_column :plants, :habitat, :text
    remove_column :plants, :species_ipni, :string
    remove_column :plants, :plantlist_status, :string
    remove_column :plants, :synonyms, :text
    remove_column :plants, :first_desc, :text
    remove_column :plants, :plantlist_url, :string
    remove_column :plants, :altitude, :string
    remove_column :plants, :province, :string
    remove_column :plants, :okrug, :string
    remove_column :plants, :rayon, :string
    remove_column :plants, :admin_regions, :text
    remove_column :plants, :status, :string

    remove_index :plants, :species_id
    remove_column :plants, :species_id, :string
    remove_column :plants, :genus_id, :string

    # --- 3) ADD: yangi CSV'da bor, eskisida analogi yo'q ---
    add_column :plants, :family_takhtajan, :string
    add_column :plants, :habitat_env, :text
    add_column :plants, :habitat_place, :text

    # species_sci endi import'ning tabiiy kaliti (find_or_initialize_by).
    # UNIQUE emas — CSV'da 1 ta bilinган takror qiymat bor
    # ("Exochorda albertii Regel", 2 ta har xil o'simlikка noto'g'ri
    # yozilgan) — bu manba ma'lumotidagi xato, import task uni
    # aniqlab ogohlantiradi, lekin DB darajasidagi UNIQUE cheklov import'ni
    # butunlay to'xtatib qo'ymasligi uchun oddiy (non-unique) index
    # qoldiramiz.
  end
end
