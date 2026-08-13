# frozen_string_literal: true
#
# PlantNet (https://my.plantnet.org) vizual aniqlash API'siga bitta rasm
# yuboradi va eng ehtimoliy turlarni qaytaradi. Rasmiy hujjatlar
# (my.plantnet.org/doc/api/identify) shu muhitdan tarmoq orqali ochilmadi
# (ECONNREFUSED — bu loyihaning ma'lum tarmoq cheklovi), shuning uchun
# format PlantNet'ning rasmiy namunalari (github.com/plantnet/my.plantnet,
# examples/post/*) va umumiy ma'lum hujjatlashtirilgan sxema asosida
# qurilgan:
#
#   POST https://my-api.plantnet.org/v2/identify/:project
#        ?api-key=...&lang=..&nb-results=..
#   multipart/form-data: images=<fayl(lar)>, organs=<"auto"|"leaf"|"flower"|...>
#
#   Javob (200):
#     { "results": [ { "score": 0.0..1.0, "species": {
#         "scientificNameWithoutAuthor", "scientificNameAuthorship",
#         "scientificName", "commonNames": [...] } } ],
#       "remainingIdentificationRequests": N }
#
#   Xatolar: 401/403 — kalit noto'g'ri; 400/404 — so'rov/rasm yaroqsiz;
#   429 — kunlik limit (bepul rejada ~500/kun) tugagan.
#
class PlantNetService
  ENDPOINT = 'https://my-api.plantnet.org/v2/identify'
  OPEN_TIMEOUT = 8
  READ_TIMEOUT = 18

  # PlantNet'da O'zbekiston yoki O'rta Osiyoga alohida "project" (flora
  # to'plami) yo'q — /v2/projects ro'yxatidagilar asosan mintaqaviy
  # (masalan "weurope" — G'arbiy Yevropa, "canada"), boshqa qit'alarga mos
  # emas. "all" — PlantNet hujjatlari va rasmiy namunalarida standart
  # qiymat sifatida tavsiya etiladi: barcha loyihalar orasidan rasmga eng
  # mos keladiganini avtomatik tanlaydi, shu bilan O'rta Osiyo o'simliklari
  # uchun ham eng keng qamrovli variant. Kelajakda O'rta Osiyoga xosroq
  # project topilsa — kodga tegmasdan PLANTNET_PROJECT ENV o'zgaruvchisi
  # orqali almashtirish mumkin.
  DEFAULT_PROJECT = ENV.fetch('PLANTNET_PROJECT', 'all')

  # Bitta so'rovda nechta taxmin so'ralsin (frontendda 3-5 tasi ko'rsatiladi).
  DEFAULT_NB_RESULTS = 5

  Prediction = Struct.new(:scientific_name, :common_name, :score_percent, :plant, keyword_init: true)

  Outcome = Struct.new(:predictions, :error, keyword_init: true) do
    def success?
      error.nil?
    end
  end

  def initialize(project: DEFAULT_PROJECT, nb_results: DEFAULT_NB_RESULTS)
    @project = project
    @nb_results = nb_results
    @api_key = Rails.application.credentials.dig(:plantnet, :api_key)
  end

  # `image_io` — Tempfile yoki shunga o'xshash IO obyekti (masalan
  # ActionDispatch::Http::UploadedFile#tempfile). Har doim Outcome
  # qaytaradi — hech qachon istisno (exception) tashqariga chiqmaydi,
  # chaqiruvchi controller shunchaki `outcome.success?`ni tekshiradi.
  def identify(image_io)
    return Outcome.new(predictions: [], error: :missing_api_key) if @api_key.blank?

    response = perform_request(image_io)
    handle_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
    Outcome.new(predictions: [], error: :timeout)
  rescue StandardError => e
    Rails.logger.error("[PlantNetService] #{e.class}: #{e.message}")
    Outcome.new(predictions: [], error: :unknown)
  end

  private

  def perform_request(image_io)
    uri = URI("#{ENDPOINT}/#{@project}")
    uri.query = URI.encode_www_form(
      'api-key' => @api_key,
      'lang' => I18n.locale.to_s,
      'nb-results' => @nb_results
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    image_io.rewind if image_io.respond_to?(:rewind)

    request = Net::HTTP::Post.new(uri)
    # "auto" — PlantNet o'zi rasmda barg/gul/meva/po'stloqdan qaysi biri
    # ekanini aniqlaydi (foydalanuvchidan so'rash shart emas — 1-bosqichda
    # oddiyroq oqim uchun tanlandi).
    request.set_form(
      [
        ['organs', 'auto'],
        ['images', image_io, { filename: 'plant.jpg', content_type: 'image/jpeg' }]
      ],
      'multipart/form-data'
    )

    http.request(request)
  end

  def handle_response(response)
    case response
    when Net::HTTPSuccess
      Outcome.new(predictions: build_predictions(JSON.parse(response.body)), error: nil)
    when Net::HTTPTooManyRequests
      Outcome.new(predictions: [], error: :quota_exceeded)
    when Net::HTTPUnauthorized, Net::HTTPForbidden
      Outcome.new(predictions: [], error: :invalid_api_key)
    when Net::HTTPBadRequest, Net::HTTPNotFound, Net::HTTPUnprocessableEntity
      Outcome.new(predictions: [], error: :invalid_image)
    else
      Rails.logger.error("[PlantNetService] HTTP #{response.code}: #{response.body}")
      Outcome.new(predictions: [], error: :unknown)
    end
  end

  def build_predictions(body)
    Array(body['results']).filter_map do |result|
      species = result['species'] || {}
      scientific_name = species['scientificNameWithoutAuthor'].presence || species['scientificName']
      next if scientific_name.blank?

      Prediction.new(
        scientific_name: scientific_name,
        common_name: Array(species['commonNames']).first,
        score_percent: (result['score'].to_f * 100).round,
        plant: match_plant(scientific_name)
      )
    end
  end

  # Bazamizda muallif qismi bilan saqlanadi (masalan
  # "Tulipa affinis Botschantz."), PlantNet esa muallifsiz nom qaytaradi
  # (ya'ni "Tulipa affinis") — shuning uchun tenglik emas, "shu nom bilan
  # boshlanadi (keyin bo'shliq yoki qator oxiri)" qoidasi bilan
  # solishtiramiz. Plant#external_search_name'даgi naqshning aksi.
  def match_plant(scientific_name_without_author)
    Plant.where('species_sci ~* ?', "^#{Regexp.escape(scientific_name_without_author)}(\\s|$)").first
  end
end
