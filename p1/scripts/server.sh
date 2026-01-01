#!/bin/bash

set -o errtrace
set -o pipefail

error_handler() {
  echo "[ERROR] Command failed at line $1"
}

trap 'error_handler $LINENO' ERR

apt update -y
apt install -y curl vim net-tools
curl -sfL https://get.k3s.io | sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 1
done

cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token