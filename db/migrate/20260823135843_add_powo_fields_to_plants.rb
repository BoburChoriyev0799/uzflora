# frozen_string_literal: true
#
# WCVP (Kew/POWO) bilan solishtirish natijasini saqlash uchun ustunlar
# (lib/powo/matcher.rb, `plants:powo_apply` task). `species_sci`ga
# TEGILMAYDI — u CSV importining tabiiy kaliti bo'lib qoladi
# (lib/tasks/import_plants.rake). Ko'rinish (view) hali bu ustunlardan
# foydalanmaydi — bu keyingi bosqich.
class AddPowoFieldsToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :wcvp_matched_name, :string
    add_column :plants, :wcvp_status, :string
    add_column :plants, :accepted_name, :string
    add_column :plants, :accepted_authors, :string
    add_column :plants, :accepted_family, :string
    add_column :plants, :accepted_genus, :string
    add_column :plants, :accepted_rank, :string
    add_column :plants, :powo_id, :string
    add_column :plants, :powo_match_type, :string
    add_column :plants, :powo_matched_at, :datetime

    add_index :plants, :powo_id
    add_index :plants, :accepted_genus
    add_index :plants, :powo_match_type
  end
end
