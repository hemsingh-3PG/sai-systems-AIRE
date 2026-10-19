# ─────────────────────────────────────────────────────────────────────────────
#  PacEHR_AI (Node.js, TypeScript) — local container image
#
#  Lives OUTSIDE the PacEHR_AI repo; the repo is a read-only build context.
#  Build it through scripts/build.sh (runtime) or scripts/test-ai.sh (test):
#      podman build -f containerfiles/ai.Containerfile \
#                   --ignorefile containerfiles/ai.ignore  <path-to-PacEHR_AI>
#
#  The repo compiles src/ to dist/ with `npm run build` (tsc + tsc-alias) and
#  runs `node dist/server.js` in production (its `start:prod` script). The
#  compile happens inside the image; nothing is written to your checkout.
# ─────────────────────────────────────────────────────────────────────────────

ARG NODE_IMAGE=docker.io/library/node:22-alpine

FROM ${NODE_IMAGE} AS base
WORKDIR /app

# ── deps: every dependency, for building and testing ────────────────────────
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

# ── test: typecheck + unit tests (+ integration on demand) ──────────────────
# Built only by scripts/test-ai.sh (--target test).
FROM deps AS test
COPY . .
CMD ["sh", "-c", "npm run typecheck && npm test && npm run build"]

# ── build: src/*.ts → dist/*.js ──────────────────────────────────────────────
FROM deps AS build
COPY tsconfig.json tsconfig.build.json ./
COPY src/ src/
COPY migrations/ migrations/
RUN npm run build && test -f dist/server.js

# ── runtime: production dependencies and the compiled output only ───────────
FROM base AS runtime
ENV NODE_ENV=production
# The lock file is the pin: what is tested is what runs.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force
# No source, no tests, no .env.local (ai.ignore keeps every env file out of the
# context). Configuration arrives as environment variables from scripts/up.sh,
# like app settings in Azure.
COPY --from=build /app/dist ./dist
# dist/migrate.js reads ../../migrations/sql beside dist, as in the repo's own Dockerfile.
COPY --from=build /app/migrations ./migrations

USER node
ENV PORT=3000
EXPOSE 3000

# node as PID 1, not npm, so SIGTERM reaches server.js and the pool is closed.
CMD ["node", "dist/server.js"]
