require 'spec_helper'

describe Photos::ExifStripper do
  # Orientatsiya tegisiz (real, allaqachon ishlangan fayllar kabi) GPS'li JPEG
  # -> auto-orient no-op bo'lib, o'lcham o'zgarmasligi kerak.
  let(:gps_blob) { ExifFixture.jpeg_with_gps(width: 1000, height: 800) }

  def dims(blob)
    Tempfile.create(['d', '.jpg']) do |t|
      t.binmode; t.write(blob); t.flush
      `identify -format '%wx%h' #{t.path}`.strip
    end
  end

  it 'detects GPS tags in the raw bytes' do
    tags = described_class.gps_tags(gps_blob)
    expect(tags.join(' ')).to match(/GPSLatitude/i)
    expect(tags.join(' ')).to match(/GPSLongitude/i)
  end

  it 'returns bytes with no GPS tags after strip' do
    cleaned = described_class.strip(gps_blob)
    expect(described_class.gps_tags(cleaned)).to be_empty
  end

  it 'keeps the pixel dimensions when there is no stale orientation tag' do
    expect(dims(described_class.strip(gps_blob))).to eq(dims(gps_blob))
  end

  it 'reports no tags for an image that never had GPS' do
    plain = ExifFixture.plain_jpeg(300, 200)
    expect(described_class.gps_tags(plain)).to be_empty
  end

  describe '.write_back on local storage' do
    it 'overwrites the stored file in place' do
      uploader = PlantSightingUploader.new(Struct.new(:id).new(77), :photo)
      Tempfile.create(['src', '.jpg']) do |t|
        t.binmode; t.write(ExifFixture.plain_jpeg(400, 300)); t.flush
        File.open(t.path) { |f| uploader.cache!(f) }
      end
      version = uploader.versions[:small]

      # Eski (GPS'li, tozalanmagan) faylni taqlid qilib to'g'ridan-to'g'ri
      # yozamiz, keyin tozalab qaytaramiz.
      described_class.write_back(version, gps_blob)
      expect(described_class.gps_tags(File.binread(version.file.path))).not_to be_empty

      described_class.write_back(version, described_class.strip(gps_blob))
      expect(described_class.gps_tags(File.binread(version.file.path))).to be_empty
    end
  end
end
