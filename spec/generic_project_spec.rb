# frozen_string_literal: true

RSpec.describe "Generic Project" do
  let(:project) { build(:metaproject) }
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
      seen_parents = []
      mysql_instance.parents do |parent|
        seen_parents << parent.name
      end
      expect(seen_parents).to eq(["prime"])
    end
  end

  describe "#linked_to_rails_project" do
    it "returns first linked rails project, if there is one" do
      prime_stack.set_links([mysql_instance.name])
      rails_project = []
      mysql_instance.linked_to_rails_project do |rails|
        rails_project << rails.name
      end
      expect(rails_project).to eq(["prime"])
    end
  end

  describe "#each_project_for_environment" do
    it "yields self" do
      project_names = []
      mysql_instance.each_project_for_environment(Mobilis::ExecutionEnvironment.new(:production)) do |project|
        project_names << project.name
      end
      expect(project_names).to eq(%w[testm-db])
    end
    it "yields extra projects for rails production" do
      project_names = []
      prime_stack.set_links([mysql_instance.name])
      prime_stack.each_project_for_environment(Mobilis::ExecutionEnvironment.new(:production)) do |project|
        project_names << project.name
      end
      expect(project_names).to eq(%w[prime cache-testm-db queue-testm-db cable-testm-db])
    end
  end

  it "is addable" do
    project.add_rails_project "prime", %i[rspec api simplecov standard factorybot]
  end
end
