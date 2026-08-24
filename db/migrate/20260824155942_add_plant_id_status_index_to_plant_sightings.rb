# frozen_string_literal: true

# /plants ro'yxatida rasmi bor (tasdiqlangan kuzatuvi bor) o'simliklarni
# oldinga chiqarish uchun har bir Plant qatorida "shu plant_id bo'yicha
# approved kuzatuv bormi" degan EXISTS subso'rov ishlatiladi
# (plants_controller#index). Bu ustunlar bo'yicha qidiradi — indeks
# jadval kattalashganda (hozir 2 ta yozuv, lekin foydalanuvchilar ko'p
# rasm yuklagach o'sadi) subso'rovni tezlashtiradi.
class AddPlantIdStatusIndexToPlantSightings < ActiveRecord::Migration[7.1]
  def change
    add_index :plant_sightings, [:plant_id, :status], name: 'index_plant_sightings_on_plant_id_and_status'
  end
end
