# frozen_string_literal: true

FactoryBot.define do
  factory :rails_model, class: Mobilis::Model::Rails::Model do
    name { "user" }

    initialize_with { new(name) }
  end
end
