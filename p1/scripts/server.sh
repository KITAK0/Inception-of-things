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

# Install K3s in server (controller) mode, binding to the correct IP
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=192.168.56.110 \
  --bind-address=192.168.56.110 \
  --flannel-iface=eth1 \
  --write-kubeconfig-mode=644" sh -

# Wait for the node-token file to be created
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 1
done

# Share token with worker via Vagrant synced folder
cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

# Wait for K3s to be fully ready
kubectl wait --for=condition=Ready node --all --timeout=120s 2>/dev/null || true
echo "[INFO] K3s server setup complete."