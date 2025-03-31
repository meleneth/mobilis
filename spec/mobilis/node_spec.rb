# frozen_string_literal: true

RSpec.describe Mobilis::Node do
  let(:pg) { build(:postgres_node, name: "pg-1") }
  let(:rails) { build(:rails_node, name: "web", primary_database: pg) }

  describe "basic identity" do
    it "assigns a UUID by default" do
      node = build(:node, name: "foo")
      expect(node.id).to match(/[a-f0-9-]{36}/)
    end

    it "accepts an explicit ID" do
      node = build(:node, name: "bar", id: "abc123")
      expect(node.id).to eq("abc123")
    end
  end

  describe "ref_attr serialization" do
    it "emits *_id in to_h" do
      expect(rails.to_h).to include(primary_database_id: pg.id)
    end
  end

  describe "ref_attr hydration" do
    it "resolves refs from *_id data" do
      raw = build(:rails_node, name: "web", primary_database: pg)
      raw.hydrate_refs!({ "primary_database_id" => pg.id })

      index = { pg.id => pg }
      raw.resolve_references_using(index)

      expect(raw.primary_database).to eq(pg)
      expect(raw.primary_database_id).to eq(pg.id)
    end
  end

  describe "to_h roundtrip" do
    it "preserves declared references" do
      out = rails.to_h

      node = build(:rails_node, name: out[:name], id: out[:id], primary_database: pg)
      node.hydrate_refs!(out)
      node.resolve_references_using({ pg.id => pg })

      expect(node.primary_database).to eq(pg)
      expect(node.to_h).to eq(out)
    end
  end
end
