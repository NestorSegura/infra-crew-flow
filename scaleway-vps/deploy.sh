#!/usr/bin/env bash
# Pull latest images and restart the stack. Run on the VPS as user 'crewflow'.
set -euo pipefail
cd /srv/crew-flow
docker compose pull
docker compose up -d --remove-orphans
docker image prune -f >/dev/null
docker compose ps
