ActiveAdmin.register PlantSighting do
  menu priority: 4, label: "Kuzatuvlar"

  permit_params :plant_id, :status, :published, :moderation_note

  filter :status, as: :select, collection: PlantSighting.statuses.keys
  filter :published
  filter :user
  filter :plant_species_sci_or_plant_species_uz_or_plant_species_ru_cont,
         as: :string, label: "O'simlik nomi"
  filter :plant_family_lat, as: :select,
         collection: -> { Plant.distinct.pluck(:family_lat).compact.sort },
         label: 'Oila'
  filter :region, as: :select,
         collection: -> { PlantSighting::REGIONS.map { |r| r[:name] } },
         label: 'Viloyat'
  filter :created_at

  action_item :export_xlsx, only: :index do
    link_to "Excel (.xlsx)", export_xlsx_admin_plant_sightings_path(q: params[:q]&.to_unsafe_h), class: 'button'
  end

  collection_action :export_xlsx, method: :get do
    scope = PlantSighting.published.approved
    scope = scope.ransack(params[:q]).result(distinct: true) if params[:q].present?
    sightings = scope.includes(:plant, :user).order(timestamp: :desc)

    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: 'Kuzatuvlar') do |sheet|
      sheet.add_row ["O'simlik nomi", 'Sana', 'Kim joylagani', 'Rasm olingan joy', 'Rasmga havola', 'Izoh']
      sightings.find_each do |s|
        photo_url = s.photo.url if s.photo.present?
        row = sheet.add_row [
          s.plant&.species_sci.presence || 'Aniqlanmagan',
          s.timestamp&.strftime('%Y-%m-%d'),
          s.user&.full_name,
          s.export_location_string,
          photo_url,
          s.note
        ]
        sheet.add_hyperlink(location: photo_url, ref: row.cells[4]) if photo_url.present?
      end
    end

    send_data package.to_stream.read,
               filename: "plant_sightings_#{Time.zone.now.strftime('%Y%m%d_%H%M')}.xlsx",
               type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
               disposition: 'attachment'
  end

  index do
    selectable_column
    column :id
    column :user
    column :plant
    column :status do |ps|
      status_tag(ps.status)
    end
    column :published
    column :timestamp
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :user
      row :plant
      row :expert
      row :photo do |ps|
        image_tag(ps.photo.display.url) if ps.photo.present?
      end
      row :status
      row :published
      row :timestamp
      row :latitude
      row :longitude
      row :address
      row :note
      row :moderation_note
      row :reviewed_at
      row :created_at
      row :updated_at
    end

    if resource.pending?
      panel 'Moderatsiya' do
        div do
          span link_to "Tasdiqlash", approve_admin_plant_sighting_path(resource), method: :post, class: 'button', data: { confirm: 'Tasdiqlaysizmi?' }
          text_node ' '
          span link_to "Rad etish", reject_admin_plant_sighting_path(resource), method: :post, class: 'button', data: { confirm: 'Rad etasizmi?' }
        end
      end
    end

    panel 'Sharhlar' do
      table_for resource.plant_sighting_comments.ordered do
        column(:user)
        column(:text)
        column(:created_at)
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :plant
      f.input :status, as: :select, collection: PlantSighting.statuses.keys
      f.input :published
      f.input :moderation_note
    end
    f.actions
  end

  member_action :approve, method: :post do
    resource.approve!(current_user)
    redirect_to admin_plant_sighting_path(resource), notice: "Kuzatuv tasdiqlandi."
  end

  member_action :reject, method: :post do
    resource.reject!(current_user)
    redirect_to admin_plant_sighting_path(resource), notice: "Kuzatuv rad etildi."
  end

  action_item :approve, only: :show, if: proc { resource.pending? } do
    link_to "Tasdiqlash", approve_admin_plant_sighting_path(resource), method: :post, data: { confirm: 'Tasdiqlaysizmi?' }
  end

  action_item :reject, only: :show, if: proc { resource.pending? } do
    link_to "Rad etish", reject_admin_plant_sighting_path(resource), method: :post, data: { confirm: 'Rad etasizmi?' }
  end
end
