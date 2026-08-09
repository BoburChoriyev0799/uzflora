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
    I18n.t(
      'new_sighting_html',
      scope: 'notifications',
      actor: content_tag(:strong, notification.actor.full_name),
      plant: content_tag(:em, plant_name)
    )
  end
end
