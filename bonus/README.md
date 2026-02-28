# Inception of Things - Bonus: GitLab Integration

## Overview

The bonus part extends Part 3 by replacing the remote GitHub repository with a **local GitLab instance** running inside the same Kubernetes cluster. This demonstrates a fully self-contained GitOps pipeline where everything runs locally.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   k3d Cluster (iot-bonus)                │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   gitlab NS   │  │  argocd NS   │  │    dev NS    │  │
│  │               │  │              │  │              │  │
│  │  GitLab CE    │  │  Argo CD     │  │  my-app      │  │
│  │  (Helm)       │──│  (watches    │──│  (deployed   │  │
│  │               │  │   GitLab)    │  │   by ArgoCD) │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                         │
│  Traefik Ingress Controller                             │
│  ├── gitlab.localhost  → GitLab UI                      │
│  ├── argocd.localhost  → Argo CD UI                     │
│  └── my-app.localhost  → Application                    │
└─────────────────────────────────────────────────────────┘
```

## Components

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| **GitLab CE** | `gitlab` | Local Git repository server (latest Helm chart) |
| **Argo CD** | `argocd` | GitOps continuous delivery |
| **Application** | `dev` | The deployed web application |

## Project Structure

```
bonus/
├── README.md
├── app/
│   ├── Dockerfile           # Application Docker image
│   └── index.html           # Application content
├── confs/
│   ├── argocd-app.yml       # Argo CD Application (points to local GitLab)
│   ├── deployment.yml       # Application deployment manifest
│   ├── service.yml          # ClusterIP service
│   ├── ingress.yml          # Traefik Ingress for the app
│   ├── ingress-argocd.yml   # Traefik Ingress for Argo CD
│   ├── ingress-gitlab.yml   # Traefik Ingress for GitLab
│   ├── namespaces.yml       # dev, gitlab, argocd namespaces
│   └── values.yml           # Helm values for GitLab CE
└── scripts/
    └── setup.sh             # Automated setup script
```

## Prerequisites

- **Docker**: Required for k3d
- **8+ GB RAM** recommended (GitLab is resource-intensive)
- **Linux** system or VM

## Quick Start

### Automated Setup

```bash
cd bonus
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The script will install all dependencies (Docker, kubectl, k3d, Helm) and set up the full infrastructure.

### Manual Setup

#### 1. Create Cluster

```bash
k3d cluster create iot-bonus \
  -p "80:80@loadbalancer" \
  -p "8888:8888@loadbalancer" \
  --agents 2
```

#### 2. Create Namespaces

```bash
kubectl apply -f confs/namespaces.yml
```

#### 3. Install GitLab via Helm

```bash
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm install gitlab gitlab/gitlab \
  -n gitlab \
  -f confs/values.yml \
  --timeout 600s
```

Wait for GitLab to start (can take 5-10 minutes):

```bash
kubectl get pods -n gitlab -w
```

#### 4. Install Argo CD

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge -p '{"data":{"server.insecure":"true"}}'

kubectl rollout restart deployment/argocd-server -n argocd
```

#### 5. Apply Ingress Routes

```bash
kubectl apply -f confs/ingress-argocd.yml
kubectl apply -f confs/ingress-gitlab.yml
```

#### 6. Configure GitLab

Get the GitLab root password:

```bash
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab -o jsonpath="{.data.password}" | base64 --decode && echo
```

1. Access GitLab at `http://gitlab.localhost`
2. Login as `root` with the password above
3. Create a new project (e.g., `iot-app`)
4. Push the application manifests (`deployment.yml`, `service.yml`, `ingress.yml`) to the project

#### 7. Apply ArgoCD Application

Update `confs/argocd-app.yml` with your GitLab repo URL, then:

```bash
kubectl apply -f confs/argocd-app.yml
```

## GitLab Helm Values

The `confs/values.yml` configures GitLab CE with minimal resource usage:

- **Community Edition** (`global.edition: ce`)
- **HTTP only** (no TLS for local development)
- **Disabled components**: cert-manager, nginx-ingress (Traefik used instead), registry, Prometheus, GitLab Runner
- **Enabled components**: webservice, Sidekiq, GitLab Shell, PostgreSQL, Redis

## Credentials

| Service | Username | Password Command |
|---------|----------|-----------------|
| **Argo CD** | `admin` | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" \| base64 --decode` |
| **GitLab** | `root` | `kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" \| base64 --decode` |

## Verifying the Setup

```bash
# Check all three namespaces
kubectl get ns

# Check GitLab pods
kubectl get pods -n gitlab

# Check Argo CD
kubectl get pods -n argocd

# Check application
kubectl get pods -n dev

# Check all Ingress routes
kubectl get ingress --all-namespaces
```

## Version Change Demo (v1 → v2)

1. In GitLab, edit `deployment.yml` and change `image: bsouhar/my-app:v1` to `image: bsouhar/my-app:v2`
2. Commit the change
3. Argo CD will detect the change and auto-sync
4. Verify: `curl http://my-app.localhost`

## Cleanup

```bash
k3d cluster delete iot-bonus
```

## Differences from Part 3

| Feature | Part 3 | Bonus |
|---------|--------|-------|
| Git source | GitHub (remote) | GitLab (local, in-cluster) |
| Extra namespace | — | `gitlab` |
| Helm | Not used | Used for GitLab deployment |
| Self-contained | No (depends on GitHub) | Yes (everything local) |

## Troubleshooting

### GitLab pods stuck in Pending/CrashLoopBackOff
- GitLab needs significant resources. Ensure at least 8GB RAM available.
- Check events: `kubectl describe pods -n gitlab`

### Argo CD can't reach GitLab
- Verify GitLab service is reachable from within the cluster:
  ```bash
  kubectl run test --rm -it --image=curlimages/curl -- \
    curl -s http://gitlab-webservice-default.gitlab.svc.cluster.local:8181
  ```

### Application not syncing
- Check ArgoCD app status: `kubectl get application -n argocd`
- Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-server`

## References

- [GitLab Helm Chart](https://docs.gitlab.com/charts/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [k3d Documentation](https://k3d.io/)