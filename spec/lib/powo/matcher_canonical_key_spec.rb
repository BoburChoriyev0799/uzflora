require 'spec_helper'
require Rails.root.join('lib', 'powo', 'matcher')

# Qoraqalpoqcha nomlar importi (`plants:import_qoraqalpoq`) shu MAVJUD
# kanonik kalitga tayanadi — imlo variantlari (litoralis/littoralis,
# borsczowii/borszczowii) bitta kalitga tushishi shart, aks holda ~40 ta
# tur topilmay qoladi.
describe Powo::Matcher, '.canonical_key' do
  it 'maps a doubled-letter spelling variant to the same key' do
    expect(described_class.canonical_key('Aeluropus litoralis'))
      .to eq(described_class.canonical_key('Aeluropus littoralis'))
  end

  it 'maps cz / szcz spelling variants to the same key' do
    expect(described_class.canonical_key('Acanthophyllum borsczowii'))
      .to eq(described_class.canonical_key('Acanthophyllum borszczowii'))
  end

  it 'drops the author and keeps genus + epithet only' do
    expect(described_class.canonical_key('Tulipa korolkovii Regel'))
      .to eq(described_class.canonical_key('Tulipa korolkovii'))
  end

  # Dastlabki matcher'da "suffiksni barqaror bo'lguncha kesish" xatosi bor
  # edi (caligonum -> calig). Suffiks FAQAT BIR MARTA kesilishi kerak.
  it 'cuts the trailing suffix only once (caligonum -> caligon, not calig)' do
    expect(described_class.canonical_key('Calligonum densum')).to eq('caligon dens')
  end
end
