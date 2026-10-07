# frozen_string_literal: true

require "fileutils"

module Mobilis
  module ServiceWriter
    class GoHTTP < Mobilis::Base::ServiceWriter
      def write
        FileUtils.mkdir_p("cmd/#{realized_node.name}")
        FileUtils.mkdir_p("internal/app")
        File.write("go.mod", <<~GO)
          module mobilis.local/#{realized_node.name}

          go 1.25.0

          require (
          #{dependencies.map { |name, version| "\t#{name} #{version}" }.join("\n")}
          )
        GO
        File.write("Dockerfile", <<~DOCKER)
          FROM #{Mobilis::ContainerVersions::GOLANG} AS build
          WORKDIR /src
          COPY . .
          RUN go mod tidy && CGO_ENABLED=0 go build -trimpath -o /service ./cmd/#{realized_node.name}
          FROM #{Mobilis::ContainerVersions::DEBIAN}
          RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
          COPY --from=build /service /usr/local/bin/#{realized_node.name}
          USER 65532:65532
          EXPOSE #{realized_node.exposed_port_no}
          CMD ["#{realized_node.name}"]
        DOCKER
        write_main
        write_app
        write_telemetry if realized_node.otel_enabled?
        realized_node.each_model_of_type(Mobilis::Model::File, &:write_file)
      end

      private

      def dependencies
        # @type var deps: Hash[String, String]
        deps = {}
        deps["github.com/jackc/pgx/v5"] = "v5.7.6" if realized_node.database
        if realized_node.otel_enabled?
          deps.merge!(
            "go.opentelemetry.io/otel" => "v1.38.0",
            "go.opentelemetry.io/otel/sdk" => "v1.38.0",
            "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp" => "v1.38.0",
            "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp" => "v0.63.0"
          )
          deps["github.com/exaring/otelpgx"] = "v0.9.3" if realized_node.database
        end
        deps
      end

      def write_main
        File.write("cmd/#{realized_node.name}/main.go", <<~GO)
          package main

          import (
              "context"
              "errors"
              "log"
              "net/http"
              "os"
              "os/signal"
              "syscall"
              "time"
              "mobilis.local/#{realized_node.name}/internal/app"
          )

          func run() error {
              ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
              defer stop()
              handler, cleanup, err := app.New(ctx)
              if err != nil { return err }
              defer cleanup()
              port := os.Getenv("PORT")
              if port == "" { port = "#{realized_node.exposed_port_no}" }
              server := &http.Server{Addr: ":" + port, Handler: handler, ReadHeaderTimeout: 5*time.Second}
              result := make(chan error, 1)
              go func() { result <- server.ListenAndServe() }()
              select {
              case err := <-result:
                  if !errors.Is(err, http.ErrServerClosed) { return err }
              case <-ctx.Done():
                  shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
                  defer cancel()
                  if err := server.Shutdown(shutdownCtx); err != nil { _ = server.Close(); return err }
                  if err := <-result; !errors.Is(err, http.ErrServerClosed) { return err }
              }
              return nil
          }

          func main() {
              if err := run(); err != nil { log.Fatal(err) }
          }
        GO
      end

      def write_app
        imports = ['"context"', '"net/http"', '"time"']
        imports.concat(['"os"', '"time"', '"github.com/jackc/pgx/v5/pgxpool"']) if realized_node.database
        imports << '"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"' if realized_node.otel_enabled?
        imports << '"github.com/exaring/otelpgx"' if realized_node.otel_enabled? && realized_node.database
        # @type var setup: Array[String]
        setup = []
        # @type var cleanup: Array[String]
        cleanup = []
        if realized_node.otel_enabled?
          setup.concat(["shutdown, err := configureTelemetry(ctx)", "if err != nil { return nil, nil, err }"])
          cleanup.concat(["shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)", "defer cancel()", 'if err := shutdown(shutdownCtx); err != nil { log.Printf("telemetry shutdown: %v", err) }'])
          imports << '"log"'
        end
        setup << "var pool *pgxpool.Pool" if realized_node.database
        cleanup.unshift("if pool != nil { pool.Close() }") if realized_node.database
        setup << "cleanup := func() {\n        #{cleanup.join("\n        ")}\n    }"
        if realized_node.database
          setup << 'cfg, err := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))'
          setup << "if err != nil { cleanup(); return nil, nil, err }"
          setup << "cfg.ConnConfig.Tracer = otelpgx.NewTracer()" if realized_node.otel_enabled?
          setup << "pool, err = pgxpool.NewWithConfig(ctx, cfg)"
          setup << "if err != nil { cleanup(); return nil, nil, err }"
          setup << "pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)"
          setup << "err = pool.Ping(pingCtx)"
          setup << "cancel()"
          setup << "if err != nil { cleanup(); return nil, nil, err }"
        end
        client = realized_node.otel_enabled? ? "&http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}" : "&http.Client{}"
        fields = ["HTTPClient *http.Client"]
        fields << "DB *pgxpool.Pool" if realized_node.database
        File.write("internal/app/app.go", <<~GO)
          package app

          import (
              #{imports.uniq.join("\n    ")}
          )

          type Dependencies struct {
              #{fields.join("\n    ")}
          }

          func New(ctx context.Context) (http.Handler, func(), error) {
              #{setup.join("\n    ")}
              deps := Dependencies{HTTPClient: #{client}#{", DB: pool" if realized_node.database}}
              deps.HTTPClient.Timeout = 10*time.Second
              mux := http.NewServeMux()
              mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
                  w.Header().Set("Content-Type", "application/json")
                  _, _ = w.Write([]byte(`{"status":"ok"}`))
              })
              register(mux, deps)
              return #{realized_node.otel_enabled? ? 'otelhttp.NewHandler(mux, "http")' : "mux"}, cleanup, nil
          }
        GO
        File.write("internal/app/routes.go", <<~GO)
          package app

          import "net/http"

          func register(mux *http.ServeMux, deps Dependencies) {}
        GO
      end

      def write_telemetry
        File.write("internal/app/telemetry.go", <<~GO)
          package app

          import (
              "context"
              "go.opentelemetry.io/otel"
              "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
              "go.opentelemetry.io/otel/propagation"
              "go.opentelemetry.io/otel/sdk/resource"
              sdktrace "go.opentelemetry.io/otel/sdk/trace"
          )

          func configureTelemetry(ctx context.Context) (func(context.Context) error, error) {
              exporter, err := otlptracehttp.New(ctx)
              if err != nil { return nil, err }
              res, err := resource.New(ctx, resource.WithFromEnv(), resource.WithTelemetrySDK())
              if err != nil { _ = exporter.Shutdown(ctx); return nil, err }
              provider := sdktrace.NewTracerProvider(sdktrace.WithResource(res), sdktrace.WithBatcher(exporter),
                  sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.AlwaysSample())))
              otel.SetTracerProvider(provider)
              otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
              return provider.Shutdown, nil
          }
        GO
      end
    end
  end
end
