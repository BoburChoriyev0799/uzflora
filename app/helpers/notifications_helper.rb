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
    plant = notification.plant_sighting&.plant
    plant_name = plant.present? ? plant_display_name_html(plant, I18n.locale) : I18n.t('unknown_plant', scope: 'profile.photo')
    # DIQQAT: bare `I18n.t` EMAS — `t` (ActionView'ning TranslationHelper'i)
    # ishlatiladi. `_html` bilan tugaydigan kalitlar uchun FAQAT shu helper
    # natijani `html_safe` deb belgilaydi (bare `I18n.t` bunday qilmaydi —
    # tekshirib ko'rilgan: natija oddiy satr bo'lib qoladi, HAML `=` esa
    # uni QAYTA escape qilib, `<strong>`/havola teglari matn sifatida
    # ko'rinib qolardi).
    #
    # `content_tag(:em, plant_name)` ENDI ISHLATILMAYDI — `plant_name`
    # (`plant_display_name_html`) faqat ILMIY nomga tushganda o'zi
    # KURSIV bo'ladi (vernakulyar nom bo'lsa — ODDIY), butun matnni
    # majburan <em> bilan o'rash bu farqni yo'qqa chiqarardi.
    t(
      "#{notification.notification_type}_html",
      scope: 'notifications',
      actor: content_tag(:strong, notification.actor.full_name),
      plant: plant_name
    )
  end
end
