FactoryBot.define do
  factory :rails_prime, class: "Mobilis::GenericProject" do
    metaproject
    name { "rails_project" }

    initialize_with { metaproject.add_prime_stack_rails_project(name) }
  end
end
