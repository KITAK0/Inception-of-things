#!/bin/bash

set -o errtrace
set -o pipefail

error_handler() {
    echo "[ERROR] Command failed at line $1"
}

trap 'error_handler $LINENO' ERR

apt update -y
apt install -y curl vim net-tools
curl -sfL https://get.k3s.io | sh -s - \
  --node-ip=192.168.56.110