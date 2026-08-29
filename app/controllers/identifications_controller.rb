# frozen_string_literal: true
#
# Jamoaviy aniqlash — istalgan tizimga kirgan foydalanuvchi kuzatuvga tur
# taklif qiladi/o'zgartiradi (create) yoki o'z taklifini qaytarib
# oladi/ekspert boshqa birovnikini o'chiradi (destroy). Moderatsiya
# mantig'i (kelishuv sanash, avtomatik tasdiqlash) butunlay
# PlantSighting'da — ko'rish: PlantSighting#propose_identification!.
#
class IdentificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :filter_restricted_users, only: [:create]

  def create
    sighting = PlantSighting.find(params[:plant_sighting_id])
    plant = Plant.find_by(id: params[:plant_id])

    if plant.nil?
      render json: { success: false, error: I18n.t('plant_not_found', scope: 'identifications') }, status: :unprocessable_entity
      return
    end

    sighting.propose_identification!(current_user, plant)
    render json: { success: true, html: render_identifications_widget(sighting.reload) }
  end

  def destroy
    identification = Identification.find(params[:id])
    sighting = identification.plant_sighting

    if identification.owner?(current_user)
      sighting.withdraw_identification!(identification)
    elsif current_user.expert?
      sighting.destroy_identification!(identification)
    else
      render json: { success: false, error: I18n.t('forbidden', scope: 'identifications') }, status: :forbidden
      return
    end

    render json: { success: true, html: render_identifications_widget(sighting.reload) }
  end

  private

  # `compact` — moderatsiya navbatidagi (pending.html.haml) ixcham
  # ko'rinishni AJAX yangilanishdan keyin ham saqlab qolish uchun (JS
  # so'rov bilan birga vidjetning joriy `.compact` klassini yuboradi).
  def render_identifications_widget(sighting)
    render_to_string(partial: 'plant_sightings/identifications', formats: [:html],
                      locals: { plant_sighting: sighting, compact: params[:compact] == '1' })
  end

  # PlantSightingCommentsController'даgi bilan bir xil himoya —
  # cheklangan (`restricted?`) foydalanuvchilar yangi taklif qo'sha
  # olmaydi (spamга qarshi, ko'rish: User#restricted?).
  def filter_restricted_users
    render json: { success: false }, status: :forbidden if current_user.try(:restricted?)
  end
end
