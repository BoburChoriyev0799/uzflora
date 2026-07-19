ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Boshqaruv paneli"

  content title: "Uzflora Admin" do
    columns do
      column do
        panel "Foydalanuvchilar" do
          para "Jami: #{User.count}"
          para "Ekspertlar: #{User.where(is_expert: true).count}"
          para "Adminlar: #{User.where(is_admin: true).count}"
          para "Katta yilga obuna bo'lganlar (#{Time.zone.now.year}): #{Subscription.where(year: Time.zone.now.year).count}"
        end
      end

      column do
        panel "O'simliklar" do
          para "Jami: #{Plant.count}"
          para "Qizil kitobda: #{Plant.where(red_book: true).count}"
        end
      end

      column do
        panel "Kuzatuvlar (rasmlar)" do
          para "Jami: #{PlantSighting.count}"
          para link_to("Kutilayotgan: #{PlantSighting.pending.count}", admin_plant_sightings_path(q: { status_eq: 'pending' }))
          para "Tasdiqlangan: #{PlantSighting.approved.count}"
          para "Rad etilgan: #{PlantSighting.rejected.count}"
        end
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
