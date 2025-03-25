FactoryBot.define do
  factory :rack_project, class: "Mobilis::Project::RackProject" do
    metaproject
    name { "rack_project" }

    initialize_with { metaproject.add_rack_project(name) }
  end
end
