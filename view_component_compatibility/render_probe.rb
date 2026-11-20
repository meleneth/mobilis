# frozen_string_literal: true

require "json"
require "erb"
require "action_view"
require "view_component"

# This intentionally uses the real ViewComponent base class and its render_in
# lifecycle rather than a proxy renderer or an Haml fallback.
module MobilisViewComponentProbe
  class Value < ViewComponent::Base
    def initialize(value:)
      @value = value
    end

    def call
      content_tag(:span, @value)
    end
  end

  class Group < ViewComponent::Base
    def initialize(value:)
      @value = value
    end

    def call
      content_tag(:section) { render(Value.new(value: @value)) }
    end
  end
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
context = ActionView::Base.empty
html = MobilisViewComponentProbe::Group.new(value: "<unsafe> & friends").render_in(context)
elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000

JSON.generate(
  ruby: RUBY_VERSION,
  component_base: ViewComponent::Base.name,
  nested_html: html,
  render_ms: elapsed_ms
)
