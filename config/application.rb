require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Birds
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
    config.i18n.available_locales = [:ru, :en, :uz]
    config.i18n.default_locale = :uz
    config.i18n.locale = :uz
    I18n.enforce_available_locales = true

    # Ba'zi gem'lar (masalan CarrierWave) faqat en.yml bilan keladi.
    # Agar :uz'da tarjima topilmasa, "Translation missing" o'rniga
    # inglizchaga qaytsin — xunuk xatolikdan ko'ra ma'noli matn yaxshiroq.
    # Bundan tashqari, muhim joylar uchun (masalan CarrierWave xabarlari)
    # to'g'ridan-to'g'ri config/locales/uz.yml'da o'zbekcha tarjima bor.
    config.i18n.fallbacks = true

    # choices gemi o'rniga Rails'ning ichki config_for'i: xavfsiz YAML
    # alias qo'llab-quvvatlaydi va settings.yml'dagi har bir kalitni
    # (host, hybrid, recaptcha, ...) config.<kalit> sifatida qo'shadi —
    # ilova kodidagi Rails.configuration.hybrid... kabi chaqiruvlar
    # o'zgarmasdan ishlayveradi. config_for faqat eng tashqi darajani
    # OrderedOptions'ga aylantiradi, shuning uchun ichki Hash'larni ham
    # (recaptcha.public_key, hybrid.species.id kabi ko'p bosqichli dot
    # access uchun) rekursiv aylantiramiz.
    deep_ordered_options = ->(value) do
      case value
      when Hash
        ActiveSupport::OrderedOptions.new.update(value.transform_values(&deep_ordered_options))
      when Array
        value.map(&deep_ordered_options)
      else
        value
      end
    end

    config_for(:settings).each do |key, value|
      config.send("#{key}=", deep_ordered_options.call(value))
    end
  end
end
