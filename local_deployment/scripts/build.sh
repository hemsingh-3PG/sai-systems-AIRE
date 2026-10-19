#!/usr/bin/env bash
# Builds the container images from the repos.
#   ./scripts/build.sh            # all three
#   ./scripts/build.sh api        # API only
#   ./scripts/build.sh web        # frontend only
#   ./scripts/build.sh ai         # PacEHR_AI only
#   ./scripts/build.sh --no-cache # force a clean rebuild
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target="all"
extra=()
for a in "$@"; do
  case "$a" in
    api|web|ai|all) target="$a" ;;
    --no-cache)     extra+=(--no-cache) ;;
    -h|--help)      sed -n '2,9p' "$0"; exit 0 ;;
    *)              die "unknown argument: $a" ;;
  esac
done

podman_ready || die "Podman is not running. Run ./scripts/preflight.sh first."

build_api() {
  step "Building API image → $API_IMAGE"
  info "context: $API_REPO_ABS"
  info "this takes ~3-6 minutes the first time (NuGet restore), seconds after that"
  podman build \
    -t "$API_IMAGE" \
    -f "$DEPLOY_ROOT/containerfiles/api.Containerfile" \
    --ignorefile "$DEPLOY_ROOT/containerfiles/api.ignore" \
    ${extra[@]+"${extra[@]}"} \
    "$API_REPO_ABS"
  ok "built $API_IMAGE"
}

build_web() {
  step "Building web image → $WEB_IMAGE"
  info "context:  $WEB_REPO_ABS"
  info "API URL:  ${WEB_API_BASE_URL}   (baked into the bundle at build time)"
  info "ng config: ${WEB_BUILD_CONFIG:-<default: environment.ts>}   optimize=${WEB_OPTIMIZE}"
  info "this takes ~10-20 minutes the first time (npm ci + ng build)"
  podman build \
    -t "$WEB_IMAGE" \
    -f "$DEPLOY_ROOT/containerfiles/web.Containerfile" \
    --ignorefile "$DEPLOY_ROOT/containerfiles/web.ignore" \
    --build-arg "NODE_IMAGE=$NODE_IMAGE" \
    --build-arg "NGINX_IMAGE=$NGINX_IMAGE" \
    --build-arg "API_BASE_URL=$WEB_API_BASE_URL" \
    --build-arg "BUILD_CONFIG=$WEB_BUILD_CONFIG" \
    --build-arg "OPTIMIZE=$WEB_OPTIMIZE" \
    ${extra[@]+"${extra[@]}"} \
    "$WEB_REPO_ABS"
  ok "built $WEB_IMAGE"
}

build_ai() {
  step "Building AI image → $AI_IMAGE"
  info "context: $AI_REPO_ABS  (branch: $(git -C "$AI_REPO_ABS" branch --show-current 2>/dev/null || echo '?'))"
  info "npm ci + npm run build (tsc → dist/) inside the image; ~1-2 minutes the first time"
  podman build \
    -t "$AI_IMAGE" \
    -f "$DEPLOY_ROOT/containerfiles/ai.Containerfile" \
    --ignorefile "$DEPLOY_ROOT/containerfiles/ai.ignore" \
    --target runtime \
    --build-arg "NODE_IMAGE=$AI_NODE_IMAGE" \
    ${extra[@]+"${extra[@]}"} \
    "$AI_REPO_ABS"
  ok "built $AI_IMAGE"
}

for svc in $(services_for "$target"); do "build_$svc"; done
