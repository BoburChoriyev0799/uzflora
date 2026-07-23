# "Loyihani qo'llab-quvvatlash" yozuvlari. DIQQAT: bu HAQIQIY to'lov
# tasdig'i emas — merchant integratsiyasi yo'q, shuning uchun har bir
# yozuv foydalanuvchining "to'lamoqchiman" degan da'vosi (batafsil:
# app/models/donation.rb). Admin bank/ilova tarixi bilan qo'lda
# solishtirib statusni "tasdiqlangan" yoki "bekor" qiladi.
#
# Ushbu resurs FAQAT is_admin: true foydalanuvchilarga ko'rinadi — bu
# butun admin panel uchun umumiy qoida (config/initializers/active_admin.rb
# + AdminAuthorization: user.try(:admin?)), ekspertlar (is_expert) admin
# panelga umuman kira olmaydi. Bu ma'lumot saytning boshqa hech qayerida
# (profil, ro'yxat, bosh sahifa) ko'rsatilmaydi.
ActiveAdmin.register Donation do
  menu priority: 6, label: "Xayriyalar"

  # Faqat statusni o'zgartirish mumkin — summa/izoh/usul foydalanuvchi
  # kiritgan haqiqatlar, admin ularni tahrirlamaydi.
  permit_params :status

  filter :status, as: :select, collection: Donation.statuses.keys
  filter :payment_method, as: :select, collection: Donation::PAYMENT_METHODS
  filter :amount
  filter :created_at

  controller do
    def scoped_collection
      super.includes(:user)
    end
  end

  index do
    selectable_column
    column :id
    column :created_at
    column :amount do |d|
      "#{number_with_delimiter(d.amount, delimiter: ' ')} so'm"
    end
    column :comment
    column("Kim") { |d| d.user.present? ? link_to(d.user.full_name, admin_user_path(d.user)) : d.donor_label }
    column :payment_method
    column :status do |d|
      status_tag(d.status)
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row :created_at
      row :amount do |d|
        "#{number_with_delimiter(d.amount, delimiter: ' ')} so'm"
      end
      row :comment
      row("Kim") { |d| d.user.present? ? link_to(d.user.full_name, admin_user_path(d.user)) : d.donor_label }
      row :payment_method
      row :status do |d|
        status_tag(d.status)
      end
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      f.input :status, as: :select, collection: Donation.statuses.keys, include_blank: false
    end
    f.actions
  end
end
