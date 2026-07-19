ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Boshqaruv paneli"

  content title: "Uzflora Admin" do
    current_year = Time.zone.now.year

    users_total       = User.count
    experts_total      = User.where(is_expert: true).count
    plants_total       = Plant.count
    red_book_total     = Plant.where(red_book: true).count
    sightings_total    = PlantSighting.count
    pending_total      = PlantSighting.pending.count
    approved_total     = PlantSighting.approved.count
    rejected_total     = PlantSighting.rejected.count
    participants_total = Subscription.where(year: current_year).count

    div class: "uzflora-stats-grid" do
      div class: "uzflora-stat-card purple" do
        div(class: "uzflora-stat-number") { users_total }
        div(class: "uzflora-stat-label") { "Jami foydalanuvchilar" }
        div(class: "uzflora-stat-sub") { "shundan #{experts_total} ekspert" }
      end

      div class: "uzflora-stat-card green" do
        div(class: "uzflora-stat-number") { plants_total }
        div(class: "uzflora-stat-label") { "Jami o'simliklar" }
        div(class: "uzflora-stat-sub") { "shundan #{red_book_total} Qizil kitobda" }
      end

      div class: "uzflora-stat-card blue" do
        div(class: "uzflora-stat-number") { sightings_total }
        div(class: "uzflora-stat-label") { "Jami kuzatuvlar" }
        div(class: "uzflora-stat-sub") { "#{approved_total} tasdiqlangan, #{rejected_total} rad etilgan" }
      end

      div class: "uzflora-stat-card orange" do
        div(class: "uzflora-stat-number") { link_to pending_total, admin_plant_sightings_path(q: { status_eq: 'pending' }) }
        div(class: "uzflora-stat-label") { "Kutilayotgan kuzatuvlar" }
        div(class: "uzflora-stat-sub") { "moderatsiya kerak" }
      end

      div class: "uzflora-stat-card dark-green" do
        div(class: "uzflora-stat-number") { participants_total }
        div(class: "uzflora-stat-label") { "Katta yil ishtirokchilari" }
        div(class: "uzflora-stat-sub") { "#{current_year}-yil" }
      end
    end

    columns do
      column do
        panel "So'nggi kuzatuvlar" do
          table_for PlantSighting.order(created_at: :desc).limit(10) do
            column(:id) { |ps| link_to ps.id, admin_plant_sighting_path(ps) }
            column(:user)
            column(:plant)
            column(:status) { |ps| status_tag(ps.status) }
            column(:created_at)
          end
        end
      end

      column do
        panel "So'nggi ro'yxatdan o'tganlar" do
          table_for User.order(created_at: :desc).limit(10) do
            column(:id) { |user| link_to user.id, admin_user_path(user) }
            column(:email)
            column(:full_name) { |user| user.full_name }
            column(:created_at)
          end
        end
      end
    end
  end
end
