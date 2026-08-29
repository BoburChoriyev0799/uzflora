require 'spec_helper'

describe Statistics::Live, type: :model do
  before { Rails.cache.clear }

  let(:plant) { Plant.create!(species_sci: 'Testia epsilon L.') }

  it 'computes the expected counts' do
    user = FactoryBot.create(:user)
    FactoryBot.create(:user, :expert)
    sighting = PlantSighting.create!(user: user, published: true, status: 'approved',
                                      timestamp: Time.zone.now, latitude: 41.3, longitude: 69.2, plant_id: plant.id)
    PlantSighting.create!(user: user, published: true, status: 'pending', timestamp: Time.zone.now)

    stats = Statistics::Live.snapshot

    expect(stats[:users_count]).to eq(User.count)
    expect(stats[:experts_count]).to eq(1)
    expect(stats[:photos_count]).to eq(2)
    expect(stats[:approved_species_count]).to eq(1)
    expect(stats[:pending_count]).to eq(1)
    expect(stats[:research_grade_count]).to eq(sighting.research_grade? ? 1 : 0)
  end

  it 'caches the snapshot so a second call runs no queries' do
    Statistics::Live.snapshot

    query_count = 0
    callback = ->(*args) { query_count += 1 }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      Statistics::Live.snapshot
    end

    expect(query_count).to eq(0)
  end
end
