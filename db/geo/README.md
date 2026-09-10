# db/geo/

Geo-ma'lumot fayllari — commit qilinadi (`db/external/` dan farqli, u
`.gitignore` da).

## uzbekiston_viloyatlari.geojson

O'zbekiston 14 ta ma'muriy birligining (12 viloyat + Toshkent shahri +
Qoraqalpog'iston Respublikasi) soddalashtirilgan chegaralari.
`RegionLookup` (app/services/region_lookup.rb) koordinatadan viloyat
kalitini aniqlash uchun ishlatadi.

- **Manba:** Natural Earth — Admin 1 States/Provinces, 10m
  (https://www.naturalearthdata.com/downloads/10m-cultural-vectors/,
  https://github.com/nvkelso/natural-earth-vector).
- **Litsenziya:** Public domain (CC0). "Made with Natural Earth."
  Cheklovsiz ishlatish/tarqatish mumkin.
- **Qayta ishlash:** dunyo faylidan `iso_3166_2` bo'yicha O'zbekiston
  qismi ajratildi, Douglas-Peucker bilan soddalashtirildi (eps=0.005°,
  ~500 m), koordinatalar 4 kasrga yaxlitlandi. Natija ~30 KB.
  Har `Feature` ning `properties.region` — model kaliti
  (`RegionLookup::keys`, masalan `"samarqand"`, `"toshkent_shahri"`).
- **Aniqlik:** viloyat darajasi (~100 km). Chegaraga yaqin nuqtalar
  noto'g'ri tushishi mumkin — backfill natijasi `region_source="auto"`
  deb belgilanadi va keyin tuzatilishi mumkin.
