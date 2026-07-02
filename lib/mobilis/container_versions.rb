# frozen_string_literal: true

module Mobilis
  module ContainerVersions
    # ─── Language Runtimes ─────────────────────────────────────
    CRYSTAL     = "crystallang/crystal:1.9.2-alpine"
    GOLANG      = "golang:1.25.3-trixie"
    JAVA        = "eclipse-temurin:21-jdk-jammy"
    NODE        = "node:24.15-trixie"
    PYTHON      = "python:3.14.4-trixie"
    RUBY        = "ruby:4.0.2-trixie"
    BUNDLER     = "4.0.6"
    RUST        = "rust:1.86-trixie"

    # ─── Databases ─────────────────────────────────────────────
    CASSANDRA   = "cassandra:4.1"
    COUCHDB     = "couchdb:3.5.0"
    MARIADB     = "mariadb:11.1.2-ubi"
    MEMCACHED   = "memcached:1.6.21-alpine"
    MONGODB     = "mongo:7.0.5"
    MYSQL       = "mysql:9.3.0"
    POSTGRES    = "postgres:18.3-trixie"
    REDIS       = "redis:8.6.2-trixie"
    VALKEY      = "valkey/valkey:7.2"

    # ─── Framework Stacks ──────────────────────────────────────
    AIRFLOW     = "apache/airflow:2.9.1-python3.11"
    FASTAPI     = "tiangolo/uvicorn-gunicorn-fastapi:python3.11"
    JEKYLL      = "jekyll/jekyll:4.3.3"
    RAILS_BUILDER = "ghcr.io/your-org/rails-builder:latest"

    # ─── Observability / Telemetry ─────────────────────────────
    GRAFANA     = "grafana/grafana:13.1.0"
    JAEGER      = "jaegertracing/jaeger:2.19.0"
    LOKI        = "grafana/loki:3.7.3"
    OTEL_COLLECTOR = "otel/opentelemetry-collector-contrib:0.155.0"
    PROMETHEUS  = "prom/prometheus:v3.5.4"
    ALLOY       = "grafana/alloy:latest"

    # ─── Messaging / Queues ────────────────────────────────────
    KAFKA       = "bitnami/kafka:4.0.0"
    NATS        = "nats:2.10.10"
    RABBITMQ    = "rabbitmq:3.13-management"
    LOCALSTACK  = "localstack/localstack:4.6.0"
    GOAWS       = "admiralpiett/goaws:v0.5.4"

    # ─── Search / Indexing ─────────────────────────────────────
    ELASTICSEARCH = "elasticsearch:8.18.0"
    OPENSEARCH    = "opensearchproject/opensearch:2.12.0"

    # ─── Proxies / HTTP ────────────────────────────────────────
    CADDY       = "caddy:2.7.6"
    NGINX       = "nginx:1.27.5-trixie"
    TRAEFIK     = "traefik:v2.10"

    # ─── Dev / Infra Tools ─────────────────────────────────────
    ALPINE      = "alpine:3.19"
    BUSYBOX     = "busybox:1.36.1"
    CURL        = "curlimages/curl:8.5.0"
    DIND        = "docker:dind"
    DIND_ROOTLESS = "docker:24.0.7-dind-rootless"
    GITLAB_RUNNER = "gitlab/gitlab-runner:alpine-v16.11.0"
    PGADMIN     = "dpage/pgadmin4:9.16"

    # ─── Misc ──────────────────────────────────────────────────
    HUGO        = "klakegg/hugo:0.123.3-ext-alpine"
    MINIO       = "minio/minio:RELEASE.2024-04-06T05-26-02Z"
    POSTGREST   = "postgrest/postgrest:v12.0.2"
  end
end
