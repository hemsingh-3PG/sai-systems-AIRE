#!/usr/bin/env bash
# Starts the containers from the already-built images.
#   ./scripts/up.sh             # all three
#   ./scripts/up.sh api|web|ai  # just one
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target="${1:-all}"
services="$(services_for "$target")"
podman_ready || die "Podman is not running. Run ./scripts/preflight.sh first."

step "Network"
if podman network exists "$NETWORK" 2>/dev/null; then
  ok "network $NETWORK already exists"
else
  podman network create "$NETWORK" >/dev/null
  ok "created network $NETWORK"
fi

start_api() {
  image_exists "$API_IMAGE" || die "image $API_IMAGE not found — run ./scripts/build.sh api"
  step "Starting API container"
  remove_container "$API_CONTAINER"
  podman run -d \
    --name "$API_CONTAINER" \
    --network "$NETWORK" \
    -p "${API_PORT}:8080" \
    -e "ASPNETCORE_ENVIRONMENT=${ASPNETCORE_ENV}" \
    --restart unless-stopped \
    "$API_IMAGE" >/dev/null
  ok "$API_CONTAINER is up  →  http://localhost:${API_PORT}/swagger"
}

start_web() {
  image_exists "$WEB_IMAGE" || die "image $WEB_IMAGE not found — run ./scripts/build.sh web"
  step "Starting web container"
  remove_container "$WEB_CONTAINER"
  podman run -d \
    --name "$WEB_CONTAINER" \
    --network "$NETWORK" \
    -p "${WEB_PORT}:80" \
    --restart unless-stopped \
    "$WEB_IMAGE" >/dev/null
  ok "$WEB_CONTAINER is up  →  http://localhost:${WEB_PORT}"
}

start_ai() {
  image_exists "$AI_IMAGE" || die "image $AI_IMAGE not found — run ./scripts/build.sh ai"
  [ -f "$AI_ENV_FILE_ABS" ] || die "AI settings file not found: $AI_ENV_FILE_ABS  (cp .env.example .env.local in PacEHR_AI and fill it in)"
  step "Starting AI container"
  remove_container "$AI_CONTAINER"
  # The settings arrive as environment variables, as app settings do in Azure.
  # PORT is pinned after the file so the container always listens where -p points.
  # on-failure, not unless-stopped: a settings error exits at startup, and an
  # endless restart loop would bury that one log line.
  podman run -d \
    --name "$AI_CONTAINER" \
    --network "$NETWORK" \
    -p "${AI_PORT}:3000" \
    --env-file "$AI_ENV_FILE_ABS" \
    -e PORT=3000 \
    --restart on-failure:3 \
    "$AI_IMAGE" >/dev/null
  ok "$AI_CONTAINER is up  →  http://localhost:${AI_PORT}/health   (other containers: http://${AI_CONTAINER}:3000)"
}

for svc in $services; do "start_$svc"; done
