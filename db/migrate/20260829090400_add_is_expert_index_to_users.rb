# frozen_string_literal: true
#
# Bosh sahifadagi jonli statistika panelidagi "Ekspertlar soni" COUNT
# so'rovi shu indeksdan foydalanadi (ko'rish: Statistics::Live).
#
class AddIsExpertIndexToUsers < ActiveRecord::Migration[7.1]
  def change
    add_index :users, :is_expert
  end
end
