# frozen_string_literal: true
#
# Jamoaviy aniqlash natijasi — ko'rish: PlantSighting#recompute_identifications!
# `research_grade` — 3+ kelishuv (yakka g'olib) YOKI ekspert taklifi orqali
# tasdiqlanganda true (iNaturalist'dagi "research grade" tushunchasi).
# `identifications_count`/`agreement_count` — 0/3 chizig'ini har safar qayta
# hisoblamasdan (N+1'siz) ko'rsatish uchun oldindan hisoblab qo'yiladigan
# hisoblagichlar.
#
class AddResearchGradeToPlantSightings < ActiveRecord::Migration[7.1]
  def change
    add_column :plant_sightings, :research_grade, :boolean, default: false, null: false
    add_index :plant_sightings, :research_grade

    add_column :plant_sightings, :identifications_count, :integer, default: 0, null: false
    add_column :plant_sightings, :agreement_count, :integer, default: 0, null: false
    add_column :plant_sightings, :research_graded_at, :datetime
  end
end
