require 'spec_helper'

describe 'Sighting page shows the localized location name', type: :request do
  let(:owner) { FactoryBot.create(:user) }
  # Production'dagi haqiqiy qiymat — kichik harfli "toshkent".
  let!(:sighting) do
    PlantSighting.create!(user: owner, published: true, status: 'approved',
                          timestamp: Time.zone.now, latitude: 41.31, longitude: 69.28,
                          address: 'toshkent')
  end

  it 'renders "Ташкент" on the sighting page in the ru locale' do
    cookies[:locale] = 'ru'
    get plant_sighting_path(sighting)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Ташкент')
    expect(response.body).not_to include('toshkent')
    expect(response.body).not_to match(/translation missing/i)
  end

  it 'renders "Tashkent" on the sighting page in the en locale' do
    cookies[:locale] = 'en'
    get plant_sighting_path(sighting)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Tashkent')
  end
end
