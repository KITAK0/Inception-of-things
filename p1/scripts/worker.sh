#!/bin/bash

set -o errtrace
set -o pipefail

error_handler() {
  echo "[ERROR] Command failed at line $1"
}

trap 'error_handler $LINENO' ERR

export DEBIAN_FRONTEND=noninteractive
apt update -y
apt install -y curl vim net-tools

# Wait for the server to share its token
while [ ! -f /vagrant/node-token ]; do
  sleep 2
done

TOKEN=$(cat /vagrant/node-token)
SERVER_IP="192.168.56.110"

# Detect the host-only interface by IP (Debian 12 uses enp0s8, Debian 11 may use eth1)
IFACE=$(ip -o -4 addr show | awk '/192\.168\.56\.111/{print $2}')
if [ -z "$IFACE" ]; then
  echo "[ERROR] Could not detect interface for 192.168.56.111"
  ip -o -4 addr show
  exit 1
fi
echo "[INFO] Using network interface: ${IFACE}"

# If K3s agent is already installed, uninstall it first to ensure a clean join
if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
  echo "[INFO] K3s agent already installed, uninstalling for clean re-join..."
  /usr/local/bin/k3s-agent-uninstall.sh
  sleep 3
fi

# Verify server is reachable before trying to join
echo "[INFO] Checking connectivity to server at ${SERVER_IP}:6443..."
if ! curl -sk --max-time 10 "https://${SERVER_IP}:6443" > /dev/null 2>&1; then
  echo "[ERROR] Cannot reach K3s server at https://${SERVER_IP}:6443"
  echo "[INFO] Server ping test:"
  ping -c 3 "${SERVER_IP}" || true
  exit 1
fi
echo "[INFO] Server is reachable."

# Install K3s in agent (worker) mode
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="$TOKEN" \
  INSTALL_K3S_EXEC="agent \
    --node-ip=192.168.56.111 \
    --flannel-iface=${IFACE}" \
  sh -

# Verify the agent service started
sleep 5
if ! systemctl is-active --quiet k3s-agent; then
  echo "[ERROR] K3s agent service failed to start. Logs:"
  journalctl -u k3s-agent --no-pager -n 30 || true
  exit 1
fi

echo "[INFO] K3s agent setup complete."