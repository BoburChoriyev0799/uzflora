require 'spec_helper'

# 3-ISH: tur sahifasidagi "Foydalanuvchilar rasmlari" bloki.
describe 'Species page photo gallery', type: :request do
  let(:viewer)   { FactoryBot.create(:user) }
  let(:uploader) { FactoryBot.create(:user, first_name: 'Gulnora', last_name: 'Rashidova') }
  let!(:plant)   { Plant.create!(species_sci: 'Galleria testensis L.', primary_record: true) }

  before { sign_in viewer }

  context 'with photos' do
    let!(:sighting) do
      s = PlantSighting.new(user: uploader, plant: plant, status: 'approved', published: true,
                            timestamp: Time.zone.local(2025, 6, 1), address: 'toshkent',
                            latitude: 41.3, longitude: 69.28, photo_status: 'ready', research_grade: true)
      s.save!(validate: false)
      s
    end

    it 'uses the two-column layout wrappers and the auto-fill gallery grid' do
      get plant_path(plant)
      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include('plant-show-layout')
      expect(body).to include('plant-show-info')
      expect(body).to include('plant-show-gallery-col')
      expect(body).to include('repeat(auto-fill, minmax(200px, 1fr))')
    end

    it 'renders the research-grade chip on the image (short, localized) and the avatar' do
      get plant_path(plant)
      body = response.body
      expect(body).to include('plant-photo-rg-chip')
      expect(body).to include(I18n.t('identifications.research_grade_badge_short'))
      expect(body).to include('sighting-user-avatar')
    end

    it 'shows meta below the image with date, place, author in order' do
      get plant_path(plant)
      body = response.body
      date_i = body.index('plant-photo-date')
      place_i = body.index('plant-photo-place')
      author_i = body.index('plant-photo-author')
      expect([date_i, place_i, author_i]).to all(be_present)
      expect(date_i).to be < place_i
      expect(place_i).to be < author_i
    end
  end

  context 'without photos' do
    it 'shows a clean empty message and an add-photo link (no gray placeholder box)' do
      get plant_path(plant)
      body = response.body
      expect(body).to include(I18n.t('plants.show.photos_empty'))
      expect(body).to include('plant-photos-none')
      expect(body).to include(new_plant_sighting_path)
      expect(body).not_to include('plant-show-placeholder')
    end
  end
end
