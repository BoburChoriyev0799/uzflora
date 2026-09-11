require 'spec_helper'

# 2-ish: "Yuklab olish" havolasi (GET /plant_sightings/:id/download).
# `SightingDownloadUrl.for` shu yerda stub qilinadi (haqiqiy R2'ga
# tarmoq orqali murojaat qilinmasin) — o`zi alohida spec'da (
# sighting_download_url_spec.rb) va qo`lda (hisobotga qarang) tekshirilgan.
describe 'Plant sighting download', type: :request do
  let(:owner)  { FactoryBot.create(:user) }
  let(:other)  { FactoryBot.create(:user) }
  let(:expert) { FactoryBot.create(:user, :expert) }
  let(:plant)  { Plant.create!(species_sci: 'Downloadia testensis L.', primary_record: true) }

  def new_sighting(overrides = {})
    s = PlantSighting.new({
      user: owner, plant: plant, status: 'approved', published: true,
      timestamp: Time.zone.local(2026, 1, 1), photo_status: 'ready'
    }.merge(overrides))
    s.save!(validate: false)
    s
  end

  describe 'ruxsat — login shart emas (rasmlar ommaviy)' do
    it 'tizimga kirmagan foydalanuvchi ommaviy kuzatuvni yuklab ola oladi (presigned URL`ga yo`naltiriladi)' do
      sighting = new_sighting
      allow(SightingDownloadUrl).to receive(:for).with(sighting).and_return('https://pub-xyz.r2.dev/signed?X-Amz-Signature=abc')

      get download_plant_sighting_path(sighting)

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to eq('https://pub-xyz.r2.dev/signed?X-Amz-Signature=abc')
    end
  end

  describe 'rad etilgan kuzatuv — `show` bilan bir xil ko`rinish qoidasi' do
    it 'begona (tizimga kirmagan) foydalanuvchi yuklab ola olmaydi' do
      sighting = new_sighting(status: 'rejected')
      get download_plant_sighting_path(sighting)
      expect(response).to redirect_to(plants_path)
    end

    it 'begona (tizimga kirgan) foydalanuvchi ham yuklab ola olmaydi' do
      sighting = new_sighting(status: 'rejected')
      sign_in other
      get download_plant_sighting_path(sighting)
      expect(response).to redirect_to(plants_path)
    end

    it 'egasi baribir yuklab ola oladi' do
      sighting = new_sighting(status: 'rejected')
      allow(SightingDownloadUrl).to receive(:for).with(sighting).and_return('https://pub-xyz.r2.dev/owner-signed')
      sign_in owner
      get download_plant_sighting_path(sighting)
      expect(response).to redirect_to('https://pub-xyz.r2.dev/owner-signed')
    end

    it 'ekspert ham yuklab ola oladi' do
      sighting = new_sighting(status: 'rejected')
      allow(SightingDownloadUrl).to receive(:for).with(sighting).and_return('https://pub-xyz.r2.dev/expert-signed')
      sign_in expert
      get download_plant_sighting_path(sighting)
      expect(response).to redirect_to('https://pub-xyz.r2.dev/expert-signed')
    end
  end

  describe 'rasm hali tayyor bo`lmasa' do
    it 'ogohlantirish bilan kuzatuv sahifasiga qaytaradi' do
      sighting = new_sighting
      allow(SightingDownloadUrl).to receive(:for).with(sighting).and_return(nil)

      get download_plant_sighting_path(sighting)

      expect(response).to redirect_to(plant_sighting_path(sighting))
      expect(flash[:alert]).to eq(I18n.t('plant_sightings.show.download_not_ready'))
    end
  end
end
