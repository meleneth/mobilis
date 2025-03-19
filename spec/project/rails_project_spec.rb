# frozen_string_literal: true

RSpec.describe "Rails Project" do
  let(:project) { Mobilis::Project.new }

  it "is addable" do
    project.add_rails_project "prime", %i[rspec api simplecov standard factorybot]
  end

  before do
    allow(project).to receive(:username).and_return("testuser")
  end

  describe "models" do
    # rails g scaffold Author name:string
    # rails g scaffold Post title:string description:text author:references
    # rails g scaffold Comment title:string content:text score:integer author:references post:references
    # rails g scaffold FlaggedForReview comment:references status:string
  end

  describe "#generate_index" do
    let(:prime_stack) { project.add_rails_project "prime", %i[rspec api simplecov standard factorybot] }
    let(:model) { instance_double(Mobilis::RailsModel, { name: "some_model" }) }
    let(:git_untracked_files) { [instance_double(Git::Status::StatusFile, { path: "some_filename" })] }
    let(:directory_service) do
      instance_double(Mobilis::Services::Directory, { git_untracked_files: git_untracked_files })
    end
    let(:file_lines) { instance_double(Mobilis::FileLines) }
    it "Generates correct index generation line" do
      allow(prime_stack).to receive(:rails_run_command).with("./bundle_run.sh rails generate migration SomeModelNameEmailIndex")
      expect(Mobilis::FileLines).to receive(:from_file).with(filename: "some_filename").and_return file_lines
      allow(file_lines).to receive(:gsub!).with("def change",
                                                "def change\n    add_index :some_model, [:name, :email], name: \"SomeModelNameEmailIndex\"")
      expect(file_lines).to receive(:save)
      prime_stack.send(:generate_index, directory_service, model, %w[name email])
    end
  end

  describe "#wait_until_line" do
    it "Generates correct line for MySQL" do
      prime_stack = project.add_rails_project "prime", %i[rspec api simplecov standard factorybot]
      project.add_mysql_instance "testm-db"
      prime_stack.set_links(["testm-db"])
      expect(prime_stack.wait_until_line).to eq <<~MYSQL_LINE
        /myapp/wait-until "mysql -D prime_production -h testm-db -u testm-db -ptestm-db_password -e 'select 1'"
      MYSQL_LINE
    end
    it "Generates correct line for Postgres" do
      prime_stack = project.add_rails_project "prime", %i[rspec api simplecov standard factorybot]
      project.add_postgresql_instance "testp-db"
      prime_stack.set_links(["testp-db"])
      expect(prime_stack.wait_until_line).to eq <<~POSTGRES_LINE
        /myapp/wait-until "psql $DATABASE_URL -c 'select 1'"
      POSTGRES_LINE
    end
  end
end
