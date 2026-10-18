package app

import (
    "context"
    "crypto/sha256"
    "encoding/hex"
    "encoding/json"
    "net/http"
    "strings"
    "sync"
    "time"
)

type tradeCommand struct {
    CommandID string `json:"command_id"`
    IdempotencyKey string `json:"idempotency_key"`
    Commodity string `json:"commodity"`
    Buyer string `json:"buyer"`
    Seller string `json:"seller"`
    Quantity int64 `json:"quantity"`
    PriceCents int64 `json:"price_cents"`
}

var commodities = map[string]bool{
    "Martian Water": true, "Europa Ice": true, "Titan Methane": true,
    "Lunar Helium-3": true, "Venusian Sulfur": true,
}

var schemaOnce sync.Once
var schemaError error

func register(mux *http.ServeMux, deps Dependencies) {
    mux.HandleFunc("POST /trades", func(w http.ResponseWriter, r *http.Request) {
        var command tradeCommand
        r.Body = http.MaxBytesReader(w, r.Body, 8192)
        decoder := json.NewDecoder(r.Body)
        decoder.DisallowUnknownFields()
        if err := decoder.Decode(&command); err != nil {
            http.Error(w, "invalid JSON trade command", http.StatusBadRequest); return
        }
        if !commodities[command.Commodity] || command.Quantity <= 0 || command.PriceCents <= 0 ||
            strings.TrimSpace(command.Buyer) == "" || strings.TrimSpace(command.Seller) == "" ||
            command.Buyer == command.Seller || len(command.IdempotencyKey) < 8 || len(command.IdempotencyKey) > 128 {
            http.Error(w, "invalid trade fields", http.StatusBadRequest); return
        }
        schemaOnce.Do(func() {
            ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
            defer cancel()
            _, schemaError = deps.DB.Exec(ctx, `CREATE TABLE IF NOT EXISTS accepted_commands (
                idempotency_key text PRIMARY KEY, payload_hash text NOT NULL,
                command_id text NOT NULL, published boolean NOT NULL DEFAULT false,
                partition integer, offset_number bigint)`)
        })
        if schemaError != nil { http.Error(w, "command store unavailable", http.StatusServiceUnavailable); return }

        keyHash := sha256.Sum256([]byte(command.IdempotencyKey))
        command.CommandID = hex.EncodeToString(keyHash[:])
        payload := command
        payload.IdempotencyKey = ""
        payload.CommandID = ""
        payloadBytes, _ := json.Marshal(payload)
        payloadHash := sha256.Sum256(payloadBytes)
        hash := hex.EncodeToString(payloadHash[:])
        ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
        defer cancel()
        tx, err := deps.DB.Begin(ctx)
        if err != nil { http.Error(w, "command store unavailable", http.StatusServiceUnavailable); return }
        defer tx.Rollback(ctx)
        _, err = tx.Exec(ctx, `INSERT INTO accepted_commands (idempotency_key, payload_hash, command_id)
            VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`, command.IdempotencyKey, hash, command.CommandID)
        if err != nil { http.Error(w, "command store unavailable", http.StatusServiceUnavailable); return }
        var storedHash string
        var published bool
        var partition int32
        var offset int64
        err = tx.QueryRow(ctx, `SELECT payload_hash, published, COALESCE(partition, -1), COALESCE(offset_number, -1)
            FROM accepted_commands WHERE idempotency_key=$1 FOR UPDATE`, command.IdempotencyKey).
            Scan(&storedHash, &published, &partition, &offset)
        if err != nil { http.Error(w, "command store unavailable", http.StatusServiceUnavailable); return }
        if storedHash != hash { http.Error(w, "idempotency key has different command", http.StatusConflict); return }
        if !published {
            partition, offset, err = deps.Kafka.Publish(ctx, "exchange.commands", command.Commodity, command,
                map[string]string{"command-id": command.CommandID})
            if err != nil { http.Error(w, "broker did not acknowledge command", http.StatusServiceUnavailable); return }
            _, err = tx.Exec(ctx, `UPDATE accepted_commands SET published=true, partition=$2, offset_number=$3
                WHERE idempotency_key=$1`, command.IdempotencyKey, partition, offset)
            if err != nil { http.Error(w, "command store unavailable", http.StatusServiceUnavailable); return }
        }
        if err := tx.Commit(ctx); err != nil { http.Error(w, "command store unavailable", http.StatusServiceUnavailable); return }
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusAccepted)
        _ = json.NewEncoder(w).Encode(map[string]any{
            "status": "accepted", "command_id": command.CommandID,
            "topic": "exchange.commands", "partition": partition, "offset": offset,
        })
    })
}
