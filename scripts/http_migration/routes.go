package app

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"regexp"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

type item struct {
	ID   int32  `json:"id"`
	Name string `json:"name"`
}

// One semantic effect is computed before the commit decision, and supplies both
// the database values and telemetry. No separate shadow business logic exists.
type itemEffect struct {
	Operation string `json:"operation"`
	Table     string `json:"table"`
	Values    item   `json:"values"`
}

func determineEffect(value item) itemEffect {
	return itemEffect{Operation: "insert", Table: "items", Values: value}
}

// The reserved header is trusted only behind the generated gateway: backend
// HTTP ports are unpublished, and ingress strips caller copies before routing.
func isShadowRequest(r *http.Request) bool {
	values := r.Header.Values("X-Mobilis-Shadow")
	return len(values) == 1 && values[0] == "true"
}

func recordRequestContext(r *http.Request) bool {
	shadow := isShadowRequest(r)
	trace.SpanFromContext(r.Context()).SetAttributes(attribute.Bool("demo.request.shadow", shadow))
	return shadow
}

// This is the only divergence: a shadow request skips the effect-commit boundary.
func commitItem(ctx context.Context, db *pgxpool.Pool, effect itemEffect, shadow bool) (bool, error) {
	if shadow {
		return false, nil
	}
	tx, err := db.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	_, err = tx.Exec(ctx, "SET LOCAL application_name = 'candidate'")
	if err == nil {
		_, err = tx.Exec(ctx, "INSERT INTO items (id, name) VALUES ($1, $2)", effect.Values.ID, effect.Values.Name)
	}
	if err == nil {
		err = tx.Commit(ctx)
	}
	return err == nil, err
}

func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Served-By", "candidate")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("response: %v", err)
	}
}

func register(mux *http.ServeMux, deps Dependencies) {
	mux.HandleFunc("GET /items", func(w http.ResponseWriter, r *http.Request) {
		recordRequestContext(r)
		rows, err := deps.DB.Query(r.Context(), "SELECT id, name FROM items ORDER BY id")
		if err != nil {
			reply(w, 503, map[string]string{"error": "database unavailable"})
			return
		}
		defer rows.Close()
		items := make([]item, 0)
		for rows.Next() {
			var value item
			if err := rows.Scan(&value.ID, &value.Name); err != nil {
				reply(w, 500, map[string]string{"error": "database error"})
				return
			}
			items = append(items, value)
		}
		if err := rows.Err(); err != nil {
			reply(w, 500, map[string]string{"error": "database error"})
			return
		}
		reply(w, 200, items)
	})
	mux.HandleFunc("POST /items", func(w http.ResponseWriter, r *http.Request) {
		shadow := recordRequestContext(r)
		// Decode the exact field set and types, without coercion or unknown fields.
		var fields map[string]json.RawMessage
		decoder := json.NewDecoder(r.Body)
		var value item
		invalid := decoder.Decode(&fields) != nil || len(fields) != 2
		if !invalid {
			invalid = string(fields["id"]) == "null" || string(fields["name"]) == "null" ||
				json.Unmarshal(fields["id"], &value.ID) != nil || json.Unmarshal(fields["name"], &value.Name) != nil
		}
		var extra any
		if invalid || decoder.Decode(&extra) != io.EOF || value.ID < 1 || !regexp.MustCompile(`^[A-Za-z0-9_-]{1,80}$`).MatchString(value.Name) {
			reply(w, 400, map[string]string{"error": "invalid item"})
			return
		}
		effect := determineEffect(value)
		encodedEffect, _ := json.Marshal(effect)
		ctx, span := otel.Tracer("items").Start(r.Context(), "items.write")
		defer span.End()
		committed, err := commitItem(ctx, deps.DB, effect, shadow)
		if err != nil {
			var pgerr *pgconn.PgError
			if errors.As(err, &pgerr) && pgerr.Code == "23505" {
				reply(w, 409, map[string]string{"error": "item exists"})
				return
			}
			reply(w, 503, map[string]string{"error": "database unavailable"})
			return
		}
		mode := "actual"
		if shadow {
			mode = "shadow"
		}
		span.SetAttributes(attribute.String("demo.write.mode", mode), attribute.Bool("demo.request.shadow", shadow),
			attribute.Bool("demo.write.committed", committed), attribute.String("db.operation.name", "INSERT"),
			attribute.String("db.collection.name", "items"), attribute.String("demo.write.effect", string(encodedEffect)))
		reply(w, 201, value)
	})
}
