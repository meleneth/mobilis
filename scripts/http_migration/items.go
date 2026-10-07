package app

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

// This interface is owned by the demo; the archetype still supplies ordinary pgx.
type itemStore interface {
	List(context.Context) ([]item, error)
	Commit(context.Context, itemEffect) error
}

type postgresItems struct{ db *pgxpool.Pool }

var _ itemStore = postgresItems{}
var errInvalidRows = errors.New("invalid item rows")

func insertPlan(effect itemEffect) (string, []any) {
	return "INSERT INTO items (id, name) VALUES ($1, $2)", []any{effect.Values.ID, effect.Values.Name}
}

func sqlEvidence(ctx context.Context, statement string, parameters []any, executed bool) (context.Context, trace.Span) {
	if parameters == nil {
		parameters = []any{}
	}
	encoded, _ := json.Marshal(parameters)
	return trace.SpanFromContext(ctx).TracerProvider().Tracer("items").Start(ctx, "items.sql", trace.WithAttributes(
		attribute.String("demo.sql.text", statement), attribute.String("demo.sql.parameters", string(encoded)),
		attribute.Bool("demo.sql.executed", executed), attribute.Bool("demo.sql.executemany", false)))
}

func (store postgresItems) List(ctx context.Context) ([]item, error) {
	statement := "SELECT id, name FROM items ORDER BY id"
	ctx, span := sqlEvidence(ctx, statement, nil, true)
	defer span.End()
	rows, err := store.db.Query(ctx, statement)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]item, 0)
	for rows.Next() {
		var value item
		if err := rows.Scan(&value.ID, &value.Name); err != nil {
			return nil, errors.Join(errInvalidRows, err)
		}
		items = append(items, value)
	}
	if err := rows.Err(); err != nil {
		return nil, errors.Join(errInvalidRows, err)
	}
	return items, nil
}

func (store postgresItems) Commit(ctx context.Context, effect itemEffect) error {
	tx, err := store.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	_, err = tx.Exec(ctx, "SET LOCAL application_name = 'candidate'")
	if err == nil {
		statement, parameters := insertPlan(effect)
		queryCtx, span := sqlEvidence(ctx, statement, parameters, true)
		_, err = tx.Exec(queryCtx, statement, parameters...)
		span.End()
	}
	if err == nil {
		err = tx.Commit(ctx)
	}
	return err
}
