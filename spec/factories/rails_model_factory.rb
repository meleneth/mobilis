FactoryBot.define do
  factory :rails_model, class: "Mobilis::RailsModel" do
    rails_project
    name { "SomeModel" }

    initialize_with { rails_project.add_model(name) }
  end
end
