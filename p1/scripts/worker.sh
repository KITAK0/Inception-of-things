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

# Install K3s in agent (worker) mode, binding to the correct IP
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="$TOKEN" \
  INSTALL_K3S_EXEC="agent \
    --node-ip=192.168.56.111 \
    --flannel-iface=eth1" \
  sh -

echo "[INFO] K3s agent setup complete."