require 'spec_helper'

# 2-ISH: /plants oxirgi qatoridagi bo'sh katak.
# TASDIQLANGAN SABAB: (a) matematika — 24 yozuv 5 ustunga butun
# bo'linmasdi. Kontroller 24 ta qaytaradi, view AYNAN 24 ta kartochka
# render qiladi (biror yozuv tushib qolmaydi — (b) EMAS). Yechim:
# ustunlar soni 24 ga butun bo'linadigan qiymatlar (3, 4, 6).
describe 'Plants index grid', type: :request do
  let(:user) { FactoryBot.create(:user) }

  before do
    30.times { |i| Plant.create!(species_sci: "Gridtest species#{i} L.", primary_record: true) }
    sign_in user
  end

  it 'renders exactly PLANTS_PER_PAGE cards — none dropped by the view' do
    get plants_path
    expect(response).to have_http_status(:ok)
    wrappers = response.body.scan(/<div class="col-sm-6 col-md-3 plants-grid-col">/).size
    expect(wrappers).to eq(PlantsController::PLANTS_PER_PAGE)
  end

  it 'uses only column counts that divide PLANTS_PER_PAGE evenly (no 5-column step)' do
    get plants_path
    body = response.body
    # Inline <style> ustun qoidalari
    counts = body.scan(/grid-template-columns:\s*repeat\((\d+),/).flatten.map(&:to_i).uniq
    expect(counts).not_to be_empty
    expect(counts).to all(satisfy { |n| (PlantsController::PLANTS_PER_PAGE % n).zero? })
    expect(counts).not_to include(5)
  end
end
