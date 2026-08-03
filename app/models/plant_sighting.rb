# frozen_string_literal: true
#
# Foydalanuvchi yuklagan o'simlik kuzatuvi — rasm, sana, joylashuv va
# (ixtiyoriy) aniqlangan tur. Bird modeliga o'xshash naqsh: Plant — katalog,
# PlantSighting — kuzatuv yozuvi.
#
class PlantSighting < ApplicationRecord
  belongs_to :user
  belongs_to :plant, optional: true
  belongs_to :expert, class_name: 'User', optional: true

  has_many :plant_sighting_comments, dependent: :destroy

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
  # faqat tasdiqlaydi yoki rad etadi.
  def approve!(expert)
    update!(status: :approved, expert: expert, reviewed_at: Time.zone.now, moderation_note: nil)
  end

  # note — ekspert nega rad etganini tushuntiruvchi ixtiyoriy izoh, faqat
  # kuzatuv egasiga ko'rinadi (plant_sightings/show.html.haml'da tekshiriladi).
  def reject!(expert, note = nil)
    update!(status: :rejected, expert: expert, reviewed_at: Time.zone.now, moderation_note: note)
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
    %w[id status published timestamp created_at region]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user plant expert]
  end

  private

  def capture_photo_cache_name
    self.photo_cache_name = photo.cache_name
  end

  def enqueue_photo_processing
    update_column(:photo_status, 'pending') unless photo_status_pending?
    ProcessSightingImageJob.perform_later(id)
  end
end
