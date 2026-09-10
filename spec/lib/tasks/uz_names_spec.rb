require 'spec_helper'
require 'rake'
require 'csv'

# 3-ish: species_uz to'ldirish vositasi (export + import).
describe 'plants uz-names tools', type: :task do
  before(:all) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require('tasks/uz_names', [ Rails.root.join('lib').to_s ], [])
    Rake::Task.define_task(:environment)
  end

  let(:export_task) { Rake::Task['plants:export_missing_uz_names'] }
  let(:import_task) { Rake::Task['plants:import_uz_names'] }
  after { [ export_task, import_task ].each(&:reenable) }

  let(:csv_path) { Rails.root.join('tmp', "uz_names_test_#{SecureRandom.hex(4)}.csv") }
  before { stub_const('UzNamesTool::EXPORT_PATH', csv_path) }
  after { File.delete(csv_path) if File.exist?(csv_path) }

  let(:user) { FactoryBot.create(:user) }

  def silence
    o = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = o
  end

  def run(task, **env)
    env.each { |k, v| ENV[k.to_s] = v.to_s }
    task.reenable
    silence { task.invoke }
  ensure
    env.each_key { |k| ENV.delete(k.to_s) }
  end

  def write_csv(rows)
    CSV.open(csv_path, 'w') do |csv|
      csv << UzNamesTool::EXPORT_HEADERS
      rows.each { |r| csv << r }
    end
  end

  describe 'export' do
    it 'faqat species_uz bo`sh turlarni, foydalilik tartibida chiqaradi' do
      with_name = Plant.create!(species_sci: 'Named plantus L.', species_uz: 'nomli', primary_record: true)
      no_name_rare = Plant.create!(species_sci: 'Aaa rareus L.', primary_record: true)
      no_name_common = Plant.create!(species_sci: 'Zzz communis L.', primary_record: true)
      PlantSighting.new(user: user, plant: no_name_common, status: 'approved', published: true,
                        timestamp: Time.zone.now, latitude: 41, longitude: 69, photo_status: 'ready').save!(validate: false)

      run(export_task)
      rows = CSV.read(csv_path, headers: true)
      ids = rows['id'].map(&:to_i)
      expect(ids).not_to include(with_name.id)
      # kuzatuvi bor tur (Zzz) alifbo bo'yicha keyin bo'lsa ham TEPADA
      expect(ids.first).to eq(no_name_common.id)
      expect(ids).to include(no_name_rare.id)
    end
  end

  describe 'import' do
    let!(:primary) do
      Plant.create!(species_sci: 'Tulipa importa Regel', accepted_name: 'Tulipa importa', primary_record: true)
    end
    let!(:group_member) do
      Plant.create!(species_sci: 'Tulipa synonyma Bunge', accepted_name: 'Tulipa importa',
                    wcvp_status: 'Synonym', primary_record: false)
    end

    it 'id bo`yicha moslashadi va guruhning BARCHA a`zolariga yozadi' do
      write_csv([ [ primary.id, primary.species_sci, primary.accepted_name, '', '', '', '', 0, 'oq lola' ] ])
      run(import_task, APPLY: true)
      expect(primary.reload.species_uz).to eq('oq lola')
      expect(group_member.reload.species_uz).to eq('oq lola')
    end

    it 'species_uz bo`sh qatorni jim o`tkazadi (xato emas)' do
      write_csv([ [ primary.id, primary.species_sci, nil, '', '', '', '', 0, '' ] ])
      expect { run(import_task, APPLY: true) }.not_to raise_error
      expect(primary.reload.species_uz).to be_nil
    end

    it 'mavjud species_uz ustiga YOZMAYDI (ZIDDIYAT)' do
      primary.update_column(:species_uz, 'eski nom')
      write_csv([ [ primary.id, primary.species_sci, nil, '', '', '', '', 0, 'yangi nom' ] ])
      run(import_task, APPLY: true)
      expect(primary.reload.species_uz).to eq('eski nom')
    end

    it 'DRY RUN hech narsa o`zgartirmaydi' do
      write_csv([ [ primary.id, primary.species_sci, nil, '', '', '', '', 0, 'oq lola' ] ])
      run(import_task)
      expect(primary.reload.species_uz).to be_nil
    end

    it 'idempotent — ikkinchi APPLY o`zgartirmaydi' do
      write_csv([ [ primary.id, primary.species_sci, nil, '', '', '', '', 0, 'oq lola' ] ])
      run(import_task, APPLY: true)
      expect { run(import_task, APPLY: true) }.not_to(change { primary.reload.updated_at })
    end
  end
end
