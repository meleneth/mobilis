FactoryBot.define do
  factory :rails_prime, class: "Mobilis::RailsProject" do
    metaproject
    name { "rails_project" }

    initialize_with { metaproject.add_prime_stack_rails_project(name) }
  end
end

FactoryBot.define do
  factory :rails_project, class: "Mobilis::RailsProject" do
    transient do
      graphql { false }
    end

    metaproject
    name { "rails_project" }

    initialize_with do
      rails_project = metaproject.add_prime_stack_rails_project(name)
      rails_project.toggle_rails_graphql_integration if graphql
      rails_project
    end
  end
end
