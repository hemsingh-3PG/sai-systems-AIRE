#!/usr/bin/env bash
# Runs PacEHR_AI's checks inside a container (the "test" stage of ai.Containerfile),
# so they run on the same Node image the service ships on, not on your Mac's Node.
#   ./scripts/test-ai.sh                 # typecheck + unit tests + build (offline, no settings needed)
#   ./scripts/test-ai.sh --integration   # also the integration tier, which reaches Azure
#                                        # with the settings in AI_ENV_FILE
#   ./scripts/test-ai.sh --no-cache      # rebuild the test image from scratch
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

integration=0
extra=()
for a in "$@"; do
  case "$a" in
    --integration) integration=1 ;;
    --no-cache)    extra+=(--no-cache) ;;
    -h|--help)     sed -n '2,8p' "$0"; exit 0 ;;
    *)             die "unknown argument: $a" ;;
  esac
done

podman_ready || die "Podman is not running. Run ./scripts/preflight.sh ai first."
[ -n "$AI_REPO_ABS" ] || die "AI repo not found at: $(_resolve "$AI_REPO")  (fix AI_REPO in config.env)"

step "Building AI test image → $AI_TEST_IMAGE"
podman build \
  -t "$AI_TEST_IMAGE" \
  -f "$DEPLOY_ROOT/containerfiles/ai.Containerfile" \
  --ignorefile "$DEPLOY_ROOT/containerfiles/ai.ignore" \
  --target test \
  --build-arg "NODE_IMAGE=$AI_NODE_IMAGE" \
  ${extra[@]+"${extra[@]}"} \
  "$AI_REPO_ABS"
ok "built $AI_TEST_IMAGE"

step "Typecheck + unit tests + build (network blocked, no settings)"
podman run --rm "$AI_TEST_IMAGE"
ok "typecheck, unit tests and build passed"

if [ "$integration" -eq 1 ]; then
  [ -f "$AI_ENV_FILE_ABS" ] || die "AI settings file not found: $AI_ENV_FILE_ABS"
  step "Integration tests (reach Azure SQL and Azure OpenAI)"
  info "a test that cannot reach Azure is reported as skipped, with the reason"
  podman run --rm --env-file "$AI_ENV_FILE_ABS" "$AI_TEST_IMAGE" npm run test:integration
  ok "integration run finished"
fi
