# frozen_string_literal: true

require "fileutils"

module Mobilis
  module ServiceWriter
    class Cassandra < Mobilis::Base::ServiceWriter
      def write
        node = realized_node.config_node
        schema = node.schema_path ? File.read(node.schema_path) : ""
        validate_schema!(schema)
        File.write("schema.cql", schema)
        File.write("Dockerfile", <<~DOCKER)
          FROM #{realized_node.source_image}
          USER root
          RUN sed -i 's/^authenticator: AllowAllAuthenticator$/authenticator: PasswordAuthenticator/; s/^authorizer: AllowAllAuthorizer$/authorizer: CassandraAuthorizer/' /etc/cassandra/cassandra.yaml
          COPY --chmod=755 entrypoint.sh /usr/local/bin/mobilis-cassandra-entrypoint
          COPY schema.cql /opt/mobilis/schema.cql
          ENTRYPOINT ["mobilis-cassandra-entrypoint"]
          CMD ["cassandra", "-f"]
        DOCKER
        File.write("entrypoint.sh", <<~'SH')
          #!/usr/bin/env bash
          set -Eeuo pipefail
          rm -f /tmp/mobilis-cassandra-ready
          if [[ "$MOBILIS_CASSANDRA_USER" == REPLACE_* || "$MOBILIS_CASSANDRA_PASSWORD" == REPLACE_* ]]; then
            echo 'Cassandra credentials must be set in the generated production.env' >&2
            exit 1
          fi
          if [[ ! "$MOBILIS_CASSANDRA_USER" =~ ^[a-z][a-z0-9_]*$ || ! "$MOBILIS_CASSANDRA_PASSWORD" =~ ^[A-Za-z0-9_@!.-]+$ ]]; then
            echo 'Cassandra credentials contain unsupported CQL characters' >&2
            exit 1
          fi
          docker-entrypoint.sh "$@" &
          server=$!
          trap 'kill "$server" 2>/dev/null || true' EXIT
          ready=0
          for attempt in $(seq 1 90); do
            if ! kill -0 "$server" 2>/dev/null; then
              echo 'Cassandra exited before CQL became available; inspect container logs' >&2
              wait "$server"
              exit 1
            fi
            if cqlsh 127.0.0.1 9042 -u cassandra -p cassandra -e 'SELECT release_version FROM system.local' >/dev/null 2>&1; then
              ready=1
              break
            fi
            sleep 4
          done
          if [[ "$ready" != 1 ]]; then
            echo 'Cassandra CQL did not become available within 360 seconds' >&2
            exit 1
          fi
          # Existing roles and data survive restarts. A changed password is applied deliberately.
          printf "CREATE ROLE IF NOT EXISTS %s WITH PASSWORD = '%s' AND LOGIN = true;\n" "$MOBILIS_CASSANDRA_USER" "$MOBILIS_CASSANDRA_PASSWORD" > /tmp/mobilis-role.cql
          if ! cqlsh 127.0.0.1 9042 -u cassandra -p cassandra -f /tmp/mobilis-role.cql; then
            echo 'Cassandra role initialization failed' >&2
            exit 1
          fi
          rm -f /tmp/mobilis-role.cql
          if [[ -n "${MOBILIS_KEYSPACE:-}" ]]; then
            printf "CREATE KEYSPACE IF NOT EXISTS %s WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};\n" "$MOBILIS_KEYSPACE" > /tmp/mobilis-keyspace.cql
            if ! cqlsh 127.0.0.1 9042 -u cassandra -p cassandra -f /tmp/mobilis-keyspace.cql; then
              echo "Cassandra keyspace initialization failed: $MOBILIS_KEYSPACE" >&2
              exit 1
            fi
            rm -f /tmp/mobilis-keyspace.cql
            printf 'GRANT SELECT ON KEYSPACE %s TO %s;\nGRANT MODIFY ON KEYSPACE %s TO %s;\n' "$MOBILIS_KEYSPACE" "$MOBILIS_CASSANDRA_USER" "$MOBILIS_KEYSPACE" "$MOBILIS_CASSANDRA_USER" > /tmp/mobilis-grant.cql
            if ! cqlsh 127.0.0.1 9042 -u cassandra -p cassandra -f /tmp/mobilis-grant.cql; then
              echo "Cassandra keyspace grant failed: $MOBILIS_KEYSPACE" >&2
              exit 1
            fi
            rm -f /tmp/mobilis-grant.cql
            if [[ -s /opt/mobilis/schema.cql ]] && ! cqlsh 127.0.0.1 9042 -u cassandra -p cassandra -k "$MOBILIS_KEYSPACE" -f /opt/mobilis/schema.cql; then
              echo "Cassandra schema initialization failed for $MOBILIS_KEYSPACE" >&2
              exit 1
            fi
          fi
          touch /tmp/mobilis-cassandra-ready
          wait "$server"
        SH
        FileUtils.chmod("+x", "entrypoint.sh")
      end

      private

      def validate_schema!(schema)
        return if schema.strip.empty?
        raise ArgumentError, "Cassandra schema requires a keyspace" unless realized_node.config_node.keyspace_name
        statements = schema.gsub(/--[^\n]*/, "").split(";").map(&:strip).reject(&:empty?)
        statements.each do |statement|
          unless statement.match?(/\ACREATE\s+(?:TABLE|TYPE|INDEX|CUSTOM INDEX)\s+IF\s+NOT\s+EXISTS\b/i)
            raise ArgumentError, "Cassandra schema permits only CREATE ... IF NOT EXISTS statements for repeatable startup"
          end
        end
      end
    end
  end
end
