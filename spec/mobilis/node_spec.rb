# frozen_string_literal: true

require "spec_helper"
require "securerandom"

class TestNode < Mobilis::Node
  ref_attr :db
  ref_list :models
end

class FakeRef < Mobilis::Node
end

RSpec.describe Mobilis::Node do
  let(:uuid_regex) { /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i }
  let(:node) { TestNode.new }
  let(:fakeref) { FakeRef.new }

  it "assigns a UUID by default" do
    node = TestNode.new
    expect(node.id).to match(uuid_regex)
  end

  it "accepts an explicit ID" do
    node = TestNode.new(id: "abc-123")
    expect(node.id).to eq("abc-123")
  end

  it "serializes ref_attr to *_id" do
    db = FakeRef.new(id: "db-1")
    node = TestNode.new
    node.db = db
    expect(node.to_h[:db_id]).to eq("db-1")
  end

  it "serializes ref_list to *_ids" do
    a = FakeRef.new(id: "a-1")
    b = FakeRef.new(id: "b-2")
    node = TestNode.new
    node.models = [a, b]
    expect(node.to_h[:models_ids]).to contain_exactly("a-1", "b-2")
  end

  it "resolves ref_attr from raw_data using ID" do
    db = FakeRef.new(id: "db-1")
    node = TestNode.new
    node.raw_data = { "db_id" => "db-1" }
    node.resolve_references_using("db-1" => db)
    expect(node.db).to eq(db)
  end

  it "resolves ref_list from raw_data using IDs" do
    a = FakeRef.new(id: "a-1")
    b = FakeRef.new(id: "b-2")
    node = TestNode.new
    node.raw_data = { "models_ids" => %w[a-1 b-2] }
    node.resolve_references_using("a-1" => a, "b-2" => b)
    expect(node.models).to contain_exactly(a, b)
  end
end
