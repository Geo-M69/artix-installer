#!/usr/bin/env bash
set -euo pipefail

if ! command -v ufw >/dev/null 2>&1; then
  echo "Skipping firewall setup: ufw not found"
  exit 0
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "Skipping firewall setup: sudo not found"
  exit 0
fi

docker_profile_present() {
  if command -v docker >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x /etc/init.d/docker ]]; then
    return 0
  fi

  if [[ -e /etc/runlevels/default/docker ]]; then
    return 0
  fi

  return 1
}

sudo ufw default deny incoming
sudo ufw default allow outgoing

# LocalSend default ports.
sudo ufw allow 53317/udp
sudo ufw allow 53317/tcp

if docker_profile_present; then
  # Allow Docker bridge DNS requests to host resolver.
  sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
  sudo ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'allow-docker-dns'
else
  echo "Skipping Docker DNS firewall rules: docker profile not detected"
fi

sudo ufw --force enable

if command -v rc-update >/dev/null 2>&1; then
  sudo rc-update add ufw default >/dev/null 2>&1 || true
fi
if command -v rc-service >/dev/null 2>&1; then
  sudo rc-service ufw start >/dev/null 2>&1 || true
fi

if docker_profile_present && command -v ufw-docker >/dev/null 2>&1; then
  sudo ufw-docker install || true
fi
sudo ufw reload || true
