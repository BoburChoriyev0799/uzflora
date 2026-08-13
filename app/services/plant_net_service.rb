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
    log_key_status

    return Outcome.new(predictions: [], error: :missing_api_key) if @api_key.blank?

    response = perform_request(image_io)
    handle_response(response)
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
    Rails.logger.error(
      "[PlantNetService] timeout: #{e.class} - #{e.message} " \
      "(open_timeout=#{OPEN_TIMEOUT}s, read_timeout=#{READ_TIMEOUT}s)"
    )
    Outcome.new(predictions: [], error: :timeout)
  rescue StandardError => e
    Rails.logger.error("[PlantNetService] exception: #{e.class} - #{e.message}")
    Outcome.new(predictions: [], error: :unknown)
  end

  private

  # DIQQAT: kalitning O'ZI hech qachon log qilinmaydi — faqat mavjudligi,
  # uzunligi va oxirgi 4 belgisi (production'da credentials to'g'ri
  # o'qilayotganini tekshirish uchun yetarli, lekin kalitni oshkor
  # qilmaydi).
  def log_key_status
    if @api_key.blank?
      Rails.logger.error(
        '[PlantNetService] api_key MISSING (Rails.application.credentials.dig(:plantnet, :api_key) bo\'sh) — ' \
        'RAILS_MASTER_KEY yoki credentials.yml.enc shu muhitda tekshirilsin'
      )
    else
      Rails.logger.info("[PlantNetService] api_key present: length=#{@api_key.length}, last4=#{@api_key[-4..]}")
    end
  end

  def perform_request(image_io)
    uri = URI("#{ENDPOINT}/#{@project}")
    uri.query = URI.encode_www_form(
      'api-key' => @api_key,
      'lang' => I18n.locale.to_s,
      'nb-results' => @nb_results
    )

    # DIQQAT: log qatorida `uri` (api-key'ni o'z ichiga oladi) EMAS,
    # faqat kalitsiz komponentlar ishlatiladi.
    image_size_kb = image_io.respond_to?(:size) ? (image_io.size / 1024.0).round(1) : 'unknown'
    Rails.logger.info(
      "[PlantNetService] request: endpoint=#{ENDPOINT}/#{@project}, project=#{@project}, " \
      "organs=auto, lang=#{I18n.locale}, nb_results=#{@nb_results}, image_size=#{image_size_kb}KB, " \
      "open_timeout=#{OPEN_TIMEOUT}s, read_timeout=#{READ_TIMEOUT}s"
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
    # Barcha holatlarda (200 ham, 401/403/429/400 ham) log qilinadi —
    # aynan xato javoblar (masalan noto'g'ri kalit yoki limit tugashi)
    # ilgari LOG QILINMAGANDI, shuning uchun sabab ko'rinmasdi.
    body_preview = response.body.to_s[0, 500]
    Rails.logger.info("[PlantNetService] response: HTTP #{response.code}, body_preview=#{body_preview.inspect}")

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
      Outcome.new(predictions: [], error: :unknown)
    end
  end

  def build_predictions(body)
    results = Array(body['results'])
    Rails.logger.info("[PlantNetService] results count=#{results.size}")

    results.filter_map do |result|
      species = result['species'] || {}
      scientific_name = species['scientificNameWithoutAuthor'].presence || species['scientificName']
      next if scientific_name.blank?

      score_percent = (result['score'].to_f * 100).round
      plant = match_plant(scientific_name)
      Rails.logger.info(
        "[PlantNetService] returned: #{scientific_name} (score #{score_percent}) → " \
        "#{plant ? "bazada topildi (id=#{plant.id})" : 'bazada topilmadi'}"
      )

      Prediction.new(
        scientific_name: scientific_name,
        common_name: Array(species['commonNames']).first,
        score_percent: score_percent,
        plant: plant
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
