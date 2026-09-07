require 'spec_helper'
require 'rake'

describe 'photos:strip_exif rake task', type: :task do
  before(:all) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require('tasks/strip_exif', [Rails.root.join('lib').to_s])
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['photos:strip_exif'] }
  after { task.reenable }

  let(:user) { FactoryBot.create(:user) }

  # Rasmni LOKAL diskka saqlaymiz (test'da R2 yo'q) — rake task DB'даgi
  # kuzatuvlar bo'yicha aylanadi va har versiyani o'qiydi.
  around do |example|
    PlantSightingUploader.storage :file
    example.run
  ensure
    PlantSightingUploader.storage :fog
    FileUtils.rm_rf(Rails.root.join('public/images/plant_sighting'))
  end

  # `enqueue_photo_processing` after_commit callback'i photo_status'ni
  # 'pending'ga qaytaradi (fon jarayoni) — bu test'да kerak emas.
  before { allow_any_instance_of(PlantSighting).to receive(:enqueue_photo_processing) }

  let(:gps_file) do
    path = Rails.root.join('tmp', "rake_exif_#{SecureRandom.hex(4)}.jpg")
    File.binwrite(path, ExifFixture.jpeg_with_gps(width: 1200, height: 900))
    path
  end
  after { File.delete(gps_file) if File.exist?(gps_file) }

  # GPS'li rasm bilan kuzatuv; keyin har bir saqlangan versiya faylini
  # to'g'ridan-to'g'ri GPS'li bayt bilan qayta yozamiz — uploader endi
  # tozalaydi, shuning uchun ESKI (tozalanmagan) yuklashlarni shunday
  # taqlid qilamiz.
  let!(:sighting) do
    s = PlantSighting.new(user: user, timestamp: Time.zone.now, latitude: 41.5, longitude: 69.5)
    File.open(gps_file) { |f| s.photo = f }
    s.save!(validate: false)
    # Model `store_photo!` after_save callback'ini o'tkazib yuboradi (fon
    # jarayoni) — test'да lokal store'ga qo'lda saqlaymiz.
    s.photo.store!
    s.update_column(:photo_status, 'ready')
    gps = ExifFixture.jpeg_with_gps(width: 400, height: 300)
    { original: s.photo }.merge(s.photo.versions).each_value { |u| Photos::ExifStripper.write_back(u, gps) }
    s.reload
  end

  def any_gps?
    { original: sighting.photo }.merge(sighting.photo.versions).any? do |_, u|
      Photos::ExifStripper.gps_tags(File.binread(u.file.path)).any?
    end
  end

  it 'DRY-RUN reports GPS files but changes nothing' do
    expect { task.invoke }.to output(/GPS topilgan fayl:\s+[1-9]/).to_stdout
    expect(any_gps?).to be(true)
  end

  it 'APPLY strips GPS from every version' do
    expect(any_gps?).to be(true)

    ENV['APPLY'] = 'true'
    begin
      task.invoke
    ensure
      ENV.delete('APPLY')
    end
    expect(any_gps?).to be(false)
  end
end
