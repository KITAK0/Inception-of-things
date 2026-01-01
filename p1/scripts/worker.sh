#!/bin/bash

set -o errtrace
set -o pipefail

error_handler() {
  echo "[ERROR] Command failed at line $1"
}

trap 'error_handler $LINENO' ERR

apt update -y
apt install -y curl vim net-tools git

while [ ! -f /vagrant/node-token ]; do
  sleep 2
done

TOKEN=$(cat /vagrant/node-token)
SERVER_IP="192.168.56.110"

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="$TOKEN" \
  sh -