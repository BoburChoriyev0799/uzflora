#!/usr/bin/env bash
# Render.com uchun build skripti.
#
# Bepul (free) planda alohida "pre-deploy" bosqichi yo'q — shuning uchun
# migratsiya va o'simliklarni import qilish ham shu build skriptining o'zida,
# har deploy'da ishga tushadi. Bu xavfsiz: db:migrate faqat yangi
# migratsiyalarni qo'llaydi, plants:import esa species_id bo'yicha
# find_or_initialize_by ishlatgani uchun qayta-qayta ishga tushirilsa ham
# dublikat yaratmaydi (mavjud yozuvlarni shunchaki yangilaydi).
set -o errexit

bundle install

bundle exec rails assets:precompile
bundle exec rails assets:clean

bundle exec rails db:migrate

bundle exec rails plants:import
