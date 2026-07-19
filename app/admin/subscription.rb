ActiveAdmin.register Subscription do
  menu priority: 6, label: "Katta yil obunalari"

  actions :index, :show

  filter :user
  filter :year
  filter :created_at

  # subscriptions.user_id ustunida DB darajasidagi foreign key yo'q
  # (schema.rb'да tasdiqlandi) — agar foydalanuvchi keyinchalik o'chirilsa
  # (masalan shu admin panelning o'zidan), obuna yozuvi "yetim" bo'lib
  # qolishi mumkin. Statistics::BigYear.user_approved_count ichida
  # User.find(user_id) chaqiriladi — bu holatda RecordNotFound ko'tarib,
  # BUTUN ro'yxat sahifasini buzardi. Shuning uchun sub.user (assotsiatsiya,
  # xato ko'tarmaydi) orqali oldindan tekshiramiz.
  safe_approved_count = lambda do |sub|
    next '—' unless sub.user.present?
    Statistics::BigYear.user_approved_count(sub.user_id, sub.year)
  end

  safe_ranking = lambda do |sub|
    next '—' unless sub.user.present?
    Statistics::BigYear.user_ranking(sub.user_id, sub.year)
  end

  index do
    selectable_column
    column :id
    column :user
    column :year
    column('Tasdiqlangan turlar') { |sub| safe_approved_count.call(sub) }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :user
      row :year
      row('Tasdiqlangan turlar soni') { |sub| safe_approved_count.call(sub) }
      row("Reyting o'rni") { |sub| safe_ranking.call(sub) }
      row :created_at
    end
  end
end
