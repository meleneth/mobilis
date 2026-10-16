# frozen_string_literal: true

require "json"

module Mobilis
  module ServiceWriter
    class GooglePubSub < Mobilis::Base::ServiceWriter
      def write
        topology = {
          project: realized_node.config_node.project_id,
          topics: realized_node.config_node.topics,
          subscriptions: realized_node.config_node.subscriptions
        }
        File.write("topology.json", JSON.pretty_generate(topology))
        File.write("Dockerfile", <<~DOCKER)
          FROM #{Mobilis::ContainerVersions::GOOGLE_CLOUD_EMULATORS}
          USER root
          RUN apt-get update && apt-get install -y --no-install-recommends python3-venv && rm -rf /var/lib/apt/lists/* \\
              && python3 -m venv /opt/mobilis-venv && /opt/mobilis-venv/bin/pip install --no-cache-dir 'google-cloud-pubsub>=2.30,<3'
          ENV PATH="/opt/mobilis-venv/bin:${PATH}"
          COPY bootstrap.py health.py topology.json /opt/mobilis/
          ENTRYPOINT ["python", "/opt/mobilis/bootstrap.py"]
        DOCKER
        File.write("bootstrap.py", <<~'PYTHON')
          import json
          import os
          import signal
          import subprocess
          import sys
          import time

          from google.api_core.exceptions import AlreadyExists, GoogleAPICallError
          from google.cloud import pubsub_v1


          with open("/opt/mobilis/topology.json", encoding="utf-8") as file:
              topology = json.load(file)
          project = topology["project"]
          publisher = pubsub_v1.PublisherClient()
          subscriber = pubsub_v1.SubscriberClient()
          server = subprocess.Popen([
              "gcloud", "beta", "emulators", "pubsub", "start",
              "--project=" + project, "--host-port=0.0.0.0:8085",
          ])
          try:
              os.unlink("/tmp/mobilis-pubsub-ready")
          except FileNotFoundError:
              pass


          def terminate(_signal, _frame):
              server.terminate()


          signal.signal(signal.SIGTERM, terminate)
          signal.signal(signal.SIGINT, terminate)

          def provision():
              for topic in topology["topics"]:
                  path = publisher.topic_path(project, topic)
                  try:
                      publisher.create_topic(request={"name": path}, timeout=5)
                  except AlreadyExists:
                      pass
              for item in topology["subscriptions"]:
                  path = subscriber.subscription_path(project, item["name"])
                  topic_path = publisher.topic_path(project, item["topic"])
                  try:
                      subscriber.create_subscription(
                          request={"name": path, "topic": topic_path, "ack_deadline_seconds": 10},
                          timeout=5,
                      )
                  except AlreadyExists:
                      existing = subscriber.get_subscription(request={"subscription": path}, timeout=5)
                      if existing.topic != topic_path:
                          raise RuntimeError(f"subscription {item['name']} already points to {existing.topic}")


          try:
              for attempt in range(60):
                  if server.poll() is not None:
                      raise RuntimeError(f"Pub/Sub emulator exited with status {server.returncode}")
                  try:
                      provision()
                      break
                  except (GoogleAPICallError, OSError) as error:
                      if attempt == 59:
                          raise RuntimeError("Pub/Sub emulator unavailable after 120 seconds") from error
                      time.sleep(2)
              provision()  # Exercise existing-topic and existing-subscription paths before readiness.
              open("/tmp/mobilis-pubsub-ready", "w", encoding="utf-8").close()
              sys.exit(server.wait())
          except Exception as error:
              print(f"Pub/Sub initialization failed: {error}", file=sys.stderr, flush=True)
              server.terminate()
              sys.exit(1)
          finally:
              publisher.transport.close()
              subscriber.transport.close()
        PYTHON
        File.write("health.py", <<~'PYTHON')
          import json
          from google.cloud import pubsub_v1

          with open("/opt/mobilis/topology.json", encoding="utf-8") as file:
              topology = json.load(file)
          publisher = pubsub_v1.PublisherClient()
          try:
              topics = topology["topics"]
              if topics:
                  publisher.get_topic(request={"topic": publisher.topic_path(topology["project"], topics[0])}, timeout=3)
              else:
                  next(iter(publisher.list_topics(request={"project": "projects/" + topology["project"]}, timeout=3)), None)
          finally:
              publisher.transport.close()
        PYTHON
      end
    end
  end
end
