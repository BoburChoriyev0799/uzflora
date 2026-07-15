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

  # Moderatsiya holati. Rails enum'ning o'zi .pending/.approved/.rejected
  # scope'larini va pending?/approved?/rejected? metodlarini avtomatik
  # yaratadi — buni qo'lda alohida yozish shart emas. Yangi yozuv har doim
  # ustunning DB standart qiymati ("pending") bilan boshlanadi — hech qayerda
  # avtomatik "approved" qilinmaydi.
  enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected' }

  validates_presence_of :user_id
  validates :note, length: { maximum: 100 }

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :known, -> { where.not(plant_id: nil) }
  scope :unknown, -> { where(plant_id: nil) }
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

  # Ekspert turni o'zgartirmaydi (foydalanuvchi tanlagan plant_id qoladi) —
  # faqat tasdiqlaydi yoki rad etadi.
  def approve!(expert)
    update!(status: :approved, expert: expert, reviewed_at: Time.zone.now)
  end

  def reject!(expert)
    update!(status: :rejected, expert: expert, reviewed_at: Time.zone.now)
  end
end
