# Department of Unnecessary Approvals

A generated, standalone local system: GraphQL intake in Applications (FastAPI,
Strawberry, PostgreSQL), a Pub/Sub emulator topic and pull subscription, a Go
bureaucrat, Cassandra decisions, and a Grafbase federated gateway. Run after
generating the project:

```sh
./demo up
./demo seed
./demo exercise
./demo verify
./demo down
```

The public GraphQL endpoint is `http://localhost:5000/graphql` (see
`development.env` if the mapped port differs). The exercise submits four
requests, including a rejected second coffee, then confirms the federation
entity lookup and authoritative Cassandra rows. It publishes a duplicate and
a malformed message to check conditional insertion and terminal disposition.
`./demo down` preserves PostgreSQL and Cassandra data; ordinary Compose volume
and bind mount commands control local cleanup.

Set `DUA_OTEL=1` **while generating** for explicit collector connections to
Gateway, both subgraphs, and the Go worker. Without it, no collector, Jaeger or
exporter is required. The connected runner also checks asynchronous span links,
the gateway mutation, PostgreSQL insert and a federated Cassandra lookup in
Jaeger. Generated projects operate without the Mobilis source.

Applications commits to PostgreSQL before publishing. If Pub/Sub is down,
the mutation returns an error while a pending row remains: there is a
**dual-write failure window**. This demo does not implement a transactional
outbox or automatic replay. The Go worker acknowledges only after Cassandra's
`INSERT ... IF NOT EXISTS` succeeds; duplicate events retain the first row.
Malformed events are logged and acknowledged as terminal failures. Cassandra
uses one local node and replication factor one: this demonstrates neither
fault tolerance nor disaster recovery. The Pub/Sub emulator does not certify
hosted service ordering or exactly-once guarantees.
