#!/usr/bin/env bash
# Removes containers, images and the network created by this deployment.
# Nothing else on your machine is touched.  ./scripts/clean.sh [--yes]
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

podman_ready || die "Podman is not running."

printf 'This will remove:\n'
printf '  containers : %s, %s, %s\n' "$API_CONTAINER" "$WEB_CONTAINER" "$AI_CONTAINER"
printf '  images     : %s, %s, %s, %s\n' "$API_IMAGE" "$WEB_IMAGE" "$AI_IMAGE" "$AI_TEST_IMAGE"
printf '  network    : %s\n\n' "$NETWORK"

if [ "${1:-}" != "--yes" ]; then
  printf 'Continue? [y/N] '
  read -r reply
  case "$reply" in y|Y|yes|YES) ;; *) echo "aborted"; exit 0 ;; esac
fi

step "Removing"
remove_container "$API_CONTAINER"
remove_container "$WEB_CONTAINER"
remove_container "$AI_CONTAINER"
for img in "$API_IMAGE" "$WEB_IMAGE" "$AI_IMAGE" "$AI_TEST_IMAGE"; do
  if image_exists "$img"; then podman rmi -f "$img" >/dev/null 2>&1 && info "removed image $img" || warn "could not remove $img"; fi
done
podman network exists "$NETWORK" 2>/dev/null && podman network rm "$NETWORK" >/dev/null 2>&1 && info "removed network $NETWORK" || true
ok "cleaned"
