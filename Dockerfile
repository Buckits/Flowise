# syntax=docker/dockerfile:1.7-labs
FROM --platform=linux/amd64 node:20-alpine
USER root

# Copy combined certs into container's trusted certs directory.

# Install all packages needed
RUN apk add --update libc6-compat python3 make g++ git vim curl jq sed wget supervisor gettext
RUN apk add --no-cache build-base cairo-dev pango-dev
RUN apk add --no-cache chromium
RUN rm -rf /var/cache/apk/*

RUN npm install -g pnpm

WORKDIR /app/src

# ---- ARG/ENV ----
ARG UID
ARG GID
ARG USER

ENV PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
    PATH="/usr/local/bin/pnpm:$PATH" \
    NODE_OPTIONS="--max-old-space-size=8192 --tls-cipher-list=DEFAULT@SECLEVEL=0 --openssl-legacy-provider" \
    NODE_TLS_REJECT_UNAUTHORIZED=0 \
    CI=true \
    PNPM_YES=true \
    NPM_CONFIG_YES=true

# ----------------------------
# 1) Dependency layer keyed ONLY on the lockfile/workspace files
# ----------------------------
COPY src/pnpm-lock.yaml src/pnpm-workspace.yaml src/package.json src/turbo.json src/.npmrc ./

# Pre-download deps into pnpm store (fast & cacheable)
RUN --mount=type=cache,id=pnpm-store,target=/root/.pnpm-store \
    pnpm fetch

# ----------------------------
# 2) Copy the rest of the source AFTER the fetch layer
# ----------------------------
COPY src/ ./

# Materialize node_modules from the cached store without network
RUN --mount=type=cache,id=pnpm-store,target=/root/.pnpm-store \
    pnpm install --offline --frozen-lockfile

# ----------------------------
# 3) Build only what changed (persist Turborepo cache across builds)
# ----------------------------
ENV TURBO_CACHE_DIR=/app/src/.turbo
RUN --mount=type=cache,id=turbo-cache-root,target=/app/src/.turbo \
    --mount=type=cache,id=turbo-cache-legacy,target=/app/src/node_modules/.cache/turbo \
    pnpm turbo run build

# Clean pnpm store metadata
RUN pnpm store prune

EXPOSE 3000

CMD ["pnpm", "start"]
