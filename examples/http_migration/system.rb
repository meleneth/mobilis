# frozen_string_literal: true

require "mobilis"

module HTTPMigrationDemo
  def self.system(mirror_percent: 100, candidate_percent: 0)
    system = Mobilis::System.new("http-migration")
    dsl = Mobilis::DSL::DSLContext.new(system)
    db = dsl.postgres("store")
    traces = dsl.otel_collector("telemetry")
    jaeger = dsl.jaeger("trace-viewer")
    dsl.connect(from: traces, to: jaeger)

    legacy = dsl.fastapi("legacy")
    legacy.add_sqlalchemy_model("Item", table: "items") do |model|
      model.column("id", "Integer", python_type: "int", primary_key: true)
      model.column("name", "String(80)", python_type: "str", unique: true)
    end
    legacy.add_model(Mobilis::Model::File.new("src/service_legacy/routes.py", <<~PYTHON))
      from sqlalchemy import select
      from .database import Session
      from .models import Item


      def register(app):
          @app.get("/items")
          def items():
              with Session() as session:
                  return [{"id": item.id, "name": item.name}
                          for item in session.scalars(select(Item).order_by(Item.id))]
    PYTHON

    candidate = dsl.go_http("candidate")
    candidate.add_model(Mobilis::Model::File.new("internal/app/routes.go", <<~GO))
      package app

      import (
          "encoding/json"
          "log"
          "net/http"
      )

      func register(mux *http.ServeMux, deps Dependencies) {
          mux.HandleFunc("GET /items", func(w http.ResponseWriter, r *http.Request) {
              rows, err := deps.DB.Query(r.Context(), "SELECT id, name FROM items ORDER BY id")
              if err != nil {
                  log.Printf("query items: %v", err)
                  http.Error(w, "database unavailable", http.StatusServiceUnavailable)
                  return
              }
              defer rows.Close()
              type item struct {
                  ID int `json:"id"`
                  Name string `json:"name"`
              }
              items := make([]item, 0)
              for rows.Next() {
                  var value item
                  if err := rows.Scan(&value.ID, &value.Name); err != nil {
                      log.Printf("scan item: %v", err)
                      http.Error(w, "database error", http.StatusInternalServerError)
                      return
                  }
                  items = append(items, value)
              }
              if err := rows.Err(); err != nil {
                  log.Printf("read items: %v", err)
                  http.Error(w, "database error", http.StatusInternalServerError)
                  return
              }
              w.Header().Set("Content-Type", "application/json")
              if err := json.NewEncoder(w).Encode(items); err != nil { log.Printf("write response: %v", err) }
          })
      }
    GO
    gateway = dsl.envoy("gateway")
    [legacy, candidate].each do |service|
      dsl.connect(from: service, to: db)
      dsl.connect(from: service, to: traces)
    end
    dsl.connect(from: gateway, to: traces)
    dsl.route(from: gateway, to: legacy, candidate: candidate,
      mirror_percent: mirror_percent, candidate_percent: candidate_percent)
    system
  end
end
