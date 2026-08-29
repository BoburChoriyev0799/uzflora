# frozen_string_literal: true
#
# Bildirishnoma tizimi endi comment/identifikatsiya turlari uchun ham
# qayta ishlatiladi (ko'rish: Notification#new_comment/#new_identification
# yaratuvchi kod PlantSightingComment/PlantSighting'da). Eski unique
# indeks FAQAT (recipient, sighting) bo'yicha edi — ya'ni bitta sighting
# uchun bitta recipient'ga umuman BITTA xabar (turi qat'i nazar) mumkin
# edi. Endi TUR ham qamrovga qo'shiladi — shu bilan bir xil (recipient,
# sighting) juftligi uchun HAR TURDAN bittadan xabar bo'lishi mumkin
# (masalan bitta "tasdiqlandi" + bitta "izoh qoldirildi"), lekin bitta
# turdan ikkinchisi hali ham yaratilmaydi (takroriy izohlar shu BITTA
# qatorni yangilaydi — ko'rish: PlantSightingComment#notify_owner!).
# Mavjud qatorlar yangi (kengroq) cheklovga avtomatik mos keladi —
# ma'lumot migratsiyasi shart emas.
#
class WidenNotificationUniqueness < ActiveRecord::Migration[7.1]
  def change
    remove_index :notifications, name: 'index_notifications_on_recipient_id_and_plant_sighting_id'
    add_index :notifications, [:recipient_id, :plant_sighting_id, :notification_type],
              unique: true, name: 'index_notifications_on_recipient_sighting_type'
  end
end
