# frozen_string_literal: true

FactoryBot.define do
  factory :realized_env, class: "Mobilis::RealizedEnv" do
    transient do
      system_traits { [] }
      system { nil }
      execution_environment { build(:execution_environment) }
    end

    skip_create

    initialize_with do
      sys = system || build(:system, *system_traits)
      new(sys, execution_environment)
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
  end
end
