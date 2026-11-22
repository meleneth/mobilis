#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_DIR="${PUBLIC_DIR:-${ROOT}/playground/public}"
DIST_DIR="${DIST_DIR:-${ROOT}/dist/mobilis}"
REMOTE="${WHIRRED_HOST:-whirred.io}"
REMOTE_DIR="${WHIRRED_DIR:-dist/mobilis}"
IMAGE="${WHIRRED_IMAGE:-mobilis-staging}"
SERVICE="${WHIRRED_SERVICE:-mobilis-staging}"
COMPOSE_DIR="${WHIRRED_COMPOSE_DIR:-/www/docker-stuff}"
PROXY_SERVICE="${WHIRRED_PROXY_SERVICE:-caddy}"

# Preserve normal SSH aliases and identities when the host configuration is
# usable. Sandboxed hosts can expose an SSH system include with ownership that
# OpenSSH rejects; in that case, use an empty config and the standard identity
# file discovery instead. An explicit config always wins.
SSH_ARGS=()
if [[ -n "${WHIRRED_SSH_CONFIG:-}" ]]; then
  SSH_ARGS=(-F "$WHIRRED_SSH_CONFIG")
elif ! ssh -G "$REMOTE" >/dev/null 2>&1; then
  SSH_ARGS=(-F /dev/null)
fi

RSYNC_RSH="ssh"
for arg in "${SSH_ARGS[@]}"; do
  printf -v quoted_arg '%q' "$arg"
  RSYNC_RSH+=" ${quoted_arg}"
done

for command in rsync ssh docker; do
  # docker itself only runs on the remote machine, so do not require it locally.
  if [[ "$command" == docker ]]; then continue; fi
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  fi
done

# This deploy script intentionally does not generate the Ruby WASM runtime,
# install dependencies, build JavaScript/CSS, or run the playground build.
# Package precisely the already-built web assets.
for file in index.html application.js application.css runtime-config.json mobilis-app-manifest.json; do
  if [[ ! -s "${PUBLIC_DIR}/${file}" ]]; then
    printf 'Missing built asset: %s\nBuild the playground locally before deployment.\n' "${PUBLIC_DIR}/${file}" >&2
    exit 1
  fi
done
if ! compgen -G "${PUBLIC_DIR}/vendor/ruby-*.wasm" >/dev/null; then
  printf 'Missing content-addressed Ruby WASM runtime under %s/vendor/\n' "$PUBLIC_DIR" >&2
  exit 1
fi
if ! compgen -G "${PUBLIC_DIR}/mobilis-app-*.tar" >/dev/null; then
  printf 'Missing packaged Mobilis browser application under %s/\n' "$PUBLIC_DIR" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rsync -a --delete "${PUBLIC_DIR}/" "${DIST_DIR}/"
cp "${ROOT}/playground/nginx.conf" "${DIST_DIR}/nginx.conf"
cat >"${DIST_DIR}/Dockerfile" <<'DOCKERFILE'
FROM nginx:1.30.6-trixie
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY . /usr/share/nginx/html/
EXPOSE 80
DOCKERFILE

# Check inputs and scripts before touching the remote deployment.
ssh "${SSH_ARGS[@]}" "$REMOTE" "mkdir -p '$REMOTE_DIR'"
rsync -e "$RSYNC_RSH" -av --delete "${DIST_DIR}/" "${REMOTE}:${REMOTE_DIR}/"

ssh "${SSH_ARGS[@]}" "$REMOTE" "bash -se" -- \
  "$REMOTE_DIR" "$IMAGE" "$COMPOSE_DIR" "$SERVICE" "$PROXY_SERVICE" <<'REMOTE_SCRIPT'
set -euo pipefail
remote_dir="$1"
image="$2"
compose_dir="$3"
service="$4"
proxy_service="$5"

cd "$remote_dir"
docker build --tag "$image" .
cd "$compose_dir"
docker compose up -d --no-deps "$service"
docker compose exec -T "$proxy_service" \
  caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
REMOTE_SCRIPT

printf 'Deployed %s via %s:%s (Compose service %s).\n' "$IMAGE" "$REMOTE" "$REMOTE_DIR" "$SERVICE"
