FactoryBot.define do
  factory :fsm, class: "Mobilis::InteractiveDesigner::MainMenu" do
    metaproject

    initialize_with do
      my_fsm = new
      my_fsm.project = metaproject if metaproject
      my_fsm
    end
  end
end
