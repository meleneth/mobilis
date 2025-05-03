# frozen_string_literal: true

require "yaml"
require "json"

module Mobilis
  module YAMLWriter
    def self.write_yaml(path, data)
      cleaned = clean_structure(data)
      File.write(path, ::YAML.dump(cleaned))
    end

    def self.clean_structure(data)
      # Converts symbols and weird objects to JSON-compatible plain data
      JSON.parse(JSON.dump(data))
    rescue => e
      raise "Mobilis::YAMLWriter failed to clean data structure for YAML output: #{e.message}"
    end
  end
end
