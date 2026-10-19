#!/usr/bin/env bash
# Shows what is running and whether each URL actually answers.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

podman_ready || die "Podman is not running."

step "Containers"
podman ps -a \
  --filter "name=^${API_CONTAINER}$" \
  --filter "name=^${WEB_CONTAINER}$" \
  --filter "name=^${AI_CONTAINER}$" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"

step "Endpoints"
api_url="http://localhost:${API_PORT}/swagger/index.html"
web_url="http://localhost:${WEB_PORT}/"
# Liveness only: /health/ready makes a billed model call on every hit.
ai_url="http://localhost:${AI_PORT}/health"

api_code="$(http_code "$api_url")"
web_code="$(http_code "$web_url")"
ai_code="$(http_code "$ai_url")"

if [ "$api_code" = "200" ]; then ok  "API  HTTP $api_code  http://localhost:${API_PORT}/swagger"
else                             warn "API  HTTP $api_code  http://localhost:${API_PORT}/swagger   (000 = not answering)"; fi
if [ "$web_code" = "200" ]; then ok  "Web  HTTP $web_code  http://localhost:${WEB_PORT}"
else                             warn "Web  HTTP $web_code  http://localhost:${WEB_PORT}   (000 = not answering)"; fi
if [ "$ai_code" = "200" ];  then ok  "AI   HTTP $ai_code  http://localhost:${AI_PORT}/health"
else                             warn "AI   HTTP $ai_code  http://localhost:${AI_PORT}/health   (000 = not answering)"; fi

step "Open these"
printf '  Frontend : http://localhost:%s\n' "$WEB_PORT"
printf '  API docs : http://localhost:%s/swagger\n' "$API_PORT"
printf '  AI       : http://localhost:%s/health   (readiness: /health/ready — calls Azure SQL and the model)\n' "$AI_PORT"
printf '\n  %sLogs:%s ./scripts/logs.sh api -f   |   ./scripts/logs.sh web -f   |   ./scripts/logs.sh ai -f\n' "$C_DIM" "$C_0"
