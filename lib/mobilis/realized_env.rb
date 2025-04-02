# frozen_string_literal: true

require "yaml"
require "fileutils"
require "open3"

module Mobilis
  class RealizedEnv
    def generate_nasty_postgres_compose!
      compose = {
        "services" => {
          "db" => {
            "image" => "postgres:16",
            "environment" => {
              "POSTGRES_USER" => "mobilis",
              "POSTGRES_PASSWORD" => "mobilis",
              "POSTGRES_DB" => "mobilis_dev"
            },
            "ports" => ["5432:5432"],
            "volumes" => ["db_data:/var/lib/postgresql/data"]
          }
        },
        "volumes" => {
          "db_data" => {}
        }
      }

      path = build_dir
      FileUtils.mkdir_p(path)
      File.write("#{path}/docker-compose.yml", compose.to_yaml)
      puts "💾 Dirty docker-compose written to #{path}/docker-compose.yml"
    end

    def run_nasty_compose!
      Dir.chdir(build_dir) do
        puts "💥 Spinning up dirty docker-compose..."
        puts "docker compose build"
        system("docker compose build")
        puts "docker compose up --detach"
        system("docker compose up --detach") || raise("🔥 docker compose up failed")
      end
    end

    def destroy_nasty_compose!
      Dir.chdir(build_dir) do
        puts "🧹 Nuking docker-compose stack..."
        system("docker compose down -v") || warn("⚠️ docker compose down failed")
      end
    end

    def build_dir
      File.expand_path("tmp/nasty_pg_env", Dir.pwd)
    end
  end
end
