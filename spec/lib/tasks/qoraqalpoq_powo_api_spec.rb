require 'spec_helper'
require 'rake'
require 'csv'

# `plants:qoraqalpoq_powo_api` — TOPILMADI qolgan nomlarni POWO jonli REST
# API orqali tekshiradi. HTTP chaqiruvlari stub qilingan.
describe 'plants:qoraqalpoq_powo_api rake task', type: :task do
  before(:all) do
    Rake.application = Rake::Application.new
    lib = [ Rails.root.join('lib').to_s ]
    # 3-argument `rake_require` (bo'sh "loaded") — $" ni ifloslantirmaydi,
    # import_qoraqalpoq_spec bilan to'qnashmaydi.
    Rake.application.rake_require('tasks/import_qoraqalpoq', lib, [])
    Rake.application.rake_require('tasks/qoraqalpoq_powo_api', lib, [])
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['plants:qoraqalpoq_powo_api'] }
  after { task.reenable }

  let(:out_path) { Rails.root.join('tmp', "qq_bazada_yoq_#{SecureRandom.hex(4)}.csv") }

  before do
    stub_const('QoraqalpoqPowoApi::BAZADA_YOQ_PATH', out_path)
    # Nom ro'yxatini to'g'ridan-to'g'ri beramiz (audit fayliga tayanmasdan).
    CSV.open(out_path, 'w') do |csv|
      csv << QoraqalpoqPowoApi::BAZADA_YOQ_HEADERS
      csv << [ 'Ceratoides fruticulosa Pazij', nil, nil, 'tekshirilmagan' ]
      csv << [ 'Psammogeton setifolium (Boiss.) Boiss.', nil, nil, 'tekshirilmagan' ]
      csv << [ 'Nonexistentia inventata', nil, nil, 'tekshirilmagan' ]
    end
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DELAY').and_return('0')
  end
  after { File.delete(out_path) if File.exist?(out_path) }

  def run_task
    original = $stdout
    $stdout = StringIO.new
    task.reenable
    task.invoke
  ensure
    $stdout = original
  end

  def result_for(name)
    CSV.read(out_path, headers: true).find { |r| r['eski_nom'] == name }
  end

  it 'records the POWO accepted name and id for a synonym, and flags a genus-jump fuzzy hit' do
    allow(QoraqalpoqPowoApi).to receive(:http_get_json) do |url|
      case url
      when /search\?.*Ceratoides/
        [ :ok, { 'results' => [ { 'name' => 'Ceratoides fruticulosa', 'accepted' => false,
                                  'fqId' => 'urn:lsid:ipni.org:names:1-1' } ] } ]
      when %r{taxon/urn:lsid:ipni.org:names:1-1}
        [ :ok, { 'accepted' => { 'name' => 'Krascheninnikovia fruticulosa', 'fqId' => 'urn:lsid:ipni.org:names:2-2' } } ]
      when /search\?.*Psammogeton/
        # POWO fuzzy qidiruvi boshqa turkumdagi turni birinchi qaytaradi.
        [ :ok, { 'results' => [ { 'name' => 'Cuminum cyminum', 'accepted' => true,
                                  'fqId' => 'urn:lsid:ipni.org:names:9-9' } ] } ]
      else
        [ :ok, { 'results' => [] } ]
      end
    end

    run_task

    cer = result_for('Ceratoides fruticulosa Pazij')
    expect(cer['powo_qabul_qilgan_nom']).to eq('Krascheninnikovia fruticulosa')
    expect(cer['powo_id']).to eq('urn:lsid:ipni.org:names:2-2')
    expect(cer['holat']).to eq('POWO: sinonim')

    psa = result_for('Psammogeton setifolium (Boiss.) Boiss.')
    expect(psa['powo_qabul_qilgan_nom']).to eq('Cuminum cyminum')
    expect(psa['holat']).to include('epitet mos emas')

    expect(result_for('Nonexistentia inventata')['holat']).to eq("POWO'da topilmadi")
  end

  it 'appends a confirmed in-database hit to the resolved-synonyms CSV' do
    resolved_path = Rails.root.join('tmp', "qq_resolved_#{SecureRandom.hex(4)}.csv")
    stub_const('QoraqalpoqImport::RESOLVED_CSV_PATH', resolved_path)
    CSV.open(resolved_path, 'w') do |csv|
      csv << QoraqalpoqImport::RESOLVED_HEADERS
      csv << [ 'Ceratoides fruticulosa Pazij', 'терескен', 'Ережепов 1978', nil, nil ]
    end
    Plant.create!(species_sci: 'Krascheninnikovia ceratoides (L.) Gueldenst.',
                  accepted_name: 'Krascheninnikovia fruticulosa', primary_record: true)

    allow(QoraqalpoqPowoApi).to receive(:http_get_json) do |url|
      if url =~ /search/
        [ :ok, { 'results' => [ { 'name' => 'Ceratoides fruticulosa', 'accepted' => false,
                                  'fqId' => 'urn:lsid:ipni.org:names:1-1' } ] } ]
      else
        [ :ok, { 'accepted' => { 'name' => 'Krascheninnikovia fruticulosa', 'fqId' => 'urn:lsid:ipni.org:names:2-2' } } ]
      end
    end

    run_task

    resolved = CSV.read(resolved_path, headers: true).find { |r| r['lotincha_nom'] == 'Ceratoides fruticulosa Pazij' }
    expect(resolved['hal_qilingan_nom']).to eq('Krascheninnikovia fruticulosa')
    expect(resolved['qaysi_bosqich']).to eq('4-bosqich (POWO API)')
  ensure
    File.delete(resolved_path) if resolved_path && File.exist?(resolved_path)
  end
end
