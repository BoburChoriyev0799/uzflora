# frozen_string_literal: true
#
# Rasm versiyalarini yaratish + R2'ga yuklash endi ProcessSightingImageJob
# orqali FON jarayonida bajariladi (PlantSightingsController#create
# darhol qaytishi uchun). Shu uchun uchta yangi ustun kerak:
#
# - photo_cache_name — CarrierWave keshdagi (hali R2'ga yuklanmagan)
#   faylning identifikatori. Request tugagandan keyin job'ga "qaysi
#   keshlangan faylni R2'ga yuklash kerak"ligini aytish uchun saqlanadi
#   (CarrierWave'ning o'zi bu qiymatni saqlamaydi — faqat vaqtinchalik,
#   forma qayta ko'rsatilganda ishlatiladi).
# - photo_status — foydalanuvchiga (galereyada) hozircha rasm fon
#   jarayonida ekanini yoki tayyorligini ko'rsatish uchun.
# - photo_error — job muvaffaqiyatsiz bo'lsa, sababi shu yerda saqlanadi
#   (loglash + kelajakda debugging/qo'llab-quvvatlash uchun).
class AddPhotoProcessingStateToPlantSightings < ActiveRecord::Migration[7.1]
  def up
    add_column :plant_sightings, :photo_cache_name, :string
    add_column :plant_sightings, :photo_status, :string, default: "pending", null: false
    add_column :plant_sightings, :photo_error, :text

    # Bu migratsiyadan OLDIN yaratilgan barcha kuzatuvlarning rasmi
    # allaqachon to'liq qayta ishlangan va R2'da — ularga "pending"
    # (yangi standart qiymat) emas, "ready" mos keladi.
    execute "UPDATE plant_sightings SET photo_status = 'ready'"

    add_index :plant_sightings, :photo_status
  end

  def down
    remove_index :plant_sightings, :photo_status
    remove_column :plant_sightings, :photo_error
    remove_column :plant_sightings, :photo_status
    remove_column :plant_sightings, :photo_cache_name
  end
end
