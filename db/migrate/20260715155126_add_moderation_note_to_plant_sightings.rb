# frozen_string_literal: true
#
# Ekspert rad etganda (reject) NEGA rad etganini yozib qo'yishi uchun —
# bu izoh faqat kuzatuv egasiga ko'rinadi.
#
class AddModerationNoteToPlantSightings < ActiveRecord::Migration[7.1]
  def change
    add_column :plant_sightings, :moderation_note, :string, limit: 100
  end
end
