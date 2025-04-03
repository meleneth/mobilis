#!/bin/bash

set -euo pipefail

bundle exec rspec

# steep check

bundle exec mobilis generate testcases/rails-postgres.json
bundle exec mobilis generate testcases/rails-mysql.json
