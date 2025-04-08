# frozen_string_literal: true

FactoryBot.define do
  factory :execution_environment, class: "Mobilis::ExecutionEnvironment" do
    transient do
      env_name { :test }
    end

    initialize_with { new(env_name) }

    trait :test do
      transient { env_name { :test } }
    end

    trait :development do
      transient { env_name { :development } }
    end

    trait :production do
      transient { env_name { :production } }
    end
  end
end
