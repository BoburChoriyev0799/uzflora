# frozen_string_literal: true
#
# Sayt ichidagi xabarnoma. Turlari: `new_sighting` — kuzatilgan
# foydalanuvchining kuzatuvi tasdiqlanganda uning followers'lariga
# yuboriladi (ko'ring PlantSighting#notify_followers_of_approval va
# NotifyFollowersJob); `new_comment` — kuzatuvga izoh qoldirilganda
# egasiga (ko'ring PlantSightingComment); `new_identification` — tur
# taklif qilinganda egasiga (ko'ring PlantSighting#propose_identification!).
#
class Notification < ApplicationRecord
  belongs_to :recipient, class_name: 'User'
  belongs_to :actor, class_name: 'User'
  belongs_to :plant_sighting

  # DIQQAT: qamrov TUR bilan ham cheklangan (bir xil (recipient, sighting)
  # juftligi uchun HAR turdan bittadan bo'lishi mumkin) — ko'rish:
  # db/migrate/*_widen_notification_uniqueness.rb. Eski (faqat sighting
  # bo'yicha) qamrov bitta sighting uchun BOR-YO'G'I bitta xabar turiga
  # imkon berardi.
  validates :recipient_id, uniqueness: { scope: [:plant_sighting_id, :notification_type] }

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    return if read?

    update!(read_at: Time.zone.now)
    recipient.clear_unread_notifications_cache!
  end

  # (recipient, sighting, type) uchun BITTA qatorni yaratadi/yangilaydi —
  # takroriy hodisalar (masalan bir nechta izoh) cheksiz qator
  # yig'masin, faqat oxirgi actor va "o'qilmagan" holatini ko'rsatsin
  # (mavjud minimalistik dizayn — navbar faqat so'nggi 8 tasini, /notifications
  # sahifasi ham to'liq tarixni emas, shu qatorlarni ko'rsatadi).
  # `rescue ... retry` — parallel so'rov (masalan ikki izoh bir vaqtda)
  # unique indeksga urilib qolsa, qayta topib UPDATE qiladi.
  def self.upsert_for!(recipient_id:, plant_sighting_id:, notification_type:, actor_id:)
    notification = find_or_initialize_by(
      recipient_id: recipient_id, plant_sighting_id: plant_sighting_id, notification_type: notification_type
    )
    notification.update!(actor_id: actor_id, read_at: nil)
    User.clear_unread_notifications_cache!(recipient_id)
    notification
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
