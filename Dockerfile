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

# Copy all workspace package.json files (but not source code yet)
COPY src/packages/api-documentation/package.json ./packages/api-documentation/
COPY src/packages/components/package.json ./packages/components/
COPY src/packages/server/package.json ./packages/server/
COPY src/packages/ui/package.json ./packages/ui/
COPY src/docker/worker/healthcheck/package.json ./docker/worker/healthcheck/

# Pre-download deps into pnpm store (fast & cacheable)
RUN --mount=type=cache,id=pnpm-store,target=/root/.pnpm-store \
    pnpm fetch

# Materialize node_modules from the cached store without network
# This layer now only rebuilds when package.json or lockfile changes!
RUN --mount=type=cache,id=pnpm-store,target=/root/.pnpm-store \
    pnpm install --offline --frozen-lockfile

# ----------------------------
# 2) Copy the rest of the source AFTER installing dependencies
# ----------------------------
COPY src/ ./

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
RUN set -eux; \
    # Check if group with target GID exists
    grp="$(getent group "${GID}" | cut -d: -f1 || true)"; \
    if [ -z "${grp}" ]; then \
        grp="${USER}"; \
        addgroup -g "${GID}" "${grp}"; \
    fi; \
    # Check if user with target UID already exists
    existing_user="$(getent passwd "${UID}" | cut -d: -f1 || true)"; \
    if [ -n "${existing_user}" ]; then \
        # User exists, modify it to match desired username
        if [ "${existing_user}" != "${USER}" ]; then \
            deluser "${existing_user}"; \
            adduser -D -u "${UID}" "${USER}" "${grp}"; \
        fi; \
    else \
        # User doesn't exist, create it
        adduser -D -u "${UID}" "${USER}" "${grp}"; \
    fi


CMD ["pnpm", "start"]
