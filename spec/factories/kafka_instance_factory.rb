FactoryBot.define do
  factory :kafka_instance, class: "Mobilis::KafkaInstance" do
    metaproject
    name { "kafka_project" }

    initialize_with { metaproject.add_kafka_instance(name) }
  end
end
