# frozen_string_literal: true

require "mobilis/interactive_designer/main_menu"

RSpec.describe 'RailsModelEdit' do
  let(:metaproject) { build(:metaproject) }
  let(:rails_project) do
    p = build(:rails_prime, metaproject: metaproject)
    m = p.add_model("Author")
    m.add_field(name: "name", type: Mobilis::RAILS_MODEL_TYPE_STRING)
    p
  end
  let(:fsm) { rails_project ; build(:fsm, project: metaproject) }
  let(:prompt) { fsm.prompt }
  let(:nav) { FSMNavigator.new fsm: fsm }

  describe "Can get to model edit screen" do
    let(:name_field) { {name: "name", type: :string} }
    let(:author_field) { {name: "author", type: :references} }
    let(:post_model) { {name: "Post", fields: [author_field, subject_field] } }
    let(:author_model) { {name: 'Author', fields: [name_field]} }
    let(:subject_field) { {name: "subject", type: :string} }
    let(:options) { [:rspec, :api, :simplecov, :standard, :factorybot] }
    let(:models) { [author_model, post_model] }
    let(:expected) do
      {
        name: "rails_project",
        type: :rails,
        controllers: [],
        models: models,
        options: options,
        attributes: {},
        links: []
      }
     end
    it "starts out simple" do
      nav.select_choice("Edit existing")
      expect(fsm.state).to eq "edit_project_menu"
      nav.select_choice("rails_project")
      expect(fsm.state).to eq "rails_project_edit"
      nav.select_choice("Add Model")
      expect(fsm.state).to eq "rails_project_add_model"
      expect(prompt).to receive(:ask).and_return "Post"
      fsm.action
      puts "took action"
      expect(fsm.state).to eq "rails_model_edit"
      nav.select_choice("Add field")
      expect(fsm.state).to eq "rails_model_add_field_select_type"
      nav.select_choice('references')
      expect(fsm.state).to eq "rails_model_add_field_references_select_model"
      nav.select_choice("Author")
      expect(fsm.state).to eq "rails_model_edit"
      nav.select_choice("Add field")
      expect(fsm.state).to eq "rails_model_add_field_select_type"
      nav.select_choice('string')
      expect(fsm.state).to eq "rails_model_add_field_enter_name"
      expect(prompt).to receive(:ask).and_return "subject"
      fsm.action
      puts "Took action"
      expect(rails_project.to_json).to eq(expected)
    end
  end
end
