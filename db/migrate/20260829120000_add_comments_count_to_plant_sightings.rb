# frozen_string_literal: true
#
# `plant_sighting_comments` soni endi oldindan hisoblab qo'yiladi
# (Rails `counter_cache`) — 💬 belgisidagi son har safar COUNT so'rovi
# yubormasdan, to'g'ridan-to'g'ri shu ustundan o'qiladi (ro'yxatlarda
# ko'plab kuzatuv bo'lganda N+1'ning oldini oladi).
#
class AddCommentsCountToPlantSightings < ActiveRecord::Migration[7.1]
  def change
    add_column :plant_sightings, :comments_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        # Mavjud (hozircha kam) izohlar uchun hisoblagichni to'g'irlab qo'yamiz.
        execute <<~SQL.squish
          UPDATE plant_sightings ps SET comments_count = (
            SELECT COUNT(*) FROM plant_sighting_comments c WHERE c.plant_sighting_id = ps.id
          )
        SQL
      end
    end
  end
end
