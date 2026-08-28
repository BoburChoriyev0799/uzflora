# frozen_string_literal: true

class AddGroupHasPhotoToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :group_has_photo, :boolean, default: false, null: false
    add_index :plants, [ :primary_record, :group_has_photo ]
  end
end
