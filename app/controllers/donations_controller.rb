# frozen_string_literal: true
#
# "Loyihani qo'llab-quvvatlash" formasini yuboradi. DIQQAT: bu yerda
# hech qanday to'lov amalga oshirilmaydi — faqat foydalanuvchi niyatini
# bazaga yozib, keyin uni tanlagan to'lov usuliga (Payme/Click ilovasini
# ochish yoki karta raqamini ko'rsatish) yo'naltiradi. Batafsil izoh
# uchun app/models/donation.rb'ga qarang.
#
class DonationsController < ApplicationController
  def create
    @donation = Donation.new(donation_params)
    @donation.user = current_user if current_user

    if @donation.save
      redirect_to thanks_donations_path(method: @donation.payment_method)
    else
      redirect_to donation_pages_path, alert: @donation.errors.full_messages.to_sentence
    end
  end

  # Donation ID orqali EMAS — query param orqali qaysi to'lov usuli
  # tanlanganini bilamiz. Shu tufayli bu sahifa hech qanday yozuvni ID
  # bo'yicha o'qimaydi (ketma-ket ID orqali boshqa birovning summasi/izohi
  # ko'rinib qolish xavfi umuman yo'q).
  def thanks
    @payment_method = Donation::PAYMENT_METHODS.include?(params[:method]) ? params[:method] : 'card'
    @donation_config = Rails.configuration.donation
  end

  private

  def donation_params
    params.require(:donation).permit(:amount, :comment, :donor_name, :payment_method)
  end
end
