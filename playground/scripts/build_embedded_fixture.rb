# frozen_string_literal: true

require_relative "../../lib/mobilis/embedded_archive"

output = ARGV.fetch(0)
payload = Mobilis::EmbeddedArchive.pack(
  files: {
    "README.md" => "hello from the archive\n",
    "config/settings.txt" => "preserve this member\n"
  },
  entrypoint: "README.md",
  dependencies: ["rack"]
)
source = <<~RUBY
  # This comment and the second archive member must survive embedded edits.
  require "mobilis"

  Mobilis::DSL.generate("embedded-browser") do
    rack("api") do |service|
      service.embedded_archive("application-files", payload: #{payload.dump})
    end
    redis("cache")
    connect(from: "api", to: "cache")
  end
RUBY

File.write(output, source)
