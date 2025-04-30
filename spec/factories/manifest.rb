# frozen_string_literal: true

FactoryBot.define do
  factory :manifest, class: "Mobilis::Manifest" do
    transient do
      system_traits { [] }
      system { nil }
      execution_environment { build(:execution_environment) }
      suppress_plugins { false }
    end

    skip_create

    initialize_with do
      sys = system || build(:system, *system_traits)
      new(sys, suppress_plugins: suppress_plugins)
    end

    trait :suppress_plugins do
      transient do
        suppress_plugins { true }
      end
    end

    trait :with_rails do
      transient do
        system_traits { [:with_rails] }
      end
    end

    trait :with_postgres do
      transient do
        system_traits { [:with_postgres] }
      end
    end

    trait :with_rails_and_postgres do
      transient do
        system_traits { [:with_rails_and_postgres] }
      end
    end

    trait :with_two_rails_and_postgres do
      transient do
        system_traits { [:with_two_rails_and_postgres] }
      end
    end
  end
end
