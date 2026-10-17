# frozen_string_literal: true

require "fileutils"

module Mobilis
  module ServiceWriter
    class Airflow < Mobilis::Base::ServiceWriter
      VERSION = "3.1.0"
      PYTHON = "3.12"

      def write
        FileUtils.mkdir_p("dags")
        FileUtils.mkdir_p("../packages")
        packages = realized_node.config_node.each_model_of_type(Mobilis::Model::LocalPythonPackage).to_a.uniq(&:name)
        packages.each { |package| package.write_files("../packages/#{package.name}") }
        realized_node.each_model_of_type(Mobilis::Model::File, &:write_file)
        extras = realized_node.collector ? "[celery,postgres,redis,fab,otel]" : "[celery,postgres,redis,fab]"
        File.write("Dockerfile", <<~DOCKER)
          FROM apache/airflow:#{VERSION}-python#{PYTHON}
          COPY --chown=airflow:0 packages /opt/airflow/local-packages
          COPY --chown=airflow:0 #{realized_node.name}/validate_dags.py /opt/airflow/validate_dags.py
          RUN pip install --no-cache-dir --constraint https://raw.githubusercontent.com/apache/airflow/constraints-#{VERSION}/constraints-#{PYTHON}.txt \\
              "apache-airflow#{extras}==#{VERSION}" #{packages.map { |pkg| "/opt/airflow/local-packages/#{pkg.name}" }.join(" ")}
        DOCKER
        File.write("validate_dags.py", <<~PYTHON)
          from airflow.models.dagbag import DagBag

          bag = DagBag(dag_folder="/opt/airflow/dags", include_examples=False)
          assert not bag.import_errors, bag.import_errors
          assert bag.dags, "no DAGs discovered"
          if set(#{realized_node.config_node.each_model_of_type(Mobilis::Model::File).map { |file| File.basename(file.path, ".py") }.to_json}) == {"ingest", "aggregate", "report"}:
              assert {"demo_ingest", "demo_aggregate", "demo_report"} <= set(bag.dags)
              ingest = bag.dags["demo_ingest"]
              for upstream in ("normalize_west", "normalize_east"):
                  assert "load" in ingest.task_dict[upstream].downstream_task_ids
              assert "normalize_west" in ingest.task_dict["extract_west"].downstream_task_ids
              assert "normalize_east" in ingest.task_dict["extract_east"].downstream_task_ids
          print("DAG imports, discovery and task dependencies validated")
        PYTHON
        File.write("README.md", <<~MD)
          # #{realized_node.name}

          Generated Airflow #{VERSION} on Python #{PYTHON}. Edit DAGs in `dags/` directly; they are mounted into the parser and workers.
          Edit packages in `../packages/`, then run `../dc_dev build` and `../dc_dev up -d` from this directory. The Docker image installs distributions through pip; it does not depend on Mobilis or PYTHONPATH.

          From the project root, independently test packages with `python#{PYTHON} -m venv .venv`,
          `. .venv/bin/activate`, `pip install -e 'packages/PACKAGE[test]'`, and `pytest packages/PACKAGE/tests`.
          Airflow image installs use the Apache Airflow #{VERSION} constraints for Python #{PYTHON}; package dependencies must be compatible with that set.
          The generated admin login is `admin` / `admin` for local demonstration only. Trigger `demo_ingest`, then `demo_aggregate`, then `demo_report`; each DAG must succeed before the next is triggered. Query `demo_sales`, `demo_aggregates`, and `demo_reports` in PostgreSQL to inspect the results.
          Run `../dc_dev exec #{realized_node.name}-worker python /opt/airflow/validate_dags.py` to check DAG imports, discovery and dependencies in the pinned Airflow runtime.
          #{realized_node.collector ? "Native Airflow traces and metrics use the connected collector. Package spans extract Airflow task context and carry DAG, run, task, and attempt attributes. Airflow task spans link to the DAG run with `FOLLOWS_FROM`; worker package spans parent under task spans when Airflow supplies a context carrier. Inspect the connected trace backend to verify exported data." : "No telemetry exporter is configured."}
        MD
      end
    end
  end
end
