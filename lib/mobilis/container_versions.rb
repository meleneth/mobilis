# frozen_string_literal: true

module Mobilis
  module ContainerVersions
    # ─── Language Runtimes ─────────────────────────────────────
    CRYSTAL     = "crystallang/crystal:1.9.2-alpine"
    GOLANG      = "golang:1.24.2-bookworm"
    JAVA        = "eclipse-temurin:21-jdk-jammy"
    NODE        = "node:20.10-bookworm"
    PYTHON      = "python:3.13.3-slim-bookworm"
    RUBY        = "ruby:3.4.3-bookworm"
    RUST        = "rust:1.86-bookworm"

    # ─── Databases ─────────────────────────────────────────────
    CASSANDRA   = "cassandra:4.1"
    COUCHDB     = "couchdb:3.4.3"
    MARIADB     = "mariadb:11.1.2-ubi"
    MEMCACHED   = "memcached:1.6.21-alpine"
    MONGODB     = "mongo:7.0.5"
    MYSQL       = "mysql:8.3"
    POSTGRES    = "postgres:17.4-bookworm"
    REDIS       = "redis:7.4.2-bookworm"
    SQLITE      = "nouchka/sqlite3:latest"
    VALKEY      = "valkey/valkey:7.2"

    # ─── Framework Stacks ──────────────────────────────────────
    AIRFLOW     = "apache/airflow:2.9.1-python3.11"
    FASTAPI     = "tiangolo/uvicorn-gunicorn-fastapi:python3.11"
    JEKYLL      = "jekyll/jekyll:4.3.3"
    RAILS_BUILDER = "ghcr.io/your-org/rails-builder:latest"

    # ─── Observability / Telemetry ─────────────────────────────
    GRAFANA     = "grafana/grafana:11.6.0"
    JAEGER      = "jaegertracing/all-in-one:1.53"
    LOKI        = "grafana/loki:2.9.2"
    OTEL_COLLECTOR = "otel/opentelemetry-collector-contrib:0.93.0"
    PROMETHEUS  = "prom/prometheus:v3.3.0"

    # ─── Messaging / Queues ────────────────────────────────────
    KAFKA       = "bitnami/kafka:4.0.0"
    NATS        = "nats:2.10.10"
    RABBITMQ    = "rabbitmq:3.13-management"

    # ─── Search / Indexing ─────────────────────────────────────
    ELASTICSEARCH = "elasticsearch:8.18.0"
    OPENSEARCH    = "opensearchproject/opensearch:2.12.0"

    # ─── Proxies / HTTP ────────────────────────────────────────
    CADDY       = "caddy:2.7.6"
    NGINX       = "nginx:1.27.5-bookworm"
    TRAEFIK     = "traefik:v2.10"

    # ─── Dev / Infra Tools ─────────────────────────────────────
    ALPINE      = "alpine:3.19"
    BUSYBOX     = "busybox:1.36.1"
    CURL        = "curlimages/curl:8.5.0"
    DIND        = "docker:dind"
    DIND_ROOTLESS = "docker:24.0.7-dind-rootless"
    GITLAB_RUNNER = "gitlab/gitlab-runner:alpine-v16.11.0"
    PGADMIN     = "dpage/pgadmin4:9.2.0"

    # ─── Misc ──────────────────────────────────────────────────
    HUGO        = "klakegg/hugo:0.123.3-ext-alpine"
    MINIO       = "minio/minio:RELEASE.2024-04-06T05-26-02Z"
    POSTGREST   = "postgrest/postgrest:v12.0.2"
  end
end
