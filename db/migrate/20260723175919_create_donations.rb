# frozen_string_literal: true
#
# Foydalanuvchi "Loyihani qo'llab-quvvatlash" sahifasida to'lov niyatini
# bildirganda yaratiladigan yozuv. DIQQAT: bu HAQIQIY TO'LOV TASDIG'I EMAS —
# saytda merchant integratsiyasi yo'q, shuning uchun to'lov muvaffaqiyatli
# o'tganini avtomatik tekshirib bo'lmaydi (batafsil: app/models/donation.rb).
#
class CreateDonations < ActiveRecord::Migration[7.1]
  def change
    create_table :donations do |t|
      t.integer :amount, null: false
      t.string :comment, limit: 100
      t.references :user, null: true, foreign_key: true
      t.string :donor_name
      t.string :payment_method, null: false
      t.string :status, null: false, default: 'kutilmoqda'

      t.timestamps
    end

    add_index :donations, :status
    add_index :donations, :created_at
  end
end
