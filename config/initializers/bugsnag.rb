Bugsnag.configure do |config|
  config.api_key = "86f84a784e7041f9bcb1c32bd1e28d4b"

  # Standart holda Bugsnag gem'ining o'zida `release_stage` VA
  # `notify_release_stages` ikkalasi ham nil (bugsnag-ruby manba kodi,
  # `configuration.rb`: `should_notify_release_stage?` — ikkalasi ham
  # nil bo'lsa har doim `true` qaytaradi). Shuning uchun avval ilova
  # QAYSI muhitda ishlayotgani Bugsnag'ga aytilmagan edi va xato QAYSI
  # muhitlarda yuborilishi ham cheklanmagan edi — natijada development/
  # test'da (hatto RSpec'dagi kutilgan/testga oid xatolarda ham) real
  # Bugsnag dashboard'ga xabar ketardi. Endi faqat production'da yuboriladi.
  config.release_stage = Rails.env
  config.notify_release_stages = %w[production]
end
