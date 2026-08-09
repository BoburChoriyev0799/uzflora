# frozen_string_literal: true
#
# Sayt ichidagi xabarnomalar. Hozircha yagona tur bor (kuzatilgan
# foydalanuvchining kuzatuvi tasdiqlanishi) — shuning uchun polimorfik
# emas, to'g'ridan-to'g'ri `plant_sighting_id` FK. `notification_type`
# ustuni baribir saqlanadi — kelajakda boshqa turdagi xabarlar
# (masalan "sizni kuzata boshladi") qo'shilganda migratsiyasiz
# kengayish imkonini beradi.
#
class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :plant_sighting, null: false, foreign_key: true
      t.string :notification_type, null: false, default: 'new_sighting'
      t.datetime :read_at

      t.timestamps
    end

    # Ro'yxat tartibi uchun.
    add_index :notifications, [:recipient_id, :created_at]
    # O'qilmaganlarni tez sanash uchun QISMAN indeks — faqat read_at
    # NULL bo'lgan qatorlarni o'z ichiga oladi, jadval katta o'sib
    # ketsa ham kichik/tez qoladi (navbar qo'ng'iroq soni shu yerdan).
    add_index :notifications, :recipient_id, where: 'read_at IS NULL', name: 'index_notifications_on_recipient_id_unread'
    # Bir xil (recipient, plant_sighting) juftligi uchun ikkinchi marta
    # xabar yaratilmasin (job qayta ishga tushsa ham idempotent bo'lsin).
    add_index :notifications, [:recipient_id, :plant_sighting_id], unique: true
  end
end
