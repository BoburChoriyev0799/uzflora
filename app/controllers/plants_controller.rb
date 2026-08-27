class PlantsController < ApplicationController
  before_action :authenticate_user!, only: [:identify]

  PLANTS_PER_PAGE = 24
  # Endi UCH ustunli grid (avval ikki edi) — 3 ga bo'linadigan son kerak,
  # aks holda oxirgi qator chala qoladi. 9 = 3 qator: 12 (4 qator) ham
  # to'g'ri bo'lardi, lekin oldingi 8/2=4 qatorlik balans (chap tarafdagi
  # taksonomiya jadvali bilan) saqlanishi uchun 9 (3 qator) tanlandi —
  # sahifa juda uzun bo'lib ketmaydi.
  SIGHTINGS_PER_PAGE = 9

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

    # Rasmi bor (tasdiqlangan kuzatuvi bor) o'simliklar birinchi
    # sahifalarda chiqsin — sayt "tirik"ligini darhol ko'rsatadi. Bitta
    # EXISTS subso'rov bilan (JOIN/GROUP BY EMAS — Kaminari `count`
    # bilan chalkashib, sahifalashni buzardi) `plants` jadvalining o'zida
    # hisoblanadi: har qatorga TO'G'RIDAN-TO'G'RI bog'liq (correlated),
    # natijada qo'shimcha qator ko'paymaydi, N+1 ham yo'q. ENG BIRINCHI
    # `.order()` sifatida qo'shiladi — shu bilan u ustuvor (primary) saralash
    # kaliti bo'ladi, pastda qo'shiladigan `.search` ichidagi qo'shimcha
    # `.order()`lar esa (agar chaqirilsa) shundan KEYIN qo'shiladi va
    # `species_sci`ning o'zi UNIQUE bo'lgani uchun amalda hech narsani
    # o'zgartirmaydi — "guruh ichida hozirgi alifbo tartibi saqlansin"
    # talabi shu bilan avtomatik bajariladi.
    #
    # GURUHGA OID: "rasmli" hisobiga shu yozuvning O'ZI ham, uning ORQASIDA
    # haqiqatan YASHIRINGAN (`primary_record = FALSE`) guruh a'zolari ham
    # kiradi — BOSHQA primary'ga ega a'zolar (masalan `db/duplikat_
    # istisnolar.csv` orqali istisno qilingan Malus sieversii) KIRMAYDI,
    # ular allaqachon o'zining kartochkasida, o'z rasmi bilan ko'rinadi —
    # aks holda BIR XIL rasm ikki xil kartochkada chiqib qolardi.
    has_approved_photo_sql = <<~SQL.squish
      EXISTS (
        SELECT 1 FROM plant_sightings ps
        WHERE ps.status = 'approved' AND ps.published = TRUE
          AND (
            ps.plant_id = plants.id
            OR ps.plant_id IN (
              SELECT p2.id FROM plants p2
              WHERE p2.accepted_name = plants.accepted_name
                AND plants.accepted_name IS NOT NULL
                AND p2.primary_record = FALSE
            )
          )
      )
    SQL

    # POWO/WCVP taksonomik birlashtirish natijasida bir nechta eski tur
    # bitta accepted_name'ga tenglashtirilgan bo'lishi mumkin (masalan
    # Merendera robusta va Merendera hissarica — ikkalasi ham Colchicum
    # robustum). Ro'yxatda har guruhdan FAQAT bitta ("primary") kartochka
    # ko'rsatiladi — qolganlari bazada, o'z sahifasida qoladi (ko'rish:
    # `plants:mark_primary` rake task, `Plant#primary_record`). Shu
    # kartochkada guruhning BARCHA a'zolari haqidagi ma'lumot (o'zbekcha
    # nomlari, sinonimlari, rasmlari) birlashtirilib ko'rsatiladi (pastga
    # qarang, `@group_members_by_accepted_name`/`@group_display_info`).
    @plants = Plant.where(primary_record: true)
                    .order(Arel.sql("(#{has_approved_photo_sql}) DESC"))
                    .order(:species_sci)
    @plants = @plants.merge(Plant.group_search(params[:q])) if params[:q].present?
    @plants = @plants.by_family(params[:family]) if params[:family].present?
    # Qizil kitob filtri GURUH darajasida: `group_red_book` (`plants:
    # mark_primary` tomonidan oldindan hisoblab qo'yilgan — shu yozuvning
    # o'zi YOKI accepted_name guruhidagi BIROR a'zosi Qizil kitobda
    # bo'lsa true) — aks holda yashiringan Qizil kitob turi filtrga
    # umuman tushmay qolardi.
    @plants = @plants.group_red_listed if params[:red_book].present?
    @plants = @plants.page(params[:page]).per(PLANTS_PER_PAGE)

    @families = Plant.where.not(family_lat: nil).distinct.order(:family_lat).pluck(:family_lat)

    # Joriy sahifadagi (primary) kartochkalar orqasidagi TO'LIQ guruhni
    # (accepted_name bo'yicha bir xil BARCHA yozuvlar, primary_record
    # qiymatidan qat'i nazar) yuklab olamiz — o'zbekcha nom(lar), sinonim
    # ro'yxati va rasmlarni birlashtirib ko'rsatish uchun. BITTA qo'shimcha
    # so'rov (N+1 emas).
    accepted_names = @plants.map(&:accepted_name).select(&:present?).uniq
    @group_members_by_accepted_name = if accepted_names.any?
                                         Plant.where(accepted_name: accepted_names)
                                              .select(:id, :species_sci, :species_uz, :species_ru, :accepted_name, :primary_record)
                                              .group_by(&:accepted_name)
                                       else
                                         {}
                                       end

    # Har bir primary kartochka uchun "effektiv a'zolar"ni (sci nom,
    # kartochka mantig'i va rasm qidiruvi UCHUNGI YAGONA manba) oldindan
    # hisoblab qo'yamiz — ko'rish: PlantsHelper#plant_card_group_info
    # (xuddi shu logikani ishlatadi, lekin qayta HISOBLAMAYDI, faqat shu
    # yerda tayyorlangan natijani o'qiydi).
    #
    # DIQQAT: BOSHQA primary'ga ega a'zo (istisno) HECH QACHON bu ro'yxatga
    # kirmaydi — accepted_name bu holda kartochkalarni farqlamaydi, shuning
    # uchun "birlashtirish" UMUMAN qo'llanilmaydi (sarlavha ham shu
    # yozuvning O'Z, xom nomi bo'ladi). ESLATMA: nazariy jihatdan bitta
    # guruhda HAM bir nechta primary (istisno), HAM haqiqatan yashiringan
    # (primary_record=false) a'zo bo'lsa, o'sha yashiringan a'zo hech
    # qaysi primary kartochkaga qo'shilmay qoladi — bu HOZIRGI ma'lumotlar
    # bilan (faqat Malus'da 2 ta istisno, 0 ta yashiringan a'zo) yuz
    # bermaydi, lekin kelajakda db/duplikat_istisnolar.csv kengaytirilsa
    # e'tiborga olinishi kerak.
    @group_display_info = {}
    @plants.each do |plant|
      all_members = plant.accepted_name.present? ? (@group_members_by_accepted_name[plant.accepted_name] || [ plant ]) : [ plant ]
      other_primary_exists = all_members.any? { |m| m.id != plant.id && m.primary_record? }

      @group_display_info[plant.id] =
        if other_primary_exists
          { sci_name: plant.species_sci, members: [ plant ] }
        else
          { sci_name: plant.display_sci_name, members: [ plant ] + all_members.reject { |m| m.id == plant.id } }
        end
    end

    # Kartochkalarda placeholder o'rniga tasdiqlangan rasm(lar)ni
    # ko'rsatish uchun — BITTA query bilan (N+1 emas!) joriy sahifadagi
    # o'simliklarga VA ularning (yuqoridagi) effektiv guruh a'zolariga
    # tegishli barcha tasdiqlangan kuzatuvlarni olib, ORIGINAL plant_id
    # bo'yicha guruhlaymiz, so'ng har PRIMARY uchun o'zi + a'zolarining
    # rasmlarini birlashtirib, `@sightings_by_plant[primary.id]`ga
    # yig'amiz — shu bilan view'ning o'zi o'zgarishsiz qoladi (u faqat
    # `@sightings_by_plant[plant.id]`ni o'qiydi).
    all_relevant_ids = @group_display_info.values.flat_map { |info| info[:members].map(&:id) }.uniq
    sightings_by_raw_plant_id = PlantSighting.published.approved
                                              .where(plant_id: all_relevant_ids)
                                              .order(created_at: :desc)
                                              .group_by(&:plant_id)
    @sightings_by_plant = @group_display_info.transform_values { |info|
      info[:members].flat_map { |m| sightings_by_raw_plant_id[m.id] || [] }
                     .sort_by { |s| -s.created_at.to_i }
    }
  end

  def show
    @plant = Plant.find(params[:id])

    # POWO taksonomik birlashtiruvi: shu yozuv bilan bir xil accepted_name'ga
    # ega, HAQIQATAN yashiringan (primary_record=false) BOSHQA yozuvlar —
    # ular "Bazada boshqa nomlar ostida" bo'limida ko'rsatiladi. Bir xil
    # accepted_name'ga ega, lekin O'ZI HAM primary=true bo'lgan yozuv
    # (masalan `db/duplikat_istisnolar.csv` orqali istisno qilingan)
    # BU YERGA KIRMAYDI — u allaqachon o'zining kartochkasida ko'rinadi.
    #
    # Primary BO'LMAGAN yozuv sahifasida esa (@plant.primary_record ==
    # false) aksincha — qaysi primary sahifaga o'tish kerakligi
    # ko'rsatiladi (ko'rish: PlantsHelper#plant_merged_notice,
    # views/plants/show.html.haml).
    if @plant.accepted_name.present?
      if @plant.primary_record?
        @group_siblings = Plant.where(accepted_name: @plant.accepted_name, primary_record: false)
                                .where.not(id: @plant.id)
                                .order(:species_sci)
      else
        @primary_sibling = Plant.where(accepted_name: @plant.accepted_name, primary_record: true).order(:id).first
      end
    end

    # Shu o'simlikka VA (agar u primary bo'lsa) uning ORQASIDA haqiqatan
    # yashiringan (`@group_siblings`) guruh a'zolariga bog'langan, faqat
    # tasdiqlangan va nashr qilingan kuzatuvlar (rasmlar) — index'даgi
    # mehmon galereyasi bilan bir xil siyosat (.published.approved).
    # Egasi ham, mehmon ham faqat tasdiqlanganlarini ko'radi (kutilayotgan/
    # rad etilganlar bu yerda ko'rsatilmaydi). `includes(:user, :plant)` —
    # N+1'ning oldini olish uchun (har rasm ostida muallif ismi, guruh
    # a'zosidan kelgan rasm ostida esa "X sifatida" izohi ko'rsatiladi —
    # ko'rish: views/plants/show.html.haml). `param_name: :sightings_page`
    # — bu sahifada hozircha boshqa sahifalanadigan ro'yxat yo'q, lekin
    # standart `:page` nomini ATAYLAB ishlatmaymiz: profiles#show'da xuddi
    # shu xato (umumiy `:page` bir nechta ro'yxat orasida to'qnashib,
    # sahifalash ishlamay qolgan edi) shu yerda takrorlanmasligi uchun.
    sighting_plant_ids = [ @plant.id ] + Array(@group_siblings).map(&:id)
    @sightings = PlantSighting.published.approved
                               .where(plant_id: sighting_plant_ids)
                               .includes(:user, :plant)
                               .order(created_at: :desc)
                               .page(params[:sightings_page]).per(SIGHTINGS_PER_PAGE)
  end

  # AJAX (plants#index'даgi "Rasm orqali o'simlik aniqlash" bo'limi):
  # PlantNet'ga rasm yuboradi, top natijalarni (@predictions) yoki
  # tushunarli xato xabarini (@identify_error_message) qaytaradi.
  # Bazaga hech narsa saqlanmaydi — 1-bosqichda faqat bir martalik
  # taxmin, wizard/ekspert integratsiyasi keyingi bosqichda.
  #
  # MUHIM: har doim `render json:` — `respond_to`/format.js EMAS.
  # Productionda `.js.erb` formatga tayangan versiya HTTP 406 berardi:
  # brauzer AJAX so'rovi (yoki jquery_ujs'ning `data-remote` mexanizmi)
  # har doim ham "text/javascript" Accept header bilan kelavermas edi —
  # `render json:` esa so'rovning Accept header'iga qaramay doim ishlaydi,
  # shuning uchun format nomuvofiqligi endi mumkin emas.
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

    render json: { html: render_to_string(partial: 'plant_identify_results', formats: [:html]) }
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
