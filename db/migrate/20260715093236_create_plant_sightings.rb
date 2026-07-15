# frozen_string_literal: true
#
# Foydalanuvchilar yuklagan o'simlik kuzatuvlari (rasm + joylashuv + sana).
# Bird jadvaliga o'xshash naqsh: Plant — katalog, PlantSighting — kuzatuv.
#
class CreatePlantSightings < ActiveRecord::Migration[7.1]
  def change
    create_table :plant_sightings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plant, null: true, foreign_key: true
      # Kuzatuvni tasdiqlovchi mutaxassis — Bird'dagi expert_id bilan bir xil
      # naqsh. Hozircha ishlatilmaydi (moderatsiya interfeysi keyingi
      # bosqichda quriladi), lekin "Katta yil" ball tizimi buni talab qiladi.
      t.references :expert, null: true, foreign_key: { to_table: :users }

      t.string :photo
      t.datetime :timestamp
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.text :address
      t.string :note, limit: 100

      # Hozircha yaratilishning o'zidayoq true — to'liq moderatsiya
      # keyingi bosqichda qo'shiladi.
      t.boolean :published, null: false, default: true

      t.timestamps
    end

    add_index :plant_sightings, :published
  end
end
