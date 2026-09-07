# frozen_string_literal: true
#
# Test yordamchisi: GPS koordinatasi VA orientatsiya (burilish) tegi bo'lgan
# haqiqiy EXIF APP1 segmentini o'z ichiga olgan JPEG yaratadi. Tashqi
# kutubxona (exiftool/piexif) shart emas — TIFF/EXIF strukturasi qo'lda
# yig'iladi (little-endian "II").
module ExifFixture
  module_function

  # 41°18'42" N, 69°16'45" E  (Toshkent atrofi) + Orientation = 6 (90° CW).
  GPS_LAT_DEG = 41
  GPS_LAT_MIN = 18
  GPS_LAT_SEC = 42
  GPS_LON_DEG = 69
  GPS_LON_MIN = 16
  GPS_LON_SEC = 45

  # orientation: 1..8 EXIF Orientation tegi; nil -> Orientation tegisiz
  # (allaqachon to'g'ri joylashgan, ishlangan fayllar kabi).
  def jpeg_with_gps_and_orientation(width: 1200, height: 900, orientation: 6)
    base = plain_jpeg(width, height)
    app1 = exif_app1_segment(orientation)
    # APP1 segmentini SOI (FF D8) dan keyin joylashtiramiz.
    base[0, 2] + app1 + base[2..]
  end

  def jpeg_with_gps(width: 1000, height: 800)
    jpeg_with_gps_and_orientation(width: width, height: height, orientation: nil)
  end

  # EXIF/GPS'siz oddiy JPEG (ImageMagick orqali).
  def plain_jpeg(width, height)
    require 'open3'
    out, err, status = Open3.capture3(
      'magick', '-size', "#{width}x#{height}", 'xc:#4a7c2a', 'jpg:-'
    )
    raise "magick failed: #{err}" unless status.success?

    out.b
  end

  def exif_app1_segment(orientation)
    tiff = tiff_body(orientation)
    payload = "Exif\x00\x00".b + tiff
    length = payload.bytesize + 2
    "\xFF\xE1".b + [length].pack('n') + payload
  end

  # TIFF: II header -> IFD0 (ixtiyoriy Orientation + GPS IFD pointer) -> GPS IFD.
  def tiff_body(orientation)
    ifd0_entries = orientation ? 2 : 1
    ifd0_offset = 8
    ifd0_size = 2 + ifd0_entries * 12 + 4
    gps_ifd_offset = ifd0_offset + ifd0_size
    gps_ifd_size = 2 + 5 * 12 + 4       # 66
    lat_data_offset = gps_ifd_offset + gps_ifd_size
    lon_data_offset = lat_data_offset + 24

    header = "II".b + [42].pack('v') + [ifd0_offset].pack('V')

    ifd0 = [ifd0_entries].pack('v')
    ifd0 << ifd_entry(0x0112, 3, 1, [orientation].pack('v') + "\x00\x00") if orientation
    ifd0 << ifd_entry(0x8825, 4, 1, [gps_ifd_offset].pack('V')) # GPS IFD pointer
    ifd0 << [0].pack('V')

    gps = [5].pack('v')
    gps << ifd_entry(0x0000, 1, 4, "\x02\x03\x00\x00")          # GPSVersionID
    gps << ifd_entry(0x0001, 2, 2, "N\x00\x00\x00")             # GPSLatitudeRef
    gps << ifd_entry(0x0002, 5, 3, [lat_data_offset].pack('V')) # GPSLatitude
    gps << ifd_entry(0x0003, 2, 2, "E\x00\x00\x00")             # GPSLongitudeRef
    gps << ifd_entry(0x0004, 5, 3, [lon_data_offset].pack('V')) # GPSLongitude
    gps << [0].pack('V')

    lat = rational(GPS_LAT_DEG) + rational(GPS_LAT_MIN) + rational(GPS_LAT_SEC)
    lon = rational(GPS_LON_DEG) + rational(GPS_LON_MIN) + rational(GPS_LON_SEC)

    header + ifd0 + gps + lat + lon
  end

  def ifd_entry(tag, type, count, value_or_offset)
    value = value_or_offset.b
    value += "\x00" * (4 - value.bytesize) if value.bytesize < 4
    [tag].pack('v') + [type].pack('v') + [count].pack('V') + value[0, 4]
  end

  def rational(numerator, denominator = 1)
    [numerator].pack('V') + [denominator].pack('V')
  end
end
