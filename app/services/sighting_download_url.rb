# frozen_string_literal: true
#
# 2-ish (YECHIM A): kuzatuv rasmini ILMIY NOM bilan yuklab olish uchun R2
# presigned URL — `response-content-disposition` R2 (S3-mos) so'rov
# parametri orqali, server trafigi sarflanmaydi.
#
# NEGA ISHLAYDI: bucket ommaviy (`fog_public = true`), shuning uchun
# CarrierWave'ning oddiy `#url` HAR DOIM imzosiz `public_url`ni qaytaradi
# (options'ni E'TIBORGA OLMAYDI — ko'rish: carrierwave/storage/fog.rb
# `File#url`). Lekin `#authenticated_url` (xuddi shu fayl klassida,
# `fog_public`dan MUSTAQIL, umumiy metod) to'g'ridan-to'g'ri chaqirilsa —
# vaqtinchalik IMZOLANGAN R2 (S3 API) havolasini beradi, va S3-mos API
# `response-content-disposition` so'rov parametrini QO'LLAB-QUVVATLAYDI
# (ommaviy bucket bo'lsa ham) — ODDIY (imzosiz) ommaviy URL esa bunday
# parametrni UMUMAN qabul qilmaydi. Haqiqiy R2'da qo'lda TEKSHIRILGAN
# (curl bilan `Content-Disposition` javob sarlavhasi tasdiqlangan).
#
# CarrierWave'ning MAVJUD Fog ulanishi qayta ishlatiladi
# (`connection_cache`) — bu yerda yangi kalit/ulanish YARATILMAYDI.
module SightingDownloadUrl
  EXPIRES_IN = 60 # soniya — foydalanuvchi havolani DARHOL bosishi kutiladi

  module_function

  # Yuklab olish uchun havola yoki nil (rasm hali saqlanmagan bo'lsa).
  def for(sighting)
    return nil unless sighting.photo.present? && sighting.photo_status_ready?

    filename = SightingDownloadFilename.for(sighting)
    sighting.photo.file.authenticated_url(
      expire_at: Time.now + EXPIRES_IN,
      query: { 'response-content-disposition' => %(attachment; filename="#{filename}") }
    )
  end
end
