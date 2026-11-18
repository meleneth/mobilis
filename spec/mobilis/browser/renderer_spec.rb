# frozen_string_literal: true

require "haml"
require_relative "../../../playground/app/renderer"

RSpec.describe MobilisPlayground::Renderer do
  it "renders Haml components without a server framework" do
    html = described_class.new.render(
      :diagnostics,
      errors: [],
      status: "Runtime initialized"
    )

    expect(html).to include("Runtime initialized")
    expect(html).to include("border-teal-950")
  end

  it "renders Turbo Stream messages for targeted updates" do
    stream = described_class.new.stream(action: "replace", target: "diagnostics-region", html: "<p>ok</p>")

    expect(stream).to eq('<turbo-stream action="replace" target="diagnostics-region"><template><p>ok</p></template></turbo-stream>')
  end
end
