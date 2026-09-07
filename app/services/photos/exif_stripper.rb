# frozen_string_literal: true

require 'shellwords'
require 'tempfile'

# Rasm baytlaridan EXIF metama'lumotni (jumladan GPS koordinatasini)
# tozalash yordamchisi — `photos:strip_exif` rake task ishlatadi.
#
# TARTIB: `-auto-orient` (EXIF burilish tegini piksellarga singdirish)
# -> `-strip` (barcha metama'lumotni o'chirish). Faqat `-strip` qilinsa,
# eski (POWO/Rails 7 migratsiyasidan oldingi, auto-orient qilinmagan)
# fayllarда tik olingan rasmlar yon tomonga ag'darilib qolardi.
module Photos
  module ExifStripper
    module_function

    # Berilgan JPEG baytlarida mavjud GPS EXIF teglari ro'yxati
    # (bo'sh massiv — GPS yo'q).
    def gps_tags(blob)
      with_tempfile(blob) do |path|
        out = `identify -format '%[EXIF:*]' #{path.to_s.shellescape} 2>/dev/null`
        out.each_line.filter_map do |line|
          key, value = line.strip.split('=', 2)
          next unless key&.match?(/gps/i)
          next if value.to_s.strip.empty?

          "#{key.sub(/\Aexif:/i, '')}=#{value}"
        end
      end
    end

    # Metama'lumati tozalangan JPEG baytlarini qaytaradi. Piksel o'lchami
    # o'zgarmaydi (`-strip` resize qilmaydi); `-auto-orient` faqat eski,
    # noto'g'ri joylashgan fayllarни to'g'rilaydi (tegi bo'lmagan/1 bo'lgan
    # faylda no-op).
    def strip(blob)
      with_tempfile(blob) do |src|
        dst = "#{src}.cleaned.jpg"
        system('magick', src.to_s, '-auto-orient', '-strip', dst, exception: true)
        bytes = File.binread(dst)
        File.delete(dst) if File.exist?(dst)
        bytes
      end
    end

    # Tozalangan baytlarni O'SHA joyga qayta yozadi. Fog (R2) va lokal
    # disk ikkalasini ham qo'llab-quvvatlaydi.
    def write_back(uploader, bytes)
      storage_file = uploader.file

      if storage_file.respond_to?(:store)
        # CarrierWave::Storage::Fog::File — o'sha `path`ga qayta yuklaydi.
        ext = File.extname(uploader.path.to_s)
        Tempfile.create(['exif_clean', ext.presence || '.jpg']) do |t|
          t.binmode
          t.write(bytes)
          t.flush
          t.rewind
          storage_file.store(CarrierWave::SanitizedFile.new(t))
        end
      elsif storage_file.respond_to?(:path) && storage_file.path && File.exist?(storage_file.path)
        File.binwrite(storage_file.path, bytes)
      else
        raise "qo'llab-quvvatlanmaydigan storage: #{storage_file.class}"
      end
    end

    def with_tempfile(blob)
      Tempfile.create(['exif_src', '.jpg']) do |t|
        t.binmode
        t.write(blob)
        t.flush
        yield Pathname.new(t.path)
      end
    end
  end
end
