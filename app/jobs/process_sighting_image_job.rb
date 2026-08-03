# frozen_string_literal: true
#
# PlantSightingsController#create endi rasmni faqat LOKAL keshlaydi
# (tez) va darhol qaytadi. Versiyalarni (asl/display/small/thumb) R2'ga
# yuklash (tarmoq orqali, sekin — o'lchovlar 6-12 soniya ko'rsatdi) shu
# job orqali fon jarayonida bajariladi.
class ProcessSightingImageJob < ApplicationJob
  queue_as :default

  # R2 (Cloudflare) vaqtincha ishlamasa yoki tarmoq uzilib qolsa —
  # foydalanuvchi rasmi "yo'qolib" qolmasin, avtomatik qayta uriniladi
  # (5 marta, oralig'i asta ortib boradi: ~3s, ~18s, ~83s, ...). Faqat
  # BARCHA urinishlar tugagandan keyin "failed" deb belgilanadi — oraliq
  # urinishlarda holat "pending"ligicha qoladi (foydalanuvchiga soxta
  # xato ko'rsatilmasin).
  retry_on Excon::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError,
           wait: :polynomially_longer, attempts: 5 do |job, error|
    mark_failed(job.arguments.first, error, "5 urinishdan keyin ham muvaffaqiyatsiz")
  end

  # Kuzatuv o'chirilgan bo'lsa (masalan foydalanuvchi bekor qilgan) —
  # qayta urinishning ma'nosi yo'q.
  discard_on ActiveRecord::RecordNotFound

  # Lokal kesh topilmasa (masalan instance qayta ishga tushib, vaqtinchalik
  # disk tozalangan) — qayta urinish yordam bermaydi, darhol "failed".
  discard_on CarrierWave::InvalidParameter do |job, error|
    mark_failed(job.arguments.first, error, "kesh topilmadi")
  end

  def perform(plant_sighting_id)
    PlantSighting.find(plant_sighting_id).process_pending_photo!
  rescue Excon::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, CarrierWave::InvalidParameter
    raise # yuqoridagi retry_on/discard_on'ga topshiriladi — faqat OXIRIDA "failed" belgilanadi
  rescue StandardError => e
    # Kutilmagan xato (dastur xatosi) — yuqoridagi ro'yxatda yo'q, shuning
    # uchun avtomatik qayta urinilmaydi. Foydalanuvchi holati abadiy
    # "pending"da (galereyada abadiy "ishlanmoqda...") qolib ketmasligi
    # uchun darhol "failed" deb belgilanadi.
    self.class.mark_failed(plant_sighting_id, e, "kutilmagan xato")
    raise # Bugsnag'ga (ActiveJob integratsiyasi orqali) va solid_queue failed_executions'ga yozilishi uchun
  end

  def self.mark_failed(plant_sighting_id, error, context)
    sighting = PlantSighting.find_by(id: plant_sighting_id)
    sighting&.mark_photo_failed!(error.message)
    Rails.logger.error(
      "[ProcessSightingImageJob] #{context} sighting=#{plant_sighting_id}: #{error.class} #{error.message}"
    )
  end
end
