package app

import "context"

func recordDecision(ctx context.Context, store decisionStore, event ApprovalEvent, decision Decision, messageID string) (bool, error) {
    return store.Insert(ctx, event, decision, messageID)
}
