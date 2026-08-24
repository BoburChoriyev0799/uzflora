# Be sure to restart your server when you modify this file.

# Cookie kaliti ATAYLAB "_birds_session" qoldirilgan (moduldan farqli —
# u yuqorida Uzflora::Application'ga o'zgartirildi): buni "_uzflora_session"ga
# o'zgartirsak, HAMMA hozir tizimga kirgan foydalanuvchining sessiyasi
# darhol uziladi (eski cookie yangi kalitda topilmay qoladi) — Bobur bilan
# kelishilgan holda tegilmadi.
Uzflora::Application.config.session_store :cookie_store, key: '_birds_session'
