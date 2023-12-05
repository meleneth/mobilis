FactoryBot.define do
  factory :rails_field, class: "Mobilis::RailsField" do
    rails_model
    name { "name" }
    type { Mobilis::RAILS_MODEL_TYPE_STRING }

    initialize_with { rails_model.add_field(name: name, type: type) }
  end
end
