# frozen_string_literal: true
#
# Foydalanuvchi yuklagan o'simlik kuzatuvi — rasm, sana, joylashuv va
# (ixtiyoriy) aniqlangan tur. Bird modeliga o'xshash naqsh: Plant — katalog,
# PlantSighting — kuzatuv yozuvi.
#
class PlantSighting < ApplicationRecord
  belongs_to :user
  belongs_to :plant, optional: true
  belongs_to :expert, class_name: 'User', optional: true

  mount_uploader :photo, PlantSightingUploader

  validates_presence_of :user_id
  validates :note, length: { maximum: 100 }

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :known, -> { where.not(plant_id: nil) }
  scope :unknown, -> { where(plant_id: nil) }
  scope :unconfirmed, -> { where(expert_id: nil) }
  scope :approved, -> { where.not(expert_id: nil) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  def unknown?
    plant_id.blank?
  end

  def can_publish?
    photo.present? && timestamp.present? && address_valid?
  end

  def address_valid?
    latitude.present? && longitude.present?
  end

  def address_string
    address.presence || "#{latitude}; #{longitude}"
  end

  def owner?(user)
    user_id == user.try(:id)
  end
end
