# frozen_string_literal: true
module PlantsHelper
  # Botanik taksonomiya zanjiri, yuqoridan pastga: bo'lim -> sinf ->
  # tartib -> oila -> turkum -> tur. Har biri [label_key, qiymat_metodi].
  # Faqat lotincha (ilmiy) nom ko'rsatiladi — bazadagi *_ru ustunlari
  # (qavs ichidagi ruscha tarjima, masalan "Однодольные") uch tilda ham
  # keraksiz hisoblanib chiqarib tashlangan. Oila/turkum/tur POWO
  # moslashtirilgan bo'lsa accepted_* qiymatlardan olinadi (Plant#display_
  # family_lat/display_genus_lat/display_sci_name), bo'lmasa eskisidan —
  # bo'lim/sinf/tartib uchun POWO ustuni yo'q, o'zgarishsiz qoladi.
  PLANT_TAXONOMY_LEVELS = [
    [:division, :division_lat],
    [:class_name, :class_lat],
    [:order, :order_lat],
    [:family, :display_family_lat],
    [:genus, :display_genus_lat],
    [:species, :display_sci_name]
  ].freeze

  # plants/show'даgi taksonomiya jadvali uchun qatorlar: [label_key, lat]
  # — lotincha nomi bo'sh bo'lgan daraja butunlay chiqarib tashlanadi.
  def plant_taxonomy_rows(plant)
    PLANT_TAXONOMY_LEVELS.filter_map do |label_key, method_name|
      lat = plant.public_send(method_name)
      [label_key, lat] if lat.present?
    end
  end

  # plants/show'даgi "uch nom" bloki uchun qatorlar: [label_key, value].
  # Til bo'yicha tartib va yorliqlar farq qiladi (uz/ru/en), lekin har
  # birida bo'sh qiymatli qator chiqarib tashlanadi. species_en ustuni
  # bazada yo'q — "Common name:" shu sabab hozircha doim yashiringan.
  def plant_name_rows(plant, locale)
    sci_name = plant.display_sci_name
    rows = case locale.to_sym
           when :ru
             [
               [:name_ru, plant.species_ru],
               [:name_lat, sci_name],
               [:name_local, plant.species_uz]
             ]
           when :en
             [
               [:name_lat, sci_name],
               [:name_ru, plant.species_ru],
               [:name_local, plant.species_uz]
             ]
           else
             [
               [:name_uz, plant.species_uz],
               [:name_lat, sci_name],
               [:name_ru, plant.species_ru]
             ]
           end
    rows.select { |_, value| value.present? }
  end

  # plants#index kartochkasi uchun ko'rsatish ma'lumotini tayyorlaydi
  # (sci nom, lokalizatsiya nomi, sinonim qatori) — `group_info`
  # (`PlantsController#index`da `@group_display_info[plant.id]` sifatida
  # BITTA so'rov bilan oldindan hisoblab qo'yilgan: `{ sci_name:, members: }`
  # — `members` ODDIY birlashtirish holida [o'zi + haqiqatan yashiringan
  # a'zolar], ISTISNO holida (`db/duplikat_istisnolar.csv`) esa [o'zi]
  # xolos, `sci_name` esa mos ravishda `display_sci_name` yoki xom
  # `species_sci`) — bu yerda qo'shimcha so'rov YUBORILMAYDI, na
  # branching mantig'i takrorlanadi.
  #
  # Qizil kitob nishoni ATAYLAB `group_red_book` ustunidan (butun
  # accepted_name guruhi bo'yicha oldindan hisoblangan) olinadi, `members`
  # ro'yxatidan EMAS — ISTISNO holida ham (masalan Malus domestica)
  # guruhning boshqa a'zosi Qizil kitobda bo'lsa shu nishon ko'rinadi;
  # bu ataylab shunday (filtr ham xuddi shu ustun bo'yicha ishlaydi,
  # ikkalasi mos kelishi kerak).
  def plant_card_group_info(plant, group_info, locale)
    field = locale.to_sym == :ru ? :species_ru : :species_uz
    members = group_info[:members]
    sci_name = group_info[:sci_name]
    names = members.map { |m| m.public_send(field) }.filter_map(&:presence).uniq

    {
      sci_name: sci_name,
      localized_name: (names.any? ? names.join(', ') : sci_name),
      synonyms_text: (members.size > 1 ? "= #{members.map(&:species_sci).join(', ')}" : nil),
      red_book: plant.group_red_book?
    }
  end

  # plants/show'даgi primary BO'LMAGAN yozuv sahifasi tepasidagi eslatma —
  # "POWO bo'yicha bu tur — <qabul qilingan nom>. <asosiy sahifaga havola>".
  # Alohida metodga chiqarilgan ikkita sabab: (1) ko'p qatorli `t(...)`
  # chaqiruvini to'g'ridan-to'g'ri HAML'ga yozish qator davomiyligi
  # (indent) qoidalariga tez-tez qoqilib `ActionView::Template::Error`
  # beradi; (2) `_html` qo'shimchali kalit (avtomatik html_safe) FAQAT
  # `t`/`translate` VIEW HELPERI orqali ishlaydi — xom `I18n.t` chaqirilsa
  # natija HTML sifatida ESKEP qilinib chiqadi (`&lt;strong&gt;` va h.k.).
  def plant_merged_notice(plant, primary_sibling, scope)
    t(
      'merged_notice_html', scope: scope, name: content_tag(:strong, plant.display_sci_name),
      link: link_to(t('merged_notice_link_text', scope: scope), plant_path(primary_sibling))
    )
  end

  # Tashqi manba tugmalarida ko'rsatiladigan rasmiy logo fayllari
  # (app/assets/images/external_sources/). Har biri o'z nomini o'zida
  # tashiydi (wordmark), shuning uchun tugmada alohida matn label
  # kerak emas — logo yonida faqat img bor.
  PLANT_EXTERNAL_LINK_LOGOS = {
    'inaturalist' => 'external_sources/inaturalist-logo.svg',
    'gbif' => 'external_sources/gbif-logo.svg',
    'powo' => 'external_sources/powo-logo.png',
    'plantarium' => 'external_sources/plantarium-logo.svg',
    'iucn' => 'external_sources/iucn-logo.png'
  }.freeze

  # Tashqi ilmiy manbalar (iNaturalist, GBIF, POWO, Plantarium, IUCN Red
  # List) uchun havolalar: [key, label, logo_path, url] ro'yxati. Tur
  # nomi bo'lmasa bo'sh massiv qaytadi — bu holda blok umuman
  # ko'rsatilmaydi.
  def plant_external_links(plant)
    name = plant.external_search_name
    return [] if name.blank?

    # ERB::Util.url_encode bo'shliqni "%20" bilan kodlaydi ("+" emas) —
    # GBIF'ning qidiruv sahifasi "+" ni to'g'ri dekodlamas edi.
    q = ERB::Util.url_encode(name)
    [
      ['inaturalist', 'iNaturalist', "https://www.inaturalist.org/observations?taxon_name=#{q}"],
      # "/species/search" GBIF'da "/taxon/search"ga redirect bo'ladi va
      # shu jarayonda ?q= parametri tushib qolib, butun bazani ko'rsatib
      # yuboradi — shuning uchun to'g'ridan-to'g'ri "/taxon/search".
      ['gbif', 'GBIF', "https://www.gbif.org/taxon/search?q=#{q}"],
      ['powo', 'POWO', "https://powo.science.kew.org/results?q=#{q}"],
      # Qidiruv formasining haqiqiy maydon nomlari (sample/match/type/
      # mode) plantarium.ru'ning o'z HTML formasidan olindi — "query"
      # kabi taxmin qilingan nom natija bermas edi.
      ['plantarium', 'Plantarium', "https://www.plantarium.ru/page/search.html?match=begins&type=0&mode=full&sample=#{q}"],
      ['iucn', 'IUCN Red List', "https://www.iucnredlist.org/search?query=#{q}&searchType=species"]
    ].map { |key, label, url| [key, label, PLANT_EXTERNAL_LINK_LOGOS[key], url] }
  end
end
