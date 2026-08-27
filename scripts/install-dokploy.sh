#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root or with sudo." >&2
  exit 1
fi

for port in 80 443 3000; do
  if ss -ltnH | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
    echo "Port ${port} is already in use. Stop that service before installing Dokploy." >&2
    exit 1
  fi
done

if command -v docker >/dev/null 2>&1 \
  && docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -qx active; then
  echo "Docker Swarm is already active. Review the host before installing Dokploy." >&2
  exit 1
fi

if [[ "${DOKPLOY_CONFIRM:-}" != "YES" ]]; then
  read -r -p "Install Dokploy on this server? Type YES to continue: " confirmation
  [[ "${confirmation}" == "YES" ]] || { echo "Cancelled."; exit 1; }
fi

curl -sSL https://dokploy.com/install.sh | sh
