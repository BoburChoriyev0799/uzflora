require 'spec_helper'

describe 'Users experts list', type: :request do
  it 'lists users flagged as expert or admin, with their identified species count' do
    expert = FactoryBot.create(:user, :expert)
    FactoryBot.create(:user) # not an expert, should not appear
    plant = Plant.create!(species_sci: 'Testia zeta L.')
    PlantSighting.create!(user: expert, published: true, status: 'approved',
                           timestamp: Time.zone.now, latitude: 41.3, longitude: 69.2, plant_id: plant.id)

    get experts_users_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(expert.full_name)
  end
end
