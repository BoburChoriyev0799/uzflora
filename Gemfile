source 'https://rubygems.org'

ruby '3.3.9'

# Rails 5.1 -> 7.1: Ruby 3.3 bilan rasman mos, ekotizim yetarlicha yetilgan.
gem 'rails', '~> 7.1.0'

# 0.20 -> 1.5: eski native extension Ruby 3.3 bilan build bo'lmaydi.
gem 'pg', '~> 1.5'

# Standart Rails xabarlari (validatsiya, "N ta xato topildi" va h.k.) uchun
# o'zbekcha tarjima — bularsiz default_locale :uz bo'lsa ham bu matnlar
# "Translation missing" bo'lib chiqadi.
gem 'rails-i18n', '~> 7.0'

# Sprockets orqali asset pipeline'ni saqlab qolamiz (jquery-rails, uglifier
# shu tizimga bog'liq). Rails 7 buni endi avtomatik qo'shmaydi.
gem 'sprockets-rails'

# Eski Gemfile'da web-server gemi umuman ko'rsatilmagan edi.
gem 'puma', '~> 6.4'

# 1-4-stable (git) -> 3.x: ActiveAdmin 1.x Rails 6/7 bilan ishlamaydi.
# app/admin/*.rb DSL o'zgarishlari va Ransack allowlist talabi tekshiriladi.
gem 'activeadmin', '~> 3.2'

# Brute-force (parol taxmin qilish) himoyasi — login va /admin uchun
# so'rov chastotasini cheklaydi (config/initializers/rack_attack.rb).
gem 'rack-attack', '~> 6.7'

# Deyarli tashlab qo'yilgan gem (oxirgi relizi 2018), Rails 7/UJS bilan
# sinovdan o'tkazish kerak (app/views/profiles/_profile.html.haml).
gem 'best_in_place', '~> 3.1', require: false

gem 'bootstrap3-datetimepicker-rails', '~> 4.17.47'
gem 'bugsnag', '~> 6.26'
gem 'carrierwave', '~> 3.0'

# Render'ning bepul rejasida disk efemer (har deploy'da tozalanadi) —
# yuklangan rasmlar S3-mos obyekt xotirasida (Cloudflare R2) saqlanadi.
# fog-aws istalgan S3-mos provayder bilan ishlaydi (R2, Backblaze B2,
# Supabase ...), shuning uchun kod provayderdan mustaqil.
gem 'fog-aws', '~> 3.28'

gem 'closure_tree', '~> 8.0'
gem 'devise', '~> 4.9'
gem 'devise-two-factor', '~> 5.1'
gem 'rqrcode', '~> 3.0'
gem 'globalize', '~> 6.3'
gem 'globalize-accessors', '~> 0.3'
gem 'jquery-rails', '~> 4.6'
gem 'haml-rails', '~> 2.1'
gem 'kaminari', '~> 1.2'
gem 'mini_magick', '~> 4.13'
gem 'momentjs-rails', '~> 2.20'

# 1.x -> 2.x: 1.x'da GET so'rov orqali autentifikatsiyani amalga oshirish
# mumkin bo'lgan CVE bor edi. 2.x bilan login route POST bo'lishi shart —
# shuning uchun CSRF himoya gem'i ham qo'shildi.
gem 'omniauth', '~> 2.1'
gem 'omniauth-rails_csrf_protection', '~> 1.0'
gem 'omniauth-facebook', '~> 9.0'

gem 'recaptcha', '~> 5.16', require: 'recaptcha/rails'

# sass-rails o'rniga: eski Sprockets+Sass pipeline (require_tree, .sass/.scss
# to'g'ridan-to'g'ri kompilyatsiya) ishlashi uchun sassc kerak. sass-rails
# gemining o'zi endi kerak emas (sprockets-rails buni allaqachon
# qo'llab-quvvatlaydi), faqat native kompilyator yetishmayapti edi.
#
# dartsass-rails ATAYLAB ishlatilmaydi: gemning o'zi mavjud bo'lishining
# o'zi `assets:precompile`ni so'zsiz `dartsass:build`ga bog'lab qo'yadi
# (config.dartsass.builds standart qiymati bilan application.scss'ni
# qidiradi — bizda esa application.css.sass bor). Bu Render'da build'ni
# buzgan edi. Biz dartsass'dan foydalanmaymiz, shuning uchun gem umuman
# qo'shilmagan.
gem 'sassc', '~> 2.4'

# git/mbleigh -> rasmiy reliz: git manba faol emasga o'xshaydi. Rasmiy
# gem versiyasiga o'tkazildi, lekin Rails 7 bilan ishlashi sinovdan
# o'tkazilishi kerak (ActiveRecord adapter ichki API'lariga bog'liq).
gem 'seed-fu', '~> 2.3'

gem 'seedbank', '~> 0.5'
gem 'turbolinks', '~> 5.2'

# uglifier -> terser: Uglifier ES5'dan naryi sintaksisni tushunmaydi, Rails
# 7'ning o'z JS asset'lari (activestorage, actioncable, actiontext) esa
# const/let/class/arrow function/spread kabi to'liq ES6+ sintaksisda —
# Render'da assets:precompile shu yerda yiqilgan edi. Terser zamonaviy,
# faol qo'llab-quvvatlanadi va ES2020+ sintaksisni to'liq tushunadi.
gem 'terser', '~> 1.2'

# terser (va ExecJS) ishlashi uchun JS runtime kerak. Tizim Node.js'iga
# tayanish o'rniga (bu muhitda umuman yo'q edi, Render'da ham borligi
# kafolatlanmagan) — mini_racer orqali V8'ni to'g'ridan-to'g'ri gem
# ichiga o'rnatamiz. Shunda build har qanday muhitda bir xil ishlaydi.
gem 'mini_racer', '~> 0.16'


group :test, :development do
  # factory_girl* -> factory_bot*: eski nom 2016'dan beri yangilanmaydi,
  # yangi loyihalarda ishlatib bo'lmaydi. factory_girl_rspec shart emas —
  # factory_bot rspec bilan to'g'ridan-to'g'ri ishlaydi.
  gem 'factory_bot'
  gem 'factory_bot_rails'

  gem 'pry'
  gem 'pry-doc'
  gem 'pry-rails'
  gem 'pry-byebug'

  gem 'rspec', '~> 3.13'
  gem 'rspec-rails', '~> 6.1'
end

group :test do
  gem 'shoulda-matchers', '~> 6.4'
end

group :development do
  # Capistrano 3.6.1 -> 3.19: bundler 2.x bilan ishlashi uchun zarur.
  gem 'capistrano', '~> 3.19', require: false
  gem 'capistrano-bundler', '~> 2.1'
  gem 'capistrano-rails', '~> 1.6'
  # .ruby-gemset fayli RVM ishlatilishini ko'rsatadi — agar deploy muhiti
  # endi RVM ishlatmasa, bu gem almashtirilishi kerak bo'ladi (keyinroq
  # aniqlashtiramiz).
  gem 'capistrano-rvm'
end

group :deploy do
  # remember to update deploy.rb
  gem 'bcrypt_pbkdf', '~> 1.1'
  gem 'ed25519', '~> 1.3'
end
