#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "uri"
require "yaml"

# Run after deployment. A gateway URL allows testing before DNS is installed:
# MOBILIS_GATEWAY_URL=http://127.0.0.1:18080 ruby scripts/kubernetes/verify.rb
project = ENV.fetch("MOBILIS_DEMO_PROJECT", "initial")
environment = ENV.fetch("MOBILIS_ENV", "dev")
base = "#{environment}.deva.station"
namespace = "#{project}-#{environment}"
context = ENV.fetch("MOBILIS_KUBE_CONTEXT", "kind-devastation")
gateway = ENV["MOBILIS_GATEWAY_URL"]

request = lambda do |host, path|
  url = URI("#{gateway || "http://#{host}"}#{path}")
  http = Net::HTTP.new(url.host, url.port, nil)
  http.use_ssl = url.scheme == "https"
  http.open_timeout = 5
  http.read_timeout = 10
  http.request(Net::HTTP::Get.new(url.request_uri, "Host" => host))
end

app_host = "#{project}.#{base}"
jaeger_host = "#{project}-jaeger.#{base}"
grafana_host = "#{project}-grafana.#{base}"
response = request.call(app_host, "/")
abort "App failed: #{response.code} #{response.body}" unless response.code == "200"
abort "Unexpected app response" unless JSON.parse(response.body).fetch("project") == project
%w[loki prometheus otel-collector alloy app-db app-db-cache app-db-cable app-db-queue].each do |service|
  response = request.call("#{project}-#{service}.#{base}", "/")
  abort "Private service #{service} received an external route" unless response.code == "404"
end

# Trace export and log delivery happen asynchronously.
def eventually(message)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
  loop do
    return if yield
    abort message if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep 2
  end
end

eventually("No demo.request trace in Jaeger") do
  response = request.call(jaeger_host, "/api/traces?service=app&limit=20")
  response.code == "200" && JSON.parse(response.body).fetch("data", []).any? do |trace|
    trace.fetch("spans", []).any? { |span| span["operationName"] == "demo.request" }
  end
end

# Grafana proxies requests to private data sources, proving the same path the UI uses.
grafana_request = lambda do |path|
  url = URI("#{gateway || "http://#{grafana_host}"}#{path}")
  http = Net::HTTP.new(url.host, url.port, nil)
  http.use_ssl = url.scheme == "https"
  req = Net::HTTP::Get.new(url.request_uri, "Host" => grafana_host)
  req.basic_auth("admin", "mobilis-admin")
  http.request(req)
end
response = grafana_request.call("/api/datasources")
abort "Grafana failed: #{response.code}" unless response.code == "200"
datasources = JSON.parse(response.body).to_h { |source| [source.fetch("type"), source.fetch("uid")] }
query = URI.encode_www_form(query: "mobilis_demo_requests_total")
eventually("Application metrics unavailable through Grafana") do
  response = grafana_request.call("/api/datasources/proxy/uid/#{datasources.fetch("prometheus")}/api/v1/query?#{query}")
  response.code == "200" && JSON.parse(response.body).dig("data", "result").any? { |result| result.fetch("value").last.to_f >= 1 }
end
query = URI.encode_www_form(query: '{service="app"} |= "Kubernetes demo request"', limit: 20)
eventually("Application logs unavailable through Grafana") do
  response = grafana_request.call("/api/datasources/proxy/uid/#{datasources.fetch("loki")}/loki/api/v1/query_range?#{query}")
  response.code == "200" && !JSON.parse(response.body).dig("data", "result").empty?
end

output, status = Open3.capture2("kubectl", "--context", context, "-n", namespace, "get", "services", "-o", "json")
abort "Cannot inspect Kubernetes Services" unless status.success?
services = JSON.parse(output).fetch("items")
expected_count = (environment == "prod") ? 11 : 8
abort "Unexpected ClusterIP services" unless services.size == expected_count && services.all? { |service| service.dig("spec", "type") == "ClusterIP" }
# Compare the user's generated artifact with project-only and environment queries.
root = ENV.fetch("MOBILIS_ARTIFACT_ROOT", File.expand_path("../../generate", __dir__))
expected = YAML.load_stream(File.read(File.join(root, "kubernetes", environment, "resources.yml")))
kinds = expected.map { |object| object.fetch("kind") }.uniq.join(",")
selector = "mobilis.io/project=#{project}"
output, status = Open3.capture2("kubectl", "--context", context, "get", kinds, "-A", "-l", selector, "-o", "json")
abort "Cannot discover project resources" unless status.success?
project_objects = JSON.parse(output).fetch("items")
expected.each do |object|
  live = project_objects.find do |candidate|
    candidate["kind"] == object["kind"] && candidate.dig("metadata", "name") == object.dig("metadata", "name") &&
      candidate.dig("metadata", "namespace") == object.dig("metadata", "namespace")
  end
  abort "Resource missing from project discovery: #{object["kind"]}/#{object.dig("metadata", "name")}" unless live
  labels = object.dig("metadata", "labels")
  abort "Missing ownership labels" unless labels.fetch("mobilis.io/project") == project && labels.fetch("mobilis.io/environment") == environment
  abort "Live ownership differs from artifact" unless labels.all? { |key, value| live.dig("metadata", "labels", key) == value }
end
output, status = Open3.capture2("kubectl", "--context", context, "get", kinds, "-A", "-l", "#{selector},mobilis.io/environment=#{environment}", "-o", "json")
abort "Cannot discover environment resources" unless status.success?
selected = JSON.parse(output).fetch("items")
abort "Environment discovery mismatch" unless selected.size == expected.size && selected.all? { |object| object.dig("metadata", "labels", "mobilis.io/environment") == environment }

puts "Verified #{namespace}: Istio endpoints, Rails trace in Jaeger, metrics and logs through Grafana, and private infrastructure."
