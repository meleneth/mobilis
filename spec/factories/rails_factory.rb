FactoryBot.define do
  factory :rails_prime, class: "Mobilis::RailsProject" do
    metaproject
    name { "rails_project" }

    initialize_with { metaproject.add_prime_stack_rails_project(name) }
  end
end

FactoryBot.define do
  factory :rails_project, class: "Mobilis::RailsProject" do
    metaproject
    name { "rails_project" }

    initialize_with { metaproject.add_prime_stack_rails_project(name) }
  end
end
