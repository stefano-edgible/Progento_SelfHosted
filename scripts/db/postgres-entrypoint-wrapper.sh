#!/bin/sh
# Chown data dir to postgres (999:999) inside the container so bind mounts work on Docker Desktop (macOS).
# Official postgres:15 (Debian) runs as UID 999. The host may not preserve UIDs; chown here fixes it
# before the real entrypoint runs.
chown -R 999:999 /var/lib/postgresql/data 2>/dev/null || true
exec /usr/local/bin/docker-entrypoint.sh "$@"
