# frozen_string_literal: true
#
# `:medium` versiyasi PlantSightingUploader'ga YANGI qo'shildi (izohlar
# MODALIDA — plant_sightings/_comment_modal_trigger.html.haml — endi
# to'liq (1600px) versiya o'rniga shu yengilroq (1000px) variant
# ko'rsatiladi, R2'dan yuklanadigan trafikni kamaytirish uchun).
#
# CarrierWave versiyani faqat YANGI yuklangan rasmlar uchun avtomatik
# yaratadi — bu task shu qo'shilishdan OLDIN yuklangan (mavjud) rasmlar
# uchun `:medium`ni orqaga to'ldiradi. `recreate_versions!(:medium)` R2'da
# ALLAQACHON saqlangan asosiy (versiyasiz) fayldan ishlaydi — asl faylni
# qayta yuklashni TALAB QILMAYDI.
#
# Faqat `photo_status: ready` bo'lgan yozuvlar qamrab olinadi — `pending`/
# `failed` holatida R2'da ishonchli fayl yo'q (ko'rish:
# PlantSighting#process_pending_photo!).
#
# Avtomatik db:migrate zanjiriga QASDDAN ULANMAGAN — backfill_identifications
# kabi, BIR MARTA qo'lda ishga tushiriladigan ma'lumot migratsiyasi.
#
# Ishga tushirish:
#   rails plant_sightings:backfill_medium_photo
namespace :plant_sightings do
  desc "Mavjud kuzatuv rasmlariga izohlar modali uchun :medium versiyasini orqaga to'ldirish"
  task backfill_medium_photo: :environment do
    scope = PlantSighting.where.not(photo: [nil, '']).where(photo_status: 'ready')
    total = scope.count
    done = 0
    failed = 0

    scope.find_each do |sighting|
      sighting.photo.recreate_versions!(:medium)
      done += 1
    rescue StandardError => e
      failed += 1
      Rails.logger.error("[backfill_medium_photo] sighting=#{sighting.id}: #{e.class} #{e.message}")
    end

    puts "Tekshirildi: #{total} ta kuzatuv. Muvaffaqiyatli: #{done}, xato: #{failed}."
  end
end
