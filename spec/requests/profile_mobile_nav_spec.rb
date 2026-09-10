require 'spec_helper'

# 1b-ish: yorliqlar qatori (.sub-nav-pils) endi mobilda ham ko'rinadi —
# `sm-display-none` klassisiz. Gorizontal scroll va akkordeonni yashirish
# CSS orqali (@media <768).
describe 'Profile & map — mobile tab bar visibility', type: :request do
  let(:user)   { FactoryBot.create(:user) }
  let(:viewer) { FactoryBot.create(:user) }
  before { sign_in viewer }

  it 'profil sahifasida yorliqlar qatori sm-display-none klassisiz' do
    get profile_path(user)
    expect(response).to have_http_status(:ok)
    bar = response.body[/<div class="[^"]*sub-nav-pils[^"]*"/]
    expect(bar).to be_present
    expect(bar).not_to include('sm-display-none')
  end

  it 'xarita sahifasida yorliqlar qatori sm-display-none klassisiz' do
    get user_map_path(user)
    bar = response.body[/<div class="[^"]*sub-nav-pils[^"]*"/]
    expect(bar).to be_present
    expect(bar).not_to include('sm-display-none')
  end
end
