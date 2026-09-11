require 'spec_helper'

# 1-ish: kuzatuvni TO'LIQ tahrirlash (rasm/sana/koordinata/viloyat/
# joy/tur — bitta sahifada).
describe 'Plant sighting full edit', type: :request do
  let(:owner)   { FactoryBot.create(:user) }
  let(:expert)  { FactoryBot.create(:user, :expert) }
  let(:other)   { FactoryBot.create(:user) }
  let(:plant)   { Plant.create!(species_sci: 'Editia testensis L.', primary_record: true) }
  let(:plant2)  { Plant.create!(species_sci: 'Alia editia L.', primary_record: true) }

  def new_sighting(overrides = {})
    s = PlantSighting.new({
      user: owner, plant: plant, status: 'approved', published: true,
      timestamp: 3.days.ago, latitude: 41.311, longitude: 69.279,
      address: 'Toshkent', region: 'toshkent_shahri', region_source: 'auto',
      photo_status: 'ready'
    }.merge(overrides))
    s.save!(validate: false)
    s
  end

  # --- GET /plant_sightings/:id/edit — ruxsat ---
  describe 'GET edit — permissions' do
    let!(:sighting) { new_sighting }

    it 'egasi ko`radi' do
      sign_in owner
      get edit_plant_sighting_path(sighting)
      expect(response).to have_http_status(:ok)
    end

    it 'ekspert ko`radi' do
      sign_in expert
      get edit_plant_sighting_path(sighting)
      expect(response).to have_http_status(:ok)
    end

    it 'begona foydalanuvchi -> 403' do
      sign_in other
      get edit_plant_sighting_path(sighting)
      expect(response).to have_http_status(:forbidden)
    end

    it 'tizimga kirmagan -> login sahifasiga' do
      get edit_plant_sighting_path(sighting)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  # --- PATCH update (full_edit=1) — maydonlar ---
  describe 'PATCH update — barcha maydonlar' do
    let!(:sighting) { new_sighting }

    before { sign_in owner }

    it 'sana, koordinata, viloyat, joy, turni yangilaydi' do
      patch plant_sighting_path(sighting), params: {
        full_edit: '1',
        plant_sighting: {
          timestamp: '2026-05-01 10:00:00', latitude: 39.654, longitude: 66.960,
          address: 'Samarqand shahri', region: 'samarqand', plant_id: plant2.id
        }
      }
      expect(response).to redirect_to(plant_sighting_path(sighting))
      sighting.reload
      expect(sighting.latitude.to_f).to eq(39.654)
      expect(sighting.longitude.to_f).to eq(66.960)
      expect(sighting.address).to eq('Samarqand shahri')
      expect(sighting.region).to eq('samarqand')
      expect(sighting.region_source).to eq('user') # ro'yxatdan boshqa qiymat tanlandi
      expect(sighting.plant_id).to eq(plant2.id)
    end

    it 'begona foydalanuvchi hech narsani o`zgartira olmaydi (403)' do
      sign_in other
      patch plant_sighting_path(sighting), params: { full_edit: '1', plant_sighting: { address: 'boshqa joy' } }
      expect(response).to have_http_status(:forbidden)
      expect(sighting.reload.address).to eq('Toshkent')
    end

    it 'ekspert boshqa birovning kuzatuvini tahrirlay oladi' do
      sign_in expert
      patch plant_sighting_path(sighting), params: { full_edit: '1', plant_sighting: { address: 'Ekspert tuzatdi' } }
      expect(sighting.reload.address).to eq('Ekspert tuzatdi')
    end

    it 'kelajakdagi sana rad etiladi' do
      patch plant_sighting_path(sighting), params: {
        full_edit: '1', plant_sighting: { timestamp: 1.year.from_now.strftime('%d/%m/%Y') }
      }
      expect(response).to redirect_to(edit_plant_sighting_path(sighting))
      expect(sighting.reload.timestamp.to_date).not_to eq(1.year.from_now.to_date)
    end

    it 'user_id, created_at, id o`zgarmaydi' do
      original_user_id = sighting.user_id
      original_created_at = sighting.created_at
      original_id = sighting.id
      patch plant_sighting_path(sighting), params: { full_edit: '1', plant_sighting: { address: 'yangi' } }
      sighting.reload
      expect(sighting.user_id).to eq(original_user_id)
      expect(sighting.created_at).to be_within(1.second).of(original_created_at)
      expect(sighting.id).to eq(original_id)
    end
  end

  # --- Viloyat manbasi (region_source) qoidasi ---
  describe 'region_source qoidasi' do
    before { sign_in owner }

    it 'koordinata ko`chirilsa, viloyat o`zgarmasa, avval "auto" bo`lsa -> qayta hisoblanib "auto" qoladi' do
      sighting = new_sighting(region: 'toshkent_shahri', region_source: 'auto')
      patch plant_sighting_path(sighting), params: {
        full_edit: '1',
        plant_sighting: { latitude: 39.654, longitude: 66.960, region: 'toshkent_shahri' } # forma eski qiymatni submit qiladi
      }
      sighting.reload
      expect(sighting.region).to eq('samarqand') # yangi koordinataga mos
      expect(sighting.region_source).to eq('auto')
    end

    it 'avval "user" bo`lgan viloyat, koordinata ko`chirilsa ham, o`zgarmay qoladi' do
      sighting = new_sighting(region: 'toshkent_shahri', region_source: 'user')
      patch plant_sighting_path(sighting), params: {
        full_edit: '1',
        plant_sighting: { latitude: 39.654, longitude: 66.960, region: 'toshkent_shahri' }
      }
      sighting.reload
      expect(sighting.region).to eq('toshkent_shahri')
      expect(sighting.region_source).to eq('user')
    end

    it 'ro`yxatdan boshqa viloyat tanlansa -> "user"' do
      sighting = new_sighting(region: 'toshkent_shahri', region_source: 'auto')
      patch plant_sighting_path(sighting), params: {
        full_edit: '1', plant_sighting: { region: 'buxoro' }
      }
      sighting.reload
      expect(sighting.region).to eq('buxoro')
      expect(sighting.region_source).to eq('user')
    end
  end

  # --- Rasm almashtirilganda — ilmiy yaxlitlik ---
  describe 'rasm almashtirish — aniqlashlar' do
    before { sign_in owner }

    it 'rasm almashtirilsa: status pending, research_grade false, agreement_count 0, identifications saqlanadi' do
      sighting = new_sighting(status: 'approved', research_grade: true, agreement_count: 3, research_graded_at: 1.day.ago)
      voter = FactoryBot.create(:user)
      sighting.propose_identification!(voter, plant)
      ident_count_before = sighting.identifications.count

      patch plant_sighting_path(sighting), params: {
        full_edit: '1',
        plant_sighting: { photo: fixture_file_upload_jpeg }
      }

      sighting.reload
      expect(sighting.status).to eq('pending')
      expect(sighting.research_grade).to be(false)
      expect(sighting.agreement_count).to eq(0)
      expect(sighting.identifications.count).to eq(ident_count_before) # o'chirilmagan
      expect(sighting.photo_replaced_at).to be_present
    end

    it 'rasm almashtirilmasa: aniqlashlarga tegilmaydi' do
      sighting = new_sighting(status: 'approved', research_grade: true, agreement_count: 3)
      patch plant_sighting_path(sighting), params: {
        full_edit: '1', plant_sighting: { address: 'yangi manzil' }
      }
      sighting.reload
      expect(sighting.status).to eq('approved')
      expect(sighting.research_grade).to be(true)
      expect(sighting.agreement_count).to eq(3)
      expect(sighting.photo_replaced_at).to be_nil
    end

    it 'aniqlashi yo`q yangi kuzatuvda rasm almashtirilsa ham status o`zgarmaydi' do
      sighting = new_sighting(status: 'pending')
      patch plant_sighting_path(sighting), params: {
        full_edit: '1', plant_sighting: { photo: fixture_file_upload_jpeg }
      }
      expect(sighting.reload.status).to eq('pending')
    end
  end

  def fixture_file_upload_jpeg
    path = Rails.root.join('tmp', "full_edit_photo_#{SecureRandom.hex(4)}.jpg")
    File.binwrite(path, ExifFixture.plain_jpeg(400, 300))
    Rack::Test::UploadedFile.new(path, 'image/jpeg')
  end
end
