# frozen_string_literal: true
#
# Sayt ichidagi xabarnoma. Hozircha yagona turi bor: `new_sighting` —
# kuzatilgan foydalanuvchining kuzatuvi tasdiqlanganda uning
# followers'lariga yuboriladi (ko'ring PlantSighting#notify_followers_of_approval
# va NotifyFollowersJob).
#
class Notification < ApplicationRecord
  belongs_to :recipient, class_name: 'User'
  belongs_to :actor, class_name: 'User'
  belongs_to :plant_sighting

  validates :recipient_id, uniqueness: { scope: :plant_sighting_id }

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
end
