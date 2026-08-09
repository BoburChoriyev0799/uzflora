class User < ActiveRecord::Base
  include Models::Subscribable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  #
  # :two_factor_authenticatable :database_authenticatable'ni o'z ichiga
  # oladi (parol tekshiruvi saqlanib qoladi), shuning uchun uni alohida
  # qo'shish shart emas. 2FA FAQAT otp_required_for_login=true bo'lgan
  # userlar uchun amalda ishlaydi (SessionsController#create'da tekshiriladi)
  # — bu maydon hozircha faqat admin o'zi yoqqanda true bo'ladi, shuning
  # uchun oddiy foydalanuvchilar/ekspertlarning kirish oqimi o'zgarmaydi.
  devise :two_factor_authenticatable, :two_factor_backupable,
         :registerable, :recoverable, :rememberable, :trackable,
         :validatable, :omniauthable

  mount_uploader :avatar, AvatarUploader

  has_and_belongs_to_many :roles
  has_many :birds
  has_many :plant_sightings, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :plant_sighting_comments, dependent: :destroy

  # Kuzatish (follow) — bir tomonlama. "active" — MEN kimnidir kuzataman
  # (follower men), "passive" — kimdir MENI kuzatadi (followed men).
  has_many :active_follows, class_name: 'Follow', foreign_key: :follower_id, dependent: :destroy, inverse_of: :follower
  has_many :following, through: :active_follows, source: :followed

  has_many :passive_follows, class_name: 'Follow', foreign_key: :followed_id, dependent: :destroy, inverse_of: :followed
  has_many :followers, through: :passive_follows, source: :follower

  validates_uniqueness_of :email, case_sensitive: false
  validates_presence_of :email, :first_name, :last_name
  validates :password, presence: true, if: :password_required?

  scope :big_year_members, ->() { where(big_year: true) }

  # Ransack 4+ xavfsizlik uchun ochiq (filtrlanadigan/qidiriladigan)
  # ustunlarni ANIQ ro'yxatlashni talab qiladi — admin paneldagi
  # filter'lar shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id email first_name last_name is_expert is_admin big_year created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def full_name
    "#{last_name} #{first_name}"
  end

  def has_role?(role)
    roles.map(&:name).map(&:downcase).include? role.to_s.downcase
  end

  def current?(current_user)
    current_user && (current_user.id == id)
  end

  # Ekspert huquqi shu ustun orqali beriladi (Role/has_role? tizimi emas —
  # u hech qachon seed qilinmagan va biriktirish uchun UI yo'q edi).
  # PlantSighting moderatsiyasi va Bird'ning eski "Confirm" tugmasi
  # (birds_controller#approve) ikkalasi ham shu metoddan foydalanadi.
  # Admin har doim ekspert huquqiga ham ega — buning uchun is_expert
  # ustunini alohida yoqish shart emas.
  def expert?
    is_expert? || admin?
  end

  # Bosh admin — FAQAT admin boshqa foydalanuvchilarni ekspert qilib
  # tayinlashi/bekor qilishi mumkin (users#toggle_expert).
  def admin?
    is_admin?
  end

  # Ekspert huquqidan farqli — istalgan (login qilgan) foydalanuvchi
  # boshqasini kuzatishi mumkin, tasdiqlash/rad etish yo'q. O'zini
  # o'zi kuzatish — bu yerda ham (controllerdan tashqari, model
  # darajasida ham) bloklanadi: `find_or_create_by` validatsiyani
  # ishga tushiradi, `Follow#cannot_follow_self` uni saqlashga
  # qo'ymaydi — natijada `persisted?` false qaytadi.
  def follow(user)
    return false if user.nil? || user.id == id

    active_follows.find_or_create_by(followed_id: user.id).persisted?
  end

  def unfollow(user)
    active_follows.where(followed_id: user&.id).destroy_all
  end

  def following?(user)
    user.present? && following.exists?(user.id)
  end

  def friend?
    has_role?(:friend)
  end

  def restricted?
    has_role?(:restricted)
  end

  def self.from_omniauth(auth)
    provider = auth[:social_accounts_attributes][:provider]
    uid = auth[:social_accounts_attributes][:uid]
    where(provider: provider, uid: uid).first_or_create do |user|
      user.provider = provider
      user.uid = uid
      user.email = auth[:email]
      user.first_name = auth[:first_name]
      user.last_name = auth[:last_name]
    end
  end

  private
  # super call contains (!persisted? || password.present? || password_confirmation.present?)
  def password_required?
    super && provider.blank? && uid.blank?
  end
end
