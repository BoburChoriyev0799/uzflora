# frozen_string_literal: true
#
# O'simliklarning QORAQALPOQCHA nomi va uning manbasi (ilmiy sayt uchun
# muhim — 1970-80 yillardagi Ережепов/Шербаев kitoblari).
#
# ISO 639-3 kodi ATAYLAB `kaa` (qoraqalpoq) — `kk` (qozoqcha) EMAS, ikkisi
# adashtirilmasin. `species_uz`/`species_ru`ga TEGILMAYDI — bu mustaqil,
# qo'shimcha ma'lumot ustuni (til almashtirgichga qo'shilmaydi).
#
# `species_kaa` indekslanadi — `Plant.search` (SEARCH_COLUMNS) bu ustunni
# ham qamrab oladi, foydalanuvchi "козыткен" deb qidirsa tur topilsin.
class AddSpeciesKaaToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :species_kaa, :string
    add_column :plants, :species_kaa_source, :string

    add_index :plants, :species_kaa
  end
end
