require 'spec_helper'

# 1-ish: to'liq tahrirlash qo'shilgandan keyin ESKI bosqichma-bosqich
# (create) oqimi hali ham ishlaydimi — smoke test. Avval bu action'larga
# hech qanday maxsus test yo'q edi; `require_manage_access!` before_action
# qo'shilgani buni buzmasligini shu yerda tasdiqlaymiz.
describe 'Plant sighting create wizard — smoke', type: :request do
  let(:user) { FactoryBot.create(:user) }
  before { sign_in user }

  let(:photo_path) do
    path = Rails.root.join('tmp', "wizard_smoke_#{SecureRandom.hex(4)}.jpg")
    File.binwrite(path, ExifFixture.plain_jpeg(300, 200))
    path
  end
  after { File.delete(photo_path) if File.exist?(photo_path) }

  it 'create -> edit_date -> edit_map -> edit_plant -> publish, bosqichma-bosqich' do
    post plant_sightings_path, params: {
      plant_sighting: { photo: Rack::Test::UploadedFile.new(photo_path, 'image/jpeg') }
    }
    sighting = user.plant_sightings.last
    expect(sighting).to be_present
    expect(response).to redirect_to(edit_date_plant_sighting_path(sighting))

    get edit_date_plant_sighting_path(sighting)
    expect(response).to have_http_status(:ok)

    patch plant_sighting_path(sighting), params: { plant_sighting: { timestamp: '01/03/2026' } }
    expect(response).to redirect_to(edit_map_plant_sighting_path(sighting))

    get edit_map_plant_sighting_path(sighting)
    expect(response).to have_http_status(:ok)

    patch plant_sighting_path(sighting), params: { plant_sighting: { latitude: 41.3, longitude: 69.3 } }
    expect(response).to redirect_to(edit_plant_plant_sighting_path(sighting))

    get edit_plant_plant_sighting_path(sighting)
    expect(response).to have_http_status(:ok)

    post publish_plant_sighting_path(sighting), params: { plant_sighting: { note: 'sinov' } }
    expect(response).to redirect_to(plant_sighting_path(sighting))
    expect(sighting.reload.published).to be(true)
  end

  it 'begona foydalanuvchi boshqa birovning qoralamasini davom ettira olmaydi' do
    owner = FactoryBot.create(:user)
    draft = PlantSighting.new(user: owner, published: false, photo_status: 'pending')
    draft.save!(validate: false)

    get edit_date_plant_sighting_path(draft)
    expect(response).to have_http_status(:forbidden)
  end
end
