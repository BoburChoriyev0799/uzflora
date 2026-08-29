# frozen_string_literal: true
module NotificationsHelper
  # Rails'ning o'zi (rails-i18n gem, uz/ru/en uchun) beradigan
  # `time_ago_in_words` faqat davomiylikni qaytaradi ("2 soat"), "oldin"/
  # "назад"/"ago" qo'shimchasi bo'lmaydi — uni lokalizatsiya bilan
  # qo'shamiz.
  def notification_time_ago(time)
    I18n.t('time_ago', scope: 'notifications', time: time_ago_in_words(time))
  end

  def notification_text(notification)
    plant_name = notification.plant_sighting&.plant&.display_name(I18n.locale) || I18n.t('unknown_plant', scope: 'profile.photo')
    # DIQQAT: bare `I18n.t` EMAS — `t` (ActionView'ning TranslationHelper'i)
    # ishlatiladi. `_html` bilan tugaydigan kalitlar uchun FAQAT shu helper
    # natijani `html_safe` deb belgilaydi (bare `I18n.t` bunday qilmaydi —
    # tekshirib ko'rilgan: natija oddiy satr bo'lib qoladi, HAML `=` esa
    # uni QAYTA escape qilib, `<strong>`/havola teglari matn sifatida
    # ko'rinib qolardi).
    t(
      "#{notification.notification_type}_html",
      scope: 'notifications',
      actor: content_tag(:strong, notification.actor.full_name),
      plant: content_tag(:em, plant_name)
    )
  end
end
