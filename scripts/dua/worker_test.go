package app

import (
    "context"
    "errors"
    "sync"
    "testing"
)

type fakeStore struct { mu sync.Mutex; rows map[string]Decision; fail bool }
func (store *fakeStore) Insert(_ context.Context, event ApprovalEvent, decision Decision, _ string) (bool, error) {
    if store.fail { return false, errors.New("database unavailable") }
    store.mu.Lock(); defer store.mu.Unlock()
    if _, exists := store.rows[event.ApplicationID]; exists { return false, nil }
    store.rows[event.ApplicationID] = decision
    return true, nil
}

func TestPolicies(t *testing.T) {
    cases := []struct{ activity, outcome string }{
        {"DEPLOY_RUBBER_DUCK", "APPROVED"}, {"SECOND_COFFEE", "DENIED"},
        {"RENAME_PRODUCTION_SERVER", "DENIED"}, {"FRIDAY_DEPENDENCY", "APPROVED_WITH_WARNING"},
    }
    for _, tc := range cases {
        decision, err := policy(ApprovalEvent{Activity: tc.activity})
        if err != nil || decision.Outcome != tc.outcome || decision.Reason == "" { t.Fatalf("%s: %+v %v", tc.activity, decision, err) }
    }
    if _, err := policy(ApprovalEvent{Activity: "APPROVE_EVERYTHING"}); err == nil { t.Fatal("unknown policy accepted") }
}

func TestConditionalInsertSuppressesConcurrentDuplicates(t *testing.T) {
    store := &fakeStore{rows: map[string]Decision{}}
    event := ApprovalEvent{ApplicationID: "same", Activity: "DEPLOY_RUBBER_DUCK"}
    decision, _ := policy(event)
    var wg sync.WaitGroup
    results := make(chan bool, 12)
    for i := 0; i < 12; i++ {
        wg.Add(1)
        go func() { defer wg.Done(); applied, err := recordDecision(context.Background(), store, event, decision, "message"); if err != nil { t.Error(err) }; results <- applied }()
    }
    wg.Wait(); close(results)
    applied := 0
    for result := range results { if result { applied++ } }
    if applied != 1 || len(store.rows) != 1 { t.Fatalf("applied=%d rows=%d", applied, len(store.rows)) }
}

func TestDatabaseFailureDoesNotLookApplied(t *testing.T) {
    store := &fakeStore{fail: true}
    applied, err := recordDecision(context.Background(), store, ApprovalEvent{}, Decision{}, "message")
    if applied || err == nil { t.Fatalf("applied=%v err=%v", applied, err) }
}
