#!/usr/bin/env ruby

require "mobilis"

Mobilis::DSL.generate("generate") do
  redis("some")
  flask("verifier") do |svc|
    svc.env_var_alias("REDIS_URL", "SOME_REDIS_URL")
    svc.write_file("app.py", <<~PY)
      import os
      import redis
      from flask import Flask
      from datetime import datetime

      r = redis.from_url(os.environ["REDIS_URL"])
      app = Flask(__name__)

      @app.route("/")
      def index():
          now = datetime.utcnow().isoformat()
          r.set("last_ping", now)
          return f"Wrote to Redis at: {now}"
    PY
  end
  connect from: "verifier", to: "some"
end
