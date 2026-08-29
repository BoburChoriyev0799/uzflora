# frozen_string_literal: true
#
# Brute-force (parol taxmin qilish) himoyasi. Rails.cache orqali ishlaydi
# (bitta Puma jarayoni, WEB_CONCURRENCY=0 — hisoblagichlar barcha so'rovlar
# uchun izchil bo'ladi, alohida Redis shart emas).
#
class Rack::Attack
  # Bir IP'дan daqiqada 5 martadan ortiq kirish (login) urinishi bo'lsa —
  # keyingi urinishlar shu daqiqa oxirigacha bloklanadi.
  throttle('logins/ip', limit: 5, period: 60) do |req|
    req.ip if req.path == '/user/sign_in' && req.post?
  end

  # Parolni tiklash so'rovi ham xuddi shunday cheklanadi (email spam va
  # token generatsiyasini suiiste'mol qilishning oldini olish uchun).
  throttle('password_resets/ip', limit: 5, period: 60) do |req|
    req.ip if req.path == '/user/password' && req.post?
  end

  # 2FA kod kiritish (TOTP 6 xonali kod — 1 000 000 variant): parol allaqachon
  # to'g'ri tekshirilgan bo'lsa ham, kodni cheksiz taxmin qilishning oldini
  # olish uchun bu qadam ham cheklanadi.
  throttle('otp_attempts/ip', limit: 10, period: 60) do |req|
    req.ip if req.path == '/user/otp' && req.post?
  end

  # /admin ostidagi barcha yo'llarga umumiy himoya — avtomatlashtirilgan
  # skanerlash/urinishlarni sekinlashtiradi (oddiy foydalanish uchun
  # yetarlicha keng limit).
  throttle('admin/ip', limit: 100, period: 60) do |req|
    req.ip if req.path.start_with?('/admin')
  end

  # O'simlik aniqlash (PlantNet) — login talab qilinadi (controller
  # darajasida), lekin PlantNet'ning bepul kunlik limiti (~500/kun)
  # bitta foydalanuvchi/skript tomonidan tez tugatilib qo'yilmasligi
  # uchun IP bo'yicha ham cheklanadi. BITTA umumiy hisoblagich — bir necha
  # kirish nuqtasi bor (o'simliklar sahifasi `/plants/identify` va rasm
  # qo'shish wizardining "O'simlik" bosqichi `/plant_sightings/:id/
  # identify`, 2b-bosqichda ekspert moderatsiyasi ham shu ikkinchi
  # yo'ldan foydalanadi) — agar har biri ALOHIDA hisoblansa, bitta IP
  # kunlik 500 ta so'rovni bir necha barobar tezroq tugatib qo'yishi
  # mumkin edi.
  throttle('plant_identify/ip', limit: 10, period: 60) do |req|
    next unless req.post?

    is_plants_identify = req.path == '/plants/identify'
    is_sighting_identify = req.path.match?(%r{\A/plant_sightings/\d+/identify\z})
    req.ip if is_plants_identify || is_sighting_identify
  end

  # Jamoaviy aniqlash — tur taklif qilish (IdentificationsController#create).
  # Login talab qilinadi (controller darajasida), lekin skript orqali
  # spam/soxta ovoz yig'ishning oldini olish uchun IP bo'yicha ham
  # cheklanadi.
  throttle('identifications/ip', limit: 20, period: 60) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/plant_sightings/\d+/identifications\z})
  end

  # Kuzatuvlarga izoh yozish (PlantSightingCommentsController#create) —
  # xuddi shu sababdan (spam) IP bo'yicha cheklanadi.
  throttle('comments/ip', limit: 20, period: 60) do |req|
    req.ip if req.post? && req.path == '/plant_sighting_comments'
  end

  # "Loyihani qo'llab-quvvatlash" formasi mehmonlarga ham ochiq (login
  # shart emas), shuning uchun spam/bazani to'ldirish xavfi bor — bir IP
  # soatiga 10 tadan ortiq Donation yozuvi yubora olmaydi.
  throttle('donations/ip', limit: 10, period: 3600) do |req|
    req.ip if req.path == '/donations' && req.post?
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env['rack.attack.match_data'] || {})[:period]
    [
      429,
      { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s },
      [{ error: "Juda ko'p urinish. Iltimos, biroz kutib qayta urinib ko'ring." }.to_json]
    ]
  end
end
