# frozen_string_literal: true
#
# XAVFSIZLIK: allaqachon yuklangan kuzatuv rasmlarining EXIF metama'lumotini
# (jumladan aniq GPS koordinatasini) tozalaydi. Telefon rasmlarida GPS
# ko'pincha EXIF'да qoladi — bu serverdagi koordinata yaxlitlashni
# (SightingCoordinates, Qizil kitob turlari uchun) butunlay bekor qiladi.
#
# Uploader (PlantSightingUploader) endi YANGI yuklashlarda `strip_metadata`
# qiladi — bu task esa ESKI fayllar uchun (R2'да saqlangan har bir versiya).
#
# Ishga tushirish:
#   rails photos:strip_exif             # DRY-RUN (standart): faqat sanaydi
#   APPLY=true rails photos:strip_exif  # tozalaydi va R2'ga qayta yuklaydi
#
# - Rasm piksellar/o'lchami o'zgarmaydi — faqat `-strip` (metama'lumot).
#   TARTIB: avval `-auto-orient` (agar eski faylда burilish tegi qolgan
#   bo'lsa — rasm piksellariga singdiriladi), keyin `-strip`. Shunday
#   qilmasa tik olingan eski rasmlar yon tomonga ag'darilib qolardi.
# - Har bir fayl uchun log.
# - IDEMPOTENT: qayta ishga tushirilsa, GPS'i yo'q fayllar chetlab
#   o'tiladi.
namespace :photos do
  desc 'Kuzatuv rasmlaridan EXIF (GPS) metama\'lumotni tozalash. APPLY=true bilan qo\'llanadi.'
  task strip_exif: :environment do
    apply = ENV['APPLY'].to_s.downcase == 'true'
    mode = apply ? 'APPLY' : 'DRY-RUN'
    puts "[photos:strip_exif] rejim: #{mode}"
    puts '  (DRY-RUN — hech narsa o\'zgartirilmaydi; APPLY=true bilan tozalash yoqiladi)' unless apply

    scope = PlantSighting.where(photo_status: 'ready').where.not(photo: [nil, ''])
    total_sightings = scope.count
    puts "  tekshiriladigan kuzatuvlar: #{total_sightings}"

    files_checked = 0
    files_with_gps = 0
    files_cleaned = 0
    sightings_with_gps = 0
    errors = 0

    scope.find_each do |sighting|
      versions = { original: sighting.photo }.merge(sighting.photo.versions)
      sighting_had_gps = false

      versions.each do |name, uploader|
        blob =
          begin
            uploader.read
          rescue StandardError => e
            warn "  [xato] kuzatuv ##{sighting.id} #{name}: o'qib bo'lmadi — #{e.class}: #{e.message}"
            errors += 1
            nil
          end
        next if blob.nil? || blob.empty?

        files_checked += 1
        gps = Photos::ExifStripper.gps_tags(blob)
        next if gps.empty?

        files_with_gps += 1
        sighting_had_gps = true
        puts "  kuzatuv ##{sighting.id} — #{name}: GPS topildi (#{gps.join(', ')})"

        next unless apply

        begin
          cleaned = Photos::ExifStripper.strip(blob)
          Photos::ExifStripper.write_back(uploader, cleaned)
          files_cleaned += 1
          puts "    -> tozalandi va qayta yuklandi (#{blob.bytesize} -> #{cleaned.bytesize} bayt)"
        rescue StandardError => e
          warn "    [xato] tozalab bo'lmadi — #{e.class}: #{e.message}"
          errors += 1
        end
      end

      sightings_with_gps += 1 if sighting_had_gps
    end

    puts ''
    puts "[photos:strip_exif] YAKUN (#{mode}):"
    puts "  tekshirilgan fayl:            #{files_checked}"
    puts "  GPS topilgan fayl:            #{files_with_gps}"
    puts "  GPS topilgan kuzatuv:         #{sightings_with_gps}"
    puts "  tozalangan fayl:              #{files_cleaned}#{apply ? '' : ' (DRY-RUN)'}"
    puts "  xatolar:                      #{errors}"
    puts ''
    puts '  Tozalash uchun: APPLY=true rails photos:strip_exif' if !apply && files_with_gps.positive?
  end
end
