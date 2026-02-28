#!/bin/bash
#
# Inception of Things - Part 3: K3d + Argo CD Setup Script
# This script installs all necessary tools and sets up the cluster
# Run this script during defense to set up the infrastructure
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot-cluster"

# ─── Colors for output ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── 1. Install Docker (if not installed) ───
install_docker() {
  if command -v docker &>/dev/null; then
    info "Docker is already installed: $(docker --version)"
  else
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    info "Docker installed. You may need to log out and back in for group changes."
  fi
}

# ─── 2. Install kubectl (if not installed) ───
install_kubectl() {
  if command -v kubectl &>/dev/null; then
    info "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
  else
    info "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    info "kubectl installed."
  fi
}

# ─── 3. Install k3d (if not installed) ───
install_k3d() {
  if command -v k3d &>/dev/null; then
    info "k3d is already installed: $(k3d --version)"
  else
    info "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    info "k3d installed."
  fi
}

# ─── 4. Create k3d cluster ───
create_cluster() {
  if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    warn "Cluster '$CLUSTER_NAME' already exists. Deleting and recreating..."
    k3d cluster delete "$CLUSTER_NAME"
  fi

  info "Creating k3d cluster '$CLUSTER_NAME'..."
  k3d cluster create "$CLUSTER_NAME" \
    -p "80:80@loadbalancer" \
    --agents 2 \
    --wait

  info "Cluster created. Waiting for nodes to be ready..."
  kubectl wait --for=condition=Ready node --all --timeout=120s
  kubectl get nodes
}

# ─── 5. Install Argo CD ───
install_argocd() {
  info "Creating argocd namespace..."
  kubectl create namespace argocd 2>/dev/null || true

  info "Installing Argo CD..."
  kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  info "Waiting for Argo CD server to be ready..."
  kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

  info "Configuring Argo CD for insecure (HTTP) mode..."
  kubectl patch configmap argocd-cmd-params-cm -n argocd \
    --type merge -p '{"data":{"server.insecure":"true"}}'

  # Restart the server to pick up the config change
  kubectl rollout restart deployment/argocd-server -n argocd
  kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

  info "Argo CD installed and configured."
}

# ─── 6. Apply Kubernetes manifests ───
apply_manifests() {
  info "Applying Kubernetes manifests from $CONFS_DIR..."

  # Create the dev namespace
  kubectl apply -f "$CONFS_DIR/namespaces.yml"

  # Create Ingress for Argo CD UI
  kubectl apply -f "$CONFS_DIR/ingress-argocd.yml"

  # Create the Argo CD Application (triggers GitOps deployment)
  kubectl apply -f "$CONFS_DIR/argocd-app.yml"

  info "Manifests applied. Argo CD will now sync the application from GitHub."
}

# ─── 7. Print access info ───
print_info() {
  echo ""
  echo "=============================================="
  echo "        SETUP COMPLETE"
  echo "=============================================="
  echo ""

  # Get Argo CD admin password
  ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "N/A (still initializing)")

  info "Argo CD UI:    http://argocd.localhost"
  info "Application:   http://my-app.localhost"
  info ""
  info "Argo CD Login:"
  info "  Username: admin"
  info "  Password: $ARGOCD_PASSWORD"
  echo ""
  info "Add these to /etc/hosts if not using *.localhost:"
  info "  127.0.0.1 argocd.localhost"
  info "  127.0.0.1 my-app.localhost"
  echo ""
  info "Verify with:"
  info "  kubectl get ns"
  info "  kubectl get pods -n argocd"
  info "  kubectl get pods -n dev"
  info "  kubectl get application -n argocd"
  echo ""
  info "To change app version (v1 → v2):"
  info "  Edit p3/confs/deployment.yml, change image tag to v2"
  info "  git add . && git commit -m 'update to v2' && git push"
  info "  Argo CD will auto-sync the change."
  echo "=============================================="
}

# ─── Main ───
main() {
  info "Starting Inception of Things - Part 3 setup..."
  echo ""
  install_docker
  install_kubectl
  install_k3d
  create_cluster
  install_argocd
  apply_manifests
  print_info
}

main "$@"
