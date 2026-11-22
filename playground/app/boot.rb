# frozen_string_literal: true

# Fail at the dependency boundary, before Mobilis loads any application code.
require "json"
raise "Ruby WASM JSON release mismatch: #{JSON::VERSION}" unless JSON::VERSION == "3.1.0"
raise "Ruby WASM must use native JSON parser" unless defined?(JSON::Ext::Parser)
raise "Ruby WASM JSON parser failed" unless JSON.parse('{"ok":true}') == {"ok" => true}
raise "Ruby WASM JSON generator failed" unless JSON.generate({"ok" => true}) == '{"ok":true}'
raise "Ruby WASM native JSON generator API mismatch" unless JSON::Ext::Generator::State.respond_to?(:default_sort_keys_proc=)

require "js"
require "mobilis/browser_runtime"
require "diesl"
require "carbn"
require "mobilis/browser/diesl_editor"
require "renderer"
require "application"

MobilisPlayground::Application.new.start
