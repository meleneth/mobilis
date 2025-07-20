# 🔧 Lessons from the `dc_dev` Spike — July 2025

This document captures the integration pain points, fixes, and future improvements uncovered while bringing up the multi-service environment for `parent_account_id` using Mobilis.

---

## ✅ What Worked

- Services booted correctly with proper Compose config
- Inter-service HTTP calls routed via Docker DNS (`service-name`)
- ENV injection via Compose worked for basic values like `RAILS_SECRET_KEY_BASE`
- `user-management-service` rendered HTML properly when assets were precompiled

---

## 🔨 What Broke (and How We Fixed It)

### 1. 🔥 `RAILS_SECRET_KEY_BASE` Missing at Build Time

**Problem**:  
`rails assets:precompile` failed because the env var wasn't set at build.

**Fix**:  
Set `RAILS_SECRET_KEY_BASE_DUMMY=1` and guard the initializer:

```ruby
unless ENV.key?("RAILS_SECRET_KEY_BASE_DUMMY")
  Rails.application.config.secret_key_base = ENV.fetch("RAILS_SECRET_KEY_BASE")
end
```

In the Dockerfile, pass the dummy env var during build:

```dockerfile
RUN RAILS_SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
```

---

### 2. 🚡 `HostAuthorization` 403s from Internal Service Calls

**Problem**:  
Rails blocked requests with error:

```
Blocked hosts: organization-service, organization-service
```

**Cause**:  
`config.hosts` was missing or had a typo (`organizaton-service` 🙃)

**Fix**:

In `config/environments/production.rb`:

```ruby
config.hosts << "organization-service"
```

Or use a dev-wide regex:

```ruby
config.hosts << /.*-service$/
```

**Debug tip**:

```bash
rails runner 'puts Rails.application.config.hosts.inspect'
```

---

### 3. 🤯 Inconsistent `RAILS_ENV` Across Services

**Problem**:  
`user-management-service` was in `production`, but the API services (`user`, `account`, `organization`) were defaulting to `development`.

**Impact**:

- Wrong `environments/*.rb` used
- Host authorization config ignored
- ENV-based secrets and logging misaligned

**Fix**:

Explicitly set `RAILS_ENV=production` in each service Compose block:

```yaml
environment:
  RAILS_ENV: production
  RAILS_LOG_TO_STDOUT: 1
```

---

## 📌 Mobilis Fixes to Implement

- [ ] Default `RAILS_ENV=production` for all Rails services in dev Compose
- [ ] Auto-generate dummy `RAILS_SECRET_KEY_BASE` for builds
- [ ] Inject `RAILS_LOG_TO_STDOUT` for dev observability
- [ ] Add plugin to inject proper `config.hosts` entries or regex
- [ ] Add realization warning when a Rails service lacks `RAILS_ENV`
- [ ] Add helper to define dev-only env vars (e.g. `env.dev_only(...)`)

---

*These pain points were real, but they made the system better. Lock the knowledge in, and make the next stack smoother.*

