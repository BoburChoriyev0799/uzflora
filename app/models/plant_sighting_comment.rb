# frozen_string_literal: true
#
# O'simlik kuzatuviga sharh. Har qanday foydalanuvchi boshqa birovning
# kuzatuviga (u tasdiqlangan yoki hali kutilayotgan bo'lsa ham) sharh
# qoldira oladi — rad etilgan kuzatuvlar esa allaqachon faqat egasi va
# ekspertga ko'rinadi, shuning uchun ularga sharh yozish imkoniyati ham
# amalda faqat o'sha ikkoviga ochiq bo'ladi.
#
class PlantSightingComment < ApplicationRecord
  belongs_to :user
  # `counter_cache: :comments_count` — ustun nomi standart Rails
  # konvensiyasidan (`plant_sighting_comments_count`) ATAYLAB qisqartirilgan
  # (ko'rish: db/migrate/*_add_comments_count_to_plant_sightings.rb).
  belongs_to :plant_sighting, counter_cache: :comments_count

  validates_presence_of :text
  validates :text, length: { maximum: 100 }

  scope :ordered, -> { order(created_at: :asc) }

  after_create :notify_owner!

  def owner?(user)
    user_id == user.try(:id)
  end

  def deletable_by?(user)
    owner?(user) || user.try(:expert?)
  end

  # Ransack 4+ xavfsizlik uchun ochiq ustunlarni talab qiladi — admin
  # paneldagi filter/qidiruv shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id text created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user plant_sighting]
  end

  private

  # Egasi o'ziga o'zi bildirishnoma olmasin (o'z rasmiga o'zi izoh
  # qoldirganda). `Notification.upsert_for!` (ko'rish: app/models/
  # notification.rb) — takroriy izohlarda BITTA qatorni yangilaydi.
  def notify_owner!
    return if plant_sighting.user_id.blank? || plant_sighting.user_id == user_id

    Notification.upsert_for!(
      recipient_id: plant_sighting.user_id, plant_sighting_id: plant_sighting_id,
      notification_type: 'new_comment', actor_id: user_id
    )
  end
end
