# frozen_string_literal: true

class AddPrimaryRecordToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :primary_record, :boolean, default: true, null: false
    add_index :plants, [ :primary_record, :accepted_name ]
  end
end
