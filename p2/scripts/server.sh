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

# Install K3s in server mode with proper networking
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=192.168.56.110 \
  --bind-address=192.168.56.110 \
  --flannel-iface=eth1 \
  --write-kubeconfig-mode=644" sh -

# Wait for K3s to be ready
echo "[INFO] Waiting for K3s to be ready..."
while ! kubectl get nodes &>/dev/null; do
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=120s

# Deploy the three applications and ingress
echo "[INFO] Deploying applications..."
kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yml

echo "[INFO] Waiting for all pods to be ready..."
kubectl wait --for=condition=Ready pods --all --timeout=120s

echo "[INFO] K3s server with 3 applications setup complete."
kubectl get pods
kubectl get ingress