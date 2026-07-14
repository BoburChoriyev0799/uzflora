# best_in_place 3.1.1 (gem, 2018-yildan beri yangilanmagan) o'z railtie'sida
# `ActionView::Base.new` ni parametrsiz chaqiradi — bu konstruktor Rails 6+
# da olib tashlangan. Shu sabab Gemfile'da `require: false` qo'yilgan;
# gem'ning buzuq railtie'sini butunlay chetlab o'tamiz va uning ikkita
# vazifasini (helper'larni ulash, JS asset yo'lini ro'yxatga olish) shu
# yerda to'g'ridan-to'g'ri bajaramiz. `BestInPlace::Engine`ni ishlatmaymiz —
# u config/initializers/*.rb ichida yuklansa, Rails uning initializer'larini
# allaqachon yig'ib bo'lgan bo'ladi va ular hech qachon ishga tushmaydi.
require 'best_in_place/utils'
require 'best_in_place/helper'
require 'best_in_place/controller_extensions'
require 'best_in_place/display_methods'

module BestInPlace
  def self.configure
    @configuration ||= Configuration.new
    yield @configuration if block_given?
  end

  def self.method_missing(method_name, *args, &block)
    @configuration.respond_to?(method_name) ?
        @configuration.send(method_name, *args, &block) : super
  end

  class Configuration
    attr_accessor :container, :skip_blur

    def initialize
      @container = :span
      @skip_blur = false
    end
  end

  configure
end

ActiveSupport.on_load(:action_view) { include BestInPlace::Helper }
ActiveSupport.on_load(:action_controller) { include BestInPlace::ControllerExtensions }

best_in_place_root = Gem::Specification.find_by_name('best_in_place').gem_dir
Rails.application.config.assets.paths << "#{best_in_place_root}/lib/assets/javascripts"
Rails.application.config.assets.paths << "#{best_in_place_root}/vendor/assets/javascripts"

Rails.application.config.after_initialize do
  BestInPlace::ViewHelpers = ActionView::Base.empty
end
