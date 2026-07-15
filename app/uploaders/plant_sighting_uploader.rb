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
end
