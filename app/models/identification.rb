# frozen_string_literal: true
#
# Jamoaviy aniqlash — bitta foydalanuvchining bitta kuzatuvga (PlantSighting)
# tur haqidagi taklifi. Yaratish/o'zgartirish/qaytarib olish — ko'rish:
# PlantSighting#propose_identification!/#withdraw_identification!
# (IdentificationsController shu metodlarni chaqiradi, bu yerda o'zi
# hech qanday moderatsiya mantig'i YO'Q — faqat ma'lumot saqlaydi).
#
class Identification < ApplicationRecord
  belongs_to :plant_sighting
  belongs_to :user
  belongs_to :plant

  scope :active, -> { where(withdrawn_at: nil) }

  def owner?(user)
    user_id == user.try(:id)
  end

  def withdrawn?
    withdrawn_at.present?
  end

  def expert_vote?
    user.expert?
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[id plant_sighting_id user_id plant_id withdrawn_at created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[plant_sighting user plant]
  end
end
