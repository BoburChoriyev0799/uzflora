require 'spec_helper'

# Tur sahifasida QORAQALPOQCHA nomi qatori (ruscha nomdan keyin), manba
# qavs ichida kichik kulrang shriftda.
describe 'Species page — Karakalpak name row', type: :request do
  let(:viewer) { FactoryBot.create(:user) }
  before { sign_in viewer }

  context 'when species_kaa is present' do
    let!(:plant) do
      Plant.create!(species_sci: 'Peganum harmala L.', species_uz: 'isiriq', species_ru: 'гармала',
                    species_kaa: 'адыраспан', species_kaa_source: 'Ережепов 1978 + Шербаев 1988',
                    primary_record: true)
    end

    it 'shows the label, the name and the formatted source in parentheses' do
      get plant_path(plant)
      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include('Qoraqalpoqcha nomi:')
      expect(body).to include('Адыраспан')
      expect(body).to include('plant-kaa-source')
      expect(body).to include('(Ережепов, 1978; Шербаев, 1988)')
    end
  end

  context 'when species_kaa is blank' do
    let!(:plant) { Plant.create!(species_sci: 'Bassia prostrata (L.) Beck', species_ru: 'прутняк', primary_record: true) }

    it 'does not render an empty Karakalpak row' do
      get plant_path(plant)
      expect(response.body).not_to include('Qoraqalpoqcha nomi:')
    end
  end
end
