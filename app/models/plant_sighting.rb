# frozen_string_literal: true
#
# Foydalanuvchi yuklagan o'simlik kuzatuvi — rasm, sana, joylashuv va
# (ixtiyoriy) aniqlangan tur. Plant — katalog, PlantSighting — kuzatuv
# yozuvi.
#
class PlantSighting < ApplicationRecord
  belongs_to :user
  belongs_to :plant, optional: true
  belongs_to :expert, class_name: 'User', optional: true

  # Turni ANIQLAGAN ekspert — `expert_id` (kim tasdiqladi/rad etdi)dan
  # ATAYLAB alohida: agar A ekspert `assign_plant` orqali turni biriktirsa-yu,
  # B ekspert keyinroq tasdiqlasa, "Turini aniqladi" ko'rsatuvchisi A'ni
  # ko'rsatishi kerak, tasdiqlagan B'ni emas.
  belongs_to :identified_by, class_name: 'User', optional: true

  has_many :plant_sighting_comments, dependent: :destroy
  has_many :identifications, dependent: :destroy
  has_many :notifications, dependent: :destroy

  mount_uploader :photo, PlantSightingUploader

  # CarrierWave standart holda `save` dan keyin (after_save) darhol R2'ga
  # yuklaydi — bu 4 ta versiyani (asl/display/small/thumb) TARMOQ orqali,
  # SINXRON (foydalanuvchi kutib turgan so'rov ichida) yuklaydi va
  # o'lchashlar shuni 6-12 soniyaga cho'zilishini ko'rsatdi. `cache!`
  # (o'lchamni kichraytirish — LOKAL, tez) baribir `photo=` biriktirilganda
  # sinxron ishlaydi va o'zgarmaydi — faqat TARMOQQA yuklash (`store!`)
  # ProcessSightingImageJob orqali fon jarayoniga ko'chiriladi.
  skip_callback :save, :after, :store_photo!

  # Fon job'i keyinroq (boshqa request/process'da) shu YOZUvni qayta
  # yuklab, keshlangan (hali R2'ga yuklanmagan) faylni topishi uchun
  # cache identifikatorini saqlab qo'yamiz (`photo_cache` CarrierWave'ning
  # o'zi band qilgan metod nomi bo'lgani uchun bu ALOHIDA ustun).
  before_save :capture_photo_cache_name, if: -> { photo.present? && photo.cache_name.present? }

  # Rasm haqiqatan ham o'zgargandagina (birinchi yuklash yoki kelajakda
  # qayta yuklash) — job navbatga qo'yiladi va holat "pending"ga qaytariladi.
  after_commit :enqueue_photo_processing,
               on: [ :create, :update ],
               if: -> { saved_change_to_photo? && photo.present? }

  # Kuzatuv TASDIQLANGANDA (statusi boshqa holatdan "approved"ga
  # o'tganda) egasining followers'lariga xabarnoma yaratiladi — fon
  # jarayonida (ko'p follower bo'lsa ham ekspert kutmasin). Faqat
  # `saved_change_to_status?` — ya'ni HAQIQATAN shu saqlashda status
  # o'zgargan bo'lsa — ishga tushadi, shuning uchun: (1) eski
  # (allaqachon approved) yozuvlarga qayta xabar YARATILMAYDI (ularning
  # statusi bu saqlashda o'zgarmagan); (2) `approve!` orqali ham,
  # ActiveAdmin'da status to'g'ridan-to'g'ri o'zgartirilganda ham bir xil
  # ishlaydi (ikkalasi ham shu callback'ni chaqiradi).
  after_commit :notify_followers_of_approval,
               on: :update,
               if: -> { saved_change_to_status? && approved? }

  # `plants.group_has_photo` — ro'yxatdagi "rasmli o'simliklar oldinda"
  # tartibi endi shu OLDINDAN HISOBLANGAN ustundan foydalanadi (avval
  # PlantsController#index'da har so'rovda 4000+ qatorning HAMMASI uchun
  # qayta hisoblanadigan korrelyatsiyalangan EXISTS subquery edi —
  # production'da /plants sahifasini yiqitgan asosiy sabab). Status,
  # nashr holati yoki BIRIKTIRILGAN TUR o'zgarganda (yoki kuzatuv
  # o'chirilganda) — shu o'simlik VA uning butun accepted_name guruhi
  # uchun qayta hisoblanadi (`Plant.refresh_group_has_photo!` — FAQAT shu
  # guruh, odatda 1-5 qator, butun `plants` jadvali emas). Tur QAYTA
  # biriktirilganda (`saved_change_to_plant_id?`) ESKI o'simlik/guruh ham
  # qayta hisoblanishi SHART — aks holda o'sha eski guruh "rasmli" bo'lib
  # noto'g'ri qolib ketardi.
  #
  # DIQQAT: ikkita ALOHIDA metod nomi ATAYLAB ishlatiladi (bir xil nom
  # emas) — Rails'ning `after_commit` chaqiruv ro'yxati BIR XIL filtr
  # (metod) nomiga ega ikkita e'lonni chalkashtirib, birinchisining
  # shartini (`if:`) ikkinchisi bilan ALMASHTIRIB qo'yishi tasdiqlangan
  # (tekshirib ko'rilgan: shu sababli avval CREATE'dagi chaqiruv umuman
  # ishlamay, faqat DESTROY'dagi keyingi tranzaksiyagacha "kechikkan"
  # holda ishlagan edi).
  after_commit :refresh_group_has_photo_for_plant!,
               on: [ :create, :update ],
               if: -> { saved_change_to_status? || saved_change_to_published? || saved_change_to_plant_id? }
  after_commit :refresh_group_has_photo_after_destroy!, on: :destroy

  # Moderatsiya holati. Rails enum'ning o'zi .pending/.approved/.rejected
  # scope'larini va pending?/approved?/rejected? metodlarini avtomatik
  # yaratadi — buni qo'lda alohida yozish shart emas. Yangi yozuv har doim
  # ustunning DB standart qiymati ("pending") bilan boshlanadi — hech qayerda
  # avtomatik "approved" qilinmaydi.
  enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected' }

  # Rasmning fon jarayonidagi holati (moderatsiya `status`'idan MUSTAQIL):
  # so'rov darhol qaytgandan keyin versiyalar/R2 yuklash hali tugamagan
  # bo'lishi mumkin. `prefix: true` — avtomatik yaratiladigan
  # `pending?`/`.pending` yuqoridagi moderatsiya enum'i bilan
  # to'qnashmasin (`photo_status_pending?`, `photo_status_ready?` va h.k.).
  enum :photo_status, { pending: 'pending', ready: 'ready', failed: 'failed' }, prefix: true

  validates_presence_of :user_id
  validates :note, length: { maximum: 100 }
  validates :moderation_note, length: { maximum: 100 }

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :known, -> { where.not(plant_id: nil) }
  scope :unknown, -> { where(plant_id: nil) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # O'zbekiston viloyatlari uchun TAXMINIY (bounding box) chegaralar —
  # rasmiy administrativ chegara ma'lumotlari (aniq poligon) bazada yo'q,
  # shuning uchun har bir viloyatga to'rtburchak lat/lng diapazon
  # biriktirilgan. Bu chegara yaqinidagi nuqtalarda xato bo'lishi mumkin
  # (masalan Navoiy o'ziga xos noodatiy shaklga ega, Buxoro/Samarqand/
  # Jizzaxni bir necha tomondan o'rab turadi) — shu sababli Navoiy oxirida,
  # "qolgan" hudud sifatida tekshiriladi, kichikroq/aniqroq viloyatlar esa
  # birinchi navbatda (xususan Toshkent shahri — Toshkent viloyati ICHIDA
  # joylashgan, shuning uchun undan OLDIN tekshirilishi shart).
  REGIONS = [
    { name: "Qoraqalpog'iston Respublikasi", lat: 40.0..45.6, lng: 55.9..63.0 },
    { name: 'Xorazm viloyati', lat: 41.0..42.3, lng: 60.0..61.4 },
    { name: 'Buxoro viloyati', lat: 39.3..40.8, lng: 63.5..65.2 },
    { name: 'Qashqadaryo viloyati', lat: 37.7..39.6, lng: 65.0..67.2 },
    { name: 'Surxondaryo viloyati', lat: 37.0..38.6, lng: 66.0..68.2 },
    { name: 'Samarqand viloyati', lat: 39.2..40.5, lng: 65.5..67.6 },
    { name: 'Jizzax viloyati', lat: 39.5..41.2, lng: 66.6..68.9 },
    { name: 'Sirdaryo viloyati', lat: 39.9..41.0, lng: 68.0..69.2 },
    { name: 'Toshkent shahri', lat: 41.15..41.45, lng: 69.05..69.45 },
    { name: 'Toshkent viloyati', lat: 40.7..41.8, lng: 68.6..70.6 },
    { name: "Farg'ona viloyati", lat: 39.9..40.6, lng: 70.4..71.9 },
    { name: 'Andijon viloyati', lat: 40.3..41.1, lng: 71.9..73.2 },
    { name: 'Namangan viloyati', lat: 40.6..41.4, lng: 70.6..71.9 },
    { name: 'Navoiy viloyati', lat: 39.5..43.0, lng: 61.4..66.0 }
  ].freeze

  # Ransack 4+ orqali admin panelda "Viloyat" filtri sifatida ishlatiladi
  # (q[region_eq]=...). SQL CASE — qadriyatlar shu faylda REGIONS
  # konstantasidan qattiq kodlangan (foydalanuvchi kiritmasi emas),
  # shuning uchun SQL in'ektsiya xavfi yo'q.
  ransacker :region, type: :string do
    region_case_sql = REGIONS.map { |r|
      quoted_name = "'#{r[:name].gsub("'", "''")}'"
      "WHEN latitude BETWEEN #{r[:lat].begin} AND #{r[:lat].end} " \
        "AND longitude BETWEEN #{r[:lng].begin} AND #{r[:lng].end} " \
        "THEN #{quoted_name}"
    }.join(' ')
    Arel.sql("CASE #{region_case_sql} ELSE NULL END")
  end

  def region
    return nil unless latitude.present? && longitude.present?

    REGIONS.find { |r| r[:lat].cover?(latitude) && r[:lng].cover?(longitude) }&.fetch(:name)
  end

  def unknown?
    plant_id.blank?
  end

  def can_publish?
    photo.present? && timestamp.present? && address_valid?
  end

  def address_valid?
    latitude.present? && longitude.present?
  end

  def address_string
    address.presence || "#{latitude}; #{longitude}"
  end

  # Admin Excel eksporti uchun "Rasm olingan joy" ustuni: "joy nomi
  # (koordinata)", joy nomi bo'lmasa faqat koordinata (qavssiz), hech
  # narsa bo'lmasa bo'sh satr.
  def export_location_string
    coords = "#{latitude}; #{longitude}" if address_valid?
    return "#{address} (#{coords})" if address.present? && coords
    return address if address.present?

    coords.to_s
  end

  def owner?(user)
    user_id == user.try(:id)
  end

  # Rad etilgan kuzatuvni faqat egasi va ekspert ko'ra oladi — boshqalarga
  # (profilda ham, to'g'ridan-to'g'ri havola orqali ham) ko'rinmaydi.
  def visible_to?(user)
    return true unless rejected?
    owner?(user) || user.try(:expert?)
  end

  # Ekspert turni o'zgartirmaydi (foydalanuvchi tanlagan plant_id qoladi) —
  # faqat tasdiqlaydi yoki rad etadi. `expert_id` — KIM TASDIQLADI/RAD ETDI
  # degan ma'no, har doim shu chaqirgan ekspertga yoziladi. Turni KIM
  # ANIQLAGANI — butunlay alohida `identified_by_id` ustunida saqlanadi
  # (`assign_plant`da to'ldiriladi), bu yerda unga tegilmaydi.
  def approve!(expert)
    update!(status: :approved, expert: expert, reviewed_at: Time.zone.now, moderation_note: nil)
  end

  # note — ekspert nega rad etganini tushuntiruvchi ixtiyoriy izoh, faqat
  # kuzatuv egasiga ko'rinadi (plant_sightings/show.html.haml'da tekshiriladi).
  def reject!(expert, note = nil)
    update!(status: :rejected, expert: expert, reviewed_at: Time.zone.now, moderation_note: note)
  end

  # Jamoaviy aniqlash uchun kerak bo'ladigan jami "kelishuv" soni (3 ta
  # yakka g'olib tur -> avtomatik tasdiqlanadi).
  MIN_TEAM_AGREEMENT = 3

  # Yagona kirish nuqtasi: foydalanuvchi (egasi, birinchi taklif sifatida,
  # yoki istalgan boshqa tizimga kirgan foydalanuvchi) tur taklif qiladi
  # yoki avvalgi taklifini o'zgartiradi (unique index — bitta foydalanuvchi,
  # bitta kuzatuv uchun BITTA qator, ko'rish: db/migrate/*_create_identifications.rb).
  # `assign_plant` (ekspert tezkor biriktiruvi) ham shu metodni chaqiradi —
  # ikkala yo'l (yangi "Tur taklif qilish" vidjeti va eski tezkor biriktirish)
  # bir xil kelishuv/tasdiqlash mantig'idan o'tsin.
  def propose_identification!(user, plant)
    return if plant.nil?

    identification = identifications.find_or_initialize_by(user: user)
    identification.plant = plant
    identification.withdrawn_at = nil
    identification.save!
    recompute_identifications!
    notify_owner_of_identification!(user)
    identification
  end

  # Egasi o'z taklifini qaytarib oladi (o'chirilmaydi — tarix saqlanadi,
  # `withdrawn_at` orqali "faol emas" deb belgilanadi).
  def withdraw_identification!(identification)
    identification.update!(withdrawn_at: Time.zone.now)
    recompute_identifications!
  end

  # Ekspert/admin boshqa birovning taklifini butunlay o'chiradi
  # (moderatsiya amali — o'zining taklifini "qaytarib olish"dan farqli).
  def destroy_identification!(identification)
    identification.destroy!
    recompute_identifications!
  end

  # Har bir taklif (qo'shilgan/o'zgartirilgan/qaytarib olingan/o'chirilgan)dan
  # KEYIN chaqiriladi — hisoblagichlarni yangilaydi va QOIDALARGA muvofiq
  # kerak bo'lsa avtomatik tasdiqlaydi/pasaytiradi:
  #  - Ekspert taklifi (istalgan sondagi ovoz bilan) HAMMASIDAN USTUN —
  #    bir nechta ekspert kelishmasa, ENG SO'NGGI (updated_at) ekspert
  #    taklifi g'olib.
  #  - Ekspert hech qachon aralashmagan bo'lsa (expert_id bo'sh) — jamoa
  #    ovozi: 3+ TA YAKKA g'olib tur bo'lsa avtomatik tasdiqlanadi.
  #  - Ekspert BIR MARTA bo'lsa ham aralashgan (expert_id to'ldirilgan)
  #    kuzatuvga jamoa ovozi endi TA'SIR QILMAYDI (na tasdiqlaydi, na
  #    pasaytiradi) — ekspert xulosasi doim ustun (eski qo'lda tasdiqlash
  #    navbatidagi "Tasdiqlash" tugmasi ham xuddi shu `expert_id`ni
  #    to'ldiradi, shuning uchun bu himoya o'sha eski oqim bilan ham
  #    ishlaydi, uni o'zgartirmaydi).
  def recompute_identifications!
    actives = identifications.active.includes(:user).to_a
    self.identifications_count = actives.size

    expert_votes = actives.select(&:expert_vote?)
    if expert_votes.any?
      apply_expert_identification!(expert_votes.max_by(&:updated_at), actives)
    else
      apply_team_identification!(actives)
    end
  end

  # ProcessSightingImageJob shu metodni chaqiradi (fon jarayonida).
  # `photo_cache_name` orqali hali R2'ga yuklanmagan keshlangan faylni
  # qayta tiklaydi (`photo_cache=` — CarrierWave), keyin haqiqiy tarmoq
  # ishini (versiyalarni R2'ga yuklash) bajaradi. Kesh topilmasa (masalan
  # instance qayta ishga tushib, vaqtinchalik disk tozalangan bo'lsa)
  # CarrierWave::InvalidParameter chiqadi — buni job qayta urinmasdan
  # xato deb belgilaydi, chunki qayta urinish keshni tiklamaydi.
  def process_pending_photo!
    return if photo_status_ready?
    raise CarrierWave::InvalidParameter, 'photo_cache_name saqlanmagan' if photo_cache_name.blank?

    self.photo_cache = photo_cache_name
    store_photo!
    update_columns(photo_status: 'ready', photo_error: nil, photo_cache_name: nil)
  end

  # Job barcha qayta urinishlardan keyin ham muvaffaqiyatsiz bo'lsa —
  # foydalanuvchi rasmi "yo'qolib" ketmasin, kamida holat va sabab
  # ko'rinib tursin (keyinchalik qo'llab-quvvatlash/qayta urinish uchun).
  def mark_photo_failed!(error_message)
    update_columns(photo_status: 'failed', photo_error: error_message.to_s.truncate(500))
  end

  # Ransack 4+ xavfsizlik uchun ochiq ustunlarni talab qiladi — admin
  # paneldagi filter/qidiruv shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id status published timestamp created_at region research_grade]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user plant expert identified_by identifications]
  end

  private

  def capture_photo_cache_name
    self.photo_cache_name = photo.cache_name
  end

  def enqueue_photo_processing
    update_column(:photo_status, 'pending') unless photo_status_pending?
    ProcessSightingImageJob.perform_later(id)
  end

  def notify_followers_of_approval
    NotifyFollowersJob.perform_later(id)
  end

  # `plant_id`ning o'zi qayta biriktirilgan bo'lsa (`saved_change_to_
  # plant_id?`), ESKI o'simlikni ham qo'shamiz — aks holda uning guruhi
  # "rasmli" bo'lib xato qolib ketardi (endi bu kuzatuv o'sha yerda emas).
  def refresh_group_has_photo_for_plant!
    plant_ids = [ plant_id ]
    plant_ids << plant_id_before_last_save if saved_change_to_plant_id?
    plant_ids.compact.uniq.each { |id| Plant.refresh_group_has_photo!(id) }
  end

  def refresh_group_has_photo_after_destroy!
    Plant.refresh_group_has_photo!(plant_id) if plant_id.present?
  end

  # `identification` — ekspertlardan ENG SO'NGGI (updated_at) o'zgartirgani
  # g'olib (bir nechta ekspert kelishmasa ham, "oxirgi so'z" ustun bo'ladi).
  def apply_expert_identification!(identification, actives)
    self.agreement_count = actives.count { |i| i.plant_id == identification.plant_id }

    return persist_identification_counters! if research_grade? &&
                                                 plant_id == identification.plant_id &&
                                                 expert_id == identification.user_id

    if approved?
      update!(
        plant_id: identification.plant_id,
        expert: identification.user,
        identified_by: identification.user,
        research_grade: true,
        research_graded_at: research_graded_at || Time.zone.now,
        reviewed_at: Time.zone.now
      )
    else
      self.plant_id = identification.plant_id
      approve!(identification.user)
      update!(identified_by: identification.user, research_grade: true, research_graded_at: Time.zone.now)
    end
  end

  # Ekspert HECH QACHON aralashmagan (expert_id bo'sh) kuzatuvlargagina
  # tegadi — ko'rish: `recompute_identifications!`даgi izoh.
  def apply_team_identification!(actives)
    if actives.empty?
      self.agreement_count = 0
      return persist_identification_counters!
    end

    votes = actives.group_by(&:plant_id).transform_values(&:size)
    max_votes = votes.values.max
    winners = votes.select { |_, count| count == max_votes }.keys
    self.agreement_count = max_votes

    return demote_team_identification_if_needed! if expert_id.present?

    if winners.size == 1 && max_votes >= MIN_TEAM_AGREEMENT
      winning_plant_id = winners.first
      return persist_identification_counters! if research_grade? && plant_id == winning_plant_id

      if approved?
        update!(plant_id: winning_plant_id, research_grade: true, research_graded_at: research_graded_at || Time.zone.now)
      else
        self.plant_id = winning_plant_id
        approve!(nil)
        update!(research_grade: true, research_graded_at: Time.zone.now)
      end
    else
      demote_team_identification_if_needed!
    end
  end

  # Kelishuv buzilsa (ovoz tortib olinishi bilan 3 tadan pastga tushdi
  # yoki teng bo'lib qoldi) — FAQAT jamoa orqali (ekspertsiz) erishilgan
  # research_grade bekor qilinadi, kuzatuv qayta ko'rib chiqish (pending)
  # holatiga qaytadi. Ekspert tomonidan tasdiqlangan (`expert_id` bor)
  # kuzatuvlarga bu yerda HECH QACHON tegilmaydi.
  def demote_team_identification_if_needed!
    if research_grade? && expert_id.blank?
      update!(status: :pending, research_grade: false, research_graded_at: nil)
    else
      persist_identification_counters!
    end
  end

  def persist_identification_counters!
    update_columns(identifications_count: identifications_count, agreement_count: agreement_count)
  end

  # Egasi o'ziga o'zi bildirishnoma olmasin (masalan o'z kuzatuvining
  # birinchi taklifini yaratganda). `Notification.upsert_for!` (ko'rish:
  # app/models/notification.rb) — takroriy taklif/izohlarda BITTA qatorni
  # yangilaydi, cheksiz qator yig'ilib ketmaydi (mavjud minimalistik
  # bildirishnoma tizimi bilan bir xil uslub).
  def notify_owner_of_identification!(proposer)
    return if proposer.id == user_id

    Notification.upsert_for!(
      recipient_id: user_id, plant_sighting_id: id,
      notification_type: 'new_identification', actor_id: proposer.id
    )
  end
end
