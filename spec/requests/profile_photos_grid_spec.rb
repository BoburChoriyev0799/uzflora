require 'spec_helper'

# 4-ISH: profil "Suratlar" gridi.
describe 'Profile photos grid', type: :request do
  let(:owner) { FactoryBot.create(:user, first_name: 'Dilnoza', last_name: 'Yusupova') }
  let(:plant) { Plant.create!(species_sci: 'Profilia testensis (Bunge) Stef.', primary_record: true) }

  def sighting!(attrs = {})
    s = PlantSighting.new({ user: owner, plant: plant, status: 'approved', published: true,
                            timestamp: Time.zone.local(2025, 5, 4), photo_status: 'ready' }.merge(attrs))
    s.save!(validate: false)
    s
  end

  before { sign_in owner }

  it 'renders the grid container and cards without error' do
    sighting!(research_grade: true, address: 'toshkent', latitude: 41.3, longitude: 69.28)
    get profile_path(owner)
    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('profile-birds-container')
    expect(body).to include('profile-sighting-card')
    expect(body).to include('profile-sighting-actions')
  end

  it 'shows the research-grade badge as a short chip (localized)' do
    sighting!(research_grade: true)
    get profile_path(owner)
    expect(response.body).to include('profile-sighting-rg-chip')
    expect(response.body).to include(I18n.t('identifications.research_grade_badge_short'))
  end

  it 'never shows raw coordinates — no-address location is rounded to 3 decimals' do
    sighting!(address: nil, latitude: 41.295431, longitude: 69.230574)
    get profile_path(owner)
    body = response.body
    expect(body).not_to include('69.230574')
    expect(body).to include('41.295, 69.231')
  end

  it 'obscures coordinates for a red-book species seen by a non-owner' do
    red = Plant.create!(species_sci: 'Tulipa greigii Regel', primary_record: true, red_book: true)
    sighting!(plant: red, address: nil, latitude: 41.295431, longitude: 69.230574)
    other = FactoryBot.create(:user)
    sign_in other
    get profile_path(owner)
    body = response.body
    expect(body).not_to include('41.295')
    expect(body).not_to include('69.230')
  end

  it 'gives the edit/delete buttons title and aria-label; only for owner/expert' do
    sighting!
    get profile_path(owner)
    body = response.body
    esc = ->(k) { CGI.escapeHTML(I18n.t("profile.photo.#{k}")) }
    expect(body).to include("aria-label=\"#{esc.call('edit')}\"")
    expect(body).to include("title=\"#{esc.call('edit')}\"")
    expect(body).to include("aria-label=\"#{esc.call('delete')}\"")

    other = FactoryBot.create(:user)
    sign_in other
    get profile_path(owner)
    expect(response.body).not_to include('delete_user_plant_sighting')
  end

  it 'consolidates tabs — no separate photos/map row, map is a link in the pill row' do
    get profile_path(owner)
    body = response.body
    expect(body).not_to include('profile-view-tabs')
    expect(body).to include('profile-menu-map')
    expect(body).to include(user_map_path(owner))
  end

  it 'paginates sightings at a page size divisible by every column count (2/3/4/6)' do
    28.times { sighting! }
    get profile_path(owner)
    per = controller.instance_variable_get(:@sightings).limit_value
    expect([2, 3, 4, 6]).to all(satisfy { |n| (per % n).zero? })
  end
end
