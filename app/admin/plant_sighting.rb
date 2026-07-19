ActiveAdmin.register PlantSighting do
  menu priority: 4, label: "Kuzatuvlar"

  permit_params :plant_id, :status, :published, :moderation_note

  filter :status, as: :select, collection: PlantSighting.statuses.keys
  filter :published
  filter :user
  filter :plant
  filter :created_at

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
