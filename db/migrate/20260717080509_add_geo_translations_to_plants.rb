# frozen_string_literal: true
#
# `db/uzflora_plants_v3.csv` avvalgi v2'ga 8 ta geografik/muhit tarjima
# ustuni qo'shdi: habitat_env va range_world/range_central_asia/
# range_uzbekistan — har biri ru/en variantlari bilan. O'zbekcha asl
# ustunlar saqlanadi.
#
class AddGeoTranslationsToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :habitat_env_ru, :text
    add_column :plants, :habitat_env_en, :text
    add_column :plants, :range_world_ru, :text
    add_column :plants, :range_world_en, :text
    add_column :plants, :range_central_asia_ru, :text
    add_column :plants, :range_central_asia_en, :text
    add_column :plants, :range_uzbekistan_ru, :text
    add_column :plants, :range_uzbekistan_en, :text
  end
end
