#!/usr/bin/env ruby
# frozen_string_literal: true

# Copied into the generated project; no Mobilis installation required at deploy time.
require "json"
require "open3"
require "yaml"

abort "Usage: ./deploy-kubernetes [dev|test|prod]" if ARGV.size > 1
ENVIRONMENT = ARGV.fetch(0, "dev")
abort "Expected dev, test, or prod" unless %w[dev test prod].include?(ENVIRONMENT)
Dir.chdir(__dir__)
DIRECTORY = "kubernetes/#{ENVIRONMENT}"
UNIVERSE = JSON.parse(File.read("#{DIRECTORY}/universe.json"))
CONTEXT = ENV.fetch("MOBILIS_KUBE_CONTEXT", "kind-devastation")
KUBECTL = ["kubectl", "--context", CONTEXT].freeze
NAMESPACE = UNIVERSE.fetch("namespace")

# Use argv throughout: names, file paths, and build args are never shell code.
def run!(*args)
  puts "+ #{args.join(" ")}"
  abort "Command failed: #{args.first}" unless system(*args)
end

def query!(*args, allow_missing: false)
  output, error, status = Open3.capture3(*KUBECTL, *args)
  return nil if allow_missing && !status.success? && error.include?("(NotFound)")
  abort error unless status.success?
  JSON.parse(output)
end

%w[gateways.networking.istio.io virtualservices.networking.istio.io].each do |crd|
  query!("get", "crd", crd, "-o", "json")
end
query!("get", "deployment", "istiod", "-n", "istio-system", "-o", "json")
query!("get", "deployment", "istio-ingressgateway", "-n", "istio-system", "-o", "json")

expected = {"app.kubernetes.io/managed-by" => "mobilis", "mobilis.io/project" => UNIVERSE.fetch("project"),
            "mobilis.io/environment" => ENVIRONMENT}
namespace = query!("get", "namespace", NAMESPACE, "-o", "json", allow_missing: true)
if namespace && !expected.all? { |key, value| namespace.dig("metadata", "labels", key) == value }
  abort "Namespace collision: #{NAMESPACE} is not owned by this Mobilis project/environment"
end

hosts = UNIVERSE.fetch("public").values
query!("get", "virtualservices.networking.istio.io", "-A", "-o", "json").fetch("items").each do |route|
  next if route.dig("metadata", "namespace") == NAMESPACE && expected.all? { |key, value| route.dig("metadata", "labels", key) == value }
  collisions = hosts.select do |host|
    route.fetch("spec").fetch("hosts", []).any? { |existing| existing == host || (existing.start_with?("*.") && host.end_with?(existing.delete_prefix("*"))) || existing == "*" }
  end
  abort "Hostname collision: #{collisions.join(", ")}" unless collisions.empty?
end

JSON.parse(File.read("#{DIRECTORY}/builds.json")).each do |entry|
  build = entry.fetch("build")
  args = ["docker", "build", "-t", entry.fetch("image")]
  args.concat(["-f", File.join(build.fetch("context"), build.fetch("dockerfile"))]) if build["dockerfile"]
  args.concat(["--target", build["target"]]) if build["target"]
  (build["args"] || {}).each { |name, value| args.concat(["--build-arg", "#{name}=#{value}"]) }
  run!(*args, build.fetch("context"))
  run!("docker", "push", entry.fetch("image"))
end
run!(*KUBECTL, "apply", "-f", "#{DIRECTORY}/resources.yml")

# Remove previously generated objects that disappeared from the declaration,
# including removed public routes. Never prune unowned resources or namespaces.
kinds = %w[Deployment Service ConfigMap Gateway VirtualService ServiceAccount Role RoleBinding]
api_kinds = %w[deployments services configmaps gateways.networking.istio.io virtualservices.networking.istio.io serviceaccounts roles rolebindings]
desired = YAML.load_stream(File.read("#{DIRECTORY}/resources.yml")).map { |object| [object.fetch("kind"), object.dig("metadata", "name")] }
selector = expected.map { |key, value| "#{key}=#{value}" }.join(",")
query!("get", api_kinds.join(","), "-n", NAMESPACE, "-l", selector, "-o", "json").fetch("items").each do |object|
  identity = [object.fetch("kind"), object.dig("metadata", "name")]
  next if desired.include?(identity)
  run!(*KUBECTL, "delete", api_kinds.fetch(kinds.index(identity.first)), identity.last, "-n", NAMESPACE)
end

# Local environment image tags are stable; restarting pulls the latest build.
JSON.parse(File.read("#{DIRECTORY}/builds.json")).each do |entry|
  run!(*KUBECTL, "rollout", "restart", "deployment/#{entry.fetch("service")}", "-n", NAMESPACE)
end
run!(*KUBECTL, "rollout", "status", "deployment", "-n", NAMESPACE, "-l", selector, "--timeout=300s")
UNIVERSE.fetch("public").each { |service, host| puts "#{service}: http://#{host}" }
