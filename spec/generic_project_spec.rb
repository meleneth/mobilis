# frozen_string_literal: true

RSpec.describe "Generic Project" do
  let(:project) { Mobilis::Project.new }
  let(:prime_stack) { project.add_prime_stack_rails_project "prime" }
  let(:mysql_instance) { project.add_mysql_instance "testm-db" }
  before do
    allow(project).to receive(:username).and_return("testuser")
  end

  describe "#children" do
    it "has linked projects" do
      prime_stack.set_links([mysql_instance.name])
      expect(prime_stack.children[0].name).to eq("testm-db")
    end
  end

  describe "#parents" do
    it "has projects that link to us" do
      prime_stack.set_links([mysql_instance.name])
      expect(mysql_instance.parents[0].name).to eq("prime")
    end
  end

  describe "#linked_to_rails_project" do
    it "returns first linked rails project, if there is one" do
      prime_stack.set_links([mysql_instance.name])
      expect(mysql_instance.linked_to_rails_project.name).to eq("prime")
    end
  end

  it "is addable" do
    project.add_rails_project "prime", %i[rspec api simplecov standard factorybot]
  end
end
