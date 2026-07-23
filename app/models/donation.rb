# frozen_string_literal: true
#
# "Loyihani qo'llab-quvvatlash" sahifasidagi to'lov niyati yozuvi.
#
# MUHIM: saytda merchant integratsiyasi YO'Q — Payme/Click/karta orqali
# haqiqatan pul o'tganini avtomatik tekshirib bo'lmaydi. Har bir Donation
# yozuvi shunchaki foydalanuvchining "to'lamoqchiman" degan DA'VOSI: forma
# yuborilganda (foydalanuvchi hali to'lov ilovasiga o'tmasidan OLDIN)
# "kutilmoqda" holatida saqlanadi, keyin admin buni bank/ilova tarixi bilan
# qo'lda solishtirib admin panelda (app/admin/donation.rb) "tasdiqlangan"
# yoki "bekor" qiladi. Bu yozuv HECH QAYERDA (profil, ro'yxat, bosh sahifa)
# haqiqiy to'lov sifatida ko'rsatilmaydi — faqat admin panelda ko'rinadi.
#
class Donation < ApplicationRecord
  belongs_to :user, optional: true

  PAYMENT_METHODS = %w[payme click card].freeze

  # Haddan tashqari katta summa kiritilishining (xato yoki spam) oldini
  # olish uchun sof texnik chegara — haqiqiy biznes qoidasi emas.
  MAX_AMOUNT = 100_000_000

  # Admin panelda qo'lda o'zgartiriladigan holat. Qiymatlar bevosita
  # o'zbekcha (admin panel to'liq o'zbek tilida ishlaydi) — status_tag
  # buni to'g'ridan-to'g'ri chiroyli ko'rsatadi, alohida tarjima kerak
  # emas.
  enum status: { kutilmoqda: 'kutilmoqda', tasdiqlangan: 'tasdiqlangan', bekor: 'bekor' }

  # payment_method — foydalanuvchidan (mehmon ham bo'lishi mumkin) kelgan
  # ishonchsiz input, shuning uchun Rails enum EMAS (noto'g'ri qiymat
  # enum bilan ArgumentError otib serverni 500'ga olib boradi) — oddiy
  # inclusion validatsiyasi orqali xato holat tekshiriladi.
  validates :payment_method, inclusion: { in: PAYMENT_METHODS, message: "noto'g'ri" }

  validates :amount, presence: { message: "kiritilishi shart" },
                      numericality: {
                        only_integer: true,
                        greater_than: 0,
                        less_than_or_equal_to: MAX_AMOUNT,
                        message: "noto'g'ri"
                      }
  validates :comment, length: { maximum: 100, message: "100 belgidan oshmasin" }
  validates :donor_name, length: { maximum: 60, message: "60 belgidan oshmasin" }

  # Admin panelda "Kim" ustuni uchun — user bo'lsa to'liq ism, aks holda
  # mehmon kiritgan ism yoki "Anonim". Havola qilib ko'rsatish (user
  # bo'lsa admin_user_path) admin qatlamining o'zida (app/admin/donation.rb)
  # amalga oshiriladi, bu yerda faqat matn.
  def donor_label
    user&.full_name || donor_name.presence || 'Anonim'
  end

  # Ransack 4+ xavfsizlik uchun ochiq ustunlarni talab qiladi — admin
  # paneldagi filter/qidiruv shu ro'yxatga tayanadi.
  def self.ransackable_attributes(_auth_object = nil)
    %w[id amount status payment_method donor_name created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user]
  end
end
