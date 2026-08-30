# encoding: utf-8

class PlantSightingUploader < BaseUploader
  # MUHIM: CarrierWave'da har bir `version` PARENT'ning shu nuqtagacha ishlov
  # bergan faylidan davom etadi (asl fayldan EMAS) — shuning uchun katta
  # o'lcham kerak bo'lgan qadam eng old (versiyasiz) qismda bo'lishi kerak,
  # aks holda keyingi versiyalar kichraytirilgan faylni kattalashtira olmaydi.
  #
  # Standart (versiyasiz) rasm — faqat MAX_SOURCE_DIMENSION'gacha
  # kichraytiriladi, KESILMAYDI. Kattalashtirib ko'rish/yuklab olish uchun
  # shu ishlatiladi (xotira xavfsizligi uchun cheksiz asl faylni saqlamaymiz,
  # lekin 1600px yetarlicha katta va tafsilotlarni ko'rsatadi).
  process resize_to_limit: [MAX_SOURCE_DIMENSION, MAX_SOURCE_DIMENSION]
  process :quality => 90

  # Izohlar MODALIDA (plant_sightings/_comment_modal_trigger.html.haml)
  # ko'rsatiladigan variant — standart (1600px) versiyaning o'zi emas,
  # undan ancha yengili: modal `object-fit: contain` bilan rasmni TO'LIQ
  # (kesmasdan) ko'rsatishi kerak, shuning uchun `:display` kabi
  # `resize_to_fill` (KESADI) emas, `resize_to_limit` (faqat kichraytiradi,
  # nisbatni saqlaydi) ishlatiladi — xuddi standart versiya kabi, faqat
  # kichikroq chegarada (1000px, sifat ham birozgina pasaytirilgan).
  version :medium do
    process resize_to_limit: [1000, 1000]
    process :quality => 82
  end

  # Sahifada ko'rsatiladigan asosiy (kesilgan) rasm — yuqoridagi
  # kichraytirilgan faylning o'zidan kesiladi, asl faylni qayta ochmaydi.
  version :display do
    process :resize_to_fill => [700, 524]
    process :quality => 80
  end

  version :small do
    process :resize_to_fill => [256, 192]
  end

  version :thumb do
    process :resize_to_fill => [154, 116]
  end

  def store_dir
    "images/plant_sighting/#{mounted_as}/#{salted_reproducible_id}"
  end

  def extension_white_list
    %w(jpg jpeg png)
  end

  # Talab: 10 MB'dan katta rasm yuklanmasin.
  def size_range
    0..10.megabytes
  end

  private

  def salt
    ENV['PLANT_SIGHTING_CARRIERWAVE_SALT']
  end

  # MUHIM: BaseUploader#secure_token natijani MODEL INSTANCE
  # o'zgaruvchisida (xotirada) eslab qoladi — bu FAQAT bitta so'rov/
  # instance davomida barqaror (avval `cache!` va `store!` doim BITTA
  # request ichida ishlagani uchun muammo bo'lmagan). Endi `store!`
  # ProcessSightingImageJob orqali BOSHQA (yangi yuklangan) model
  # instance'ida ishlaydi — xotiradagi tasodifiy qiymat boshqacha
  # chiqib, fayl R2'ga DB'dagi identifikatorga MOS KELMAYDIGAN nom bilan
  # yuklanardi (fayl yuklangandek ko'rinsa-da, aslida "yo'qolgan" bo'lardi
  # — o'lchov shuni ko'rsatdi).
  #
  # `model.id`ga bog'lash YECHIM EMAS: `write_photo_identifier`
  # (before_save) INSERT'dan OLDIN, ya'ni `model.id` hali NIL bo'lganda
  # ishlaydi — shu payt hisoblangan qiymat DB'ga yoziladi, keyin job
  # `model.id` ALLAQACHON mavjud bo'lganda QAYTA hisoblasa, ikkalasi
  # mos kelmay qoladi (xuddi shu muammoning o'zi, faqat boshqa shaklda).
  #
  # `cache_id` esa — CarrierWave `cache!` chaqirilganda (hali `save`dan
  # OLDIN) o'rnatiladi va `photo_cache_name` orqali DB'ga saqlanadi
  # (model.rb), keyin job xuddi shu cache_id'ni `photo_cache=` orqali
  # tiklaydi — shuning uchun ASL so'rovda ham, keyingi job'da ham BIR
  # XIL qiymat beradi.
  def secure_token(length = 16)
    Digest::SHA256.hexdigest([salt, cache_id, mounted_as].join('/'))[0, length]
  end
end
