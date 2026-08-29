FactoryBot.define do
  factory :user do
    sequence(:email) {|n| "test_#{n}@test.ru" }
    sequence(:first_name) {|n| "TestName_#{n}" }
    sequence(:last_name) {|n| "TestFamily_#{n}" }
    password { '12345678' }
    password_confirmation { '12345678' }

    # `user_expert` (pastda) `roles` orqali ishlaydi — lekin User#expert?
    # `is_expert` USTUNIGA qaraydi (Role tizimi hech qachon seed
    # qilinmagan), shuning uchun u haqiqatan `expert?` true qilmaydi.
    # Haqiqiy ekspert kerak bo'lgan testlar uchun shu trait ishlatiladi.
    trait :expert do
      is_expert { true }
    end

    factory :user_expert do
      after(:create) do |user|
        user.roles<<FactoryBot.create(:expert_role)
        user.save
      end
    end
  end
end
