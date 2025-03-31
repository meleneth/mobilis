FactoryBot.define do
  factory :node, class: Mobilis::Node do
    transient do
      id { nil }
    end

    name { "unnamed" }

    initialize_with { new(name, id: id) }
  end
end
