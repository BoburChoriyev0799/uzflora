# frozen_string_literal: true
#
# Bosh admin darajasi — faqat admin boshqa foydalanuvchini ekspert qilib
# tayinlashi/bekor qilishi mumkin (is_expert'dan farqli, alohida ustun:
# admin ekspert huquqini BERADI, o'zi ham avtomatik ekspert bo'ladi
# (User#expert?), lekin bu ikkinchi holat is_expert ustunini o'zgartirmaydi).
#
class AddIsAdminToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_admin, :boolean, default: false, null: false
  end
end
