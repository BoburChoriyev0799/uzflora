require 'spec_helper'

# XAVFSIZLIK: yuklangan rasm barcha versiyalarida (jumladan yuklab
# olinadigan "asl" faylda) EXIF/GPS metama'lumot tozalanadi — aks holda
# serverdagi koordinata yaxlitlash (SightingCoordinates) bekor bo'lardi.
describe 'PlantSighting photo EXIF/GPS stripping', type: :model do
  let(:user) { FactoryBot.create(:user) }

  # 41°18'42"N, 69°16'45"E EXIF GPS + Orientation=6 (90° CW) bo'lgan JPEG.
  let(:gps_photo_path) do
    path = Rails.root.join('tmp', "exif_gps_#{SecureRandom.hex(4)}.jpg")
    File.binwrite(path, ExifFixture.jpeg_with_gps_and_orientation(width: 2400, height: 1800))
    path
  end

  after { File.delete(gps_photo_path) if File.exist?(gps_photo_path) }

  def process_photo
    uploader = PlantSightingUploader.new(Struct.new(:id).new(4242), :photo)
    File.open(gps_photo_path) { |f| uploader.cache!(f) }
    uploader
  end

  def gps_present?(path)
    out = `identify -format '%[EXIF:*]' #{path} 2>/dev/null`
    out.match?(/gps/i)
  end

  it 'the source fixture really has GPS EXIF (sanity)' do
    expect(gps_present?(gps_photo_path)).to be(true)
  end

  it 'strips GPS EXIF from every version including the original' do
    uploader = process_photo

    %i[medium display small thumb].each do |version|
      file = uploader.versions[version].file
      expect(gps_present?(file.path)).to(be(false), "#{version} still has GPS EXIF")
    end
    expect(gps_present?(uploader.file.path)).to(be(false), 'original still has GPS EXIF')
  end

  it 'bakes in the EXIF orientation before stripping (portrait stays portrait)' do
    uploader = process_photo
    # Manba 2400x1800 (yotiq) + Orientation=6 -> auto-orient 90° -> tik.
    require 'mini_magick'
    img = MiniMagick::Image.open(uploader.file.path)
    expect(img.width).to be < img.height
  end

  it 'does not read coordinates from EXIF — sighting keeps the form values' do
    # EXIF GPS ~41.31/69.28; formadan kelgan qiymatlar butunlay boshqa.
    sighting = PlantSighting.new(user: user, timestamp: Time.zone.now,
                                 latitude: 55.75, longitude: 30.10)
    File.open(gps_photo_path) { |f| sighting.photo = f }
    sighting.save!(validate: false)

    expect(sighting.latitude.to_f).to eq(55.75)
    expect(sighting.longitude.to_f).to eq(30.10)
    expect(gps_present?(sighting.photo.file.path)).to be(false)
  end
end
