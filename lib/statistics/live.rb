# frozen_string_literal: true
#
# Bosh sahifadagi "jonli statistika" paneli uchun. BARCHA hisoblagichlar
# BITTA Rails.cache blokida, 5 daqiqaga keshlanadi — bosh sahifa HAR
# OCHILGANDA qayta hisoblanmasin (ko'rish: shared/_live_stats.html.haml).
# Kesh o'tib ketganda (yoki birinchi so'rovda) — har biri o'ziga xos
# indeksdan foydalanadigan YETTITA COUNT so'rovi, boshqa hech narsa emas
# (N+1 xavfi yo'q, jadval JOIN qilinmaydi).
module Statistics
  class Live
    CACHE_KEY = 'home/live_stats'
    CACHE_TTL = 5.minutes

    class << self
      def snapshot
        Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { compute }
      end

      private

      def compute
        {
          users_count: User.count,
          big_year_count: Statistics::BigYear.users_count,
          # `is_expert` VA `is_admin` — User#expert? bilan bir xil mantiq
          # (ko'rish: app/models/user.rb). `is_expert` indekslangan
          # (db/migrate/*_add_is_expert_index_to_users.rb); `is_admin`
          # bo'yicha alohida indeks kerak emas — hozircha jami 1-2 kishi,
          # jadvalning o'zi ham kichik.
          experts_count: User.where(is_expert: true).or(User.where(is_admin: true)).count,
          # `published` — indekslangan (index_plant_sightings_on_published).
          photos_count: PlantSighting.published.count,
          # `[plant_id, status]` — indekslangan (index_plant_sightings_on_plant_id_and_status).
          approved_species_count: PlantSighting.approved.where.not(plant_id: nil).distinct.count(:plant_id),
          # `status` — indekslangan (index_plant_sightings_on_status), `published` ham.
          pending_count: PlantSighting.published.pending.count,
          # `research_grade` — indekslangan (db/migrate/*_add_research_grade_to_plant_sightings.rb).
          research_grade_count: PlantSighting.where(research_grade: true).count
        }
      end
    end
  end
end
