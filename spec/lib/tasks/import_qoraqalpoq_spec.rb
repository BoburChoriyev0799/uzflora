require 'spec_helper'
require 'rake'
require 'csv'

# `plants:import_qoraqalpoq` — qoraqalpoqcha nomlarni (db/qoraqalpoq_nomlari.csv)
# plants.species_kaa / species_kaa_source ustunlariga moslashtirib yozadi.
describe 'plants:import_qoraqalpoq rake task', type: :task do
  before(:all) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require('tasks/import_qoraqalpoq', [ Rails.root.join('lib').to_s ])
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['plants:import_qoraqalpoq'] }
  after { task.reenable }

  let(:csv_path)      { Rails.root.join('tmp', "qq_test_#{SecureRandom.hex(4)}.csv") }
  let(:resolved_path) { Rails.root.join('tmp', "qq_resolved_#{SecureRandom.hex(4)}.csv") }
  let(:report_path)   { Rails.root.join('tmp', "qq_report_#{SecureRandom.hex(4)}.csv") }

  before do
    stub_const('QoraqalpoqImport::CSV_PATH', csv_path)
    stub_const('QoraqalpoqImport::RESOLVED_CSV_PATH', resolved_path)
    stub_const('QoraqalpoqImport::REPORT_PATH', report_path)
  end
  after do
    [ csv_path, resolved_path, report_path ].each { |p| File.delete(p) if File.exist?(p) }
  end

  def write_csv(rows)
    CSV.open(csv_path, 'w') do |csv|
      csv << %w[lotincha_nom qoraqalpoqcha_nom manba]
      rows.each { |r| csv << r }
    end
  end

  def write_resolved(rows)
    CSV.open(resolved_path, 'w') do |csv|
      csv << QoraqalpoqImport::RESOLVED_HEADERS
      rows.each { |r| csv << r }
    end
  end

  def run_task(**env)
    env.each { |k, v| ENV[k.to_s] = v.to_s }
    task.reenable
    silence { task.invoke }
  ensure
    env.each_key { |k| ENV.delete(k.to_s) }
  end

  def silence
    original = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original
  end

  def report_rows
    CSV.read(report_path, headers: true)
  end

  # --- Guruhga qo'llash + eski nom orqali topish ----------------------
  context 'a plant merged into an accepted-name group (old genus name in CSV)' do
    let!(:accepted) do
      Plant.create!(species_sci: 'Bassia prostrata (L.) Beck', accepted_name: 'Bassia prostrata',
                    wcvp_matched_name: 'Bassia prostrata (L.) Beck', wcvp_status: 'Accepted', primary_record: true)
    end
    let!(:synonym) do
      Plant.create!(species_sci: 'Kochia prostrata (L.) Schrad.', accepted_name: 'Bassia prostrata',
                    wcvp_matched_name: 'Kochia prostrata (L.) Schrad.', wcvp_status: 'Synonym', primary_record: false)
    end

    before { write_csv([ [ 'Kochia prostrata', 'изен', 'Ережепов 1978' ] ]) }

    it 'DRY RUN writes nothing to the database' do
      run_task
      expect(accepted.reload.species_kaa).to be_nil
      expect(synonym.reload.species_kaa).to be_nil
    end

    it 'APPLY writes the Karakalpak name to EVERY member of the group, not just primary' do
      run_task(APPLY: true)
      expect(accepted.reload.species_kaa).to eq('изен')
      expect(synonym.reload.species_kaa).to eq('изен')
      expect(accepted.species_kaa_source).to eq('Ережепов 1978')
    end

    it 'is idempotent — a second APPLY run reports ALLAQACHON_BOR and changes nothing' do
      run_task(APPLY: true)
      expect { run_task(APPLY: true) }.not_to(change { synonym.reload.updated_at })
      expect(report_rows.first['holat']).to eq('ALLAQACHON_BOR')
    end

    it 'writes the value verbatim (cyrillic, lowercase, unchanged)' do
      write_csv([ [ 'Kochia prostrata', 'ажрык, ажырык', 'Ережепов 1978 + Шербаев 1988' ] ])
      run_task(APPLY: true)
      expect(accepted.reload.species_kaa).to eq('ажрык, ажырык')
      expect(accepted.species_kaa_source).to eq('Ережепов 1978 + Шербаев 1988')
    end
  end

  # --- Kanonik kalit (imlo varianti) --------------------------------
  it 'matches through a spelling variant (litoralis vs littoralis)' do
    plant = Plant.create!(species_sci: 'Aeluropus littoralis (Gouan) Parl.', accepted_name: 'Aeluropus littoralis', primary_record: true)
    write_csv([ [ 'Aeluropus litoralis', 'ащы оты', 'Шербаев 1988' ] ])
    run_task(APPLY: true)
    expect(plant.reload.species_kaa).to eq('ащы оты')
  end

  # --- Bazadagi sinonim (wcvp_matched_name) — 3-bosqich -------------
  it 'matches via a database synonym (wcvp_matched_name) when species_sci/accepted_name do not match' do
    plant = Plant.create!(species_sci: 'Salsola lanata Pall.', accepted_name: 'Salsola lanata',
                          wcvp_matched_name: 'Climacoptera lanata (Pall.) Botsch.', wcvp_status: 'Synonym', primary_record: true)
    write_csv([ [ 'Climacoptera lanata', 'көк өлең', 'Ережепов 1978' ] ])
    run_task(APPLY: true)
    expect(plant.reload.species_kaa).to eq('көк өлең')
    expect(report_rows.first['qaysi_bosqich']).to start_with('3-')
  end

  # --- 4-bosqich OFFLINE: db/qoraqalpoq_nomlari_hal_qilingan.csv -----
  # PRODUCTIONDA (Render) WCVP fayli yo'q — sinonim -> zamonaviy nom
  # OLDINDAN hisoblanib, commit qilingan fayldan o'qiladi (POWO=true
  # ham, WCVP fayli ham kerak emas).
  it 'matches via the committed resolved-synonyms CSV without POWO / WCVP' do
    modern = Plant.create!(species_sci: 'Bromus tectorum L.', accepted_name: 'Bromus tectorum', primary_record: true)
    write_csv([ [ 'Anisantha tectorum Nevski', 'жалтырбас', 'Ережепов 1978' ] ])
    write_resolved([ [ 'Anisantha tectorum Nevski', 'жалтырбас', 'Ережепов 1978', 'Bromus tectorum', '4-bosqich' ] ])

    run_task(APPLY: true)

    expect(modern.reload.species_kaa).to eq('жалтырбас')
    expect(report_rows.first['qaysi_bosqich']).to start_with('4-')
  end

  # --- Noaniq moslik: ikkita turga mos kelsa — YOZILMAYDI -----------
  it 'does not write when one latin name matches two different accepted-name groups (NOANIQ)' do
    p1 = Plant.create!(species_sci: 'Carex nigra (L.) Reichard', accepted_name: 'Carex nigra', primary_record: true)
    p2 = Plant.create!(species_sci: 'Carex nigra Bernh.', accepted_name: 'Carex melanostachya', primary_record: true)
    write_csv([ [ 'Carex nigra', 'қоңыр от', 'Ережепов 1978' ] ])
    run_task(APPLY: true)

    expect(p1.reload.species_kaa).to be_nil
    expect(p2.reload.species_kaa).to be_nil
    expect(report_rows.first['holat']).to eq('NOANIQ')
  end

  # --- Ziddiyat: mavjud qiymat ustiga yozilmaydi -------------------
  it 'does not overwrite an existing different species_kaa (ZIDDIYAT)' do
    plant = Plant.create!(species_sci: 'Peganum harmala L.', accepted_name: 'Peganum harmala',
                          species_kaa: 'адыраспан', primary_record: true)
    write_csv([ [ 'Peganum harmala', 'бошқа ном', 'Ережепов 1978' ] ])
    run_task(APPLY: true)

    expect(plant.reload.species_kaa).to eq('адыраспан')
    expect(report_rows.first['holat']).to eq('ZIDDIYAT')
  end

  # --- Topilmadi --------------------------------------------------
  it 'reports TOPILMADI for a name that is nowhere in the database' do
    write_csv([ [ 'Nonexistentia inventata', 'йўқ ўсимлик', 'Ережепов 1978' ] ])
    run_task(APPLY: true)
    expect(report_rows.first['holat']).to eq('TOPILMADI')
  end

  # --- Yakuniy konsol hisoboti ----------------------------------
  it 'prints a per-status summary to the console' do
    Plant.create!(species_sci: 'Alhagi pseudalhagi (M.Bieb.) Fisch.', accepted_name: 'Alhagi maurorum', primary_record: true)
    write_csv([ [ 'Alhagi pseudalhagi', 'жантақ', 'Ережепов 1978' ] ])

    ENV['APPLY'] = 'true'
    expect { task.invoke }.to output(/QO'SHILDI: 1/).to_stdout
  ensure
    ENV.delete('APPLY')
  end
end
