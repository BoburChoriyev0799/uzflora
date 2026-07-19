ActiveAdmin.register User do
  menu priority: 2, label: "Foydalanuvchilar"

  permit_params :first_name, :last_name, :email, :is_expert, :is_admin, :big_year

  # is_admin'ni FAQAT admin o'zgartira oladi (ActiveAdmin'ga kirishning
  # o'zi allaqachon is_admin talab qiladi — bu qo'shimcha ehtiyot chorasi,
  # boshqa joydan zanjir bo'yicha noto'g'ri ishlatilib qolmasligi uchun).
  before_action :only => [:update] do
    if params.dig(:user, :is_admin).present? && !current_user.admin?
      params[:user].delete(:is_admin)
    end
  end

  # O'zini o'zi o'chirib qo'yish (va shu bilan admin panelдан butunlay
  # chiqib qolish) xavfining oldini olamiz.
  before_action :only => [:destroy] do
    if resource == current_user
      redirect_to admin_users_path, alert: "O'zingizni o'chira olmaysiz."
    end
  end

  filter :email
  filter :first_name
  filter :last_name
  filter :is_expert
  filter :is_admin
  filter :created_at

  index do
    selectable_column
    column :id
    column :email
    column :first_name
    column :last_name
    column :is_expert do |user|
      status_tag(user.is_expert?)
    end
    column :is_admin do |user|
      status_tag(user.is_admin?)
    end
    column 'Kuzatuvlar' do |user|
      user.plant_sightings.count
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :avatar do |user|
        image_tag(user.avatar.thumb.url, class: 'img-circle') if user.avatar.present?
      end
      row :email
      row :first_name
      row :last_name
      row :is_expert
      row :is_admin
      row :big_year
      row('Kuzatuvlar soni') { |user| user.plant_sightings.count }
      row('Tasdiqlangan noyob tur soni') { |user| Statistics::BigYear.user_approved_count(user.id) }
      row('Sharhlar soni') { |user| user.plant_sighting_comments.count }
      row :sign_in_count
      row :current_sign_in_at
      row :last_sign_in_at
      row :current_sign_in_ip
      row :created_at
      row :updated_at
    end

    panel "So'nggi kuzatuvlar" do
      table_for resource.plant_sightings.order(created_at: :desc).limit(10) do
        column(:id) { |ps| link_to ps.id, admin_plant_sighting_path(ps) }
        column(:plant)
        column(:status) { |ps| status_tag(ps.status) }
        column(:created_at)
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :first_name
      f.input :last_name
      f.input :email
      f.input :is_expert
      f.input :is_admin, hint: "Faqat admin o'zi boshqa admin tayinlashi mumkin."
      f.input :big_year
    end
    f.actions
  end
end
