# frozen_string_literal: true
#
# Sayt ichidagi xabarnomalar — faqat FAQAT `current_user.notifications`
# doirasida ishlaydi (recipient bilan scope qilingan), shuning uchun
# boshqa foydalanuvchining xabarini na ko'rish, na o'qilgan deb
# belgilash mumkin emas (params[:id] orqali ham).
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  DROPDOWN_LIMIT = 8

  # To'liq "Xabarlar" sahifasi.
  def index
    @notifications = current_user.notifications
                                  .includes(:actor, plant_sighting: :plant)
                                  .recent
                                  .page(params[:page]).per(20)
  end

  # Navbar qo'ng'iroq bosilganda AJAX orqali so'raladigan oxirgi
  # xabarlar (dropdown ichida). Navbar HAR SAHIFADA render bo'lgani
  # uchun bu ma'lumot navbar partial'ining o'zida emas — faqat
  # so'ralganda (bosilganda) yuklanadi, shu bilan har sahifada ortiqcha
  # JOIN so'rovi bo'lmaydi (faqat keshlangan son bo'ladi).
  def recent
    @notifications = current_user.notifications
                                  .includes(:actor, plant_sighting: :plant)
                                  .recent
                                  .limit(DROPDOWN_LIMIT)

    respond_to do |format|
      format.js
    end
  end

  # Bitta xabarni bosish: o'qilgan deb belgilaydi va tegishli
  # kuzatuvga o'tkazadi.
  def show
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!

    # Notification/PlantSighting bir xil umr bilan bog'liq (PlantSighting
    # has_many :notifications, dependent: :destroy — kuzatuv o'chsa,
    # unga oid xabar ham o'chadi), shuning uchun `plant_sighting` odatda
    # doim mavjud. Baribir qo'shimcha himoya sifatida tekshiriladi.
    if notification.plant_sighting
      redirect_to plant_sighting_path(notification.plant_sighting)
    else
      redirect_to notifications_path
    end
  end

  # "Hammasini o'qilgan deb belgilash" tugmasi — bitta bulk UPDATE.
  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    current_user.clear_unread_notifications_cache!

    redirect_to notifications_path
  end
end
