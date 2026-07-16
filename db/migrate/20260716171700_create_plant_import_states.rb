# frozen_string_literal: true
#
# `plants:import` rake taskning har deploy'da 4412 qatorni qayta o'qib
# o'tirmasligi uchun — CSV faylning SHA256 checksum'i shu yerda saqlanadi.
# Diskka (tmp/) EMAS, bazaga yozamiz, chunki Render'ning bepul planida disk
# har deploy'da tozalanadi (efemer), baza esa doimiy.
#
# Bitta qatordan iborat "singleton" jadval: har doim id=1 yozuv ishlatiladi.
#
class CreatePlantImportStates < ActiveRecord::Migration[7.1]
  def change
    create_table :plant_import_states do |t|
      t.string :csv_checksum
      t.integer :row_count
      t.datetime :imported_at

      t.timestamps
    end
  end
end
