require 'spec_helper'

# 1-ISH: kuzatuv kartochkasi rasmida (profil + tur sahifasi galereyasi)
# rasmni joylagan foydalanuvchining dumaloq avatari ko'rinadi.
describe 'User avatar on sighting cards', type: :request do
  let(:viewer)   { FactoryBot.create(:user) }
  let(:uploader) { FactoryBot.create(:user, first_name: 'Anvar', last_name: 'Karimov') }
  let!(:plant)   { Plant.create!(species_sci: 'Avataria testensis L.', primary_record: true) }
  let!(:sighting) do
    s = PlantSighting.new(user: uploader, plant: plant, status: 'approved', published: true,
                          timestamp: Time.zone.now, photo_status: 'ready')
    s.save!(validate: false)
    s
  end

  before { sign_in viewer }

  it 'shows an avatar link to the uploader on the species page gallery' do
    get plant_path(plant)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('sighting-user-avatar')
    expect(response.body).to include(profile_path(uploader))
    # Avatarsiz foydalanuvchi — ism bosh harflari bilan yashil doira.
    expect(response.body).to include('AK')
    expect(response.body).to include('aria-label="Karimov Anvar"')
  end

  it 'shows an avatar on the profile sightings grid' do
    get profile_path(uploader)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('sighting-user-avatar')
  end
end
