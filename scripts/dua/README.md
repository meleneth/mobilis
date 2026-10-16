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

The generated `applications` and `decisions` directories contain Python
`pytest` suites; run `pip install '.[test]' && pytest` in either service
directory. In generated `bureaucrat`, run `go mod tidy && go test ./internal/app`.
The top-level `./demo exercise` is the real container integration test; it
exits nonzero when domain or connected trace checks fail.

The public GraphQL endpoint is `http://localhost:5000/graphql` (see
`development.env` if the mapped port differs). The exercise submits four
requests, including a rejected second coffee, then confirms the federation
entity lookup and authoritative Cassandra rows. It publishes a duplicate and
a malformed message to check conditional insertion and terminal disposition.
`./demo down` preserves PostgreSQL and Cassandra data; ordinary Compose volume
and bind mount commands control local cleanup.

The path is `Gateway → Applications → PostgreSQL → Pub/Sub → Bureaucrat →
Cassandra → Decisions → Gateway`. Applications owns the federated `Application`
identity; Decisions resolves that entity by `id` and reads one Cassandra
partition. Each event carries a stable application UUID and correlation UUID.
The worker's CQL `INSERT ... IF NOT EXISTS` is the authoritative idempotency
gate. The verifier checks that the first message ID survives a duplicate.

To query manually after `./demo seed`:

```sh
curl -fsS http://localhost:5000/graphql -H 'Content-Type: application/json' \
  --data '{"query":"mutation { requestApproval(activity: \"DEPLOY_RUBBER_DUCK\", justification: \"Morale improvement\") { id status } }"}'
```

Use the returned `id` in:

```sh
curl -fsS http://localhost:5000/graphql -H 'Content-Type: application/json' \
  --data '{"query":"query { application(id: \"RETURNED_ID\") { id activity justification status decision { outcome reason } } }"}'
```

`status` is `PENDING` until the worker records a decision; `decision` is null
during that interval. The verifier polls the real final state with a deadline.
For `RENAME_PRODUCTION_SERVER`, supply `targetName`; names containing `final`
are rejected, while other proposed names are approved by this fixed catalogue.

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
Malformed events are logged and acknowledged as terminal failures. A Cassandra
write failure is nacked for redelivery. An operator must inspect pending rows
and replay failed publishes after a broker outage. Cassandra
uses one local node and replication factor one: this demonstrates neither
fault tolerance nor disaster recovery. The Pub/Sub emulator does not certify
hosted service ordering or exactly-once guarantees.
