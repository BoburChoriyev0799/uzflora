require 'spec_helper'

# 1a-ish: tahrirlash sahifasi joriy qiymatlar bilan OLDINDAN TO'LDIRILGAN
# bo'lishi va create-oqimidagi AYNI vidjetlarni (rasm, xarita, viloyat,
# o'simlik autocomplete) qayta ishlatishi.
describe 'Plant sighting edit page — pre-filled fields', type: :request do
  let(:owner) { FactoryBot.create(:user) }
  let(:plant) { Plant.create!(species_sci: 'Prefillia testensis L.', species_uz: 'oldindanto`ldirma', primary_record: true) }

  let!(:sighting) do
    s = PlantSighting.new(user: owner, plant: plant, status: 'approved', published: true,
                          timestamp: Time.zone.local(2026, 3, 15, 9, 0), latitude: 39.654, longitude: 66.960,
                          address: 'Registon maydoni', region: 'samarqand', region_source: 'user', photo_status: 'ready')
    s.save!(validate: false)
    s
  end

  before { sign_in owner }

  it 'sana, koordinata, manzil, viloyat, tur joriy qiymatlar bilan to`ldirilgan' do
    get edit_plant_sighting_path(sighting)
    body = response.body

    expect(body).to include('15/03/2026')
    expect(body).to include('39.654')
    expect(body).to include('66.96')
    expect(body).to include('Registon maydoni')
    expect(body).to include('selected="selected" value="samarqand"').or include('option selected value="samarqand"')
    expect(body).to include('Prefillia')
    expect(body).to include(plant_sighting_path(sighting)) # forma shu manzilga yuboradi
  end

  it 'xarita mavjud koordinata bilan (data-lat/data-lng) ishga tushiriladi' do
    get edit_plant_sighting_path(sighting)
    expect(response.body).to include('id="map_canvas"')
    expect(response.body).to include('data-lat="39.654"')
    expect(response.body).to include('data-lng="66.96"')
  end

  it 'mavjud rasm ko`rsatiladi (rasm bo`lsa)' do
    get edit_plant_sighting_path(sighting)
    expect(response.body).to include('set-plant-photo-preview')
  end

  it 'aniqlashi bo`lmagan kuzatuvda rasm almashtirish ogohlantirishi chiqmaydi' do
    get edit_plant_sighting_path(sighting)
    expect(response.body).not_to include('id="full-edit-photo-warning"')
  end

  it 'aniqlashi bor kuzatuvda ogohlantirish chiqadi' do
    voter = FactoryBot.create(:user)
    sighting.propose_identification!(voter, plant)
    get edit_plant_sighting_path(sighting)
    expect(response.body).to include('id="full-edit-photo-warning"')
    expect(response.body).to include('Rasmni almashtirsangiz')
  end
end
