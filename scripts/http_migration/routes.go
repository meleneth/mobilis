package app

import (
    "encoding/json"
    "io"
    "log"
    "net/http"
    "os"
    "regexp"

    "github.com/jackc/pgx/v5/pgconn"
    "errors"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
)

type item struct {
    ID int32 `json:"id"`
    Name string `json:"name"`
}

func reply(w http.ResponseWriter, status int, value any) {
    w.Header().Set("Content-Type", "application/json")
    w.Header().Set("X-Served-By", "candidate")
    w.WriteHeader(status)
    if err := json.NewEncoder(w).Encode(value); err != nil { log.Printf("response: %v", err) }
}

func register(mux *http.ServeMux, deps Dependencies) {
    mux.HandleFunc("GET /items", func(w http.ResponseWriter, r *http.Request) {
        rows, err := deps.DB.Query(r.Context(), "SELECT id, name FROM items ORDER BY id")
        if err != nil { reply(w, 503, map[string]string{"error":"database unavailable"}); return }
        defer rows.Close()
        items := make([]item, 0)
        for rows.Next() {
            var value item
            if err := rows.Scan(&value.ID, &value.Name); err != nil { reply(w, 500, map[string]string{"error":"database error"}); return }
            items = append(items, value)
        }
        if err := rows.Err(); err != nil { reply(w, 500, map[string]string{"error":"database error"}); return }
        reply(w, 200, items)
    })
    mux.HandleFunc("POST /items", func(w http.ResponseWriter, r *http.Request) {
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
            reply(w, 400, map[string]string{"error":"invalid item"}); return
        }
        effect, _ := json.Marshal(map[string]any{"operation":"insert", "table":"items", "values":value})
        ctx, span := otel.Tracer("items").Start(r.Context(), "items.write")
        defer span.End()
        mode := "shadow"
        if os.Getenv("SHADOW_WRITES") != "true" {
            mode = "actual"
            tx, err := deps.DB.Begin(ctx)
            if err != nil { reply(w, 503, map[string]string{"error":"database unavailable"}); return }
            defer func() { _ = tx.Rollback(ctx) }()
            _, err = tx.Exec(ctx, "SET LOCAL application_name = 'candidate'")
            if err == nil { _, err = tx.Exec(ctx, "INSERT INTO items (id, name) VALUES ($1, $2)", value.ID, value.Name) }
            if err == nil { err = tx.Commit(ctx) }
            if err != nil {
                var pgerr *pgconn.PgError
                if errors.As(err, &pgerr) && pgerr.Code == "23505" { reply(w, 409, map[string]string{"error":"item exists"}); return }
                reply(w, 503, map[string]string{"error":"database unavailable"}); return
            }
        }
        // The shadow branch performs no database operation, including no uniqueness check:
        // shared state may already contain the authoritative insert when its mirror arrives.
        span.SetAttributes(attribute.String("demo.write.mode", mode), attribute.String("db.operation.name", "INSERT"),
            attribute.String("db.collection.name", "items"), attribute.String("demo.write.effect", string(effect)))
        reply(w, 201, value)
    })
}
