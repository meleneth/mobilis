# frozen_string_literal: true

require "json/pure"
raise "WASM JSON backend must be pure Ruby" unless defined?(JSON::Pure::Parser)
raise "WASM JSON parser failed" unless JSON.parse('{"ok":true}') == {"ok" => true}
raise "WASM JSON generator failed" unless JSON.generate({"ok" => true}) == '{"ok":true}'

require "js"
require "mobilis/browser_runtime"
require "renderer"
require "projection_invalidator"
require "application"

MobilisPlayground::Application.new.start
