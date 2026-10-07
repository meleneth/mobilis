package app

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

var sample = item{ID: 42, Name: "foo"}
var expectedEffect = itemEffect{Operation: "insert", Table: "items", Values: sample}

// Implements the real production interface. Unplanned calls fail immediately;
// cleanup also rejects missing calls. No database, network or SDK mocks exist.
type validatingStore struct {
	t                  *testing.T
	wantReads          int
	expected           *itemEffect
	items              []item
	readErr, commitErr error
	reads, commits     int
}

var _ itemStore = (*validatingStore)(nil)

func (store *validatingStore) List(ctx context.Context) ([]item, error) {
	store.t.Helper()
	store.reads++
	if ctx == nil || store.reads > store.wantReads {
		store.t.Fatal("unexpected List call")
	}
	return store.items, store.readErr
}
func (store *validatingStore) Commit(ctx context.Context, effect itemEffect) error {
	store.t.Helper()
	store.commits++
	if ctx == nil || store.expected == nil || store.commits != 1 || effect != *store.expected {
		store.t.Fatalf("unexpected Commit(%+v), count=%d", effect, store.commits)
	}
	return store.commitErr
}
func newStore(t *testing.T) *validatingStore {
	store := &validatingStore{t: t}
	t.Cleanup(func() {
		wantCommits := 0
		if store.expected != nil {
			wantCommits = 1
		}
		if store.commits != wantCommits || store.reads != store.wantReads {
			t.Fatalf("calls: reads=%d/%d commits=%d/%d", store.reads, store.wantReads, store.commits, wantCommits)
		}
	})
	return store
}

func testHandler(t *testing.T, store itemStore) (http.Handler, *tracetest.SpanRecorder) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	t.Cleanup(func() {
		if err := provider.Shutdown(context.Background()); err != nil {
			t.Fatal(err)
		}
	})
	mux := http.NewServeMux()
	registerItems(mux, store, provider.Tracer("items"))
	return otelhttp.NewHandler(mux, "http", otelhttp.WithTracerProvider(provider),
		otelhttp.WithPropagators(propagation.TraceContext{})), recorder
}

func request(handler http.Handler, method, body string, marker []string) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, "/items", strings.NewReader(body))
	r.Header["X-Mobilis-Shadow"] = marker
	r.Header.Set("traceparent", "00-11111111111111111111111111111111-2222222222222222-01")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, r)
	return response
}

func checkResponse(t *testing.T, response *httptest.ResponseRecorder, status int, body any) {
	t.Helper()
	var actual any
	if err := json.Unmarshal(response.Body.Bytes(), &actual); err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	var expected any
	if err := json.Unmarshal(encoded, &expected); err != nil {
		t.Fatal(err)
	}
	if response.Code != status || !reflect.DeepEqual(actual, expected) || response.Header().Get("Content-Type") != "application/json" {
		t.Fatalf("response %d %s %v, want %d %s", response.Code, response.Body, response.Header(), status, encoded)
	}
	if response.Header().Get("X-Served-By") != "candidate" {
		t.Fatal("candidate response identity missing")
	}
}

func attributes(values []attribute.KeyValue) map[string]any {
	result := make(map[string]any)
	for _, value := range values {
		result[string(value.Key)] = value.Value.AsInterface()
	}
	return result
}

func TestHealthNeedsNoInfrastructure(t *testing.T) {
	response := httptest.NewRecorder()
	Handler(Dependencies{}).ServeHTTP(response, httptest.NewRequest("GET", "/health", nil))
	if response.Code != 200 || response.Body.String() != `{"status":"ok"}` || response.Header().Get("Content-Type") != "application/json" {
		t.Fatal(response)
	}
}

func TestItemReadContract(t *testing.T) {
	for _, values := range [][]item{{}, {{ID: 1, Name: "example"}, sample}} {
		t.Run(fmt.Sprint(values), func(t *testing.T) {
			store := newStore(t)
			store.wantReads, store.items = 1, values
			handler, _ := testHandler(t, store)
			checkResponse(t, request(handler, "GET", "", nil), 200, values)
		})
	}
}

