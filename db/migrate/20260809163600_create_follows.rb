# frozen_string_literal: true
#
# Foydalanuvchilarni kuzatish (follow) — bir tomonlama (iNaturalist kabi),
# qabul/so'rov kutish yo'q. `follower_id`/`followed_id` ikkalasi ham
# `users`ga ishora qiladi, shuning uchun oddiy `foreign_key: true` o'rniga
# `to_table: :users` aniq ko'rsatiladi (Rails standart holda ustun nomidan
# — "follower"/"followed" — jadval nomini avtomatik topa olmaydi).
#
class CreateFollows < ActiveRecord::Migration[7.1]
  def change
    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followed, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Takroriy follow bazada ham bloklansin (model validatsiyasi yagona
    # himoya bo'lmasin — parallel so'rovlar/race condition uchun).
    add_index :follows, [:follower_id, :followed_id], unique: true
  end
end
