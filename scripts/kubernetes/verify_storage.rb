#!/usr/bin/env ruby
# frozen_string_literal: true

# Explicit durability experiment, separate from the read-only telemetry verifier.
# --replace-pod writes a marker and replaces only this demo's database pod.
# --write / --check bracket a user-managed rollout or runtime restart.
require "json"
require "open3"

mode = ARGV.fetch(0, "--check")
abort "Usage: verify_storage.rb [--write|--check|--replace-pod]" unless ARGV.size <= 1 && %w[--write --check --replace-pod].include?(mode)
project = ENV.fetch("MOBILIS_DEMO_PROJECT", "initial")
environment = ENV.fetch("MOBILIS_ENV", "dev")
abort "Invalid project/environment" unless project.match?(/\A[a-z0-9][a-z0-9-]*\z/) && %w[dev test prod].include?(environment)
rails_env = {"dev" => "development", "test" => "test", "prod" => "production"}.fetch(environment)
namespace = "#{project}-#{environment}"
kubectl = ["kubectl", "--context", ENV.fetch("MOBILIS_KUBE_CONTEXT", "kind-devastation"), "-n", namespace]
value = ENV.fetch("MOBILIS_DURABILITY_VALUE", "mobilis-durable-probe")
literal = "'#{value.gsub("'", "''")}'"
sql = lambda do |statement|
  Open3.capture3(*kubectl, "exec", "deployment/app-db", "--", "psql", "-U", "app-db-#{rails_env}-user",
    "-d", "app-db_#{rails_env}", "-v", "ON_ERROR_STOP=1", "-Atc", statement)
end
check = lambda do
  output, error, status = sql.call("SELECT count(*) FROM durability_records WHERE value = #{literal}")
  abort "Durability marker missing: #{error}" unless status.success? && output.strip.to_i >= 1
  puts "Database marker #{value.inspect} survives in #{namespace}."
end

if mode == "--check"
  check.call
  exit
end
output, error, status = sql.call("INSERT INTO durability_records (value, created_at, updated_at) VALUES (#{literal}, NOW(), NOW())")
abort "Cannot write marker: #{output} #{error}" unless status.success?
check.call
exit if mode == "--write"

selector = "mobilis.io/project=#{project},mobilis.io/environment=#{environment},mobilis.io/service=app-db"
abort "Cannot replace database pod" unless system(*kubectl, "delete", "pod", "-l", selector, "--wait=true")
abort "Database did not recover" unless system(*kubectl, "rollout", "status", "deployment/app-db", "--timeout=300s")
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
loop do
  output, _error, status = sql.call("SELECT to_regclass('public.durability_records')")
  break if status.success?
  abort "Database unavailable after replacement" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  sleep 2
end
if environment == "test"
  # A replacement emptyDir starts a fresh database. Do not run migrations or
  # otherwise repair it here; the normal disposable test lifecycle owns that.
  abort "Test database unexpectedly retained its schema" unless output.strip.empty?
  puts "Test database state was discarded after pod replacement in #{namespace}."
else
  check.call
end