func TestReadDependencyFailures(t *testing.T) {
	for _, tc := range []struct {
		err     error
		status  int
		message string
	}{
		{errors.New("offline"), 503, "database unavailable"},
		{errors.Join(errInvalidRows, errors.New("scan failed")), 500, "database error"},
	} {
		t.Run(tc.message, func(t *testing.T) {
			store := newStore(t)
			store.wantReads, store.readErr = 1, tc.err
			handler, _ := testHandler(t, store)
			checkResponse(t, request(handler, "GET", "", nil), tc.status, map[string]string{"error": tc.message})
		})
	}
}

func TestShadowRequestContext(t *testing.T) {
	for _, tc := range []struct {
		values []string
		shadow bool
	}{
		{nil, false}, {[]string{"true"}, true}, {[]string{"false"}, false},
		{[]string{"true", "true"}, false}, {[]string{"true,false"}, false},
		{[]string{"TRUE"}, false}, {[]string{" true"}, false}, {[]string{"1"}, false}, {[]string{""}, false},
	} {
		t.Run(fmt.Sprint(tc.values), func(t *testing.T) {
			r := httptest.NewRequest("POST", "/items", nil)
			r.Header["X-Mobilis-Shadow"] = tc.values
			if got := isShadowRequest(r); got != tc.shadow {
				t.Fatalf("shadow=%v", got)
			}
			store := newStore(t)
			if !tc.shadow {
				store.expected = &expectedEffect
			}
			handler, recorder := testHandler(t, store)
			checkResponse(t, request(handler, "POST", `{"id":42,"name":"foo"}`, tc.values), 201, sample)
			checkEffectEvidence(t, recorder, tc.shadow, expectedEffect)
		})
	}
}

func checkEffectEvidence(t *testing.T, recorder *tracetest.SpanRecorder, shadow bool, expected itemEffect) {
	t.Helper()
	effects, servers := 0, 0
	for _, span := range recorder.Ended() {
		if span.SpanContext().TraceID().String() != "11111111111111111111111111111111" {
			t.Fatal("request context was lost")
		}
		attrs := attributes(span.Attributes())
		if span.Name() == "items.write" {
			effects++
			var effect itemEffect
			if err := json.Unmarshal([]byte(attrs["demo.write.effect"].(string)), &effect); err != nil {
				t.Fatal(err)
			}
			mode := "actual"
			if shadow {
				mode = "shadow"
			}
			if effect != expected || attrs["demo.request.shadow"] != shadow || attrs["demo.write.committed"] != !shadow || attrs["demo.write.mode"] != mode || attrs["db.operation.name"] != "INSERT" || attrs["db.collection.name"] != "items" {
				t.Fatal(attrs)
			}
		} else if span.Name() == "http" {
			servers++
			if attrs["demo.request.shadow"] != shadow {
				t.Fatal(attrs)
			}
		}
	}
	if effects != 1 || servers != 1 {
		t.Fatalf("effects=%d servers=%d", effects, servers)
	}
}

func TestShadowSkipsOnlyCommitBoundary(t *testing.T) {
	effect := determineEffect(sample)
	if effect != expectedEffect {
		t.Fatal(effect)
	}
	// Retain the nil-collaborator proof: shadow cannot make ANY database call.
	committed, err := commitItem(context.Background(), nil, effect, true)
	if err != nil || committed {
		t.Fatalf("committed=%v err=%v", committed, err)
	}
	for _, shadow := range []bool{false, true} {
		store := newStore(t)
		if !shadow {
			store.expected = &expectedEffect
		}
		handler, recorder := testHandler(t, store)
		var marker []string
		if shadow {
			marker = []string{"true"}
		}
		checkResponse(t, request(handler, "POST", `{"id":42,"name":"foo"}`, marker), 201, sample)
		// Both executions independently report EXACTLY the effect asserted at commit.
		checkEffectEvidence(t, recorder, shadow, expectedEffect)
	}
}

