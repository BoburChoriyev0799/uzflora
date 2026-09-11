require 'spec_helper'

# 2-ish (YECHIM A): R2 presigned URL + response-content-disposition.
# Haqiqiy R2 bilan tarmoq orqali bog`lanmasin (hermetik, tez, barqaror)
# uchun `photo`/`photo.file` obyektlari shu yerda double bilan almashtiriladi
# — mexanizmning o`zi (authenticated_url + query) haqiqiy bucket'da qo`lda
# curl bilan alohida tekshirilgan (hisobotga qarang).
describe SightingDownloadUrl do
  let(:user) { FactoryBot.create(:user) }
  let(:plant) { Plant.create!(species_sci: 'Urlia testensis L.', primary_record: true) }
  let(:sighting) do
    s = PlantSighting.new(user: user, plant: plant, timestamp: Time.zone.local(2026, 1, 1), photo_status: 'ready')
    s.save!(validate: false)
    s
  end

  describe '.for' do
    it 'rasm mavjud bo`lmasa nil qaytaradi' do
      allow(sighting).to receive(:photo).and_return(double(present?: false))
      expect(described_class.for(sighting)).to be_nil
    end

    it 'rasm hali tayyor bo`lmasa (fon jarayonida) nil qaytaradi' do
      allow(sighting).to receive(:photo).and_return(double(present?: true))
      allow(sighting).to receive(:photo_status_ready?).and_return(false)
      expect(described_class.for(sighting)).to be_nil
    end

    it 'to`g`ri fayl nomi bilan response-content-disposition parametrini query ostida yuboradi' do
      file_double = double('fog file', extension: 'jpg')
      allow(sighting).to receive(:photo).and_return(double(present?: true, file: file_double))
      allow(sighting).to receive(:photo_status_ready?).and_return(true)

      expected_filename = SightingDownloadFilename.for(sighting)
      expect(file_double).to receive(:authenticated_url) do |opts|
        expect(opts[:query]).to eq('response-content-disposition' => %(attachment; filename="#{expected_filename}"))
        expect(opts[:expire_at]).to be_a(Time)
        expect(opts[:expire_at]).to be > Time.now
      end.and_return('https://pub-xyz.r2.dev/signed?X-Amz-Signature=abc')

      expect(described_class.for(sighting)).to eq('https://pub-xyz.r2.dev/signed?X-Amz-Signature=abc')
    end
  end
end
