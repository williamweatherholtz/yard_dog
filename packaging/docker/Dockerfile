# syntax=docker/dockerfile:1
#
# Yard Dog control-plane image. Multi-stage: compile a static `yd` from source,
# then land it on Docker's own CLI image (which already carries `docker` + the
# compose plugin) plus git. Build multi-arch with:
#   docker buildx build --platform linux/arm64,linux/amd64 -f packaging/docker/Dockerfile .
# (arm64 first — Raspberry Pi / ARM homelab is the primary target.)

# ---- build stage: static (musl) binary, so it runs on the tiny runtime ----
FROM rust:alpine AS build
RUN apk add --no-cache musl-dev build-base
WORKDIR /src/app
COPY app/ ./
RUN cargo build --release && cp target/release/yd /yd

# ---- runtime: docker CLI + compose plugin (from docker:cli) + git + yd ----
FROM docker:28-cli AS runtime
RUN apk add --no-cache git ca-certificates
COPY --from=build /yd /usr/local/bin/yd

# yd manages the HOST's Docker through the mounted socket, and its path/backup
# features read the host filesystem, so the stacks dir is mounted at the SAME path
# inside the container (see docker-compose.yml) — that way any path yd hands to the
# host daemon resolves identically on the host. `yd serve` binds 0.0.0.0 INSIDE the
# container; the compose file publishes that port to the host's loopback only, and
# the built-in Host allowlist still refuses every non-loopback Host header, so this
# bind never opens LAN access on its own.
ENV YD_ROOT=/srv/stacks \
    YD_PORT=8770 \
    YD_BIND=0.0.0.0
EXPOSE 8770

# Health = the control plane actually answers, not merely "process started".
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${YD_PORT}/" >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/bin/sh", "-c", "exec yd serve --root \"$YD_ROOT\" --port \"$YD_PORT\" --host \"$YD_BIND\""]
