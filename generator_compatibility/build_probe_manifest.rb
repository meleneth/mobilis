# frozen_string_literal: true

require "bundler"
require "json"

specifications = Bundler.load.specs.sort_by { |specification| [specification.name, specification.version.to_s] }
native_specifications = specifications.select do |specification|
  specification.platform.to_s != "ruby" || !specification.extensions.empty?
end

manifest = {
  ruby_version: RUBY_VERSION,
  wasm_omitted: native_specifications.map do |specification|
    {
      name: specification.name,
      version: specification.version.to_s,
      platform: specification.platform.to_s,
      reason: "Host-native gem code cannot be loaded by Ruby WASM; use the standard runtime copy when one exists."
    }
  end,
  gems: specifications.map do |specification|
    {
      name: specification.name,
      version: specification.version.to_s,
      platform: specification.platform.to_s,
      path: specification.full_gem_path,
      require_paths: specification.require_paths.grep_v(%r{\A/})
    }
  end
}

puts JSON.pretty_generate(manifest)
