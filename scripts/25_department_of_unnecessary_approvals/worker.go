package app

import (
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "log"
    "net/http"
    "os"
    "strings"
    "sync/atomic"
    "time"

    "cloud.google.com/go/pubsub/v2"
    "github.com/gocql/gocql"
    "github.com/google/uuid"
)

type ApprovalEvent struct {
    Version int `json:"version"`
    ApplicationID string `json:"application_id"`
    CorrelationID string `json:"correlation_id"`
    Activity string `json:"activity"`
    Justification string `json:"justification"`
    TargetName string `json:"target_name"`
}

type Decision struct { Outcome, Reason string }

func policy(event ApprovalEvent) (Decision, error) {
    switch event.Activity {
    case "DEPLOY_RUBBER_DUCK":
        return Decision{"APPROVED", "Rubber duck deployment improves morale without a committee."}, nil
    case "SECOND_COFFEE":
        return Decision{"DENIED", "Form C-2 for a second coffee was not attached."}, nil
    case "RENAME_PRODUCTION_SERVER":
        if strings.Contains(strings.ToLower(event.TargetName), "final") {
            return Decision{"DENIED", "Production server names containing final are prohibited by the Naming Office."}, nil
        }
        return Decision{"APPROVED", "The Naming Office found no forbidden finality in the proposed name."}, nil
    case "FRIDAY_DEPENDENCY":
        return Decision{"APPROVED_WITH_WARNING", "Friday may be a dependency, but cannot be pinned in production."}, nil
    default:
        return Decision{}, fmt.Errorf("unknown activity %q", event.Activity)
    }
}

func parseEvent(data []byte) (ApprovalEvent, error) {
    var event ApprovalEvent
    if err := json.Unmarshal(data, &event); err != nil { return event, err }
    if event.Version != 1 { return event, errors.New("unsupported event version") }
    if _, err := uuid.Parse(event.ApplicationID); err != nil { return event, errors.New("invalid application ID") }
    if _, err := uuid.Parse(event.CorrelationID); err != nil { return event, errors.New("invalid correlation ID") }
    if len(event.Justification) == 0 || len(event.Justification) > 400 { return event, errors.New("invalid justification") }
    if event.Activity == "RENAME_PRODUCTION_SERVER" && (event.TargetName == "" || len(event.TargetName) > 80) {
        return event, errors.New("invalid proposed target name")
    }
    if _, err := policy(event); err != nil { return event, err }
    return event, nil
}

type decisionStore interface {
    Insert(context.Context, ApprovalEvent, Decision, string) (bool, error)
}

type cassandraStore struct { session *gocql.Session }

var acknowledged atomic.Int64
var inserted atomic.Int64
var duplicates atomic.Int64
var malformed atomic.Int64

func (store cassandraStore) Insert(ctx context.Context, event ApprovalEvent, decision Decision, messageID string) (bool, error) {
    existing := map[string]interface{}{}
    applied, err := store.session.Query(
        "INSERT INTO decisions (application_id, correlation_id, activity, outcome, reason, message_id) VALUES (?, ?, ?, ?, ?, ?) IF NOT EXISTS",
        event.ApplicationID, event.CorrelationID, event.Activity, decision.Outcome, decision.Reason, messageID,
    ).WithContext(ctx).MapScanCAS(existing)
    return applied, err
}

func openCassandra() (*gocql.Session, error) {
    cluster := gocql.NewCluster(os.Getenv("CASSANDRA_CONTACT_POINTS"))
    cluster.Port = 9042
    cluster.Keyspace = os.Getenv("CASSANDRA_KEYSPACE")
    cluster.Authenticator = gocql.PasswordAuthenticator{Username: os.Getenv("CASSANDRA_USERNAME"), Password: os.Getenv("CASSANDRA_PASSWORD")}
    cluster.Consistency = gocql.LocalQuorum
    cluster.SerialConsistency = gocql.LocalSerial
    cluster.Timeout = 10*time.Second
    cluster.ConnectTimeout = 10*time.Second
    return cluster.CreateSession()
}

func processMessage(ctx context.Context, store decisionStore, message *pubsub.Message) {
    event, err := parseEvent(message.Data)
    if err != nil {
        log.Printf("terminal invalid event message_id=%s error=%v", message.ID, err)
        message.Ack() // Invalid schema is terminal; it must not poison the subscription.
        malformed.Add(1)
        acknowledged.Add(1)
        return
    }
    decision, _ := policy(event)
    applied, err := recordDecision(ctx, store, event, decision, message.ID)
    if err != nil {
        log.Printf("decision write failed application_id=%s message_id=%s error=%v", event.ApplicationID, message.ID, err)
        message.Nack()
        return
    }
    if applied {
        inserted.Add(1)
        log.Printf("decision inserted application_id=%s correlation_id=%s message_id=%s", event.ApplicationID, event.CorrelationID, message.ID)
    } else {
        duplicates.Add(1)
        log.Printf("duplicate decision suppressed application_id=%s correlation_id=%s message_id=%s", event.ApplicationID, event.CorrelationID, message.ID)
    }
    message.Ack()
    acknowledged.Add(1)
    log.Printf("acknowledged application_id=%s message_id=%s", event.ApplicationID, message.ID)
}

func receiveLoop(ctx context.Context, ps *PubSub, store decisionStore) {
    for ctx.Err() == nil {
        err := ps.Receive(ctx, "bureaucrat", func(deliveryCtx context.Context, message *pubsub.Message) error {
            processMessage(deliveryCtx, store, message)
            return nil
        })
        if err != nil && ctx.Err() == nil {
            log.Printf("Pub/Sub receive unavailable: %v", err)
            timer := time.NewTimer(2*time.Second)
            select { case <-timer.C: case <-ctx.Done(): timer.Stop(); return }
        }
    }
}

func register(mux *http.ServeMux, deps Dependencies) {
    mux.HandleFunc("GET /processing", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(map[string]int64{
            "acknowledged": acknowledged.Load(), "inserted": inserted.Load(),
            "duplicates": duplicates.Load(), "malformed": malformed.Load(),
        })
    })
    go func() {
        // Compose readiness orders startup; this retry also covers transient Cassandra restarts.
        for {
            store, err := openCassandra()
            if err == nil {
                defer store.Close()
                receiveLoop(context.Background(), deps.PubSub, cassandraStore{store})
                return
            }
            log.Printf("Cassandra unavailable: %v", err)
            time.Sleep(2*time.Second)
        }
    }()
}
