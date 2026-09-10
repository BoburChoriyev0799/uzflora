require 'spec_helper'

# 2d/2e-ish: /plants viloyat filtri (request) + kuzatuv sahifasida viloyat.
describe 'Region filter & display', type: :request do
  let(:user) { FactoryBot.create(:user) }
  before { sign_in user }

  let!(:plant_a) { Plant.create!(species_sci: 'Tulipa alfa L.', accepted_name: 'Tulipa alfa', family_lat: 'Liliaceae', primary_record: true) }
  let!(:plant_b) { Plant.create!(species_sci: 'Rosa beta L.', accepted_name: 'Rosa beta', family_lat: 'Rosaceae', primary_record: true, red_book: true, group_red_book: true) }

  def sighting(plant, region)
    s = PlantSighting.new(user: user, plant: plant, status: 'approved', published: true,
                          timestamp: Time.zone.now, latitude: 41.0, longitude: 69.0, photo_status: 'ready')
    s.region = region
    s.region_source = 'auto'
    s.save!(validate: false)
    s
  end

  before do
    sighting(plant_a, 'samarqand')
    sighting(plant_b, 'samarqand')
    sighting(plant_a, 'xorazm')
  end

  it 'faqat tanlangan viloyatдаgi turlarni ko`rsatadi' do
    get plants_path(region: 'xorazm')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Tulipa alfa')
    expect(response.body).not_to include('Rosa beta')
  end

  it 'viloyat + oila filtri birga' do
    get plants_path(region: 'samarqand', family: 'Rosaceae')
    expect(response.body).to include('Rosa beta')
    expect(response.body).not_to include('Tulipa alfa')
  end

  it 'viloyat + Qizil kitob filtri birga' do
    get plants_path(region: 'samarqand', red_book: '1')
    expect(response.body).to include('Rosa beta')
    expect(response.body).not_to include('Tulipa alfa')
  end

  it 'filtr formasi faqat kuzatuvi bor viloyatlarni ko`rsatadi' do
    get plants_path
    expect(response.body).to include(RegionLookup.display_name('samarqand'))
    expect(response.body).to include(RegionLookup.display_name('xorazm'))
    expect(response.body).not_to include(RegionLookup.display_name('andijon'))
  end

  it 'kuzatuv sahifasida viloyat "auto" belgisi bilan ko`rsatiladi' do
    s = sighting(plant_a, 'samarqand')
    get plant_sighting_path(s)
    expect(response.body).to include(RegionLookup.display_name('samarqand'))
    expect(response.body).to include('sighting-region-auto')
  end
end
