# frozen_string_literal: true
#
# Koordinatasi bor, lekin `region` (viloyat) bo'sh bo'lgan kuzatuvlarga
# viloyatni KOORDINATADAN avtomatik qo'yadi (`RegionLookup`, Natural Earth
# poligonlari, sof Ruby ray-casting — yangi gem yo'q).
#
# QOIDALAR (topshiriq 2c):
#   - nuqta AYNAN BITTA viloyatga tushsa -> shu viloyat, region_source="auto"
#   - hech qaysiga (yoki chegarada bir nechtasiga) tushsa -> nil qoldiriladi,
#     logga yoziladi, TAXMIN QILINMAYDI
#   - `region` allaqachon to'ldirilgan (foydalanuvchi yoki admin) yozuvlarga
#     TEGILMAYDI — faqat BO'SH `region` qayta ishlanadi
#
# KOORDINATA HIMOYASI: bu SERVERDA aniq koordinata bilan ishlaydi (sizib
# chiqish emas). `SightingCoordinates` himoyasi (brauzerga yaxlitlangan
# qiymat) o'zgarmaydi. Viloyat ~100 km — yaxlitlash (11 km) dan ham
# qo'polroq, ya'ni yangi ma'lumot ochilmaydi.
#
#   rails plant_sightings:backfill_region             # dry-run
#   rails plant_sightings:backfill_region APPLY=true  # yozadi
#
# Qayta ishga tushirilsa xavfsiz (idempotent) — endi `region` bor
# yozuvlar o'tkazib yuboriladi.

namespace :plant_sightings do
  desc 'Koordinatadan viloyatni (region) avtomatik to`ldirish (sukut: dry-run; APPLY=true — yozish)'
  task backfill_region: :environment do
    apply = ActiveModel::Type::Boolean.new.cast(ENV['APPLY'])
    puts(apply ? 'APPLY=true — o`zgarishlar bazaga YOZILADI.' : 'DRY RUN — hech narsa o`zgartirilmaydi (yozish uchun APPLY=true).')
    puts '=' * 60

    scope = PlantSighting.where(region: [ nil, '' ])
                         .where.not(latitude: nil).where.not(longitude: nil)
    total = scope.count
    puts "Koordinatasi bor, region bo`sh kuzatuvlar: #{total}"

    resolved = Hash.new(0)   # region kaliti => son
    undetermined = []        # [id, lat, lon]
    to_write = []            # [id, region_key]

    scope.find_each do |s|
      key = RegionLookup.region_for(s.latitude, s.longitude)
      if key
        resolved[key] += 1
        to_write << [ s.id, key ]
      else
        undetermined << [ s.id, s.latitude.to_f.round(3), s.longitude.to_f.round(3) ]
      end
    end

    if apply && to_write.any?
      now = Time.zone.now
      PlantSighting.transaction do
        # Viloyat kaliti bo'yicha guruhlab, bitta `update_all` (validatsiya/
        # callback'siz — kalit RegionLookup dan, ishonchli).
        to_write.group_by { |_, key| key }.each do |key, pairs|
          PlantSighting.where(id: pairs.map(&:first))
                       .update_all(region: key, region_source: 'auto', updated_at: now)
        end
      end
    end

    puts "\n#{'=' * 60}"
    puts 'Viloyat bo`yicha (aniqlangan):'
    resolved.sort_by { |_, n| -n }.each { |key, n| puts "  #{key.ljust(20)} #{n}" }
    puts "\nAniqlandi (viloyat qo`yiladi):  #{to_write.size}"
    puts "Aniqlanmadi (nil qoladi):       #{undetermined.size}"

    if undetermined.any?
      puts "\nAniqlanmagan kuzatuvlar (birinchi #{[ 15, undetermined.size ].min}, id / lat / lon):"
      undetermined.first(15).each { |id, lat, lon| puts "  ##{id}  #{lat}, #{lon}" }
      Rails.logger.info("[backfill_region] aniqlanmadi: #{undetermined.map(&:first).join(', ')}")
    end

    if apply
      puts(to_write.any? ? "\nBajarildi — #{to_write.size} ta kuzatuvga viloyat yozildi." : "\nYoziladigan narsa yo`q.")
    else
      puts "\nBu DRY RUN edi. Haqiqiy yozish: rails plant_sightings:backfill_region APPLY=true"
    end
  end
end
