# Google Pub/Sub emulator

`google_pubsub` declares a local project, topics, and pull subscriptions. Each
service connection names the resources it may publish to or pull from:

```ruby
events = google_pubsub("events", project: "mobilis-local", publish_port: true) do |broker|
  broker.topic("requests")
  broker.subscription("alpha", topic: "requests")
  broker.subscription("beta", topic: "requests")
end

publisher = fastapi("publisher")
alpha_worker = fastapi("alpha-worker")
beta_worker = go_http("beta-worker")
connect(from: publisher, to: events, publish: "requests")
connect(from: alpha_worker, to: events, subscribe: "alpha")
connect(from: beta_worker, to: events, subscribe: "beta")
```

`publish:` and `subscribe:` also accept arrays. A Pub/Sub connection without
either role is rejected, as are undeclared topic and subscription names. These
roles scope the generated client helpers; the emulator does not enforce IAM.
The generated container uses Google's official Cloud SDK emulator image, with
its version in `Mobilis::ContainerVersions::GOOGLE_CLOUD_EMULATORS`.

The connected service receives `PUBSUB_EMULATOR_HOST=events:8085`,
`PUBSUB_PROJECT_ID`, `GOOGLE_CLOUD_PROJECT`,
`MOBILIS_PUBSUB_PUBLISH_TOPICS`, and `MOBILIS_PUBSUB_SUBSCRIPTIONS`. The first
address is for containers. With `publish_port: true`, the generated environment
file also contains `EVENTS_PUBSUB_HOST_ENDPOINT=localhost:<published-port>` for
host tools; set `PUBSUB_EMULATOR_HOST` to that value in the host process.
Do not use the host endpoint inside a container. No Google credentials are
needed for the local emulator.

Provisioning starts the emulator, retries connection failures, creates topics
before subscriptions, accepts existing resources, and checks that an existing
subscription still points at its declared topic. The broker becomes healthy
only after provisioning and a successful topic RPC. Connected services wait
for that healthcheck. Inspect `./dc_dev logs events` for startup or topology
errors. Clients use bounded RPC timeouts so an unavailable endpoint fails
with an exception instead of hanging indefinitely.

Generated FastAPI services use the official `google-cloud-pubsub` Python
library. Import `publish(topic, bytes, attributes=None)` and
`pull(subscription, max_messages=1, timeout=5)` from the generated
`<package>.pubsub_client`. Each returned `Delivery` has `data`, `attributes`,
`message_id`, `delivery_attempt`, `ack()`, `nack()`, and `process(handler)`.
Call `ack()` only after work succeeds, or `nack()` to make the delivery
available again. An unacknowledged delivery may return after its ack deadline.
The Go HTTP generator adds a `PubSub` client using the official
`cloud.google.com/go/pubsub/v2` package; its `Publish` and `Receive` helpers
also require explicit `Ack()` or `Nack()` in the receive handler. The Go handler
returns an error so a connected collector can record a failed processing span;
returning an error alone does not ack or nack the delivery. Application
handlers and idempotent business writes remain yours to implement.

Two subscriptions on one topic each receive a copy. Workers pulling one
subscription compete for deliveries; each message should be processed
idempotently because redelivery is possible. An explicit `nack()` sets the ack
deadline to zero. Ordering, exactly-once delivery, hosted IAM, and hosted
retention are outside this local emulator test. Push subscriptions are not
generated in this first slice. This is local development infrastructure, not
a production Pub/Sub deployment or durability guarantee.

Pub/Sub has no persistent Compose volume here: the official emulator keeps
state for its current session. On restart or `./dc_dev down` followed by `up`,
Mobilis provisions the declared topology again; local messages are cleared.
The generated project's `publisher/demo/integration` tests a fresh exchange,
restart, and reset. Run the numbered example once to generate it:

```sh
bundle exec ruby -Ilib scripts/23_google_pubsub.rb
cd generate
./publisher/demo/integration
```

The verifier publishes through the generated publisher HTTP service and checks
two independent subscriptions, two competing alpha workers, explicit ack,
nack/redelivery, and rejection of an undeclared topic. The generated project
requires Docker and Compose but no Mobilis source tree after generation.

Set `PUBSUB_DEMO_OTEL=1` when generating the example to connect the services
to a collector and Jaeger. With a collector connection, generated clients add
producer and consumer spans, inject W3C trace context into message attributes,
and link processing spans to the publisher context. This link represents
asynchronous causality; a consume span is not an HTTP child call. The spans
include operation, destination, message ID, and error type, without payloads
or credentials. `delivery_attempt` is recorded when the emulator supplies it;
use the message ID for correlation when it does not. Without a collector
connection, no trace exporter or trace-context handling is initialized.

See [Google's emulator documentation](https://docs.cloud.google.com/pubsub/docs/emulator)
for the differences from hosted Pub/Sub. Hosted service validation, ordering
and exactly-once behavior need separate tests against Google Cloud.
