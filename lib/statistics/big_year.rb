module Statistics
  class BigYear

    class << self

      # Total amount of all user who has at least one subscription for BigYear
      def users_count
        sql = 'SELECT COUNT(*)
               FROM users u
               WHERE EXISTS (SELECT 1
                             FROM subscriptions s
                             WHERE s.user_id = u.id);
              '
        result = ActiveRecord::Base.connection.execute sql
        result.first['count'].to_i
      end

      # PlantSighting: har bir ishtirokchining tasdiqlangan (approved),
      # joriy yilда PLATFORMAGA YUKLANGAN (created_at) NOYOB TUR soni —
      # rasm qachon olingani emas, balki qaysi yili joylashtirilgani
      # hisoblanadi (musobaqa "bu yil nima joyladingni" o'lchaydi).
      # Bitta turni necha marta yuklash qo'shimcha ball bermaydi.
      def plant_users_ranking(year = Time.zone.now.year)
        sql = ActiveRecord::Base.send(:sanitize_sql_array, ["
          SELECT u.*, COUNT(DISTINCT ps.plant_id) AS approved_count
          FROM users u
            INNER JOIN subscriptions s ON s.user_id = u.id AND s.year = ?
            LEFT JOIN plant_sightings ps ON ps.user_id = u.id
              AND ps.status = 'approved'
              AND ps.plant_id IS NOT NULL
              AND EXTRACT(year FROM ps.created_at) = ?
          GROUP BY u.id
          ORDER BY COUNT(DISTINCT ps.plant_id) DESC, u.id ASC
        ", year, year])
        User.find_by_sql(sql)
      end

      # Foydalanuvchining tasdiqlangan, shu yilда yuklangan noyob tur soni.
      def user_approved_count(user_id, year = Time.zone.now.year)
        return 0 unless (user = User.find(user_id)) && user.subscribed?(year)
        PlantSighting.approved
            .where(user_id: user_id)
            .where.not(plant_id: nil)
            .where("EXTRACT(year FROM created_at) = ?", year)
            .distinct
            .count(:plant_id)
      end

      # Foydalanuvchining Katta yil reytingidagi o'rni (1 — birinchi o'rin).
      def user_ranking(user_id, year = Time.zone.now.year)
        return 0 unless (user = User.find(user_id)) && user.subscribed?(year)
        index = plant_users_ranking(year).find_index { |u| u.id == user_id }
        index ? index + 1 : 0
      end

    end

  end
end
