require 'spec_helper'

# 1e-ish: rasm almashtirilganda — YANGI rasm ham AYNI uploader'dan (EXIF
# tozalanadi), ESKI fayl saqlagichdan o'chiriladi (CarrierWave'ning
# standart xatti-harakati — bu yerda LOKAL saqlagich bilan tasdiqlanadi).
describe 'Plant sighting full edit — photo replacement storage', type: :request do
  let(:owner) { FactoryBot.create(:user) }
  let(:plant) { Plant.create!(species_sci: 'Photoswappia testensis L.', primary_record: true) }

  around do |example|
    PlantSightingUploader.storage :file
    example.run
  ensure
    PlantSightingUploader.storage :fog
    FileUtils.rm_rf(Rails.root.join('public/images/plant_sighting'))
  end

  def gps_jpeg_path
    path = Rails.root.join('tmp', "full_edit_gps_#{SecureRandom.hex(4)}.jpg")
    File.binwrite(path, ExifFixture.jpeg_with_gps(width: 800, height: 600))
    path
  end

  def plain_jpeg_path
    path = Rails.root.join('tmp', "full_edit_plain_#{SecureRandom.hex(4)}.jpg")
    File.binwrite(path, ExifFixture.plain_jpeg(400, 300))
    path
  end

  let!(:sighting) do
    s = PlantSighting.new(user: owner, plant: plant, status: 'approved', published: true,
                          timestamp: 2.days.ago, latitude: 41.3, longitude: 69.3, photo_status: 'ready')
    File.open(gps_jpeg_path) { |f| s.photo = f }
    s.save!(validate: false)
    s.photo.store!
    s
  end

  it 'eski faylni saqlagichdan olib tashlaydi, yangisini saqlaydi' do
    old_path = sighting.photo.file.path
    expect(File.exist?(old_path)).to be(true)

    sign_in owner
    new_path_file = plain_jpeg_path
    patch plant_sighting_path(sighting), params: {
      full_edit: '1',
      plant_sighting: { photo: Rack::Test::UploadedFile.new(new_path_file, 'image/jpeg') }
    }

    sighting.reload
    expect(File.exist?(old_path)).to be(false), 'eski fayl hali ham saqlagichda qoldi'
  end

  it 'yangi rasmda GPS EXIF yo`q (bir xil uploader — avtomatik tozalanadi)' do
    sign_in owner
    gps_path = gps_jpeg_path
    patch plant_sighting_path(sighting), params: {
      full_edit: '1',
      plant_sighting: { photo: Rack::Test::UploadedFile.new(gps_path, 'image/jpeg') }
    }
    sighting.reload
    sighting.process_pending_photo! # productionda ProcessSightingImageJob shu metodni chaqiradi

    out = `identify -format '%[EXIF:*]' #{sighting.photo.file.path} 2>/dev/null`
    expect(out).not_to match(/gps/i)
  end
end
