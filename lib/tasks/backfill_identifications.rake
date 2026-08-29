# frozen_string_literal: true
#
# Jamoaviy aniqlash tizimi qo'shilishidan OLDIN yaratilgan kuzatuvlar
# uchun — tur allaqachon biriktirilgan (`plant_id` bor) BARCHA
# `plant_sightings`ga egasining "1-taklifi" sifatida Identification
# yozuvi yaratadi (qoida: rasm egasi yuklashda tur ko'rsatgan bo'lsa, bu
# birinchi taklif hisoblanadi — ko'rish: PlantSighting#propose_identification!).
# Shu bilan eski kuzatuvlar ham darhol "1/3" ko'rsatadi (0/3 emas).
#
# `propose_identification!` — find_or_initialize_by(user:) ishlatgani
# uchun bu task IDEMPOTENT: necha marta ishga tushirilsa ham (masalan
# ikkinchi deploy'da qayta chaqirilsa) dublikat yozuv YARATILMAYDI, mavjud
# Identification qatorlari qayta tekshiriladi, o'zgarish bo'lmasa hech
# narsa yozilmaydi.
#
# Avtomatik db:migrate/plants:import zanjiriga QASDDAN ULANMAGAN (ko'rish:
# bin/render-build.sh) — mark_primary/dedupe/powo_apply kabi, BIR MARTA
# qo'lda ishga tushiriladigan ma'lumot migratsiyasi.
#
# Ishga tushirish:
#   rails plant_sightings:backfill_identifications
namespace :plant_sightings do
  desc "Mavjud kuzatuvlar uchun jamoaviy aniqlash (identifications) yozuvlarini orqaga to'ldirish"
  task backfill_identifications: :environment do
    scope = PlantSighting.where.not(plant_id: nil).includes(:user, :plant)
    total = scope.count
    created = 0

    scope.find_each do |sighting|
      next if sighting.user.blank? || sighting.plant.blank?

      before = sighting.identifications.count
      sighting.propose_identification!(sighting.user, sighting.plant)
      created += 1 if sighting.identifications.count > before
    end

    puts "Tekshirildi: #{total} ta kuzatuv. Yangi Identification yozuvi yaratildi: #{created} ta."
  end
end
