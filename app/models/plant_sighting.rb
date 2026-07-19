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

  has_many :plant_sighting_comments, dependent: :destroy

  mount_uploader :photo, PlantSightingUploader

  # Moderatsiya holati. Rails enum'ning o'zi .pending/.approved/.rejected
  # scope'larini va pending?/approved?/rejected? metodlarini avtomatik
  # yaratadi — buni qo'lda alohida yozish shart emas. Yangi yozuv har doim
  # ustunning DB standart qiymati ("pending") bilan boshlanadi — hech qayerda
  # avtomatik "approved" qilinmaydi.
  enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected' }

  validates_presence_of :user_id
  validates :note, length: { maximum: 100 }
  validates :moderation_note, length: { maximum: 100 }

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

  # Rad etilgan kuzatuvni faqat egasi va ekspert ko'ra oladi — boshqalarga
  # (profilda ham, to'g'ridan-to'g'ri havola orqali ham) ko'rinmaydi.
  def visible_to?(user)
    return true unless rejected?
    owner?(user) || user.try(:expert?)
  end

  # Ekspert turni o'zgartirmaydi (foydalanuvchi tanlagan plant_id qoladi) —
  # faqat tasdiqlaydi yoki rad etadi.
  def approve!(expert)
    update!(status: :approved, expert: expert, reviewed_at: Time.zone.now, moderation_note: nil)
  end

  # note — ekspert nega rad etganini tushuntiruvchi ixtiyoriy izoh, faqat
  # kuzatuv egasiga ko'rinadi (plant_sightings/show.html.haml'da tekshiriladi).
  def reject!(expert, note = nil)
    update!(status: :rejected, expert: expert, reviewed_at: Time.zone.now, moderation_note: note)
  end

  # Ransack 4+ xavfsizlik uchun ochiq ustunlarni talab qiladi — admin
  # paneldagi filter/qidiruv shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id status published timestamp created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user plant expert]
  end
end
