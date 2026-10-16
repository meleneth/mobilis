package app

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/codes"
)

func recordDecision(ctx context.Context, store decisionStore, event ApprovalEvent, decision Decision, messageID string) (bool, error) {
    ctx, span := otel.Tracer("dua.worker").Start(ctx, "cassandra.insert_decision")
    defer span.End()
    span.SetAttributes(attribute.String("db.system", "cassandra"),
        attribute.String("db.operation", "INSERT"), attribute.String("db.namespace", "approvals"),
        attribute.String("dua.correlation_id", event.CorrelationID))
    applied, err := store.Insert(ctx, event, decision, messageID)
    if err != nil { span.SetStatus(codes.Error, "decision write failed") }
    span.SetAttributes(attribute.Bool("dua.decision_inserted", applied))
    return applied, err
}
