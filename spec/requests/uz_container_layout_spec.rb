require 'spec_helper'

# 3-ISH tutun testi: keng sahifalar `.uz-container`, matnli sahifalar
# `.uz-container-narrow` klassini oladi va sahifalar xatosiz render bo'ladi.
describe 'Desktop full-width layout (uz-container)', type: :request do
  let(:user) { FactoryBot.create(:user) }

  it 'renders the guest homepage with a wide container' do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('uz-container')
  end

  it 'renders the plants list with a wide container for a signed-in user' do
    sign_in user
    get plants_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('container uz-container content')
  end

  it 'renders the users list with a wide container' do
    sign_in user
    get users_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('uz-container')
  end

  it 'renders the profile page' do
    sign_in user
    get profile_path(user)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('uz-container')
  end

  it 'renders the sign-in page with a narrow container' do
    get new_user_session_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('uz-container-narrow')
  end

  it 'renders the sign-up page with a narrow container' do
    get new_user_registration_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('uz-container-narrow')
  end

  it 'renders the big year page' do
    sign_in user
    get big_year_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('uz-container')
  end
end
