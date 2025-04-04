RSpec.describe Mobilis::Node::Rails do
  let(:rails_node) { build(:rails_node, :with_postgres) }

  it "uses PostgreSQL when configured" do
    expect(rails_node.primary_database).to be_a(Mobilis::Node::PostgreSQL)
  end
end
