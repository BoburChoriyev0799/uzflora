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
  belongs_to :plant_sighting

  validates_presence_of :text
  validates :text, length: { maximum: 100 }

  scope :ordered, -> { order(created_at: :asc) }

  def owner?(user)
    user_id == user.try(:id)
  end

  # Ransack 4+ xavfsizlik uchun ochiq ustunlarni talab qiladi — admin
  # paneldagi filter/qidiruv shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id text created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user plant_sighting]
  end
end
