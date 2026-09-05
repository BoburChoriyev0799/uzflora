# frozen_string_literal: true
module PlantsHelper
  # --- Ilmiy nom formati (xalqaro nomenklatura qoidasi) ---
  # Turkum + tur epiteti (va infratur epitetlari) — KURSIV.
  # Muallif(lar), "subsp."/"var."/"f." kabi rang belgilari — ODDIY.
  # Gibrid belgisi ("x"/"×") turkum bilan tur orasida — ODDIY, undan
  # keyingi epitet — KURSIV (external_search_name'даgi bilan bir xil
  # aniqlash qoidasi).
  SCI_NAME_HYBRID_MARKER = /\A[x×]\z/i.freeze
  SCI_NAME_RANK_MARKER = /\A(subsp\.?|ssp\.?|var\.?|f\.?|forma|×)\z/i.freeze

  # Markaziy helper — ILMIY NOM chiqadigan HAMMA joyda shu ishlatiladi.
  # `name` — turkum+tur(+infratur) qismi (masalan "Acalypha australis"
  # yoki "Arnebia decumbens subsp. decumbens"), `authors` — muallif(lar)
  # ALOHIDA (masalan "L." yoki "(Bunge) Stef.") — bazadagi eng ishonchli
  # manba `accepted_name`/`accepted_authors` shu ikkalasini ALOHIDA-
  # ALOHIDA ustunlarda beradi (`plant_sci_name_html` shundan foydalanadi).
  #
  # `authors` berilmasa (yoki `name`ning o'zi — masalan eski `species_sci`
  # — muallifni ham o'z ichiga olgan bo'lsa), funksiya SO'ZMA-SO'Z
  # tahlil qiladi: turkum (1-so'z) va tur epiteti (2-so'z, yoki gibrid
  # belgisidan keyingi 3-so'z) — KURSIV; keyin ketma-ket kelgan har bir
  # "rang belgisi + epitet" jufti (masalan "subsp. decumbens") — belgi
  # ODDIY, epitet KURSIV; ROSTDAN QOLGAN barcha so'zlar (muallif) —
  # ODDIY. Shu bitta algoritm ikkala holatni (ustunlar ALOHIDA yoki
  # BIRGA) to'g'ri qamrab oladi.
  #
  # Xavfsizlik: har bir bo'lak alohida HTML-escape qilinadi (XSS'dan
  # himoya), natija esa BUTUNLAY html_safe — chaqiruvchi qayta escape
  # qilmasin (Haml `=` html_safe qatorni qayta escape qilmaydi).
  def sci_name_html(name, authors = nil)
    name = name.to_s.strip
    authors = authors.to_s.strip
    return ''.html_safe if name.blank? && authors.blank?

    tokens = name.split(/\s+/)
    segments = [] # [matn, kursivmi?] juftliklari, tartib bilan
    i = 0

    if (t = tokens[i])
      segments << [t, true]
      i += 1
    end

    if (t = tokens[i])
      if t.match?(SCI_NAME_HYBRID_MARKER)
        segments << [t, false]
        i += 1
        if (t2 = tokens[i])
          segments << [t2, true]
          i += 1
        end
      else
        segments << [t, true]
        i += 1
      end
    end

    while (t = tokens[i]) && t.match?(SCI_NAME_RANK_MARKER)
      segments << [t, false]
      i += 1
      if (t2 = tokens[i])
        segments << [t2, true]
        i += 1
      end
    end

    # `name`da qolgan so'zlar (rang belgisiga to'g'ri kelmagan qism) —
    # bu FAQAT `authors` alohida berilmagan, "xom" (masalan species_sci)
    # qator uzatilganda yuz beradi — qolgan qism muallif hisoblanadi.
    leftover = tokens[i..].to_a.join(' ')
    full_authors = [leftover, authors].reject(&:blank?).join(' ')
    segments << [full_authors, false] if full_authors.present?

    sci_name_render_segments(segments)
  end

  # Faqat TURKUM (yoki OILA) darajasidagi qiymat uchun — birinchi so'z
  # KURSIV, qolgani (muallif bo'lsa) ODDIY. Eski (POWO'siz) `genus_lat`/
  # `family_lat` ustunlarida ba'zan muallif ilashib qolgan bo'ladi
  # (masalan "Ophioglossum L.") — `sci_name_html`dan farqli, bu yerda
  # 2-so'z "tur epiteti" DEB TAXMIN QILINMAYDI (turkum darajasida tur
  # yo'q), to'g'ridan-to'g'ri muallif deb olinadi.
  def genus_name_html(value)
    value = value.to_s.strip
    return ''.html_safe if value.blank?

    tokens = value.split(/\s+/)
    genus = tokens.shift
    rest = tokens.join(' ')
    sci_name_render_segments([[genus, true], (rest.present? ? [rest, false] : nil)].compact)
  end

  # `plant`ning ENG ISHONCHLI manbadan (accepted_name + accepted_authors
  # ALOHIDA ustunlar) ilmiy nomi — POWO moslashtirilmagan (accepted_name
  # bo'sh) yozuvlarda `species_sci`ga (xom, tahlil qilinadigan) tushadi.
  def plant_sci_name_html(plant)
    return ''.html_safe if plant.blank?
    return sci_name_html(plant.accepted_name, plant.accepted_authors) if plant.accepted_name.present?

    sci_name_html(plant.species_sci)
  end

  # `Plant#display_name`ning HTML-mos varianti: tarjima (vernakulyar nom)
  # bo'lsa — oddiy (bosh harfli) matn, bo'lmasa ilmiy nomga tushadi —
  # bu holda KURSIV bo'lishi SHART (aks holda ilmiy nom oddiy shrift
  # bilan chiqib qolardi, masalan tarjimasi yo'q yangi turlarda).
  def plant_display_name_html(plant, locale)
    return ''.html_safe if plant.blank?

    case locale.to_sym
    when :uz
      plant.species_uz.present? ? capitalize_first(plant.species_uz) : plant_sci_name_html(plant)
    when :ru
      plant.species_ru.present? ? capitalize_first(plant.species_ru) : plant_sci_name_html(plant)
    else
      plant_sci_name_html(plant)
    end
  end

  private

  # Ketma-ket kelgan bir xil uslubdagi bo'laklarni BITTA teg ichiga
  # birlashtiradi (masalan turkum+tur — ikkita alohida <i> emas, bitta
  # "<i>Turkum tur</i>"), har bir bo'lakni alohida escape qiladi.
  def sci_name_render_segments(segments)
    merged = []
    segments.each do |text, italic|
      if merged.any? && merged.last[1] == italic
        merged.last[0] = "#{merged.last[0]} #{text}"
      else
        merged << [text, italic]
      end
    end

    safe_join(
      merged.map { |text, italic| italic ? content_tag(:i, text) : text },
      ' '
    )
  end

  public

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
      next if lat.blank?

      # Xalqaro nomenklatura qoidasi: bo'lim/sinf/tartib/oila — ODDIY
      # shrift; turkum va tur — KURSIV (muallifi bo'lsa — u ODDIY,
      # `genus_name_html`/`plant_sci_name_html`ning o'zi ажратади).
      value = case label_key
              when :species then plant_sci_name_html(plant)
              when :genus then genus_name_html(lat)
              else lat
              end
      [label_key, value]
    end
  end

  # plants/show'даgi "uch nom" bloki uchun qatorlar: [label_key, value].
  # Til bo'yicha tartib va yorliqlar farq qiladi (uz/ru/en), lekin har
  # birida bo'sh qiymatli qator chiqarib tashlanadi. species_en ustuni
  # bazada yo'q — "Common name:" shu sabab hozircha doim yashiringan.
  def plant_name_rows(plant, locale)
    sci_name = plant_sci_name_html(plant)
    name_uz = capitalize_first(plant.species_uz)
    name_ru = capitalize_first(plant.species_ru)
    rows = case locale.to_sym
           when :ru
             [
               [:name_ru, name_ru],
               [:name_lat, sci_name],
               [:name_local, name_uz]
             ]
           when :en
             [
               [:name_lat, sci_name],
               [:name_ru, name_ru],
               [:name_local, name_uz]
             ]
           else
             [
               [:name_uz, name_uz],
               [:name_lat, sci_name],
               [:name_ru, name_ru]
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
    sci_name = sci_name_html(group_info[:sci_name])
    names = members.map { |m| m.public_send(field) }.filter_map(&:presence).uniq.map { |n| capitalize_first(n) }

    synonyms_text = if members.size > 1
                       safe_join(['= ', safe_join(members.map { |m| sci_name_html(m.species_sci) }, ', ')])
                     end

    {
      sci_name: sci_name,
      localized_name: (names.any? ? names.join(', ') : sci_name),
      synonyms_text: synonyms_text,
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
      'merged_notice_html', scope: scope, name: content_tag(:strong, plant_sci_name_html(plant)),
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
