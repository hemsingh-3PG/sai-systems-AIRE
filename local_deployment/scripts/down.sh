#!/usr/bin/env bash
# Stops and removes the containers. Images are kept, so the next
# ./deploy.sh --no-build starts again in seconds.
#   ./scripts/down.sh [api|web|ai|all]
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

target="${1:-all}"
services="$(services_for "$target")"
podman_ready || die "Podman is not running."

container_for() { case "$1" in api) echo "$API_CONTAINER" ;; web) echo "$WEB_CONTAINER" ;; ai) echo "$AI_CONTAINER" ;; esac; }

step "Stopping containers"
for svc in $services; do remove_container "$(container_for "$svc")"; done
ok "done — images and the $NETWORK network are left in place"
