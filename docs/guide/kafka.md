# Apache Kafka

Mobilis generates a single-node [Apache Kafka 4.2.2](https://kafka.apache.org/community/downloads/) KRaft broker for development.
The generated Compose project owns the broker, its persistent named volume,
topic provisioning script, and client source. Mobilis is not needed to run it.

```ruby
events = kafka("events", publish_port: false) do |broker|
  broker.topic("exchange.commands", partitions: 5,
               retention_ms: 604_800_000, cleanup_policy: "delete")
  broker.topic("exchange.executions", partitions: 5,
               retention_ms: 604_800_000, cleanup_policy: "delete")
end

api = go_http("trading-api")
worker = fastapi("matching-engine", publish_port: false)

connect(from: api, to: events, publish: "exchange.commands")
connect(from: worker, to: events,
        publish: "exchange.executions",
        subscribe: [{topic: "exchange.commands", group: "matching-v1"}])
```

Each topic specifies a positive partition count, positive retention in
milliseconds, and `delete` or `compact` cleanup policy. The generated
`events/provision.sh` creates topics with one replica, reapplies retention and
cleanup settings on startup, and fails if an existing partition count differs.
Applications wait for broker health and successful topic provisioning.

The broker advertises `events:9092` to containers. Set `publish_port: true` to
add the developer listener at `localhost:9094`; it is disabled by default.
Different generated projects using that listener cannot run together on that
host port. This configuration has no ZooKeeper and no replication resilience.

Kafka connections generate `KAFKA_BOOTSTRAP_SERVERS`,
`MOBILIS_KAFKA_PUBLISH_TOPICS`, and `MOBILIS_KAFKA_SUBSCRIPTIONS`. Subscriptions
pair a topic with an explicit group ID. Separate groups receive their own
copies of a retained log; members of one group divide partitions.

FastAPI and Flask receive a `kafka_client.py` helper using kafka-python 3.0.11.
The generator packages its platform-independent wheel with the emitted service;
the wheel SHA-256 is `9d10cab4e11e02545d82c7e5af5702da5aa46dd4eccd11ad92a50bf6dbbecd14`.
Kafka-enabled FastAPI services also package Prometheus client 0.26.0, and
services connected to Redis package redis-py 7.2.0.
Go HTTP receives `internal/app/kafka.go` using franz-go. Rails and Rack receive
a `MobilisKafka` helper using rdkafka. Helpers send keys and trace headers,
wait for delivery acknowledgments, and commit offsets only after the handler
returns. Consumer processing spans link to producer context because queueing
and replay need not be one continuous trace. A database projection must store
processed event IDs in the same transaction as its state update. It must be
safe when the event is redelivered after a crash between DB commit and Kafka
offset commit.

The [Galactic Exchange demonstration](../../scripts/26_galactic_exchange.rb)
generates a Go trading API, Python matcher, Rails portfolio projection,
FastAPI market projection, Redis leaderboard, and an executable replay check.
Run its generator with an empty output directory argument to preserve any
existing `generate/` directory in the repository.
