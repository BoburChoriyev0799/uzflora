ActiveAdmin.register PlantSightingComment do
  menu priority: 5, label: "Sharhlar"

  actions :index, :show, :destroy

  filter :user
  filter :plant_sighting
  filter :created_at

  index do
    selectable_column
    column :id
    column :user
    column :plant_sighting
    column :text
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :user
      row :plant_sighting
      row :text
      row :created_at
    end
  end
end
