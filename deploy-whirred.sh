#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${DIST_DIR:-${ROOT}/dist/mobilis}"
REMOTE="${WHIRRED_HOST:-whirred.io}"
REMOTE_DIR="${WHIRRED_DIR:-dist/mobilis}"
IMAGE="${WHIRRED_IMAGE:-mobilis-staging}"
SERVICE="${WHIRRED_SERVICE:-mobilis-staging}"
COMPOSE_DIR="${WHIRRED_COMPOSE_DIR:-/www/docker-stuff}"
PROXY_SERVICE="${WHIRRED_PROXY_SERVICE:-caddy}"
SOURCE_IMAGE="${WHIRRED_SOURCE_IMAGE:-}"

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

for command in rsync ssh docker python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  fi
done

# The normal playground build publishes to the nginx image, not the host's
# playground/public directory. Extract the finished, already-built assets.
# This script performs no compilation or asset generation, locally or remotely.
if [[ -z "$SOURCE_IMAGE" ]]; then
  # Compose's "images" command describes containers and may report an old
  # running container even after a new image was built. Use the built image
  # tag instead. Respect COMPOSE_PROJECT_NAME and compose's project name.
  PROJECT_NAME="$(cd "$ROOT" && docker compose config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')"
  SOURCE_IMAGE="${PROJECT_NAME}-playground"
fi
if [[ -z "$SOURCE_IMAGE" ]] || ! docker image inspect "$SOURCE_IMAGE" >/dev/null 2>&1; then
  printf 'No locally built playground image found. Run docker compose build playground, or set WHIRRED_SOURCE_IMAGE to an existing image.\n' >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d)"
CONTAINER=""
cleanup() {
  if [[ -n "$CONTAINER" ]]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

CONTAINER="$(docker create "$SOURCE_IMAGE")"
docker cp "$CONTAINER:/usr/share/nginx/html/." "$STAGING_DIR/"
docker rm "$CONTAINER" >/dev/null
CONTAINER=""

# Legacy playground images may contain the raw content-addressed WASM
# without compressed sidecars. Produce them locally when absent. This is
# compression only: no Ruby or application compilation, and nothing on whirred
# runs the compressor.
WASM_PATH="$(python3 - "$STAGING_DIR/runtime-config.json" "$STAGING_DIR" <<'PY'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
url = config["runtime"]["url"]
if not url.startswith("/vendor/ruby-") or not url.endswith(".wasm") or ".." in url:
    sys.exit(f"Invalid local WASM URL: {url}")
print(pathlib.Path(sys.argv[2]) / url.lstrip("/"))
PY
)"
if [[ -s "$WASM_PATH" && ! -s "${WASM_PATH}.br" ]]; then
  if ! command -v node >/dev/null 2>&1; then
    printf 'Missing Brotli sidecar for %s; install Node.js for local compression or rebuild the playground image.\\n' "$WASM_PATH" >&2
    exit 1
  fi
  printf 'Brotli artifact absent from image %s; compressing existing WASM locally (no compilation).\\n' "$SOURCE_IMAGE"
  node "$ROOT/playground/scripts/compress-wasm.mjs" "$WASM_PATH"
fi

# Verify exactly the runtime requested by the browser, including both the
# raw content-addressed WASM and its precompressed Brotli representation.
# Reject a CDN runtime or an image lacking the deterministic app archive.
python3 - "$STAGING_DIR" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for name in ("index.html", "application.js", "application.css",
             "runtime-config.json", "mobilis-app-manifest.json"):
    path = root / name
    if not path.is_file() or path.stat().st_size == 0:
        sys.exit(f"Missing built asset in playground image: {name}")

config = json.loads((root / "runtime-config.json").read_text())
runtime = config["runtime"]
sha = runtime["sha256"]
url = runtime["url"]
expected_url = f"/vendor/ruby-{sha}.wasm"
if len(sha) != 64 or url != expected_url:
    sys.exit(f"Expected content-addressed local WASM URL {expected_url}, got {url}")
wasm = root / url.lstrip("/")
if not wasm.is_file() or wasm.stat().st_size != runtime["size"]:
    sys.exit(f"Missing or incorrectly sized Ruby WASM: {wasm}")
if hashlib.file_digest(wasm.open("rb"), "sha256").hexdigest() != sha:
    sys.exit(f"Ruby WASM SHA-256 mismatch: {wasm}")
brotli = pathlib.Path(str(wasm) + ".br")
if not brotli.is_file() or brotli.stat().st_size == 0:
    sys.exit(f"Missing precompressed Brotli runtime: {brotli}")

manifest_url = config["application_manifest_url"]
if manifest_url != "/mobilis-app-manifest.json":
    sys.exit(f"Unexpected application manifest URL: {manifest_url}")
manifest = json.loads((root / manifest_url.lstrip("/")).read_text())
artifact = manifest["artifact"]
archive_url = artifact["url"]
archive_sha = artifact["sha256"]
if len(archive_sha) != 64 or archive_url != f"/mobilis-app-{archive_sha}.tar":
    sys.exit(f"Invalid content-addressed application URL: {archive_url}")
archive = root / archive_url.lstrip("/")
if not archive.is_file() or archive.stat().st_size != artifact["size"]:
    sys.exit(f"Missing or incorrectly sized Mobilis application: {archive}")
with archive.open("rb") as stream:
    if hashlib.file_digest(stream, "sha256").hexdigest() != archive_sha:
        sys.exit(f"Mobilis application SHA-256 mismatch: {archive}")
print(f"Verified WASM {sha}: {wasm.stat().st_size:,} raw bytes, "
      f"{brotli.stat().st_size:,} Brotli bytes "
      f"({brotli.stat().st_size / 1048576:.1f} MiB)")
PY

mkdir -p "$DIST_DIR"
rsync -a --delete "$STAGING_DIR/" "$DIST_DIR/"
cp "$ROOT/playground/nginx.conf" "$DIST_DIR/nginx.conf"
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
