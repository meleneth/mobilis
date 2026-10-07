# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Mobilis::ServiceWriter::FastAPI do
  def generate(database: true, telemetry: true)
    system = Mobilis::System.new("python")
    dsl = Mobilis::DSL::DSLContext.new(system)
    api = dsl.fastapi("tiny-api", port: 8100)
    if database
      dsl.connect(from: api, to: dsl.postgres("store"))
      api.add_sqlalchemy_model("Item", table: "items") do |m|
        m.column("id", "Integer", python_type: "int", primary_key: true)
        m.column("name", "String(80)", python_type: "str", nullable: true, unique: true, default: '"unnamed"')
        m.column("enabled", "Boolean", python_type: "bool", default: true)
        m.column("parent_id", "Integer", python_type: "int", nullable: true, foreign_key: "items.id")
      end
    end
    dsl.connect(from: api, to: dsl.otel_collector("traces")) if telemetry
    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:test))
    described_class.new(nil, env, env.realized_node_by_name(api.name)).write
  end

  it "writes an installable package with an owned console entry point and typed declarative models" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        generate
        expect(File.read("pyproject.toml")).to include('tiny-api = "service_tiny_api.cli:main"', 'where = ["src"]', "psycopg[binary]")
        expect(File.read("pyproject.toml")).to include("[project.optional-dependencies]", "pytest>=", "pytest-cov>=", "flexmock>=", '["tests"]', 'source = ["service_tiny_api"]', "branch = true")
        expect(File.read("pyproject.toml").split("[project.optional-dependencies]").first).not_to include("pytest", "flexmock", "coverage")
        expect(File.read("tests/test_health.py")).to include("TestClient", "create_app(telemetry=False)")
        expect(File.read("Dockerfile")).to include("RUN pip install --no-cache-dir .", 'CMD ["tiny-api"]', "EXPOSE 8100")
        expect(File.read("src/service_tiny_api/cli.py")).to include("uvicorn.run(create_app()")
        expect(File.read("src/service_tiny_api/database.py")).to include('os.environ["DATABASE_URL"]', "postgresql+psycopg")
        expect(File.read("src/service_tiny_api/models.py")).to include("class Item(Base):", '__tablename__ = "items"', "Mapped[str | None]", "sa.String(80)", 'default="unnamed"', 'ForeignKey("items.id")', "default=True")
        expect(File.read("src/service_tiny_api/telemetry.py")).to include("SQLAlchemyInstrumentor().instrument(engine=engine)", "HTTPXClientInstrumentor().instrument()", 'exclude_spans=["receive", "send"]')
        expect(File.read("src/service_tiny_api/telemetry.py")).not_to include("PsycopgInstrumentor", "traces:")
        expect(File.read("src/service_tiny_api/app.py")).to include("instrument_app(app)", "provider.shutdown()", "get_engine().dispose()")
        expect(File.read("src/service_tiny_api/app.py")).to include("def create_app(*, telemetry=True):", "if telemetry else None")
        expect(File.read("src/service_tiny_api/database.py")).to include("def get_engine():", "def get_session():")
        expect(Dir["*.py"]).to be_empty
        expect(system("python3", "-m", "compileall", "-q", "src")).to be(true)
      end
    end
  end

  it "omits database and tracing dependencies and bootstrap when unconnected" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        generate(database: false, telemetry: false)
        expect(File.read("pyproject.toml")).not_to include("SQLAlchemy", "opentelemetry", "psycopg")
        expect(File).not_to exist("src/service_tiny_api/telemetry.py")
        expect(File).not_to exist("src/service_tiny_api/database.py")
        expect(File.read("src/service_tiny_api/app.py")).to include('@app.get("/health")')
        expect(system("python3", "-m", "compileall", "-q", "src")).to be(true)
      end
    end
  end
end
