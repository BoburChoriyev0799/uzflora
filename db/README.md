# db/ — ma'lumot fayllari va maintenance tasklari

Bu papkada: migratsiyalar (`db/migrate/`), seed'lar, **ma'lumot fayllari**
(CSV / GeoJSON) va ularni bazaga singdiradigan **rake tasklar** haqida
qo'llanma.

> **Yangi baza:** `bin/rails db:schema:load` (migratsiyalarni noldan
> `db:migrate` qilib bo'lmaydi — 2019-yilgi ba'zi migratsiyalar allaqachon
> o'chirilgan `Species` modeliga murojaat qiladi. `db/schema.rb` — haqiqiy
> manba, lekin `.gitignore`'da; `db:schema:load` mahalliy schema'дан
> yuklaydi).

---

## 1. Ma'lumot fayllari — turi bo'yicha

### ASL MANBA (hech qachon o'zgartirilmaydi)

| Fayl | Nima |
|---|---|
| `db/uzflora_plants_v8.csv` | O'simliklar katalogi (asl import manbasi). `plants:import` shundan o'qiydi. |
| `db/qoraqalpoq_nomlari.csv` | Qoraqalpoqcha nomlar — Ережепов 1978 / Шербаев 1988 kitoblari (397 qator). **TEGILMAYDI** — bibliografik hujjat. Tuzatishlar alohida faylда (pastga qarang). |
| `db/geo/uzbekiston_viloyatlari.geojson` | O'zbekiston 14 viloyati — Natural Earth admin-1 10m, **public domain (CC0)**, Douglas-Peucker bilan soddalashtirilgan (~30 KB). `RegionLookup` ishlatadi. Manba/metod: `db/geo/README.md`. |

### QO'LDA TUZATISH JADVALLARI (odam yozadi, git diff'да ko'rinadi)

| Fayl | Nima |
|---|---|
| `db/powo_overrides.csv` | POWO/WCVP moslikning qo'lda tuzatilgan natijalari (`accepted_name` yoki `wcvp_name` taxallusi). `plants:powo_export_mapping` qo'llaydi. |
| `db/duplikat_istisnolar.csv` | `plants:mark_primary` uchun istisnolar — bir `accepted_name` guruhidagi bir nechta yozuv **alohida** ko'rinishда qolishi kerak bo'lган nomlar (masalan Malus domestica / M. sieversii). |
| `db/qoraqalpoq_imlo_tuzatishlari.csv` | Qoraqalpoq CSV'даgi terish/nom xatolari: `fayldagi_nom → tuzatilgan_nom` + izoh. `plants:import_qoraqalpoq` moslashtirishдан **oldin** qo'llaydi. |
| `db/qoraqalpoq_madaniy_turlar.csv` | Ekma (madaniy) turlar — yovvoyi flora bazasida yo'q va bo'lishi ham shart emas. Audit'да `MADANIY_TUR` deb belgilanadi. |

### HISOBLANGAN / EKSPORT QILINGAN NATIJA (task qayta yaratadi — qo'lda tahrirlanmaydi)

| Fayl | Kim yaratadi | Kim o'qiydi |
|---|---|---|
| `db/powo_mapping.csv` | `plants:powo_export_mapping` (WCVP faylini talab qiladi) | `plants:powo_apply` |
| `db/qoraqalpoq_nomlari_hal_qilingan.csv` | `plants:import_qoraqalpoq POWO=true` (WCVP sinonim zanjiri) | `plants:import_qoraqalpoq` (prod'da POWO'siz) |
| `db/qoraqalpoq_bazada_yoq.csv` | `plants:qoraqalpoq_powo_api` | `plants:check_missing_species_distribution` |
| `db/gbif_*.csv` | GBIF solishtiruvi (tarixiy) | — (arxiv) |

### tmp/ ga yoziladiganlar (commit qilinmaydi, har deployда tozalanadi)

`tmp/qoraqalpoq_import_hisobot.csv`, `tmp/ozbekcha_nomlar_toldirish.csv`,
`tmp/bazada_yoq_tekshiruv.csv`, `tmp/powo_report_*.csv`. Fayl kerak bo'lsa
`FILE=` bilan boshqa yo'l bering yoki ActiveAdmin orqali yuklab oling.

