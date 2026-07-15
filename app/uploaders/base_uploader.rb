# encoding: utf-8

class BaseUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  # Storage turi bu yerda EMAS, config/initializers/carrierwave.rb'da
  # global belgilanadi (hozir :fog / Cloudflare R2). Bu yerda qattiq
  # `storage :file` yozilgan edi — u global sozlamani bekor qilib,
  # barcha uploaderlarni (shu jumladan yangi PlantSighting) doim lokal
  # diskka yozishga majburlagan edi.

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