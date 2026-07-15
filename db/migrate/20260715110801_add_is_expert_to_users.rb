# frozen_string_literal: true
#
# Ekspert huquqi endi User'ning o'z maydoni orqali beriladi (oddiy,
# to'g'ridan-to'g'ri boshqariladigan yechim — mavjud Role/has_role? tizimi
# hech qachon seed qilinmagan va uni biriktirish uchun UI umuman yo'q edi).
#
class AddIsExpertToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_expert, :boolean, default: false, null: false
  end
end