---

## 2. Rake tasklar

Umumiy naqsh: aksariyat task **DRY RUN** standart (hech narsa yozmaydi),
`APPLY=true` bilan yozadi, qayta ishga tushirilsa xavfsiz (idempotent).

### `plants:import`
```bash
bin/rails plants:import                 # o'zgargan bo'lsa import qiladi
bin/rails plants:import FORCE=true       # checksum bir xil bo'lsa ham
```
- **Nima:** `db/uzflora_plants_v8.csv` dan `plants` jadvalini to'ldiradi/yangilaydi (`upsert`, kalit — `species_sci`).
- **Qachon:** katalog CSV o'zgarганда.
- **DRY_RUN:** yo'q; `PlantImportState` checksum'i orqali o'zgarmagan bo'lsa **o'zi o'tkazib yuboradi**. `FORCE=true` — majburan.
- **Production:** `db/uzflora_plants_v8.csv` repoda bor. Boshqa narsa kerak emas.
- **Xavf:** mavjud tarjimalarni (`species_uz`/`species_ru`) CSV'даgi qiymat bilan **ustiga yozishi mumkin** — CSV'ni to'g'ri holatда saqlang.

### `plants:clear`
```bash
bin/rails plants:clear
```
- **Nima:** BARCHA `Plant` yozuvlarini o'chiradi. **⚠️ FAQAT lokal/test.** Productionда ishlatilmaydi.

