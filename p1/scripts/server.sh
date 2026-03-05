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

# Detect the host-only interface by IP (Debian 12 uses enp0s8, Debian 11 may use eth1)
IFACE=$(ip -o -4 addr show | awk '/192\.168\.56\.110/{print $2}')
if [ -z "$IFACE" ]; then
  echo "[ERROR] Could not detect interface for 192.168.56.110"
  ip -o -4 addr show
  exit 1
fi
echo "[INFO] Using network interface: ${IFACE}"

# Install K3s in server (controller) mode
# --advertise-address tells agents/kubectl which IP to connect to
# --bind-address is omitted (defaults to 0.0.0.0) to avoid failures if the
# interface is not fully up when systemd starts k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=192.168.56.110 \
  --advertise-address=192.168.56.110 \
  --flannel-iface=${IFACE} \
  --write-kubeconfig-mode=644" sh -

# Wait for the node-token file to be created (with timeout)
MAX_WAIT=120
WAITED=0
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "[ERROR] K3s server failed to start within ${MAX_WAIT}s"
    systemctl status k3s --no-pager || true
    journalctl -u k3s --no-pager -n 30 || true
    exit 1
  fi
  sleep 2
  WAITED=$((WAITED + 2))
done

# Share token with worker via Vagrant synced folder
cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

# Wait for K3s to be fully ready
kubectl wait --for=condition=Ready node --all --timeout=120s 2>/dev/null || true
echo "[INFO] K3s server setup complete."