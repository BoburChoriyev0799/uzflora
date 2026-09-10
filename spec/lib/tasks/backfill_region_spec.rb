require 'spec_helper'
require 'rake'

# 2c-ish: koordinatadan viloyatni avtomatik to`ldirish (backfill).
describe 'plant_sightings:backfill_region rake task', type: :task do
  before(:all) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require('tasks/backfill_region', [ Rails.root.join('lib').to_s ], [])
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['plant_sightings:backfill_region'] }
  after { task.reenable }

  let(:user) { FactoryBot.create(:user) }

  def sighting(attrs = {})
    s = PlantSighting.new({ user: user, timestamp: Time.zone.now, photo_status: 'ready' }.merge(attrs))
    s.save!(validate: false)
    s
  end

  def run_task(**env)
    env.each { |k, v| ENV[k.to_s] = v.to_s }
    task.reenable
    o = $stdout
    $stdout = StringIO.new
    task.invoke
  ensure
    $stdout = o
    env.each_key { |k| ENV.delete(k.to_s) }
  end

  # Toshkent (41.31, 69.28) -> toshkent_shahri
  it 'APPLY: koordinatadan viloyatni qo`yadi, region_source = "auto"' do
    s = sighting(latitude: 41.311, longitude: 69.279)
    run_task(APPLY: true)
    expect(s.reload.region).to eq('toshkent_shahri')
    expect(s.region_source).to eq('auto')
  end

  it 'DRY RUN hech narsa o`zgartirmaydi' do
    s = sighting(latitude: 41.311, longitude: 69.279)
    run_task
    expect(s.reload.region).to be_nil
  end

  it 'foydalanuvchi tanlagan viloyat (region_source="user") ustiga YOZMAYDI' do
    s = sighting(latitude: 41.311, longitude: 69.279, region: 'namangan', region_source: 'user')
    run_task(APPLY: true)
    expect(s.reload.region).to eq('namangan')
    expect(s.region_source).to eq('user')
  end

  it 'O`zbekistondan tashqaridagi nuqtani nil qoldiradi' do
    s = sighting(latitude: 43.238, longitude: 76.945) # Almati
    run_task(APPLY: true)
    expect(s.reload.region).to be_nil
    expect(s.region_source).to be_nil
  end

  it 'idempotent — ikkinchi APPLY o`zgartirmaydi' do
    s = sighting(latitude: 39.654, longitude: 66.960)
    run_task(APPLY: true)
    expect { run_task(APPLY: true) }.not_to(change { s.reload.updated_at })
  end
end