func TestDeterministicEffectAttributes(t *testing.T) {
	for _, shadow := range []bool{false, true} {
		attrs := attributes(effectAttributes(determineEffect(sample), shadow, !shadow))
		if attrs["demo.write.effect"] != `{"operation":"insert","table":"items","values":{"id":42,"name":"foo"}}` {
			t.Fatal(attrs)
		}
		if attrs["demo.request.shadow"] != shadow || attrs["demo.write.committed"] != !shadow || attrs["db.operation.name"] != "INSERT" || attrs["db.collection.name"] != "items" {
			t.Fatal(attrs)
		}
	}
}

func TestShadowHandlerUsesNormalValidationAndEffect(t *testing.T) {
	invalid := []string{"", "{", "null", "[]", "{}",
		`{"id":true,"name":"foo"}`, `{"id":1.0,"name":"foo"}`, `{"id":"42","name":"foo"}`,
		`{"id":null,"name":"foo"}`, `{"id":0,"name":"foo"}`, `{"id":-1,"name":"foo"}`,
		`{"id":2147483648,"name":"foo"}`, `{"id":42}`, `{"name":"foo"}`,
		`{"id":42,"name":null}`, `{"id":42,"name":12}`, `{"id":42,"name":""}`,
		`{"id":42,"name":"bad name"}`, `{"id":42,"name":"foo","extra":1}`,
		`{"id":42,"name":"foo"} {}`, "\xef\xbb\xbf" + `{"id":42,"name":"foo"}`,
		"\xff\xfe{\x00}", `{"id":42,"name":"é"}`, `{"id":42,"name":"` + strings.Repeat("x", 81) + `"}`}
	for _, shadow := range []bool{false, true} {
		for index, body := range invalid {
			t.Run(fmt.Sprintf("shadow=%v/input=%d", shadow, index), func(t *testing.T) {
				store := newStore(t)
				handler, recorder := testHandler(t, store)
				var marker []string
				if shadow {
					marker = []string{"true"}
				}
				checkResponse(t, request(handler, "POST", body, marker), 400, map[string]string{"error": "invalid item"})
				for _, span := range recorder.Ended() {
					if span.Name() == "items.write" {
						t.Fatal("invalid input produced an effect")
					}
				}
			})
		}
	}
}

func TestWriteBoundaries(t *testing.T) {
	for _, value := range []item{{ID: 1, Name: "A_-0"}, {ID: 2147483647, Name: strings.Repeat("x", 80)}} {
		for _, shadow := range []bool{false, true} {
			t.Run(fmt.Sprintf("%d/shadow=%v", value.ID, shadow), func(t *testing.T) {
				effect := itemEffect{Operation: "insert", Table: "items", Values: value}
				store := newStore(t)
				if !shadow {
					store.expected = &effect
				}
				handler, recorder := testHandler(t, store)
				encoded, _ := json.Marshal(value)
				var marker []string
				if shadow {
					marker = []string{"true"}
				}
				checkResponse(t, request(handler, "POST", string(encoded), marker), 201, value)
				checkEffectEvidence(t, recorder, shadow, effect)
			})
		}
	}
}

func TestWriteDependencyFailuresDoNotReportCommittedEffects(t *testing.T) {
	for _, tc := range []struct {
		err     error
		status  int
		message string
	}{
		{&pgconn.PgError{Code: "23505"}, 409, "item exists"},
		{errors.New("commit failed"), 503, "database unavailable"},
		{&pgconn.PgError{Code: "08006"}, 503, "database unavailable"},
	} {
		t.Run(tc.err.Error(), func(t *testing.T) {
			store := newStore(t)
			store.expected, store.commitErr = &expectedEffect, tc.err
			handler, recorder := testHandler(t, store)
			checkResponse(t, request(handler, "POST", `{"id":42,"name":"foo"}`, nil), tc.status, map[string]string{"error": tc.message})
			for _, span := range recorder.Ended() {
				if _, ok := attributes(span.Attributes())["demo.write.effect"]; ok {
					t.Fatal("failed commit reported as applied")
				}
			}
		})
	}
}
