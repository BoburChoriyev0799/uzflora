# Bu fayl loyihada umuman mavjud emas edi (eski Gemfile'da puma ham
# yo'q edi). Rails 7.1 standart shabloni asosida, Render.com uchun
# WEB_CONCURRENCY (cluster rejimi) qo'llab-quvvatlanadigan holda yozildi.

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count).to_i
threads min_threads_count, max_threads_count

port ENV.fetch("PORT", 3000)

environment ENV.fetch("RAILS_ENV", "development")

pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# WEB_CONCURRENCY o'rnatilmagan bo'lsa (masalan lokal dev muhitda) —
# workers 0, ya'ni bitta jarayonli oddiy rejim. Render'da WEB_CONCURRENCY=2
# beriladi (render.yaml) — shunda 2 ta worker jarayoni ishga tushadi.
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i

# Cluster rejimida preload_app! xotirani tejaydi (copy-on-write), lekin
# ActiveRecord ulanishini har bir worker fork bo'lgandan keyin qayta
# o'rnatish kerak — shu sababli on_worker_boot bilan birga ishlatiladi.
if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 0
  preload_app!

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
  end
end

plugin :tmp_restart
