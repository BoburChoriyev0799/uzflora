# frozen_string_literal: true
#
# PlantSighting#notify_followers_of_approval (after_commit, status ->
# approved) shu job'ni navbatga qo'yadi. Ko'p follower bo'lsa ham
# ekspert/foydalanuvchi kutmasin deb fon jarayonida ishlaydi, va
# `Notification.insert_all` orqali BARCHA follower uchun BITTA SQL
# so'rov bilan yaratadi (N ta alohida `.create!` emas).
class NotifyFollowersJob < ApplicationJob
  queue_as :default

  # Kuzatuv (yoki uning egasi) job ishga tushishidan oldin o'chirilgan
  # bo'lsa — xabar yaratishning ma'nosi yo'q, qayta urinish yordam
  # bermaydi.
  discard_on ActiveRecord::RecordNotFound

  def perform(plant_sighting_id)
    sighting = PlantSighting.find(plant_sighting_id)

    # Job kechikkan bo'lishi mumkin (navbatda kutgan) — shu oraliqda
    # holat yana o'zgargan bo'lsa (masalan qayta ko'rib chiqilib rad
    # etilgan) endi xabar yubormaymiz.
    return unless sighting.approved?

    owner = sighting.user
    return if owner.nil?

    # `where.not(id: owner.id)` — o'zini-o'zi follow qilish Follow
    # modelida allaqachon bloklangan, lekin bu yerda ham (talab qilingan
    # kabi) ikkinchi himoya qatlami sifatida qoldiriladi: egasi hech
    # qachon o'ziga xabar olmasin.
    follower_ids = owner.followers.where.not(id: owner.id).pluck(:id)
    return if follower_ids.empty?

    now = Time.current
    rows = follower_ids.map do |recipient_id|
      {
        recipient_id: recipient_id,
        actor_id: owner.id,
        plant_sighting_id: sighting.id,
        notification_type: 'new_sighting',
        created_at: now,
        updated_at: now
      }
    end

    # Unikal indeks (recipient_id+plant_sighting_id+notification_type) orqali —
    # job ikkinchi marta ishga tushsa ham (masalan Solid Queue qayta urinishi)
    # dublikat yozuv yaratilmaydi, mavjud qatorlar jim o'tkazib yuboriladi.
    # Indeks nomi db/migrate/*_widen_notification_uniqueness.rb'da kengaytirilgan
    # (endi comment/identification turlari ham shu jadvalni qayta ishlatadi).
    Notification.insert_all(rows, unique_by: :index_notifications_on_recipient_sighting_type)

    follower_ids.each { |recipient_id| User.clear_unread_notifications_cache!(recipient_id) }
  end
end
