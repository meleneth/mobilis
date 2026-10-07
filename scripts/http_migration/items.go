package app

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
)

// This interface is owned by the demo; the archetype still supplies ordinary pgx.
type itemStore interface {
	List(context.Context) ([]item, error)
	Commit(context.Context, itemEffect) error
}

type postgresItems struct{ db *pgxpool.Pool }

var _ itemStore = postgresItems{}
var errInvalidRows = errors.New("invalid item rows")

func (store postgresItems) List(ctx context.Context) ([]item, error) {
	rows, err := store.db.Query(ctx, "SELECT id, name FROM items ORDER BY id")
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
		_, err = tx.Exec(ctx, "INSERT INTO items (id, name) VALUES ($1, $2)", effect.Values.ID, effect.Values.Name)
	}
	if err == nil {
		err = tx.Commit(ctx)
	}
	return err
}
