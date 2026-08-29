module Statistics
  class Counts

    class << self

      # List of all users and the number of their published sightings.
      def users_sightings
        sql = "SELECT u.*, COALESCE(us.sightings_count, 0) sightings_count
               FROM users u
               LEFT JOIN (
                   SELECT
                      ps.user_id,
                      count(ps.id) AS sightings_count
                   FROM plant_sightings ps
                   WHERE ps.published = 'true'
                   GROUP BY ps.user_id
                   ) us on us.user_id = u.id
               ORDER BY u.last_name, u.first_name, u.created_at"

        User.find_by_sql(sql)
      end

      # Total amount of distinct plant species met by some user (published sightings only)
      def user_plants(user_id)
        list = Plant.joins(:plant_sightings)
            .where(plant_sightings: { published: true, user_id: user_id })
            .distinct
        list.sort_by { |p| p.species_sci.to_s }
      end

      # Ekspertlar ro'yxati (bosh sahifadagi statistika panelidan o'tiladi) —
      # har biri aniqlagan (tasdiqlangan, noyob) tur soni bilan. `User#expert?`
      # bilan bir xil mantiq (is_expert YOKI is_admin). BITTA so'rov —
      # N+1 yo'q.
      def experts_with_species_count
        sql = "SELECT u.*, COALESCE(sp.species_count, 0) species_count
               FROM users u
               LEFT JOIN (
                   SELECT ps.user_id, COUNT(DISTINCT ps.plant_id) AS species_count
                   FROM plant_sightings ps
                   WHERE ps.status = 'approved' AND ps.plant_id IS NOT NULL
                   GROUP BY ps.user_id
                   ) sp ON sp.user_id = u.id
               WHERE u.is_expert = true OR u.is_admin = true
               ORDER BY u.last_name, u.first_name, u.created_at"

        User.find_by_sql(sql)
      end
    end

  end
end
