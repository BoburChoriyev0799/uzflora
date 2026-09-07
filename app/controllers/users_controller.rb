class UsersController < Devise::RegistrationsController
  before_action :only => [:change_password, :unregister] do
    authenticate_user!(force: true)
  end
  before_action :configure_permitted_parameters, :only => [:create]
  before_action :authenticate_user!, :require_admin!, only: [:toggle_expert]
  # DIQQAT: oddiy `before_action :authenticate_user!` Devise'ning o'zidan
  # meros olgan controller'larda (`devise_controller?` true bo'lganda)
  # `force: true` bo'lmasa JIM turadi (Devise::Controllers::Helpers#
  # define_helpers: `warden.authenticate!(opts) if !devise_controller? ||
  # opts.delete(:force)`) — ya'ni bu yerda (`UsersController <
  # Devise::RegistrationsController`) himoyasiz qoladi. Yuqoridagi
  # change_password/unregister uchun `force: true` allaqachon shu sababdan
  # ishlatilgan — follow/unfollow uchun ham xuddi shu naqsh kerak.
  before_action(only: [:follow, :unfollow, :map]) { authenticate_user!(force: true) }

  #TODO!!!:: remove to separate controller!!
  def index
    @users = Statistics::Counts.users_sightings
    @big_year_users_count = Statistics::BigYear.users_count
  end

  # Bosh sahifadagi jonli statistika panelidagi "Ekspertlar" kartochkasi
  # shu yerga o'tadi (ko'rish: Statistics::Live, shared/_live_stats).
  def experts
    @experts = Statistics::Counts.experts_with_species_count
  end

  # Faqat admin (require_admin!) — boshqa foydalanuvchining ekspert
  # holatini yoqadi/o'chiradi. Admin'ning o'ziga (is_admin) tegmaydi,
  # faqat is_expert ustunini almashtiradi.
  def toggle_expert
    user = User.find(params[:id])
    user.update!(is_expert: !user.is_expert?)
    redirect_to users_path
  end

  # reCAPTCHA vaqtincha o'chirilgan — kalit (UZFLORA_RECAPTCHA_KEY /
  # BIRDS_RECAPTCHA_KEY) hech qachon sozlanmagan edi, shuning uchun
  # ro'yxatdan o'tish butunlay ishlamas edi. gem/initializer saqlanib
  # qoldi, kerak bo'lsa qayta yoqish oson bo'lsin.
  def create
    super do |user|
      user.subscribe!(Time.zone.now.year) if user.big_year
    end
  end

  # Bir tomonlama kuzatish — qabul/rad qilish yo'q. O'zini o'zi kuzatish
  # bu yerda (server tomonda) ham tekshiriladi — view'da tugma
  # ko'rsatilmasligi yagona himoya bo'lib qolmasin (masalan to'g'ridan-to'g'ri
  # so'rov yuborilsa). `User#follow` model darajasida ham xuddi shu
  # tekshiruvni takrorlaydi (`Follow#cannot_follow_self`), shu bilan birga
  # unikal indeks parallel so'rovlardan (qo'sh bosish) himoya qiladi.
  def follow
    target = User.find(params[:id])
    if target.id == current_user.id
      render json: { success: false, error: I18n.t('profile.follow.cannot_follow_self') }, status: :unprocessable_entity
      return
    end

    if current_user.follow(target)
      render json: { success: true, following: true, followers_count: target.followers.count }
    else
      render json: { success: false, error: I18n.t('profile.follow.error') }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { success: true, following: true, followers_count: target.followers.count }
  end

  def unfollow
    target = User.find(params[:id])
    current_user.unfollow(target)
    render json: { success: true, following: false, followers_count: target.followers.count }
  end

  # Profil xaritasi — FAQAT shu foydalanuvchining koordinatali kuzatuvlari.
  # HTML: bo'sh sahifa + JS (pages/profile_map.js) format:json orqali
  # markerlarni yuklaydi. JSON: faqat kerakli maydonlar (butun model emas).
  #
  # Ko'rinish:
  #   - jamoat            -> faqat tasdiqlangan + nashr qilingan;
  #   - profil egasi/ekspert -> kutilayotganlarini ham (alohida rangda).
  # Rad etilganlar hech kimga (xaritada) ko'rinmaydi.
  #
  # XAVFSIZLIK: koordinata SightingCoordinates orqali o'tadi — Qizil
  # kitob turlari uchun egasi/ekspertdan boshqaga 0.1 gradusga
  # yaxlitlangan holda (aniq qiymat JSON'ga umuman tushmaydi).
  def map
    @user = User.find(params[:id])
    @can_see_pending = @user.current?(current_user) || current_user.try(:expert?)

    respond_to do |format|
      format.html
      format.json { render json: { sightings: map_marker_data(@user) } }
    end
  end

  def change_password
    @user = User.find(current_user.id)
    if @user.update(user_params)
      # Sign in the user bypassing validation in case his password changed
      sign_in @user, :bypass => true
      redirect_to after_update_path_for(@user)
    else
      render 'profiles/show'
    end
  end

  private

  # Xarita markerlari uchun JSON — faqat kerakli maydonlar.
  def map_marker_data(user)
    # Jamoat faqat tasdiqlangan+nashr qilinganlarni; egasi/ekspert
    # kutilayotgan (moderatsiya navbatidagi, nashr qilingan) larni ham.
    # Qoralamalar (unpublished) xaritaga umuman chiqmaydi.
    statuses = @can_see_pending ? %w[approved pending] : %w[approved]
    scope = PlantSighting.includes(:plant).by_user(user.id).published
                         .where(status: statuses)
                         .where.not(latitude: nil).where.not(longitude: nil)

    scope.order(created_at: :desc).filter_map do |sighting|
      coords = SightingCoordinates.for(sighting, current_user)
      next unless coords

      plant = sighting.plant
      {
        id: sighting.id,
        lat: coords[:lat],
        lon: coords[:lon],
        obscured: coords[:obscured],
        pending: sighting.pending?,
        name: plant && helpers.capitalize_first(plant.display_name(I18n.locale)),
        sci_name: plant&.display_sci_name,
        thumb: marker_thumb_url(sighting),
        date: sighting.timestamp && helpers.date_format(sighting.timestamp),
        url: plant_sighting_path(sighting)
      }
    end
  end

  def marker_thumb_url(sighting)
    return nil unless sighting[:photo].present? && sighting.photo_status_ready?

    sighting.photo.thumb.url
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :big_year])
  end

  def require_admin!
    redirect_to root_path unless current_user.try(:admin?)
  end

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
