# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"
require "tempfile"

RSpec.describe "Cassandra container integration", if: ENV["RUN_CASSANDRA_INTEGRATION"] == "1" do
  def docker!(*args)
    stdout, stderr, status = Open3.capture3("docker", *args)
    raise "docker #{args.first} failed: #{stdout}\n#{stderr}" unless status.success?
    stdout
  end

  it "initializes once, preserves records on restart, and serves authenticated CQL" do
    system = Mobilis::System.new("cass-live")
    dsl = Mobilis::DSL::DSLContext.new(system)
    node = dsl.cassandra("history") { |db| db.keyspace("approvals") }
    schema = Tempfile.new(["mobilis-cassandra-schema", ".cql"])
    schema.write("CREATE TABLE IF NOT EXISTS spec_records (id int PRIMARY KEY, value text);\n")
    schema.flush
    node.schema_file(schema.path)
    env = Mobilis::RealizedEnv.new(system, Mobilis::ExecutionEnvironment.new(:development))
    realized = env.realized_node_for_config_node(node)
    container = "mobilis-cass-spec-#{Process.pid}"
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { realized.service_writer.new(nil, env, realized).write }
      docker!("build", "-t", container, dir)
      docker!("run", "-d", "--name", container,
              "--health-cmd", "test -f /tmp/mobilis-cassandra-ready && cqlsh 127.0.0.1 9042 -u \"$MOBILIS_CASSANDRA_USER\" -p \"$MOBILIS_CASSANDRA_PASSWORD\" -e 'SELECT release_version FROM system.local' >/dev/null 2>&1",
              "--health-interval", "15s", "--health-start-period", "120s", "--health-retries", "20",
              "-e", "CASSANDRA_DC=datacenter1", "-e", "CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch",
              "-e", "MOBILIS_KEYSPACE=approvals", "-e", "MOBILIS_CASSANDRA_USER=mobilis_dev",
              "-e", "MOBILIS_CASSANDRA_PASSWORD=mobilis_dev_password", container)
      begin
        deadline = Time.now + 420
        loop do
          status = docker!("inspect", "--format", "{{.State.Health.Status}}", container).strip
          break if status == "healthy"
          raise "Cassandra not healthy: #{docker!("logs", container)}" if Time.now > deadline || status == "unhealthy"
          sleep 5
        end
        docker!("exec", container, "cqlsh", "127.0.0.1", "9042", "-u", "mobilis_dev", "-p", "mobilis_dev_password",
                "-e", "INSERT INTO approvals.spec_records (id, value) VALUES (1, 'kept');")
        docker!("restart", container)
        deadline = Time.now + 420
        loop do
          status = docker!("inspect", "--format", "{{.State.Health.Status}}", container).strip
          break if status == "healthy"
          raise "Cassandra restart failed: #{docker!("logs", container)}" if Time.now > deadline || status == "unhealthy"
          sleep 5
        end
        result = docker!("exec", container, "cqlsh", "127.0.0.1", "9042", "-u", "mobilis_dev", "-p", "mobilis_dev_password",
                         "-e", "SELECT value FROM approvals.spec_records WHERE id = 1;")
        expect(result).to include("kept")
      ensure
        docker!("rm", "-f", container)
        schema.close!
      end
    end
  end
end
