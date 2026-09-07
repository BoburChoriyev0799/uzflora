require 'spec_helper'

# 2-ISH: profil xaritasi JSON endpoint'i — aniq koordinata sizib
# chiqmasin, ko'rinish qoidalari to'g'ri ishlasin.
describe 'Profile map (users#map)', type: :request do
  let(:owner)  { FactoryBot.create(:user) }
  let(:expert) { FactoryBot.create(:user, :expert) }
  let(:other)  { FactoryBot.create(:user) }

  let(:red_book_plant) { Plant.create!(species_sci: 'Tulipa greigii Regel', primary_record: true, red_book: true) }
  let(:ordinary_plant) { Plant.create!(species_sci: 'Ordinaria testensis L.', primary_record: true) }

  let(:exact_lat) { 41.31171 }
  let(:exact_lon) { 69.27937 }

  def create_sighting(plant:, status: 'approved', published: true, lat: exact_lat, lon: exact_lon)
    s = PlantSighting.new(user: owner, plant: plant, status: status, published: published,
                          timestamp: Time.zone.now, latitude: lat, longitude: lon, photo_status: 'ready')
    s.save!(validate: false)
    s
  end

  context 'red book sighting viewed by another user (JSON)' do
    let!(:sighting) { create_sighting(plant: red_book_plant) }

    it 'never leaks the exact coordinates and returns the rounded ones' do
      sign_in other
      get user_map_path(owner, format: :json)

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).not_to include('41.31171')
      expect(body).not_to include('69.27937')

      json = JSON.parse(body)
      marker = json['sightings'].first
      expect(marker['obscured']).to be(true)
      expect(marker['lat']).to eq(41.3)
      expect(marker['lon']).to eq(69.3)
    end
  end

  context 'red book sighting viewed by the owner (JSON)' do
    let!(:sighting) { create_sighting(plant: red_book_plant) }

    it 'returns the exact coordinates' do
      sign_in owner
      get user_map_path(owner, format: :json)

      json = JSON.parse(response.body)
      marker = json['sightings'].first
      expect(marker['obscured']).to be(false)
      expect(marker['lat']).to eq(exact_lat)
      expect(marker['lon']).to eq(exact_lon)
    end
  end

  context 'ordinary species (JSON)' do
    let!(:sighting) { create_sighting(plant: ordinary_plant) }

    it 'returns exact coordinates to any viewer' do
      sign_in other
      get user_map_path(owner, format: :json)
      json = JSON.parse(response.body)
      expect(json['sightings'].first['lat']).to eq(exact_lat)
    end
  end

  context 'visibility of pending sightings' do
    let!(:approved) { create_sighting(plant: ordinary_plant) }
    let!(:pending)  { create_sighting(plant: ordinary_plant, status: 'pending', lat: 42.0, lon: 60.0) }

    it 'hides pending from the public' do
      sign_in other
      get user_map_path(owner, format: :json)
      json = JSON.parse(response.body)
      expect(json['sightings'].size).to eq(1)
      expect(json['sightings'].none? { |m| m['pending'] }).to be(true)
    end

    it 'shows pending to the owner, flagged' do
      sign_in owner
      get user_map_path(owner, format: :json)
      json = JSON.parse(response.body)
      expect(json['sightings'].size).to eq(2)
      expect(json['sightings'].any? { |m| m['pending'] }).to be(true)
    end

    it 'shows pending to experts' do
      sign_in expert
      get user_map_path(owner, format: :json)
      json = JSON.parse(response.body)
      expect(json['sightings'].size).to eq(2)
    end
  end

  context 'HTML page' do
    it 'renders the map container when there are coordinate sightings' do
      create_sighting(plant: ordinary_plant)
      sign_in other
      get user_map_path(owner)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('profile_map_canvas')
    end

    it 'still renders (with an empty-state message) when the user has no coordinate sightings' do
      sign_in other
      get user_map_path(owner)
      expect(response).to have_http_status(:ok)
      # Bo'sh kulrang kvadrat emas — sahifa baribir render bo'ladi;
      # bo'sh holat matni JS uchun data-empty-text'да tayyor turadi.
      expect(response.body).to include('data-empty-text')
      expect(response.body).to include('profile_map_canvas')
    end

    it 'requires authentication' do
      get user_map_path(owner)
      expect(response).to have_http_status(:redirect)
    end
  end
end
