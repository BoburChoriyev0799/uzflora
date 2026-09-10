require 'spec_helper'
require 'rake'
require 'csv'

# 4-ish: bazada yo'q turlarni POWO tarqalish (UZB) bo'yicha tekshirish.
describe 'plants:check_missing_species_distribution rake task', type: :task do
  before(:all) do
    Rake.application = Rake::Application.new
    lib = [ Rails.root.join('lib').to_s ]
    Rake.application.rake_require('tasks/qoraqalpoq_powo_api', lib, [])
    Rake.application.rake_require('tasks/check_missing_species_distribution', lib, [])
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['plants:check_missing_species_distribution'] }
  after { task.reenable }

  let(:src_path) { Rails.root.join('tmp', "byq_src_#{SecureRandom.hex(4)}.csv") }
  let(:out_path) { Rails.root.join('tmp', "byq_out_#{SecureRandom.hex(4)}.csv") }

  before do
    stub_const('CheckMissingDistribution::SOURCE_PATH', src_path)
    stub_const('CheckMissingDistribution::OUT_PATH', out_path)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DELAY').and_return('0')
    CSV.open(src_path, 'w') do |csv|
      csv << QoraqalpoqPowoApi::BAZADA_YOQ_HEADERS
      csv << [ 'Typha grossheimii Pobed.', 'Typha grossheimii', 'urn:1', nil, 'POWO: qabul qilingan nom' ]
      csv << [ 'Stipa korshinskyi Roshev.', 'Stipa korshinskyi', 'urn:2', nil, 'POWO: qabul qilingan nom' ]
      csv << [ 'Alhagi sparsifolia Shap.', nil, nil, nil, "POWO'da topilmadi" ] # yechilmagan — o'tkaziladi
    end
  end
  after { [ src_path, out_path ].each { |p| File.delete(p) if File.exist?(p) } }

  def run_task
    o = $stdout
    $stdout = StringIO.new
    task.reenable
    task.invoke
  ensure
    $stdout = o
  end

  it 'UZB tarqalishiga qarab HA/YO`Q yozadi, yechilmagan qatorni o`tkazadi' do
    allow(QoraqalpoqPowoApi).to receive(:http_get_json) do |url|
      if url.include?('urn:1')
        [ :ok, { 'distributions' => [
          { 'name' => 'Uzbekistan', 'tdwgCode' => 'UZB', 'tdwgLevel' => 3, 'establishment' => 'Native' },
          { 'name' => 'Afghanistan', 'tdwgCode' => 'AFG', 'tdwgLevel' => 3, 'establishment' => 'Native' }
        ] } ]
      else
        [ :ok, { 'distributions' => [
          { 'name' => 'Kazakhstan', 'tdwgCode' => 'KAZ', 'tdwgLevel' => 3, 'establishment' => 'Native' }
        ] } ]
      end
    end

    run_task
    rows = CSV.read(out_path, headers: true)
    expect(rows.size).to eq(2) # yechilmagan qator yo'q
    typha = rows.find { |r| r['powo_qabul_qilgan_nom'] == 'Typha grossheimii' }
    stipa = rows.find { |r| r['powo_qabul_qilgan_nom'] == 'Stipa korshinskyi' }
    expect(typha['ozbekistonda_bormi']).to eq('HA')
    expect(typha['tdwg_kodlari']).to eq('AFG UZB')
    expect(stipa['ozbekistonda_bormi']).to eq("YO'Q")
  end

  it 'API xato bo`lsa NOMA`LUM (taxmin qilmaydi)' do
    allow(QoraqalpoqPowoApi).to receive(:http_get_json).and_return([ :error, 'HTTP 403' ])
    run_task
    rows = CSV.read(out_path, headers: true)
    expect(rows.map { |r| r['ozbekistonda_bormi'] }.uniq).to eq([ "NOMA'LUM" ])
  end

  it 'hech qanday Plant yozuvi yaratmaydi' do
    allow(QoraqalpoqPowoApi).to receive(:http_get_json).and_return([ :ok, { 'distributions' => [] } ])
    expect { run_task }.not_to(change { Plant.count })
  end
end
