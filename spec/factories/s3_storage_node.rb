# frozen_string_literal: true

FactoryBot.define do
  factory :s3_storage_node, class: Mobilis::Node::S3Storage do
    name { "assets" }
    buckets { ["uploads"] }

    initialize_with { new(name, buckets: buckets) }
  end
end
