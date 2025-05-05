RSpec.describe "#register" do
  let(:db_node) do
    instance_double("RealizedNode", name: "db", has_healthcheck?: true, dependant_services_require_restart?: false)
  end
  let(:search_node) do
    instance_double("RealizedNode", name: "search", has_healthcheck?: false, dependant_services_require_restart?: true)
  end
  let(:subject) { Mobilis::Compose::DependsOn.new }

  it "adds condition: service_healthy when healthcheck is present" do
    subject.register(db_node)
    expect(subject.as_json).to eq({
                                    db: { condition: "service_healthy" }
                                  })
  end

  it "adds condition: service_started and restart when needed" do
    subject.register(search_node)
    expect(subject.as_json).to eq({
                                    search: {
                                      condition: "service_started",
                                      restart: true
                                    }
                                  })
  end
end
