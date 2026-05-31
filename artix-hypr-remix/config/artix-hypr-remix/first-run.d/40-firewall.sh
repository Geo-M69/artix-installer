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

sudo ufw default deny incoming
sudo ufw default allow outgoing

# LocalSend default ports.
sudo ufw allow 53317/udp
sudo ufw allow 53317/tcp

# Allow Docker bridge DNS requests to host resolver.
sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
sudo ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'allow-docker-dns'

sudo ufw --force enable

if command -v rc-update >/dev/null 2>&1; then
  sudo rc-update add ufw default >/dev/null 2>&1 || true
fi
if command -v rc-service >/dev/null 2>&1; then
  sudo rc-service ufw start >/dev/null 2>&1 || true
fi

if command -v ufw-docker >/dev/null 2>&1; then
  sudo ufw-docker install || true
fi
sudo ufw reload || true
