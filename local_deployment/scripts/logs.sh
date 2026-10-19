#!/usr/bin/env bash
# Tails container logs.  ./scripts/logs.sh api|web|ai [-f]
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
  api) name="$API_CONTAINER" ;;
  web) name="$WEB_CONTAINER" ;;
  ai)  name="$AI_CONTAINER" ;;
  *)   die "usage: logs.sh api|web|ai [-f]" ;;
esac
shift

container_exists "$name" || die "container $name does not exist — start it with ./scripts/up.sh"
if [ "${1:-}" = "-f" ]; then podman logs -f "$name"; else podman logs --tail 100 "$name"; fi
