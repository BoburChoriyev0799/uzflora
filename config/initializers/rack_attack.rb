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

  self.throttled_responder = lambda do |request|
    retry_after = (request.env['rack.attack.match_data'] || {})[:period]
    [
      429,
      { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s },
      [{ error: "Juda ko'p urinish. Iltimos, biroz kutib qayta urinib ko'ring." }.to_json]
    ]
  end
end
