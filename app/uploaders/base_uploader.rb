# encoding: utf-8

class BaseUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  # Storage turi bu yerda EMAS, config/initializers/carrierwave.rb'da
  # global belgilanadi (hozir :fog / Cloudflare R2). Bu yerda qattiq
  # `storage :file` yozilgan edi — u global sozlamani bekor qilib,
  # barcha uploaderlarni (shu jumladan yangi PlantSighting) doim lokal
  # diskka yozishga majburlagan edi.

  # MUHIM: CarrierWave `cache_storage` ko'rsatilmasa, standart holda
  # `storage`ning O'ZINI ishlatadi (bu yerda — :fog). Demak `photo=`
  # BIRIKTIRILGANDA (hali `save` chaqirilishidan OLDIN!) MiniMagick
  # o'lchamni kichraytirishdan tashqari, R2'GA HAM (har versiya uchun
  # alohida) yuklardi — o'lchov shuni ko'rsatdi: `photo=` biriktirish
  # yolg'iz o'zi ~5.5 soniya oldi (bitta 6 MB rasmda). Kesh — vaqtinchalik,
  # faqat shu instance ichida kerak (Render'da bitta process, WEB_CONCURRENCY=0,
  # shuning uchun boshqa serverga "ko'rinmasligi" muammo emas) — shuning
  # uchun LOKAL diskka yozamiz. Doimiy saqlash (`storage :fog`) o'zgarishsiz
  # qoladi.
  cache_storage :file

  # Render'ning 512 MB'lik bepul planida ImageMagick chegarasiz o'lchamdagi
  # rasmni (masalan telefondan 4000x3000+) xotiraga to'liq yuklab qayta
  # ishlashi OOM (502)ga olib kelgan edi. Har bir uploader/versiya birinchi
  # qadam sifatida shu chegaragacha kichraytiradi (resize_to_limit — faqat
  # kichraytiradi, kichik rasmni kattalashtirmaydi), shundan keyingina
  # kesish/moslashtirish ishlaydi.
  MAX_SOURCE_DIMENSION = 1600

  # Fayl hajmi bo'yicha standart chegara — alohida uploader buni
  # o'zgartirishi mumkin (masalan PlantSightingUploader 10 MB'gacha ruxsat
  # beradi). Cheksiz fayl hajmi ham xotira xavfini oshiradi.
  def size_range
    0..8.megabytes
  end

  # EXIF/metama'lumotni (jumladan GPS koordinatasini) tozalaydi.
  #
  # XAVFSIZLIK: telefon rasmlarida ko'pincha aniq GPS koordinatasi EXIF'да
  # qoladi — bu serverdagi koordinata yaxlitlashni (SightingCoordinates)
  # butunlay bekor qiladi (himoyalangan Qizil kitob turining rasmini
  # yuklab, EXIF'дан aniq joyni o'qib olish mumkin bo'lardi). Shu sabab
  # HAR BIR versiyada, shu jumladan yuklab olinadigan "asl" (versiyasiz)
  # faylда ham metama'lumot o'chiriladi.
  #
  # TARTIB MUHIM: `image_processing` har bir amaldan OLDIN `-auto-orient`
  # qo'llaydi (EXIF'даgi burilish tegini rasm piksellariga "singdiradi"),
  # SHUNDAN KEYIN bu `-strip` barcha metama'lumotni (endi keraksiz
  # bo'lib qolgan orientatsiya tegini ham) o'chiradi — ya'ni tik (portret)
  # rasmlar yon tomonga ag'darilib qolmaydi. `strip`ни `resize_to_limit`
  # DAN KEYIN qo'yish kerak: aks holda katta (masalan 4000x3000) asl
  # rasm avval to'liq holda qayta kodlanib, xotira xavfini oshiradi.
  def strip_metadata
    minimagick! do |builder|
      builder.strip
    end
  end

  def store_dir
    "images/#{model.class.to_s.underscore}/#{mounted_as}/#{salted_reproducible_id}"
  end

  def filename
    "#{secure_token}.#{file.extension}" if original_filename.present?
  end

  protected

  def secure_token(length=16)
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.hex(length/2))
  end

  # ENV['CARRIERWAVE_SALT'] = nil on prod server (DigitalOcean)
  def salted_reproducible_id
    secret = [salt, model.id].join('/')
    Digest::SHA256.hexdigest(secret)
  end

  def salt
    # add some salt :)
    return nil
  end
end