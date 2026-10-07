# HTTP migration SQL meaning validation

Script 20 now compares SQL meaning and bound values, replacing the previous
span-count-only SQL check. The earlier migration validation notes' write-effect
proofs still apply, but their SQL evidence alone did not establish query meaning.

The verifier parses PostgreSQL SQL with pinned SQLGlot 27.29.0. It resolves
single-table read qualification and aliases against `items(id INTEGER, name
VARCHAR)`, preserves projection/filter/order/limit semantics, and binds inserts
by target column. Driver placeholders, SQLAlchemy's schema-preserving casts,
formatting and default ascending order can differ without failing comparison.
Unsupported SQL and missing/unused bindings fail closed. This is a bounded
comparison of the demonstrated contract, not a general SQL equivalence solver.

Python observes executed driver SQL and bindings in SQLAlchemy's execution
event. Go records the exact statement and arguments passed to pgx. Candidate
shadow writes report the same insert-plan builder used by actual commits,
without executing it. Both alternatives must match the independent item contract;
executed evidence must also match the automatic DB span. SQL evidence must
belong to the correlated request. Extra queries, including queries to other
tables, are rejected. Only transaction controls and the deliberate writer
identity setting are excluded. Existing database-state/audit/effect checks remain.

Validation:

- `bundle exec rspec`: 215 examples, zero failures, two existing pending specs.
- Generated Python application and verifier tests: 59 passed, 13 subtests passed.
- Generated Go `go test -race ./...`: passed, including shadow SQL plan evidence
  and boundary input values.
- An isolated generated project at `/tmp/mobilis-sql-meaning-20261007` completed
  `./demo`: full mirroring at 0%, 10%, 50% candidate authority, candidate outage
  and restoration, then 100% candidate authority with legacy stopped. All SQL,
  effects, audit, request-context and expected-error checks passed. Runtime log:
  `/tmp/mobilis-sql-meaning-demo.log`.
- Live negative test: candidate's read SQL was changed to
  `SELECT id, name FROM items WHERE id > 1 ORDER BY id`. Legacy's authoritative
  response and query count still passed, but verification exited unsuccessfully
  with `candidate`, `SQL meaning drift`, and both normalized statements. The
  candidate source was restored before the complete demo run.
- Regression tests reject changed projections, predicates, ordering, limits,
  distinctness, insert bindings, stale SQL evidence, missing/disconnected
  evidence, extra-table queries and unsupported insert clauses/casts/modifiers.

The temporary deployment was removed after validation. The repository's existing
running deployment was not restarted; its original application image tags were
restored. No materialization was used to generate the validation service files.
