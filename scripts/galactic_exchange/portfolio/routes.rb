Rails.application.routes.draw do
  get "/health", to: proc { [200, {"content-type" => "application/json"}, ['{"status":"ok"}']] }
  get "/positions", to: "positions#index"
  get "/processed", to: "positions#processed"
end
