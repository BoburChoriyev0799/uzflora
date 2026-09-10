# O'zbekcha nomlarni CSV orqali yuklash — KO'RIB CHIQISH + TASDIQLASH bilan.
#
# Oqim (stateless — yuklangan fayl DOIMIY saqlanmaydi):
#   1) content: CSV tanlash formasi  -> POST preview
#   2) preview: `UzNamesImport.plan` natijasi jadval ko'rinishida + fayl
#      matni base64 yashirin maydonда  -> POST apply
#   3) apply: base64'ni yechib `UzNamesImport.apply!`, natija + qayta
#      forma
#
# Import MANTIQI `app/services/uz_names_import.rb` da — rake task bilan
# BITTA manba.
require 'base64'

ActiveAdmin.register_page 'Ozbekcha nomlar import' do
  menu parent: "O'simliklar", label: "O'zbekcha nomlarni yuklash"

  # register_page controller'i FAQAT `authenticate_user!` dan o'tadi —
  # AdminAuthorization avtomatik qo'llanmaydi. Admin'ligini har action'да
  # aniq tekshiramiz (oddiy foydalanuvchi / ekspert -> 403).
  controller do
    before_action :require_site_admin!

    private

    # register_page controller'i FAQAT `authenticate_user!` dan o'tadi
    # (AdminAuthorization CONTENT action'i uchun qo'llanadi, lekin
    # page_action'lar uchun kafolatlanmagan) — shuning uchun HAR action'да
    # aniq tekshiramiz. Oddiy foydalanuvchi / ekspert -> admin bosh
    # sahifasiga qaytariladi, hech qanday amal bajarilmaydi.
    def require_site_admin!
      return if current_user&.admin?

      redirect_to admin_root_path, alert: "Bu sahifa faqat administrator uchun."
    end

    MAX_UPLOAD = 5.megabytes

    def read_upload(file)
      raise UzNamesImport::InvalidFile, 'fayl tanlanmadi' unless file.respond_to?(:read)
      raise UzNamesImport::InvalidFile, 'fayl juda katta (5 MB dan oshmasin)' if file.size.to_i > MAX_UPLOAD
      unless file.original_filename.to_s.downcase.end_with?('.csv') ||
             [ 'text/csv', 'application/csv', 'application/vnd.ms-excel' ].include?(file.content_type)
        raise UzNamesImport::InvalidFile, 'faqat CSV fayl qabul qilinadi'
      end

      file.read
    end
  end

  content title: "O'zbekcha nomlarni yuklash" do
    render 'admin/uz_names/form'
  end

  page_action :preview, method: :post do
    csv_text = read_upload(params[:file])
    @plan = UzNamesImport.plan(csv_text)
    @csv_b64 = Base64.strict_encode64(csv_text)
    render 'admin/uz_names/preview'
  rescue UzNamesImport::InvalidFile => e
    redirect_to admin_ozbekcha_nomlar_import_path, alert: "Fayl xatosi: #{e.message}"
  end

  page_action :apply, method: :post do
    csv_text = Base64.strict_decode64(params[:csv_b64].to_s)
    plan = UzNamesImport.plan(csv_text)
    written = UzNamesImport.apply!(plan)
    redirect_to admin_ozbekcha_nomlar_import_path,
                notice: "Bajarildi — #{written} ta yozuv yangilandi " \
                        "(#{plan.added} tur qo'shildi, #{plan.conflicts.size} ziddiyat o'tkazib yuborildi)."
  rescue ArgumentError, UzNamesImport::InvalidFile => e
    redirect_to admin_ozbekcha_nomlar_import_path, alert: "Xato: #{e.message}"
  end
end
