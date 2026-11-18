# frozen_string_literal: true

RSpec.describe Mobilis::Browser::SemanticRuntime do
  subject(:runtime) { described_class.new }

  it "counts and times only explicitly measured semantic requests" do
    expect(runtime.invocation_count).to eq(0)
    expect(runtime.measure("validate") { :result }).to eq(:result)

    expect(runtime.invocation_count).to eq(1)
    expect(runtime.last_label).to eq("validate")
    expect(runtime.last_duration_ms).to be >= 0
    expect(runtime.total_duration_ms).to eq(runtime.last_duration_ms)
  end

  it "records failed requests while preserving their exception" do
    expect { runtime.measure("failure") { raise ArgumentError, "nope" } }
      .to raise_error(ArgumentError, "nope")
    expect(runtime).to have_attributes(invocation_count: 1, last_label: "failure")
  end
end
