ActiveAdmin.register Plant do
  menu priority: 3, label: "O'simliklar"

  permit_params :division_lat, :division_ru, :class_lat, :class_ru, :order_lat, :order_ru,
                :family_lat, :family_ru, :family_takhtajan, :genus_lat, :genus_ru,
                :species_sci, :species_ru, :species_uz, :plantarium_url,
                :life_form, :life_form_ru, :life_form_en,
                :habitat_env, :habitat_env_ru, :habitat_env_en,
                :habitat_place, :habitat_place_ru, :habitat_place_en,
                :usage, :usage_ru, :usage_en,
                :range_world, :range_world_ru, :range_world_en,
                :range_central_asia, :range_central_asia_ru, :range_central_asia_en,
                :range_uzbekistan, :range_uzbekistan_ru, :range_uzbekistan_en,
                :endemism, :protected_areas, :red_book

  filter :species_uz
  filter :species_sci
  filter :species_ru
  filter :genus_lat
  filter :family_lat
  filter :red_book

  index do
    selectable_column
    column :id
    column :species_uz
    column :species_sci
    column :family_lat
    column :red_book do |plant|
      status_tag(plant.red_book?)
    end
    column 'Kuzatuvlar' do |plant|
      plant.plant_sightings.count
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row :species_uz
      row :species_sci
      row :species_ru
      row :red_book
      row :division_lat
      row :division_ru
      row :class_lat
      row :class_ru
      row :order_lat
      row :order_ru
      row :family_lat
      row :family_ru
      row :family_takhtajan
      row :genus_lat
      row :genus_ru
      row :life_form
      row :life_form_ru
      row :life_form_en
      row :habitat_env
      row :habitat_place
      row :usage
      row :range_world
      row :range_central_asia
      row :range_uzbekistan
      row :endemism
      row :protected_areas
      row :plantarium_url do |plant|
        link_to(plant.plantarium_url, plant.plantarium_url, target: '_blank', rel: 'noopener') if plant.plantarium_url.present?
      end
      row('Kuzatuvlar soni') { |plant| plant.plant_sightings.count }
      row :created_at
      row :updated_at
    end

    panel "Bu o'simlik bo'yicha kuzatuvlar" do
      table_for resource.plant_sightings.order(created_at: :desc).limit(20) do
        column(:id) { |ps| link_to ps.id, admin_plant_sighting_path(ps) }
        column(:user)
        column(:status) { |ps| status_tag(ps.status) }
        column(:created_at)
      end
    end
  end

  form do |f|
    f.inputs 'Nom' do
      f.input :species_sci
      f.input :species_ru
      f.input :species_uz
      f.input :red_book
    end
    f.inputs 'Taksonomiya' do
      f.input :division_lat
      f.input :division_ru
      f.input :class_lat
      f.input :class_ru
      f.input :order_lat
      f.input :order_ru
      f.input :family_lat
      f.input :family_ru
      f.input :family_takhtajan
      f.input :genus_lat
      f.input :genus_ru
    end
    f.inputs 'Tavsif' do
      f.input :life_form
      f.input :life_form_ru
      f.input :life_form_en
      f.input :habitat_env
      f.input :habitat_env_ru
      f.input :habitat_env_en
      f.input :habitat_place
      f.input :habitat_place_ru
      f.input :habitat_place_en
      f.input :usage
      f.input :usage_ru
      f.input :usage_en
    end
    f.inputs 'Tarqalish va muhofaza' do
      f.input :range_world
      f.input :range_world_ru
      f.input :range_world_en
      f.input :range_central_asia
      f.input :range_central_asia_ru
      f.input :range_central_asia_en
      f.input :range_uzbekistan
      f.input :range_uzbekistan_ru
      f.input :range_uzbekistan_en
      f.input :endemism
      f.input :protected_areas
    end
    f.inputs 'Boshqa' do
      f.input :plantarium_url
    end
    f.actions
  end
end
