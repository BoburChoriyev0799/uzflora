# frozen_string_literal: true
#
# Bir tomonlama kuzatish yozuvi (iNaturalist kabi) — qabul/rad qilish
# yo'q, follower shunchaki followed'ni kuzata boshlaydi.
#
class Follow < ApplicationRecord
  belongs_to :follower, class_name: 'User', inverse_of: :active_follows
  belongs_to :followed, class_name: 'User', inverse_of: :passive_follows

  validates :follower_id, uniqueness: { scope: :followed_id }
  validate :cannot_follow_self

  private

  def cannot_follow_self
    errors.add(:followed_id, "o'zini o'zi kuzata olmaydi") if follower_id.present? && follower_id == followed_id
  end
end
