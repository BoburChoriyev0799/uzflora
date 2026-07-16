# frozen_string_literal: true
#
# `db/uzflora_plants_v2.csv` avvalgi CSV'ga 6 ta tarjima ustuni qo'shdi
# (life_form, habitat_place, usage — har biri ru/en variantlari bilan).
# O'zbekcha asl ustunlar (life_form, habitat_place, usage) saqlanadi.
#
class AddTranslationsToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :life_form_ru, :string
    add_column :plants, :life_form_en, :string
    add_column :plants, :habitat_place_ru, :text
    add_column :plants, :habitat_place_en, :text
    add_column :plants, :usage_ru, :text
    add_column :plants, :usage_en, :text
  end
end
