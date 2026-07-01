require "spec_helper"

RSpec.describe Mobilis::System do
  it "can serialize and deserialize a Rails + PostgreSQL graph" do
    pg = build(:postgres_node, name: "pg_main")
    rails = build(:rails_node, name: "myapp", primary_database: pg)

    rails.add_rails_model("user")

    system = described_class.new("generate")
    system << pg
    system << rails

    json = system.to_json
    loaded = described_class.from_json(json)

    loaded_rails = loaded[rails.id]
    loaded_pg = loaded[pg.id]

    expect(loaded_rails).to be_a(Mobilis::Node::Rails)
    expect(loaded_pg).to be_a(Mobilis::Node::PostgreSQL)
    expect(loaded_rails.primary_database).to eq(loaded_pg)
    expect(loaded_rails.models[0].name).to eq("user")
  end

  it "can serialize and deserialize a Rails + MySQL graph" do
    mysql = build(:mysql_node, name: "mysql_main")
    rails = build(:rails_node, name: "myapp", primary_database: mysql)

    system = described_class.new("generate")
    system << mysql
    system << rails

    loaded = described_class.from_json(system.to_json)

    expect(loaded[mysql.id]).to be_a(Mobilis::Node::MySQL)
    expect(loaded[rails.id].primary_database).to eq(loaded[mysql.id])
  end
end
