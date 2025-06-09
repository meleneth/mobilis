# frozen_string_literal: true

FactoryBot.define do
  factory :rails_field, class: Mobilis::Model::Rails::Field do
    name { "name" }
    type { "string" }

    initialize_with { new(name: name, type: type) }
  end
end
