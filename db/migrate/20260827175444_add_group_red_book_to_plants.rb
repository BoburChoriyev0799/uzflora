# frozen_string_literal: true

class AddGroupRedBookToPlants < ActiveRecord::Migration[7.1]
  def change
    add_column :plants, :group_red_book, :boolean, default: false, null: false
    add_index :plants, [ :primary_record, :group_red_book ]

    # Guruh (accepted_name) bo'yicha qidiruv/rasm/oq kitob hisob-kitoblari
    # (PlantsController#index, `plants:mark_primary`) endi tez-tez
    # `WHERE accepted_name = ...` yoki `IN (SELECT accepted_name ...)`
    # ishlatadi — mavjud `[primary_record, accepted_name]` kompozit
    # indeksi FAQAT `primary_record` ham filtrlanganda foydali (chapdan
    # o'ngga qidiriladi), shuning uchun alohida indeks kerak.
    add_index :plants, :accepted_name
  end
end
