class PlantsController < ApplicationController
  before_action :authenticate_user!, only: [:identify]

  PLANTS_PER_PAGE = 24

  # PlantSightingUploader bilan bir xil chegara (10 MB) — foydalanuvchi
  # kutgan xatti-harakat izchil bo'lsin.
  IDENTIFY_MAX_IMAGE_SIZE = 10.megabytes
  IDENTIFY_ALLOWED_CONTENT_TYPES = %w[image/jpeg image/jpg image/png].freeze

  # Mehmon (ro'yxatdan o'tmagan) foydalanuvchi uchun — o'simliklar ro'yxati
  # o'rniga faqat ko'rsatuv uchun mo'ljallangan "kirish oynasi" (karusel +
  # xarita). Ichkariga (kataloг, profil va h.k.) kirish faqat tizimga
  # kirgandan keyin ochiladi.
  def index
    if current_user.blank?
      # 5 tadan ko'p olamiz (galereya 5 katakda ko'rsatadi, lekin har 5
      # soniyada navbatdagi 5 tasiga "varaqlanadi" — shuning uchun aylanish
      # uchun ko'proq material kerak).
      @recent_sightings = PlantSighting.published.approved
                                        .includes(:plant, :user)
                                        .order(created_at: :desc)
                                        .limit(20)
      @map_sightings = PlantSighting.published.approved
                                     .where.not(latitude: nil, longitude: nil)
      render 'welcome'
      return
    end

    @plants = Plant.all.order(:species_sci)
    @plants = @plants.search(params[:q]) if params[:q].present?
    @plants = @plants.by_family(params[:family]) if params[:family].present?
    @plants = @plants.red_listed if params[:red_book].present?
    @plants = @plants.page(params[:page]).per(PLANTS_PER_PAGE)

    @families = Plant.where.not(family_lat: nil).distinct.order(:family_lat).pluck(:family_lat)

    # Kartochkalarda placeholder o'rniga tasdiqlangan rasm(lar)ni
    # ko'rsatish uchun — BITTA query bilan (N+1 emas!) joriy sahifadagi
    # (24 ta) o'simlikka tegishli barcha tasdiqlangan kuzatuvlarni olib,
    # plant_id bo'yicha Ruby'da guruhlaymiz (@sightings_by_plant[id]).
    # plants/show'даgi bilan bir xil siyosat: faqat .published.approved.
    plant_ids = @plants.map(&:id)
    @sightings_by_plant = PlantSighting.published.approved
                                        .where(plant_id: plant_ids)
                                        .order(created_at: :desc)
                                        .group_by(&:plant_id)
  end

  def show
    @plant = Plant.find(params[:id])

    # Shu o'simlikka bog'langan, faqat tasdiqlangan va nashr qilingan
    # kuzatuvlar (rasmlar) — index'даgi mehmon galereyasi bilan bir xil
    # naqsh (.published.approved). Egasi ham, mehmon ham faqat
    # tasdiqlanganlarini ko'radi — izchil siyosat (kutilayotgan/rad
    # etilganlar bu yerda ko'rsatilmaydi). includes(:user) — N+1'ning
    # oldini olish uchun (har rasm ostida muallif ismi ko'rsatiladi).
    @sightings = @plant.plant_sightings.published.approved
                        .includes(:user)
                        .order(created_at: :desc)
  end

  # AJAX (plants#index'даgi "Rasm orqali o'simlik aniqlash" bo'limi):
  # PlantNet'ga rasm yuboradi, top natijalarni (@predictions) yoki
  # tushunarli xato xabarini (@identify_error_message) qaytaradi.
  # Bazaga hech narsa saqlanmaydi — 1-bosqichda faqat bir martalik
  # taxmin, wizard/ekspert integratsiyasi keyingi bosqichda.
  def identify
    image = params[:image]

    if (validation_error = validate_identify_image(image))
      @identify_error_message = validation_error
    else
      outcome = PlantNetService.new.identify(image.tempfile)
      if outcome.success?
        @predictions = outcome.predictions
      else
        # Hozircha PlantNet'dagi barcha nosozliklar (limit, timeout,
        # noto'g'ri kalit, kutilmagan javob) uchun bitta tushunarli xabar —
        # foydalanuvchi texnik sababni bilishi shart emas (xato turi
        # PlantNetService orqali serverda allaqachon log qilingan).
        @identify_error_message = I18n.t('generic', scope: 'plants.index.identify.errors')
      end
    end

    respond_to(&:js)
  end

  private

  def validate_identify_image(image)
    scope = 'plants.index.identify.errors'
    return I18n.t('invalid_image', scope: scope) unless image.respond_to?(:tempfile)
    return I18n.t('invalid_image', scope: scope) unless IDENTIFY_ALLOWED_CONTENT_TYPES.include?(image.content_type)
    return I18n.t('invalid_image', scope: scope) if image.size > IDENTIFY_MAX_IMAGE_SIZE

    nil
  end
end
