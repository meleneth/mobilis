package app

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestShadowRequestContext(t *testing.T) {
	for _, tc := range []struct {
		values []string
		shadow bool
	}{
		{nil, false}, {[]string{"true"}, true}, {[]string{"false"}, false},
		{[]string{"true", "true"}, false}, {[]string{"true,false"}, false},
	} {
		r := httptest.NewRequest("POST", "/items", nil)
		r.Header["X-Mobilis-Shadow"] = tc.values
		if got := isShadowRequest(r); got != tc.shadow {
			t.Fatalf("%v: shadow=%v", tc.values, got)
		}
	}
}

func TestShadowSkipsOnlyCommitBoundary(t *testing.T) {
	effect := determineEffect(item{ID: 42, Name: "foo"})
	encoded, err := json.Marshal(effect)
	if err != nil {
		t.Fatal(err)
	}
	if string(encoded) != `{"operation":"insert","table":"items","values":{"id":42,"name":"foo"}}` {
		t.Fatal(string(encoded))
	}
	// A nil database proves the shadow boundary makes no database call.
	committed, err := commitItem(context.Background(), nil, effect, true)
	if err != nil || committed {
		t.Fatalf("shadow committed=%v err=%v", committed, err)
	}
}

func TestShadowHandlerUsesNormalValidationAndEffect(t *testing.T) {
	mux := http.NewServeMux()
	register(mux, Dependencies{})
	for _, tc := range []struct {
		body   string
		status int
	}{
		{`{"id":42,"name":"foo"}`, 201}, {`{"id":true,"name":"foo"}`, 400},
		{`{"id":42,"name":"bad name"}`, 400}, {`{"id":42,"name":"foo","extra":1}`, 400},
	} {
		request := httptest.NewRequest("POST", "/items", strings.NewReader(tc.body))
		request.Header.Set("X-Mobilis-Shadow", "true")
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, request)
		if response.Code != tc.status {
			t.Fatalf("%s: %d", tc.body, response.Code)
		}
	}
}
