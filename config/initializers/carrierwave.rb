module CarrierWave
  module MiniMagick
    def quality(percentage)
      manipulate! do |img|
        img.quality(percentage.to_s)
        img = yield(img) if block_given?
        img
      end
    end
  end
end

# Render'ning bepul rejasida disk efemer (har deploy'da tozalanadi) —
# barcha uploaderlar (avatar, bird/plant rasmi, species/category rasmi)
# S3-mos obyekt xotirasida saqlanadi. Sozlama provayderdan MUSTAQIL:
# hozir Cloudflare R2, lekin credentials.yml.enc'dagi `object_storage`
# qiymatlarini almashtirish bilan (masalan Backblaze B2'ga) kod
# o'zgarishisiz o'tish mumkin — chunki ikkalasi ham S3-mos.
os = Rails.application.credentials.object_storage

CarrierWave.configure do |config|
  config.fog_provider = 'fog/aws'
  config.fog_credentials = {
    provider: 'AWS',
    aws_access_key_id: os[:access_key_id],
    aws_secret_access_key: os[:secret_access_key],
    region: os[:region],
    endpoint: os[:endpoint],
    path_style: true
  }
  config.fog_directory = os[:bucket]
  config.fog_public = true
  # Ommaviy URL manzili — R2'ning S3 API endpoint'i emas (u xususiy),
  # balki bucket uchun alohida yoqilgan ochiq (r2.dev yoki custom domain)
  # manzil. Shu orqali yuklangan rasmlar saytda to'g'ridan-to'g'ri ko'rinadi.
  config.asset_host = os[:public_url]
  config.storage = :fog
end
