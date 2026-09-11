class PlantSightingsController < ApplicationController
  # 2-ish: rasmni yuklab olish HAM login talab qilmaydi (rasmlar ommaviy,
  # `show` bilan bir xil qoida) — pastdagi `download` action'ning o'zida
  # `visible_to?` orqali rad etilgan kuzatuvlar hamon himoyalangan.
  before_action :authenticate_user!, except: [:show, :download]
  before_action :require_expert!, only: [:approve, :reject, :assign_plant]
  # 1-ish: tahrirlash bosqichlari (yangi to'liq tahrirlash HAM, eski
  # bosqichma-bosqich oqim HAM) — FAQAT kuzatuv egasi yoki ekspert/admin.
  # AVVAL bu action'larda umuman ruxsat tekshiruvi YO'Q edi (har qanday
  # tizimga kirgan foydalanuvchi ID'ni bilsa yetardi) — mavjud `owner?`/
  # `expert?` naqshi (destroy/show'да ishlatiladigan) shu yerga ham
  # kengaytirildi, hech narsa TORAYTIRILMADI.
  before_action :require_manage_access!, only: [:edit, :update, :edit_date, :edit_map, :edit_plant, :publish]

  layout 'plant_map', only: [:edit_map, :edit, :show]

  # Moderatsiya navbati — TIZIMGA KIRGAN har qanday foydalanuvchiga ochiq
  # (avval `require_expert!` bilan faqat ekspertlarga ochiq edi — lekin
  # jamoaviy aniqlash (`_identifications.html.haml`dagi "tur taklif
  # qilish" vidjeti, pastda `render 'identifications'`) aynan shu
  # sahifada ishlaydi, oddiy foydalanuvchi tur taklif qila olishi kerak).
  # Tasdiqlash/rad etish/turni majburan biriktirish esa ALOHIDA
  # action'lar (`approve`/`reject`/`assign_plant`) va ular hamon faqat
  # ekspertga ochiq — yuqoridagi `before_action`ga qarang.
  #
  # BUG TUZATILDI: avval bu yerda `.known` scope'i bor edi, ya'ni faqat
  # tur (plant_id) tanlangan kuzatuvlar ko'rinardi — lekin plant_id
  # ixtiyoriy (`belongs_to :plant, optional: true`, `can_publish?`
  # plant_id'ni talab qilmaydi), shuning uchun turi aniqlanmagan
  # (unknown) holda nashr qilingan kuzatuvlar moderatsiya navbatidan
  # butunlay tushib qolardi. Endi published+pending BARCHASI (known ham,
  # unknown ham) ko'rsatiladi.
  def pending
    @plant_sightings = PlantSighting.published.pending
                                     .includes(:plant, :user, :identified_by, identifications: [:user, :plant])
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

    sighting.update!(plant: plant, identified_by: current_user)
    render json: {
      success: true,
      plant: {
        id: plant.id,
        selected_text: "#{plant.display_name(I18n.locale)} | #{plant.display_sci_name}"
      }
    }
  end

  # Rad etilgan kuzatuvni faqat egasi va ekspert ko'ra oladi.
  def show
    @plant_sighting = PlantSighting.find(params[:id])
    redirect_to plants_path unless @plant_sighting.visible_to?(current_user)
  end

  # 2-ish: rasmni ILMIY NOM bilan (Genus_species_YYYY-MM-DD_uzflora-<id>)
  # yuklab olish. Login SHART EMAS (rasmlar ommaviy) — lekin rad etilgan
  # kuzatuv `show`dagi bilan AYNI qoida bo'yicha hamon himoyalangan
  # (`visible_to?` — faqat egasi/ekspert ko'radi). R2 (S3-mos) presigned
  # URL'ga 302 bilan yo'naltiriladi — server rasm trafigini o'zidan
  # o'tkazmaydi (ko'ring SightingDownloadUrl).
  def download
    sighting = PlantSighting.find(params[:id])
    unless sighting.visible_to?(current_user)
      redirect_to plants_path
      return
    end

    url = SightingDownloadUrl.for(sighting)
    if url.nil?
      redirect_to plant_sighting_path(sighting), alert: I18n.t('plant_sightings.show.download_not_ready')
    else
      redirect_to url, allow_other_host: true
    end
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
    @timestamp = @plant_sighting.timestamp ||
                 current_user.plant_sightings.where.not(timestamp: nil).order(created_at: :desc).limit(1).pluck(:timestamp).first ||
                 Time.zone.now
  end

  def edit_map
  end

  def edit_plant
  end

  # 1-ish: kuzatuvni TO'LIQ tahrirlash — rasm, sana, koordinata, viloyat,
  # aniq joy, tur — BITTA sahifada, joriy qiymatlar bilan to'ldirilgan.
  # Bosqichma-bosqich (create) oqimidagi AYNI vidjetlar qayta ishlatiladi
  # (rasm oldindan ko'rish + siqish, xarita, viloyat tanlash, o'simlik
  # autocomplete) — foydalanuvchi bir xil interfeysni ko'radi, faqat
  # bitta sahifada, oldindan to'ldirilgan holda.
  def edit
    @timestamp = @plant_sighting.timestamp || Time.zone.now
  end

  # AJAX ("O'simlik" bosqichi — edit_plant.html.haml, 2b-bosqichda ekspert
  # moderatsiyasi ham shu action'ni qayta ishlatadi, shuning uchun
  # avtorizatsiya ikkalasini ham qamrab oladi: egasi YOKI ekspert).
  #
  # Bu bosqichga kelib ORIGINAL yuklangan fayl (create so'rovidagi
  # tempfile) allaqachon yo'q — faqat R2'da (yoki hali fon jarayonida)
  # saqlangan versiya bor. Shuning uchun original faylni EMAS, R2'dagi
  # mavjud faylni serverda qayta yuklab olamiz (HTTP GET → Tempfile) va
  # uni MAVJUD, O'ZGARTIRILMAGAN PlantNetService#identify'ga beramiz —
  # servisning o'ziga hech narsa qo'shilmaydi.
  def identify
    sighting = PlantSighting.find(params[:id])

    unless sighting.owner?(current_user) || current_user.try(:expert?)
      render json: { error: 'forbidden' }, status: :forbidden
      return
    end

    unless sighting.photo_status_ready?
      @identify_error_message = I18n.t('not_ready', scope: 'plant_sightings.edit.identify.errors')
      render json: { html: render_to_string(partial: 'plant_sightings/identify_results', formats: [:html]) }
      return
    end

    image_io = fetch_sighting_photo_tempfile(sighting)
    if image_io.nil?
      @identify_error_message = I18n.t('fetch_failed', scope: 'plant_sightings.edit.identify.errors')
    else
      outcome = PlantNetService.new.identify(image_io)
      if outcome.success?
        @predictions = outcome.predictions
      else
        @identify_error_message = I18n.t('generic', scope: 'plants.index.identify.errors')
      end
    end

    render json: { html: render_to_string(partial: 'plant_sightings/identify_results', formats: [:html]) }
  ensure
    image_io&.close! if image_io.respond_to?(:close!)
  end

  # Bosqichma-bosqich (create) oqimi VA to'liq tahrirlash (1-ish) SHU
  # BIR action orqali saqlanadi — `full_edit` yashirin maydoni (faqat
  # `edit.html.haml` formasida) ikkalasini ajratadi. Wizard mantig'i
  # (`update_wizard_step!`) BUTUNLAY o'zgarishsiz qoldi.
  def update
    if params[:full_edit].present?
      update_full_edit!
    else
      update_wizard_step!
    end
  end

  def publish
    @plant_sighting.update(plant_sighting_params)
    propose_owner_identification!(@plant_sighting)
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
        sci: plant.display_sci_name,
        secondary: [plant.species_uz, plant.species_ru].map(&:presence).compact.uniq.join(' / '),
        selected_text: "#{plant.display_name(I18n.locale)} | #{plant.display_sci_name}"
      }
    }
  end

  private

  def require_expert!
    redirect_to root_path unless current_user.try(:expert?)
  end

  # Kuzatuvni tahrirlash — FAQAT egasi yoki ekspert/admin (`User#expert?`
  # admin'ni ham qamraydi). Boshqa hamma — 403. `@plant_sighting` shu
  # yerda yuklanadi, action'larning o'zi qayta `find` qilmaydi.
  def require_manage_access!
    @plant_sighting = PlantSighting.find(params[:id])
    head :forbidden unless @plant_sighting.owner?(current_user) || current_user.try(:expert?)
  end

  # `identify` action uchun — R2'dagi (Cloudflare, `PlantSightingUploader`
  # orqali `:fog` bilan saqlangan) mavjud rasmni HTTP GET bilan qayta
  # yuklab, mahalliy Tempfile'ga yozadi. PlantNetService bu haqda hech
  # narsa bilmaydi — u faqat oddiy IO oladi, xuddi to'g'ridan-to'g'ri
  # yuklangan fayl kabi (plants#identify'даgi bilan bir xil interfeys).
  # Xato bo'lsa (tarmoq, R2'da fayl yo'q va h.k.) — nil qaytadi, chaqiruvchi
  # buni "hozir aniqlab bo'lmadi" xabariga aylantiradi, ilova qulamaydi.
  def fetch_sighting_photo_tempfile(sighting)
    response = Net::HTTP.get_response(URI(sighting.photo.display.url))
    return nil unless response.is_a?(Net::HTTPSuccess)

    tempfile = Tempfile.new(['sighting_photo', '.jpg'], binmode: true)
    tempfile.write(response.body)
    tempfile.rewind
    tempfile
  rescue StandardError => e
    Rails.logger.error("[PlantSightingsController#identify] R2 fetch error: #{e.class} - #{e.message}")
    nil
  end

  def plant_sighting_params
    params.require(:plant_sighting).permit(
      :photo,
      :photo_cache,
      :timestamp,
      :latitude,
      :longitude,
      :address,
      :region,
      :note,
      :plant_id
    )
  end

  # Foydalanuvchi formada viloyat tanlaganda `region_source = "user"`
  # (bo'sh qoldirsa — nil). `region_source` foydalanuvchi kiritmasidan
  # KELMAYDI (aks holda "auto"/"admin" deb yuborishi mumkin edi) —
  # faqat `region` maydoni yuborilganda shu yerda o'rnatiladi.
  def apply_user_region_source(sighting)
    return unless params.dig(:plant_sighting).try(:key?, 'region')

    sighting.region_source = sighting.region.present? ? 'user' : nil
  end

  # Egasi wizard orqali (edit_plant bosqichida) tur tanlaganda — bu
  # jamoaviy aniqlashning "1-taklifi" hisoblanadi (ko'rish:
  # PlantSighting#propose_identification!). Tur hali tanlanmagan bo'lsa
  # (unknown kuzatuv) hech narsa qilinmaydi.
  def propose_owner_identification!(sighting)
    return if sighting.plant.blank?

    sighting.propose_identification!(sighting.user, sighting.plant)
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

  # Bosqichma-bosqich (create) oqimi — O'ZGARISHSIZ, faqat nomlandi
  # (`update` endi ikkalasini ham marshrutlaydi, ko'rish yuqorida).
  def update_wizard_step!
    @plant_sighting.assign_attributes(plant_sighting_params)
    apply_user_region_source(@plant_sighting)

    if @plant_sighting.save
      propose_owner_identification!(@plant_sighting)
      redirect_to action: next_edit_action(@plant_sighting), id: @plant_sighting.id
    else
      redirect_to action: :edit_date, id: @plant_sighting.id, alert: @plant_sighting.errors.full_messages.to_sentence
    end
  end

  # 1-ish: to'liq tahrirlashni saqlash. Wizard'dan farqi:
  #   - keyingi bosqichga EMAS, tur sahifasiga qaytadi
  #   - rasm HAQIQATAN almashtirilgan bo'lsa — moderatsiya holati qayta
  #     tiklanadi (PlantSighting#reset_after_photo_replacement!)
  #   - viloyat manbasi maxsus qoida bilan (pastga qarang)
  def update_full_edit!
    sighting = @plant_sighting
    previous_region = sighting.region
    previous_region_source = sighting.region_source
    previous_lat = sighting.latitude
    previous_lng = sighting.longitude

    sighting.assign_attributes(plant_sighting_params)
    apply_region_source_for_full_edit!(sighting, previous_region, previous_region_source, previous_lat, previous_lng)

    if sighting.save
      # FAQAT tur HAQIQATAN o'zgargan bo'lsa — bu wizard'даgi "birinchi
      # taklif" bilan bir xil ma'noda, EGASI YANGI tur tanlagani. Har
      # tahrirlashда (masalan faqat manzil o'zgarsa ham) qayta chaqirilsa,
      # `recompute_identifications!` allaqachon tasdiqlangan/baholangan
      # kuzatuvni SABABSIZ pending'ga qaytarib yuborardi.
      propose_owner_identification!(sighting) if sighting.saved_change_to_plant_id?
      # Rasm almashtirilgan bo'lsa — ENG OXIRIDA, tur ham birga
      # o'zgargan taqdirda ham "pending/reset" holati yakuniy bo'lib qolsin
      # (eski ovozlar eski RASMga tegishli edi, yangi tur tanlangan
      # bo'lsa ham ular hisobga olinmasin).
      sighting.reset_after_photo_replacement! if sighting.saved_change_to_photo?
      redirect_to plant_sighting_path(sighting), notice: I18n.t('plant_sightings.edit.saved')
    else
      redirect_to edit_plant_sighting_path(sighting), alert: sighting.errors.full_messages.to_sentence
    end
  end

  # Viloyat manbasi (1e):
  #   - foydalanuvchi ro'yxatdan BOSHQA qiymat tanlagan (yoki tozalagan)
  #     bo'lsa -> "user" (yoki bo'sh bo'lsa nil)
  #   - viloyat O'ZGARMAGAN, lekin koordinata ko'chirilgan VA avvalgi
  #     manba "auto" edi -> YANGI koordinatadan QAYTA hisoblanadi, manba
  #     "auto" bo'lib qoladi
  #   - aks holda (viloyat o'zgarmagan, koordinata o'zgarmagan, YOKI
  #     manba "user"/"admin" edi) — TEGILMAYDI. Foydalanuvchi/admin
  #     qo'lda tanlagan qiymat koordinata biroz siljigani uchun
  #     "auto"ga almashtirilib yubORilmaydi.
  def apply_region_source_for_full_edit!(sighting, previous_region, previous_region_source, previous_lat, previous_lng)
    coords_changed = sighting.latitude.to_f != previous_lat.to_f || sighting.longitude.to_f != previous_lng.to_f

    if sighting.region != previous_region
      sighting.region_source = sighting.region.present? ? 'user' : nil
    elsif coords_changed && previous_region_source == 'auto'
      recomputed = RegionLookup.region_for(sighting.latitude, sighting.longitude)
      sighting.region = recomputed
      sighting.region_source = recomputed.present? ? 'auto' : nil
    end
  end
end
