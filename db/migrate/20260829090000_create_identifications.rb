# frozen_string_literal: true
#
# Jamoaviy aniqlash (community identification) — istalgan foydalanuvchi
# kuzatuvga tur taklif qilishi mumkin (ko'rish: PlantSighting#propose_identification!).
# Bitta foydalanuvchi — bitta kuzatuvga BITTA qator (unique index): fikrini
# o'zgartirsa shu qatorning o'zi yangilanadi (`plant_id`), qaytarib olsa
# `withdrawn_at` belgilanadi — hech qachon ikkinchi qator yaratilmaydi.
#
class CreateIdentifications < ActiveRecord::Migration[7.1]
  def change
    create_table :identifications do |t|
      t.references :plant_sighting, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :plant, null: false, foreign_key: true
      t.datetime :withdrawn_at

      t.timestamps
    end

    add_index :identifications, [:plant_sighting_id, :user_id], unique: true
  end
end
