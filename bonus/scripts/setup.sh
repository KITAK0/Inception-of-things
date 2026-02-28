#!/bin/bash
#
# Inception of Things - Bonus: K3d + Argo CD + GitLab Setup Script
# This script installs all necessary tools and sets up the full cluster
# with a local GitLab instance, Argo CD, and the application.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFS_DIR="$SCRIPT_DIR/../confs"
CLUSTER_NAME="iot-bonus"

# ─── Colors for output ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}\n"; }

# ─── 1. Install Docker ───
install_docker() {
  if command -v docker &>/dev/null; then
    info "Docker is already installed: $(docker --version)"
  else
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    info "Docker installed."
  fi
}

# ─── 2. Install kubectl ───
install_kubectl() {
  if command -v kubectl &>/dev/null; then
    info "kubectl is already installed."
  else
    info "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    info "kubectl installed."
  fi
}

# ─── 3. Install k3d ───
install_k3d() {
  if command -v k3d &>/dev/null; then
    info "k3d is already installed: $(k3d --version)"
  else
    info "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    info "k3d installed."
  fi
}

# ─── 4. Install helm ───
install_helm() {
  if command -v helm &>/dev/null; then
    info "Helm is already installed: $(helm version --short)"
  else
    info "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    info "Helm installed."
  fi
}

# ─── 5. Create k3d cluster ───
create_cluster() {
  if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    warn "Cluster '$CLUSTER_NAME' already exists. Deleting and recreating..."
    k3d cluster delete "$CLUSTER_NAME"
  fi

  info "Creating k3d cluster '$CLUSTER_NAME'..."
  # More memory-friendly: 1 server, 2 agents, ports for HTTP + app
  k3d cluster create "$CLUSTER_NAME" \
    -p "80:80@loadbalancer" \
    -p "8888:8888@loadbalancer" \
    --agents 2 \
    --wait

  info "Waiting for nodes to be ready..."
  kubectl wait --for=condition=Ready node --all --timeout=120s
  kubectl get nodes
}

# ─── 6. Apply namespaces ───
apply_namespaces() {
  info "Creating namespaces (dev, gitlab, argocd)..."
  kubectl apply -f "$CONFS_DIR/namespaces.yml"
}

# ─── 7. Install GitLab via Helm ───
install_gitlab() {
  step "Installing GitLab (this may take 5-10 minutes)..."

  # Add the GitLab Helm repo
  helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
  helm repo update

  # Check if GitLab is already installed
  if helm list -n gitlab 2>/dev/null | grep -q "gitlab"; then
    warn "GitLab is already installed. Upgrading..."
    helm upgrade gitlab gitlab/gitlab \
      -n gitlab \
      -f "$CONFS_DIR/values.yml" \
      --timeout 600s
  else
    info "Installing GitLab via Helm chart..."
    helm install gitlab gitlab/gitlab \
      -n gitlab \
      -f "$CONFS_DIR/values.yml" \
      --timeout 600s
  fi

  info "Waiting for GitLab webservice to be ready (this takes a while)..."
  # GitLab takes time to start - wait with a long timeout
  kubectl wait --for=condition=available --timeout=600s \
    deployment/gitlab-webservice-default -n gitlab 2>/dev/null || {
      warn "GitLab webservice not yet available. It may still be starting."
      warn "Check with: kubectl get pods -n gitlab"
  }

  info "GitLab installation initiated."
}

# ─── 8. Install Argo CD ───
install_argocd() {
  step "Installing Argo CD..."

  info "Installing Argo CD in argocd namespace..."
  kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  info "Waiting for Argo CD server to be ready..."
  kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

  info "Configuring Argo CD for insecure (HTTP) mode..."
  kubectl patch configmap argocd-cmd-params-cm -n argocd \
    --type merge -p '{"data":{"server.insecure":"true"}}'

  kubectl rollout restart deployment/argocd-server -n argocd
  kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

  info "Argo CD installed."
}

# ─── 9. Apply remaining manifests ───
apply_manifests() {
  step "Applying Kubernetes manifests..."

  # Argo CD Ingress
  kubectl apply -f "$CONFS_DIR/ingress-argocd.yml"

  # GitLab Ingress
  kubectl apply -f "$CONFS_DIR/ingress-gitlab.yml"

  # The ArgoCD Application resource (points to local GitLab)
  # NOTE: This should be applied AFTER GitLab is running and has the repo configured
  info "ArgoCD Application manifest is at: $CONFS_DIR/argocd-app.yml"
  info "Apply it AFTER configuring the GitLab repository:"
  info "  kubectl apply -f $CONFS_DIR/argocd-app.yml"

  info "Manifests applied."
}

# ─── 10. Print access info ───
print_info() {
  echo ""
  echo "=============================================="
  echo "        BONUS SETUP COMPLETE"
  echo "=============================================="
  echo ""

  # Get Argo CD admin password
  ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "N/A (still initializing)")

  # Get GitLab root password
  GITLAB_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password \
    -n gitlab -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "N/A (still initializing)")

  info "Services:"
  info "  Argo CD UI:    http://argocd.localhost"
  info "  GitLab UI:     http://gitlab.localhost"
  info "  Application:   http://my-app.localhost"
  echo ""
  info "Argo CD Login:"
  info "  Username: admin"
  info "  Password: $ARGOCD_PASSWORD"
  echo ""
  info "GitLab Login:"
  info "  Username: root"
  info "  Password: $GITLAB_PASSWORD"
  echo ""
  info "Add these to /etc/hosts:"
  info "  127.0.0.1 argocd.localhost"
  info "  127.0.0.1 gitlab.localhost"
  info "  127.0.0.1 my-app.localhost"
  echo ""
  info "Next steps:"
  info "  1. Wait for GitLab to fully start: kubectl get pods -n gitlab"
  info "  2. Access GitLab UI and create a project with the K8s manifests"
  info "  3. Push deployment.yml, service.yml, ingress.yml to the GitLab repo"
  info "  4. Apply the ArgoCD application: kubectl apply -f $CONFS_DIR/argocd-app.yml"
  info "  5. ArgoCD will auto-sync the app from local GitLab"
  echo ""
  info "To change app version (v1 -> v2):"
  info "  Update deployment.yml image tag in GitLab repo"
  info "  ArgoCD will auto-sync the change"
  echo "=============================================="
}

# ─── Main ───
main() {
  step "Inception of Things - Bonus Setup (GitLab + ArgoCD + K3d)"
  install_docker
  install_kubectl
  install_k3d
  install_helm
  create_cluster
  apply_namespaces
  install_gitlab
  install_argocd
  apply_manifests
  print_info
}

main "$@"
