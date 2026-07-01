# frozen_string_literal: true

require "fileutils"

module Mobilis
  module ServiceWriter
    class PostgreSQL < Mobilis::Base::ServiceWriter
      def write
        write_primary_script if realized_node.primary_with_replicas?
        write_replica_entrypoint if realized_node.replica?
      end

      private

      def write_primary_script
        write_executable("init-replication-primary.sh", <<~SH)
          #!/usr/bin/env bash
          set -e

          cat >> "$PGDATA/pg_hba.conf" <<HBA
          host replication ${POSTGRES_REPLICATION_USER} all scram-sha-256
          HBA

          psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
          DO \\$\\$
          BEGIN
            IF NOT EXISTS (
              SELECT FROM pg_catalog.pg_roles
              WHERE rolname = '${POSTGRES_REPLICATION_USER}'
            ) THEN
              CREATE ROLE "${POSTGRES_REPLICATION_USER}" WITH REPLICATION LOGIN PASSWORD '${POSTGRES_REPLICATION_PASSWORD}';
            END IF;
          END
          \\$\\$;
          SQL
        SH
      end

      def write_replica_entrypoint
        write_executable("replica-entrypoint.sh", <<~SH)
          #!/usr/bin/env bash
          set -e

          if [ "$1" = "postgres" ] && [ ! -s "$PGDATA/PG_VERSION" ]; then
            chown -R postgres:postgres /var/lib/postgresql
            rm -rf "$PGDATA"/*

            until pg_isready -h "$POSTGRES_PRIMARY_HOST" -p "$POSTGRES_PRIMARY_PORT" -U "$POSTGRES_REPLICATION_USER"; do
              sleep 1
            done

            export PGPASSWORD="$POSTGRES_REPLICATION_PASSWORD"
            pg_basebackup \\
              -h "$POSTGRES_PRIMARY_HOST" \\
              -p "$POSTGRES_PRIMARY_PORT" \\
              -U "$POSTGRES_REPLICATION_USER" \\
              -D "$PGDATA" \\
              -Fp \\
              -Xs \\
              -P \\
              -R

            chown -R postgres:postgres /var/lib/postgresql
            chmod 700 "$PGDATA"
          fi

          exec docker-entrypoint.sh "$@"
        SH
      end

      def write_executable(path, content)
        File.binwrite(path, content.gsub("\r\n", "\n"))
        FileUtils.chmod("+x", path)
      end
    end
  end
end
