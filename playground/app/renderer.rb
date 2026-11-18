# frozen_string_literal: true

require "haml"

module MobilisPlayground
  class Renderer
    TEMPLATE_ROOT = File.expand_path("../templates", __dir__)

    def initialize
      @templates = {}
    end

    def render(name, **locals)
      template(name).render(Object.new, locals)
    end

    def stream(action:, target:, html:)
      %(<turbo-stream action="#{action}" target="#{target}"><template>#{html}</template></turbo-stream>)
    end

    def apply(action:, target:, html:)
      JS.global[:Turbo].call(:renderStreamMessage, stream(action:, target:, html:))
    end

    private

    def template(name)
      @templates[name] ||= Haml::Template.new(filename: File.join(TEMPLATE_ROOT, "#{name}.haml")) do
        File.read(File.join(TEMPLATE_ROOT, "#{name}.haml"))
      end
    end
  end
end
