# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Mobilis::ServiceWriter::GoHTTP do
  [false, true].product([false, true]).each do |database, telemetry|
    it "writes conventional Go with database=#{database}, telemetry=#{telemetry}" do
      system = Mobilis::System.new("go")
      dsl = Mobilis::DSL::DSLContext.new(system)
      api = dsl.go_http("tiny-go", port: 8200)
      dsl.connect(from: api, to: dsl.postgres("store")) if database
      dsl.connect(from: api, to: dsl.otel_collector("traces")) if telemetry
      env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
      node = env.realized_node_by_name(api.name)
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          described_class.new(nil, env, node).write
          expect(File.read("go.mod")).to include("module mobilis.local/tiny-go", "go 1.25.0")
          expect(File.read("Dockerfile")).to include('CMD ["tiny-go"]', "CGO_ENABLED=0 go build", "EXPOSE 8200")
          expect(File.read("Dockerfile")).to include("FROM debian:trixie-slim", "apt-get install -y --no-install-recommends ca-certificates")
          expect(File.read("Dockerfile")).not_to include("alpine", "apk")
          main = File.read("cmd/tiny-go/main.go")
          expect(main).to include("signal.NotifyContext", "server.Shutdown(shutdownCtx)", "errors.Is(err, http.ErrServerClosed)", "defer cleanup()")
          app = File.read("internal/app/app.go")
          expect(app).to include("http.NewServeMux()", '"GET /health"')
          if database
            expect(app).to include('pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))', "pool.Ping(pingCtx)", "pool.Close()")
            expect(node.env_vars_for_env_file.map(&:env_repr)).to include("TINY_GO_DATABASE_URL=postgres://store-test-user:store-test-password@store:5432/store_test")
          else
            expect(File.read("go.mod")).not_to include("pgx")
          end
          if telemetry
            expect(app).to include("otelhttp.NewHandler", "otelhttp.NewTransport")
            expect(File.read("internal/app/telemetry.go")).to include("propagation.TraceContext{}", "resource.WithFromEnv()", "otlptracehttp.New(ctx)")
            expect(app).to include("cfg.ConnConfig.Tracer = otelpgx.NewTracer()") if database
          else
            expect(File.read("go.mod")).not_to include("opentelemetry")
            expect(File).not_to exist("internal/app/telemetry.go")
          end
        end
      end
    end
  end
end
