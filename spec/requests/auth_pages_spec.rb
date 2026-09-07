require 'spec_helper'

# Kirish / ro'yxatdan o'tish sahifalarining yangi dizayni. Autentifikatsiya
# MANTIG'I o'zgarmadi — faqat ko'rinish.
describe 'Auth pages (new design)', type: :request do
  describe 'sign in page' do
    it 'opens as a real Rails form with a CSRF token (form_for, not a hand-written <form>)' do
      original = ActionController::Base.allow_forgery_protection
      begin
        ActionController::Base.allow_forgery_protection = true
        get new_user_session_path
      ensure
        ActionController::Base.allow_forgery_protection = original
      end
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="authenticity_token"')
      expect(response.body).to match(%r{<form[^>]+action="#{Regexp.escape(user_session_path)}"[^>]*method="post"}i)
      expect(response.body).to include('auth-card')
      # Kirish holati — .is-register YO'Q.
      expect(response.body).not_to match(/class="auth-card[^"]*is-register/)
    end

    it 'has accessible hidden labels and autocomplete attributes' do
      get new_user_session_path
      body = response.body
      expect(body).to include('autocomplete="username"')
      expect(body).to include('autocomplete="current-password"')
      expect(body).to include('auth-visually-hidden')
    end

    it 'renders the Facebook button pointing to the omniauth route (and no dead social buttons)' do
      get new_user_session_path
      body = response.body
      expect(body).to include(user_facebook_omniauth_authorize_path)
      expect(body).not_to match(/google|github|linkedin/i)
    end
  end

  describe 'sign up page' do
    it 'opens in the register state (.is-register)' do
      get new_user_registration_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/class="auth-card[^"]*is-register/)
    end

    it 'keeps every field from the old form' do
      get new_user_registration_path
      body = response.body
      expect(body).to include('user[first_name]')
      expect(body).to include('user[last_name]')
      expect(body).to include('user[email]')
      expect(body).to include('user[password]')
      expect(body).to include('user[big_year]')
      expect(body).to include('autocomplete="new-password"')
    end
  end

  describe 'logging in' do
    let!(:user) { FactoryBot.create(:user, email: 'auth_ok@test.ru', password: '12345678', password_confirmation: '12345678') }

    it 'works with the correct password' do
      post user_session_path, params: { user: { email: 'auth_ok@test.ru', password: '12345678' } }
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(controller.current_user).to eq(user)
    end

    it 'shows an error (in the card) on a wrong password and does not sign in' do
      post user_session_path, params: { user: { email: 'auth_ok@test.ru', password: 'nope-nope' } }
      # Devise noto'g'ri parolda sessions#new'ni QAYTA render qiladi
      # (redirect emas) — xato karta ichida ko'rinadi.
      expect(response.body).to include('auth-alert--error')
      expect(controller.current_user).to be_nil
    end
  end

  describe 'registering' do
    it 'creates the user with all submitted fields' do
      expect {
        post user_registration_path, params: { user: {
          first_name: 'Sardor', last_name: 'Aliyev', email: 'newreg@test.ru',
          password: '12345678', big_year: '1'
        } }
      }.to change(User, :count).by(1)

      u = User.find_by(email: 'newreg@test.ru')
      expect(u.first_name).to eq('Sardor')
      expect(u.last_name).to eq('Aliyev')
      expect(u.big_year).to be(true)
    end

    it 'on a validation error re-renders with the REGISTER panel open and the error visible' do
      FactoryBot.create(:user, email: 'taken@test.ru')
      post user_registration_path, params: { user: {
        first_name: 'X', last_name: 'Y', email: 'taken@test.ru', password: '12345678'
      } }
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:ok)
      expect(response.body).to match(/class="auth-card[^"]*is-register/)
      expect(response.body).to include('auth-alert--error')
    end
  end

  describe 'localization' do
    { 'uz' => 'Kirish', 'ru' => 'Вход', 'en' => 'Log in' }.each do |locale, word|
      it "renders the #{locale} translation" do
        get new_user_session_path, headers: { 'HTTP_COOKIE' => "locale=#{locale}" }
        expect(response.body).to include(word)
        expect(response.body).not_to match(/translation missing/i)
      end
    end
  end

  # Telefonда karta ekranga sig'sin — auth.css.scss'да qat'iy katta
  # piksel kengliklari (width: Npx) bo'lmasligi kerak (faqat max-width /
  # min-width / kichik ikonka o'lchamlari).
  describe 'auth.css.scss has no oversized fixed pixel widths' do
    let(:css) { File.read(Rails.root.join('app/assets/stylesheets/pages/auth.css.scss')) }

    it 'declares only max-width / min-width / tiny widths in px' do
      offenders = css.each_line.map(&:strip).select do |line|
        m = line.match(/\A(?<prop>[a-z-]*width):\s*(?<val>\d+)px/)
        m && m[:prop] == 'width' && m[:val].to_i > 40
      end
      expect(offenders).to be_empty, "oversized fixed width(s): #{offenders.inspect}"
    end

    it 'sizes .auth-card by max-width, not a fixed width' do
      expect(css).to match(/\.auth-page \.auth-card \{[^}]*width:\s*100%/m)
      expect(css).to match(/\.auth-page \.auth-card \{[^}]*max-width:\s*850px/m)
    end
  end

  # XAVFSIZLIK: kirish/ro'yxat sahifasidan boshqa hech narsa o'zgarmasin.
  describe 'no regression on other pages' do
    let(:user) { FactoryBot.create(:user) }

    it 'the guest homepage renders as before (no auth-body class, no auth card)' do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('class="auth-body"')
      expect(response.body).not_to include('auth-card')
    end

    it '/plants renders as before' do
      sign_in user
      get plants_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('class="auth-body"')
      expect(response.body).not_to include('auth-card')
    end
  end
end
