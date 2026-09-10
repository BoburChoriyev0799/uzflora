require 'spec_helper'
require 'rake'
require 'csv'

# `plants:import_qoraqalpoq` — qoraqalpoqcha nomlarni (db/qoraqalpoq_nomlari.csv)
# plants.species_kaa / species_kaa_source ustunlariga moslashtirib yozadi.
describe 'plants:import_qoraqalpoq rake task', type: :task do
  before(:all) do
    Rake.application = Rake::Application.new
    # 3-argument `rake_require`: bo'sh "loaded" ro'yxati — global `$"` ga
    # tegmaydi, shuning uchun boshqa rake-spec fayl ($" ni ifloslantirib)
    # bu task'ni yangi Rake::Application ga yuklashni to'sib qo'ymaydi.
    Rake.application.rake_require('tasks/import_qoraqalpoq', [ Rails.root.join('lib').to_s ], [])
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['plants:import_qoraqalpoq'] }
  after { task.reenable }

  let(:csv_path)       { Rails.root.join('tmp', "qq_test_#{SecureRandom.hex(4)}.csv") }
  let(:resolved_path)  { Rails.root.join('tmp', "qq_resolved_#{SecureRandom.hex(4)}.csv") }
  let(:report_path)    { Rails.root.join('tmp', "qq_report_#{SecureRandom.hex(4)}.csv") }
  let(:spelling_path)  { Rails.root.join('tmp', "qq_spelling_#{SecureRandom.hex(4)}.csv") }
  let(:cultivated_path) { Rails.root.join('tmp', "qq_cultivated_#{SecureRandom.hex(4)}.csv") }

  before do
    stub_const('QoraqalpoqImport::CSV_PATH', csv_path)
    stub_const('QoraqalpoqImport::RESOLVED_CSV_PATH', resolved_path)
    stub_const('QoraqalpoqImport::REPORT_PATH', report_path)
    # Sukut bo'yicha imlo/madaniy fayllarni ham izolyatsiya qilamiz
    # (aks holda test haqiqiy db/qoraqalpoq_*.csv fayllarini o'qir edi).
    stub_const('QoraqalpoqImport::SPELLING_CSV_PATH', spelling_path)
    stub_const('QoraqalpoqImport::CULTIVATED_CSV_PATH', cultivated_path)
  end
  after do
    [ csv_path, resolved_path, report_path, spelling_path, cultivated_path ].each { |p| File.delete(p) if File.exist?(p) }
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

  # --- NOANIQ qoidasi: infratur epiteti mos -> o'sha takson -----------
  context 'when one latin name matches several groups (NOANIQ tie-break rule)' do
    # Ikkala yozuv ham "Capparis spinosa" ga kanonik kalit bilan mos keladi
    # (canonical_key faqat turkum+epitet oladi) — 4-bosqich sinonim
    # ("Capparis herbacea" -> "Capparis spinosa") ikkalasini ham qaytaradi.
    let!(:species_rec) do
      Plant.create!(species_sci: 'Capparis spinosa L.', accepted_name: 'Capparis spinosa', primary_record: true)
    end
    let!(:variety_rec) do
      Plant.create!(species_sci: 'Capparis spinosa var. herbacea (Willd.) Fici', accepted_name: 'Capparis spinosa var. herbacea', primary_record: true)
    end

    it 'picks the infraspecific taxon whose epithet matches the old species epithet' do
      write_csv([ [ 'Capparis herbacea Willd.', 'геуил', 'Шербаев 1988' ] ])
      write_resolved([ [ 'Capparis herbacea Willd.', 'геуил', 'Шербаев 1988', 'Capparis spinosa', '4-bosqich' ] ])
      run_task(APPLY: true)
      expect(variety_rec.reload.species_kaa).to eq('геуил')
      expect(species_rec.reload.species_kaa).to be_nil
      expect(report_rows.first['qaysi_bosqich']).to include('noaniq-hal(Capparis spinosa var. herbacea)')
    end

    it 'falls back to the species-rank group when no infraspecific epithet matches' do
      write_csv([ [ 'Capparis ovata Desf.', 'геул', 'Ережепов 1978' ] ])
      write_resolved([ [ 'Capparis ovata Desf.', 'геул', 'Ережепов 1978', 'Capparis spinosa', '4-bosqich' ] ])
      run_task(APPLY: true)
      expect(species_rec.reload.species_kaa).to eq('геул')
      expect(variety_rec.reload.species_kaa).to be_nil
      expect(report_rows.first['qaysi_bosqich']).to include('noaniq-hal(Capparis spinosa)')
    end

    it 'still reports NOANIQ when the rule cannot single out one group' do
      # Ikkita TUR darajasidagi guruh — qoida hal qila olmaydi.
      p1 = Plant.create!(species_sci: 'Carex nigra (L.) Reichard', accepted_name: 'Carex nigra', primary_record: true)
      p2 = Plant.create!(species_sci: 'Carex nigra Bernh.', accepted_name: 'Carex melanostachya', primary_record: true)
      write_csv([ [ 'Carex nigra', 'қоңыр от', 'Ережепов 1978' ] ])
      run_task(APPLY: true)

      expect(p1.reload.species_kaa).to be_nil
      expect(p2.reload.species_kaa).to be_nil
      expect(report_rows.first['holat']).to eq('NOANIQ')
    end
  end

  # --- Imlo tuzatishlari (asl manba fayli o'zgarmaydi) --------------
  it 'applies a spelling correction before matching, and notes it in the audit' do
    plant = Plant.create!(species_sci: 'Potamogeton filiformis Pers.', accepted_name: 'Potamogeton filiformis', primary_record: true)
    write_csv([ [ 'Potamogeton filaformis Pers.', 'шаланг', 'Ережепов 1978' ] ])
    CSV.open(spelling_path, 'w') do |csv|
      csv << %w[fayldagi_nom tuzatilgan_nom izoh]
      csv << [ 'Potamogeton filaformis Pers.', 'Potamogeton filiformis Pers.', 'terish xatosi' ]
    end

    run_task(APPLY: true)
    expect(plant.reload.species_kaa).to eq('шаланг')
    expect(report_rows.first['izoh']).to include('imlo:')
  end

  # --- Madaniy (ekma) turlar — alohida holat -----------------------
  it 'classifies a cultivated species as MADANIY_TUR and never writes it, even on a fuzzy match' do
    wild = Plant.create!(species_sci: 'Daucus carota L.', accepted_name: 'Daucus carota', primary_record: true)
    write_csv([ [ 'Triticum aestivum L.', 'бийдай', 'Шербаев 1988' ],
                [ 'Daucus sativus (Hoffm.) Rochl.', 'гешир', 'Шербаев 1988' ] ])
    CSV.open(cultivated_path, 'w') do |csv|
      csv << %w[lotincha_nom qoraqalpoqcha_nom manba]
      csv << [ 'Triticum aestivum L.', 'бийдай', 'Шербаев 1988' ]
      csv << [ 'Daucus sativus (Hoffm.) Rochl.', 'гешир', 'Шербаев 1988' ]
    end

    run_task(APPLY: true)
    expect(wild.reload.species_kaa).to be_nil
    expect(report_rows.map { |r| r['holat'] }).to all(eq('MADANIY_TUR'))
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
