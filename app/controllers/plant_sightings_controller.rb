class PlantSightingsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :require_expert!, only: [:pending, :approve, :reject, :assign_plant]

  layout 'plant_map', only: [:edit_map, :show]

  # Moderatsiya navbati — faqat ekspertlarga ko'rinadi. BUG TUZATILDI:
  # avval bu yerda `.known` scope'i bor edi, ya'ni faqat tur (plant_id)
  # tanlangan kuzatuvlar ko'rinardi — lekin plant_id ixtiyoriy
  # (`belongs_to :plant, optional: true`, `can_publish?` plant_id'ni
  # talab qilmaydi), shuning uchun turi aniqlanmagan (unknown) holda
  # nashr qilingan kuzatuvlar moderatsiya navbatidan butunlay tushib
  # qolardi. Endi published+pending BARCHASI (known ham, unknown ham)
  # ko'rsatiladi.
  def pending
    @plant_sightings = PlantSighting.published.pending
                                     .includes(:plant, :user)
                                     .order(created_at: :asc)
  end

  # Ekspert tasdiqlaydi. Tur hali biriktirilmagan (plant_id NULL) bo'lsa
  # tasdiqlashga yo'l qo'yilmaydi — avvalgi bug (unknown kuzatuvlar tur
  # biriktirmasdan ham tasdiqlanaverishi) qaytmasligi uchun himoya frontendda
  # (tugma disabled) VA shu yerda backendda ham tekshiriladi.
  def approve
    sighting = PlantSighting.find(params[:id])
    if sighting.unknown?
      render json: { success: false, error: I18n.t('plant_sightings.pending.plant_required_warning') }, status: :unprocessable_entity
      return
    end

    sighting.approve!(current_user)
    render json: { success: true }
  end

  def reject
    sighting = PlantSighting.find(params[:id])
    sighting.reject!(current_user, params[:moderation_note])
    render json: { success: true }
  end

  # Ekspert moderatsiya navbatida turni biriktiradi/tuzatadi — tasdiqlashdan
  # ALOHIDA amal, status/expert/reviewed_at'ga tegmaydi. plant_id doim
  # bazadagi mavjud Plant yozuviga ishora qilishi shart — ekspert faqat
  # autocomplete ro'yxatidan tanlaydi, erkin matn saqlanmaydi.
  def assign_plant
    sighting = PlantSighting.find(params[:id])
    plant = Plant.find_by(id: params[:plant_id])

    if plant.nil?
      render json: { success: false, error: I18n.t('plant_sightings.pending.plant_not_found') }, status: :unprocessable_entity
      return
    end

    sighting.update!(plant: plant)
    render json: {
      success: true,
      plant: {
        id: plant.id,
        selected_text: "#{plant.display_name(I18n.locale)} | #{plant.species_sci}"
      }
    }
  end

  # Rad etilgan kuzatuvni faqat egasi va ekspert ko'ra oladi.
  def show
    @plant_sighting = PlantSighting.find(params[:id])
    redirect_to plants_path unless @plant_sighting.visible_to?(current_user)
  end

  def new
    @plant_sighting = PlantSighting.new
  end

  def create
    permit_params = plant_sighting_params
    if permit_params[:photo].blank?
      redirect_to new_plant_sighting_path, alert: t('.photo_required')
      return
    end

    sighting = PlantSighting.new(permit_params)
    sighting.user = current_user

    if sighting.save
      redirect_to action: :edit_date, id: sighting.id
    else
      redirect_to new_plant_sighting_path, alert: sighting.errors.full_messages.to_sentence
    end
  end

  def edit_date
    @plant_sighting = PlantSighting.find(params[:id])
    @timestamp = @plant_sighting.timestamp ||
                 current_user.plant_sightings.where.not(timestamp: nil).order(created_at: :desc).limit(1).pluck(:timestamp).first ||
                 Time.zone.now
  end

  def edit_map
    @plant_sighting = PlantSighting.find(params[:id])
  end

  def edit_plant
    @plant_sighting = PlantSighting.find(params[:id])
  end

  def update
    @plant_sighting = PlantSighting.find(params[:id])

    if @plant_sighting.update(plant_sighting_params)
      redirect_to action: next_edit_action(@plant_sighting), id: @plant_sighting.id
    else
      redirect_to action: :edit_date, id: @plant_sighting.id, alert: @plant_sighting.errors.full_messages.to_sentence
    end
  end

  def publish
    @plant_sighting = PlantSighting.find(params[:id])
    @plant_sighting.update(plant_sighting_params)
    redirect_to plant_sighting_path(@plant_sighting)
  end

  def destroy
    sighting = PlantSighting.find(params[:id])
    return redirect_to plants_path unless sighting.owner?(current_user)

    sighting_published = sighting.published
    PlantSighting.destroy(sighting.id)
    sightings_count = sighting_published ? current_user.plant_sightings.published.count : current_user.plant_sightings.unpublished.count
    render json: { published: sighting_published, count: sightings_count }
  end

  # AJAX: Plant.search orqali o'simlik nomi qidiruvi (lotin/rus/o'zbek).
  def search_plant
    @plants = params[:text].present? ? Plant.search(params[:text]).limit(20) : Plant.none
    respond_to do |format|
      format.js
    end
  end

  # AJAX (JSON): "O'simlik" bosqichidagi live-autocomplete uchun yengil
  # endpoint — foydalanuvchi yozayotganda pastda ochiluvchi ro'yxatni
  # to'ldiradi. Kamida 2 belgidan keyin ishlaydi, natija 10 taga cheklangan.
  def autocomplete
    text = params[:text].to_s.strip
    plants = text.length >= 2 ? Plant.search(text).limit(10) : Plant.none

    render json: plants.map { |plant|
      {
        id: plant.id,
        sci: plant.species_sci,
        secondary: [plant.species_uz, plant.species_ru].map(&:presence).compact.uniq.join(' / '),
        selected_text: "#{plant.display_name(I18n.locale)} | #{plant.species_sci}"
      }
    }
  end

  private

  def require_expert!
    redirect_to root_path unless current_user.try(:expert?)
  end

  def plant_sighting_params
    params.require(:plant_sighting).permit(
      :photo,
      :photo_cache,
      :timestamp,
      :latitude,
      :longitude,
      :address,
      :note,
      :plant_id
    )
  end

  def next_edit_action(sighting)
    if sighting.timestamp.blank?
      :edit_date
    elsif sighting.latitude.blank? || sighting.longitude.blank?
      :edit_map
    else
      :edit_plant
    end
  end
end
