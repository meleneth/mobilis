RSpec.describe 'Factories' do
  let(:metaproject) { build(:metaproject) }
  let(:rails_project) { build(:rails_prime, metaproject: metaproject, name: "somerails") }
  let(:fsm) { rails_project ; build(:fsm, project: metaproject) }
  let(:prompt) { fsm.prompt }

    it "Assigns rails_project to metaproject" do
      rails_project
      expect(metaproject.projects[0].name).to eq("somerails")
    end
    it "Assigns metaproject to the rails project" do
      expect(rails_project.metaproject).to eq(metaproject)
    end
    it "Assigns metaproject to the fsm project" do
      expect(fsm.project).to eq(metaproject)
    end
    it "mention things to force them to build" do
      expect(fsm.state).to eq("main_menu")
      fsm.choices[4][:value].call
      expect(fsm.state).to eq("edit_project_menu")
      expect(fsm.choices[0][:name]).to eq("return to Main Menu")
      expect(fsm.project.projects[0]).to eq(rails_project)
      expect(fsm.choices[1][:name]).to eq("Edit 'somerails' project")
    end
end
