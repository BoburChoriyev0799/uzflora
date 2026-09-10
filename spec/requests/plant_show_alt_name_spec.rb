require 'spec_helper'

# Tur sahifasidagi eski ilmiy nom qatori: neytral "Bazadagi nom:" holati
# (wcvp_status bo'sh / "Accepted") OLIB TASHLANGAN. "Sinonimi:" /
# "Bazadagi imlo:" / "Rad etilgan nom:" QOLADI.
describe 'Species page — old scientific name row', type: :request do
  let(:viewer) { FactoryBot.create(:user) }
  before { sign_in viewer }

  it 'does NOT show a neutral "database name" row when wcvp_status is Accepted' do
    plant = Plant.create!(species_sci: 'Peganum harmalum L.', # ataylab imlo farqi
                          accepted_name: 'Peganum harmala', accepted_authors: 'L.',
                          wcvp_status: 'Accepted', primary_record: true)
    get plant_path(plant)

    expect(response.body).not_to include('Bazadagi nom:')
    expect(response.body).not_to include('Peganum harmalum')
  end

  it 'still shows the "Sinonimi:" row when wcvp_status is Synonym' do
    plant = Plant.create!(species_sci: 'Merendera robusta Bunge',
                          accepted_name: 'Colchicum robustum', accepted_authors: '(Bunge) Stef.',
                          wcvp_status: 'Synonym', primary_record: true)
    get plant_path(plant)

    expect(response.body).to include('Sinonimi:')
    expect(response.body).to include('Merendera robusta')
  end
end
