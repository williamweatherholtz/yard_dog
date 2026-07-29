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
# container because Docker port-publishing forwards to the container's interface,
# not its loopback.
#
# SECURITY — read this: the ONLY thing confining this no-auth, socket-wired
# (host-root-equivalent) control plane is the `127.0.0.1:` prefix on the publish in
# docker-compose.yml. The built-in Host allowlist is a *browser DNS-rebinding*
# defense, NOT an access control — any direct client can just send `Host: 127.0.0.1`.
# Do NOT change the publish to a non-loopback address (e.g. "8770:8770"); doing so
# exposes UNAUTHENTICATED HOST ROOT to anything that can reach the port. For remote
# access, front it with an authenticated reverse proxy or an SSH tunnel.
# Config env (container-scoped, so no vendor prefix needed). The entrypoint bridges
# these to `yd serve` flags; the binary itself takes --root/--port/--host.
ENV ROOT=/srv/stacks \
    PORT=8770 \
    BIND=0.0.0.0 \
    BACKUP_ROOT=
EXPOSE 8770

# Health = the control plane actually answers, not merely "process started".
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/" >/dev/null 2>&1 || exit 1

# BACKUP_ROOT is read from the environment by `yd serve` directly (clap env), so no
# flag bridging is needed — set it via compose/`docker run -e BACKUP_ROOT=…`.
ENTRYPOINT ["/bin/sh", "-c", "exec yd serve --root \"$ROOT\" --port \"$PORT\" --host \"$BIND\""]
