# frozen_string_literal: true
#
# O'simlik kuzatuviga sharh — Bird'ning eski Comment tizimiga o'xshash
# naqsh, lekin alohida jadval (mavjud Comment/Bird tizimiga tegilmaydi).
#
class CreatePlantSightingComments < ActiveRecord::Migration[7.1]
  def change
    create_table :plant_sighting_comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plant_sighting, null: false, foreign_key: true
      t.string :text, limit: 100, null: false

      t.timestamps
    end
  end
end
