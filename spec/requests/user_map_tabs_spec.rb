require 'spec_helper'

# 1a-ish: xarita sahifasi (users#map) HTML — profil sahifasidagi AYNI
# yorliqlar qatorini ko'rsatadi, "Xarita" faol.
describe 'Profile map page — tab bar', type: :request do
  let(:owner) { FactoryBot.create(:user) }
  let(:other) { FactoryBot.create(:user) }
  let(:plant) { Plant.create!(species_sci: 'Tabbia testensis L.', primary_record: true) }

  before do
    s = PlantSighting.new(user: owner, plant: plant, status: 'approved', published: true,
                          timestamp: Time.zone.now, latitude: 41.3, longitude: 69.2, photo_status: 'ready')
    s.save!(validate: false)
    PlantSightingComment.create!(user: owner, plant_sighting: s, text: 'test')
  end

  it 'renders the full profile tab bar with "Xarita" active and links back to the profile' do
    sign_in other
    get user_map_path(owner)

    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('sub-nav-pils')
    expect(body).to include(I18n.t('profile.show.tab_species'))
    expect(body).to include(I18n.t('profile.show.tab_comments'))
    expect(body).to include(I18n.t('profile.show.tab_followers'))
    # "Xarita" faol
    expect(body).to include('profile-menu-map active')
    # yorliqlar profilga havola (#blockN)
    expect(body).to include("#{profile_path(owner)}#block2")
    # profile.js preventDefault qo'yadigan aynan `profile-menu` klassi YO'Q
    # (haqiqiy havolalar — .profile-menu-link).
    expect(body).not_to include('"profile-menu"')
    expect(body).to include('profile-menu-link')
    # yorliqlar JS blok-almashtirgichi EMAS (data-view="blockN" yo'q)
    expect(body).not_to match(/data-view=["']block/)
  end

  it 'shows the Profil and Qoralamalar tabs only to the profile owner' do
    sign_in owner
    get user_map_path(owner)
    expect(response.body).to include(I18n.t('profile.show.tab_drafts'))

    sign_in other
    get user_map_path(owner)
    expect(response.body).not_to include(I18n.t('profile.show.tab_drafts'))
  end
end
