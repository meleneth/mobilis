#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${REGISTRY:-registry.deva.station/meleneth}"
IMAGE_NAME="${IMAGE_NAME:-mobilis-playground}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-devastation}"
NAMESPACE="${NAMESPACE:-mobilis}"
DEPLOYMENT="${DEPLOYMENT:-mobilis}"
CONTAINER="${CONTAINER:-mobilis}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-300s}"
RUBY_RUNTIME_IMAGE="${MOBILIS_RUBY_RUNTIME_IMAGE:-mobilis-playground-ruby-runtime:2.10.1-ruby-4.0.10-rails-8.1.4.1}"

for command in git docker kubectl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  printf 'Refusing to deploy from a dirty working tree. Commit the intended changes first.\n' >&2
  exit 1
fi

revision="$(git rev-parse --short=7 HEAD)"
image="${REGISTRY}/${IMAGE_NAME}:${revision}"

if ! docker image inspect "$RUBY_RUNTIME_IMAGE" >/dev/null 2>&1; then
  printf 'Required Ruby WASM runtime image is missing: %s\nRun bin/build-playground-runtime after committing runtime dependency changes.\n' \
    "$RUBY_RUNTIME_IMAGE" >&2
  exit 1
fi

printf 'Building %s\n' "$image"
docker build \
  --build-arg "RUBY_WASM_RUNTIME_IMAGE=${RUBY_RUNTIME_IMAGE}" \
  --file Dockerfile.playground \
  --tag "$image" \
  .

printf 'Pushing %s\n' "$image"
docker push "$image"

printf 'Deploying %s to %s/%s in context %s\n' \
  "$image" "$NAMESPACE" "$DEPLOYMENT" "$KUBE_CONTEXT"
kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
  set image "deployment/${DEPLOYMENT}" "${CONTAINER}=${image}"
kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
  rollout status "deployment/${DEPLOYMENT}" --timeout "$ROLLOUT_TIMEOUT"

deployed_image="$(
  kubectl --context "$KUBE_CONTEXT" --namespace "$NAMESPACE" \
    get "deployment/${DEPLOYMENT}" \
    --output "jsonpath={.spec.template.spec.containers[?(@.name=='${CONTAINER}')].image}"
)"

if [[ "$deployed_image" != "$image" ]]; then
  printf 'Deployment image mismatch: expected %s, found %s\n' "$image" "$deployed_image" >&2
  exit 1
fi

printf 'Deployed %s successfully.\n' "$image"
