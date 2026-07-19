class Subscription < ActiveRecord::Base
  belongs_to :user

  validates_presence_of :user, :year

  # Ransack 4+ xavfsizlik uchun ochiq ustunlarni talab qiladi — admin
  # paneldagi filter/qidiruv shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id year created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user]
  end
end