### `plants:powo_export_mapping`
```bash
bin/rails plants:powo_export_mapping
```
- **Nima:** `Powo::Matcher` (WCVP faylini o'qiydi) bilan har `species_sci` uchun accepted nom/muallif/oila/powo_id ni hisoblab `db/powo_mapping.csv` ga yozadi. `db/powo_overrides.csv` qo'lda tuzatishlarini ustiga qo'llaydi.
- **Qachon:** matcher mantig'i yoki overrides o'zgарганда — natija git diff'да ko'rinsin.
- **DRY_RUN:** yo'q (faqat faylga yozadi, bazaga tegmaydi).
- **Production:** **ishlamaydi** — `db/external/wcvp_names.csv` (~300 MB, `.gitignore`'да) kerak. Faqat lokalda.
- **Xavf:** yo'q (bazaga yozmaydi).

### `plants:powo_apply`
```bash
bin/rails plants:powo_apply              # dry-run
bin/rails plants:powo_apply APPLY=true   # yozadi + mark_primary
```
- **Nima:** `db/powo_mapping.csv` dan `plants` jadvalining `accepted_*`/`wcvp_*`/`powo_*` ustunlarini yozadi. `APPLY=true` oxirida `plants:mark_primary` ni ham chaqiradi.
- **Qachon:** `powo_mapping.csv` yangilangач.
- **DRY_RUN:** ha (standart).
- **Production:** `db/powo_mapping.csv` repoда bor — WCVP fayli **kerak emas**. Bu asosiy prod yo'li.
- **Xavf:** faqat "xavfsiz" `match_type` lar yoziladi; `species_sci` hech qachon o'zgarmaydi.

### `plants:mark_primary`
```bash
bin/rails plants:mark_primary              # dry-run
bin/rails plants:mark_primary APPLY=true
```
- **Nima:** bir xil `accepted_name` guruhидаgi yozuvlarдан bittasini `primary_record=true` qiladi (ro'yxatда shu ko'rinadi), `group_red_book`/`group_has_photo` ni qayta hisoblaydi. `db/duplikat_istisnolar.csv` istisnolarini hisobga oladi.
- **Qachon:** `accepted_name` guruhlari o'zgарганда (odatда `powo_apply` o'zi chaqiradi).
- **DRY_RUN:** ha.
- **Production:** ha, ishlaydi. Fayl: `db/duplikat_istisnolar.csv`.

### `plants:powo_report`
```bash
bin/rails plants:powo_report
```
- **Nima:** WCVP bilan solishtiruv **hisoboti** — `tmp/powo_report_full.csv`, `tmp/powo_not_found.csv`, `tmp/powo_changes.csv`.
- **DRY_RUN:** mavzu emas — **FAQAT O'QIYDI**, bazaga hech narsa yozmaydi.
- **Production:** WCVP fayli kerak (lokal).

### `plants:dedupe`
```bash
bin/rails plants:dedupe              # dry-run
bin/rails plants:dedupe APPLY=true
```
- **Nima:** bir xil turга tegishli dublikat `Plant` yozuvlarini birlashtiradi (kuzatuvlarни ko'chiradi).
- **DRY_RUN:** ha.
- **Xavf:** yozuvlarni **o'chiradi/ko'chiradi** — avval DRY_RUN natijasini diqqat bilan ko'ring.

### `plants:import_qoraqalpoq`
```bash
bin/rails plants:import_qoraqalpoq                 # dry-run
bin/rails plants:import_qoraqalpoq APPLY=true      # yozadi
bin/rails plants:import_qoraqalpoq POWO=true       # + 4-bosqich (WCVP), hal_qilingan.csv ni qayta yozadi
```
- **Nima:** `db/qoraqalpoq_nomlari.csv` dan `species_kaa`/`species_kaa_source` ni to'ldiradi. Moslashtirish: kanonik kalit → `species_sci` / `accepted_name` / `wcvp_matched_name` / (4) sinonim → zamonaviy nom. Imlo tuzatishlari va madaniy turlar fayllarini hisobga oladi. Audit: `tmp/qoraqalpoq_import_hisobot.csv`.
- **DRY_RUN:** ha. Idempotent. Guruhning barcha a'zolariga yozadi, mavjud qiymat ustiga yozmaydi (ZIDDIYAT).
- **Production:** `db/qoraqalpoq_nomlari.csv` + `db/qoraqalpoq_nomlari_hal_qilingan.csv` + `imlo_tuzatishlari.csv` + `madaniy_turlar.csv` repoда bor. **`POWO=true` / WCVP fayli kerak emas** (prod'да).
- **Xavf:** yo'q (`species_uz`/`species_ru` ga tegmaydi).

### `plants:qoraqalpoq_powo_api`
```bash
bin/rails plants:qoraqalpoq_powo_api DELAY=2
```
- **Nima:** `import_qoraqalpoq` da TOPILMADI qolgan nomlarni **POWO jonli REST API** orqali yechadi → `db/qoraqalpoq_bazada_yoq.csv` (eski_nom, powo_qabul_qilgan_nom, powo_id, holat). Ishonchli (epitet mos) natijalarни `hal_qilingan.csv` ga qo'shadi.
- **DRY_RUN:** mavzu emas — faqat CSV yozadi, bazaga tegmaydi.
- **Production:** internet kerak (POWO API). `DELAY` — so'rovlar orasidagi kutish (s).
- **Xavf:** yo'q. **Hech qanday turни bazaga qo'shmaydi.**

### `plants:check_missing_species_distribution`
```bash
bin/rails plants:check_missing_species_distribution DELAY=2
```
- **Nima:** `db/qoraqalpoq_bazada_yoq.csv` turlarини POWO **tarqalish** (TDWG/UZB) bo'yicha tekshiradi → `tmp/bazada_yoq_tekshiruv.csv` (HA/YO'Q/NOMA'LUM). **Tekshiruv varaqasi** — qo'shish qarorini odam qabul qiladi.
- **DRY_RUN:** mavzu emas. **Hech qanday turни bazaga qo'shmaydi.**
- **Production:** internet kerak.

### `plants:export_missing_uz_names`
```bash
bin/rails plants:export_missing_uz_names
```
- **Nima:** `species_uz` bo'sh turlarni `tmp/ozbekcha_nomlar_toldirish.csv` ga chiqaradi (kuzatuvi bor turlar tepада, keyin Qizil kitob, keyin oila+lotincha).
- **Asosiy yo'l:** ActiveAdmin → O'simliklar → **"O'zbekcha nomlar CSV"** tugmasi (brauzerдан yuklab olinadi).

### `plants:import_uz_names`
```bash
bin/rails plants:import_uz_names                              # dry-run (tmp/)
bin/rails plants:import_uz_names APPLY=true
bin/rails plants:import_uz_names FILE=db/ozbekcha_nomlar.csv APPLY=true
```
- **Nima:** to'ldirilgan CSV'дан `species_uz` ni yozadi. Moslik **faqat `id`** bo'yicha; bo'sh qator o'tkaziladi; mavjud qiymat ustiga yozilmaydi (ZIDDIYAT); guruhning barcha a'zolariga; idempotent.
- **DRY_RUN:** ha. `FILE=` — boshqa fayl (repoga commit qilib import qilish uchun).
- **Asosiy yo'l:** ActiveAdmin → O'simliklar → **"O'zbekcha nomlarni yuklash"** (ko'rib chiqish + tasdiqlash).
- **Mantiq:** `app/services/uz_names_import.rb` — rake va admin bitta manba.

### `plant_sightings:backfill_region`
```bash
bin/rails plant_sightings:backfill_region              # dry-run
bin/rails plant_sightings:backfill_region APPLY=true
```
- **Nima:** koordinatasi bor, `region` bo'sh kuzatuvlarга viloyatни koordinatadan qo'yadi (`RegionLookup`, ray-casting). `region_source="auto"`.
- **DRY_RUN:** ha. Idempotent. Foydalanuvchi qiymati (`region_source="user"`) ustiga **yozmaydi**. Aniqlanmasa nil + logga.
- **Production:** `db/geo/uzbekiston_viloyatlari.geojson` repoда bor. Boshqa narsa kerak emas.
- **Xavf:** yo'q — koordinata SERVERДА ishlatiladi (sizib chiqish emas); `SightingCoordinates` himoyasi o'zgarmaydi. Viloyat ~100 km, yaxlitlashдан ham qo'polroq.

### `plant_sightings:normalize_addresses`
```bash
bin/rails plant_sightings:normalize_addresses               # dry-run
APPLY=true bin/rails plant_sightings:normalize_addresses
```
- **Nima:** `plant_sightings.address` dagi ortiqcha bo'shliqni tozalaydi (`squish`).
- **DRY_RUN:** ha (`APPLY=true`).
- **Xavf:** past — faqat bo'shliq.

### `photos:strip_exif`
```bash
bin/rails photos:strip_exif                    # dry-run — nechta GPS'li fayl borligini sanaydi
APPLY=true bin/rails photos:strip_exif         # tozalaydi va R2'ga QAYTA YUKLAYDI
```
- **Nima:** eski kuzatuv rasmlarининг har bir versiyasidан EXIF/GPS metama'lumotni tozalaydi (yangi yuklashlar uploaderда allaqachon tozalanadi).
- **DRY_RUN:** ha.
- **Production:** R2 (fog storage) sozlangан bo'lishi kerak.
- **⚠️ XAVF:** tozalangan faylни **R2'даgi asl fayl ustiga qayta yozadi — ZAXIRA YO'Q.** Avval DRY_RUN, keyin kichik partiyada sinab ko'ring. Qaytarib bo'lmaydigan.

### `plant_sightings:backfill_identifications`
```bash
bin/rails plant_sightings:backfill_identifications
```
- **Nima:** mavjud (eski) kuzatuvlar uchun jamoaviy aniqlash (`identifications`) yozuvlarini orqага to'ldiradi.
- **Bir martalik** migratsiya-yordamchi. **Idempotent** (necha marta ishga tushirilsa ham bir xil natija). Xavfsiz.

### `plant_sightings:backfill_medium_photo`
```bash
bin/rails plant_sightings:backfill_medium_photo
```
- **Nima:** eski rasmlarга izohlar modali uchun `:medium` versiyasini yaratadi (`recreate_versions!(:medium)` — R2'га yozadi). `failed` photo_status'дагиlar o'tkaziladi.
- **Production:** R2 kerak. **Xavf:** R2'га yangi fayl yozadi (asl versiyalар ustiga yozmaydi), lekin trafik/xotira sarflaydi.

### `big_years:gen_subscriptions[year]`  *(fayl: `lib/tasks/subscriptions.rake`)*
```bash
bin/rails "big_years:gen_subscriptions[2027]"
```
- **Nima:** berilgan yil uchun Katta Yil ishtirokchilarига obuna yozuvlarини yaratadi (eski yildan yangi yilга o'tish).
- **Yillik.** Xavfsiz.
