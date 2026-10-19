# ─────────────────────────────────────────────────────────────────────────────
#  PacEHR web (Angular 18) — local container image
#
#  Lives OUTSIDE the PacEHR repo; the repo is a read-only build context.
#  Build it through scripts/build.sh, which supplies the build args below.
#
#  The API URL is rewritten INSIDE the image only (see the sed step) — the
#  checked-out environment.ts on your Mac is never modified.
# ─────────────────────────────────────────────────────────────────────────────

ARG NODE_IMAGE=docker.io/library/node:22-alpine
ARG NGINX_IMAGE=docker.io/library/nginx:alpine

# ── build stage ─────────────────────────────────────────────────────────────
FROM ${NODE_IMAGE} AS build

# Base URL the browser will use to reach the API (default = local API container).
ARG API_BASE_URL=http://localhost:8080
# Angular configuration name from angular.json; empty = default (environment.ts).
ARG BUILD_CONFIG=""
# "true" to minify/optimize the bundle.
ARG OPTIMIZE=true

ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_BROWSERS_PATH=0 \
    NG_CLI_ANALYTICS=false \
    CI=true \
    NODE_OPTIONS=--max-old-space-size=12288

WORKDIR /src

# Dependencies first so this layer is reused when only source changes.
# `npm install --legacy-peer-deps` mirrors the Azure pipeline exactly: `npm ci`
# fails here because @agm/core@1.0.0 declares peers for Angular 6-9 while the app
# is on Angular 18.
COPY package.json package-lock.json ./
RUN npm install --legacy-peer-deps --no-audit --no-fund

COPY . .

# Point the app at the chosen API. The whole apiBaseUrl line is replaced in
# every environment file, so it works no matter which Angular configuration is
# built — including environment.prod.ts, whose value is the CI placeholder
# '__apiBaseUrl__'. Commented-out variants start with // and are left alone.
RUN set -eu; \
    for f in src/environments/environment*.ts; do \
      sed -i -E "s|^([[:space:]]*)apiBaseUrl:.*$|\1apiBaseUrl: \`${API_BASE_URL}\`,|" "$f"; \
      printf '  patched %s -> %s\n' "$f" "${API_BASE_URL}"; \
    done

RUN set -eu; \
    args="--base-href=/ --output-hashing=all"; \
    [ -n "${BUILD_CONFIG}" ] && args="$args --configuration ${BUILD_CONFIG}" || true; \
    if [ "${OPTIMIZE}" = "true" ]; then args="$args --optimization=true --source-map=false"; \
    else args="$args --optimization=false"; fi; \
    printf 'ng build %s\n' "$args"; \
    npx ng build $args

# angular.json sets outputPath dist/pacehrweb; the `application` builder puts
# the site under a browser/ subfolder. Normalise either shape to /out.
RUN set -eu; \
    if [ -d dist/pacehrweb/browser ]; then cp -r dist/pacehrweb/browser /out; \
    else cp -r dist/pacehrweb /out; fi; \
    ls -la /out | head

# ── runtime stage ───────────────────────────────────────────────────────────
FROM ${NGINX_IMAGE} AS runtime
COPY --from=build /out /usr/share/nginx/html

# SPA config: deep links and page refreshes must fall back to index.html,
# otherwise Angular's client-side routes 404 on reload.
RUN printf '%s\n' \
    'server {' \
    '    listen 80;' \
    '    server_name _;' \
    '    root /usr/share/nginx/html;' \
    '    index index.html;' \
    '    gzip on;' \
    '    gzip_types text/css application/javascript application/json image/svg+xml;' \
    '    gzip_min_length 1024;' \
    '    location ~* \.(?:js|css|woff2?|ttf|eot|otf|png|jpe?g|gif|svg|ico)$ {' \
    '        expires 7d;' \
    '        add_header Cache-Control "public";' \
    '        try_files $uri =404;' \
    '    }' \
    '    location / {' \
    '        try_files $uri $uri/ /index.html;' \
    '        add_header Cache-Control "no-store";' \
    '    }' \
    '}' \
    > /etc/nginx/conf.d/default.conf \
    && nginx -t

EXPOSE 80
