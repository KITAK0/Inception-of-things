# Inception of Things - Changes & Audit Report

## Branch: `audit-fix`

This document details all changes made during the project audit and completion process, comparing the original codebase against the subject requirements (Version 4.0).

---

## Summary of Issues Found

| # | Part | Severity | Issue | Status |
|---|------|----------|-------|--------|
| 1 | P1 | HIGH | `server.sh` missing `--node-ip`, `--bind-address`, `--flannel-iface` flags | **Fixed** |
| 2 | P1 | HIGH | `worker.sh` missing `--node-ip`, `--flannel-iface` flags for agent | **Fixed** |
| 3 | P1 | MEDIUM | Vagrantfile missing `vb.customize ["modifyvm"]` for VM naming | **Fixed** |
| 4 | P1 | LOW | Vagrantfile had ~60 lines of commented boilerplate | **Fixed** |
| 5 | P2 | HIGH | `server.sh` did not auto-deploy K8s manifests after K3s install | **Fixed** |
| 6 | P2 | MEDIUM | Config folder was `k3s-deploy/` instead of `confs/` (subject requires `confs/`) | **Fixed** |
| 7 | P2 | MEDIUM | Vagrantfile used direct config instead of `config.vm.define` block | **Fixed** |
| 8 | P2 | MEDIUM | Vagrantfile missing `vb.customize ["modifyvm"]` | **Fixed** |
| 9 | P2 | MEDIUM | `server.sh` missing `--flannel-iface`, `--bind-address` flags | **Fixed** |
| 10 | P2 | LOW | Vagrantfile had ~60 lines of commented boilerplate | **Fixed** |
| 11 | P3 | **CRITICAL** | No `scripts/` folder — subject requires setup script for defense | **Fixed** |
| 12 | P3 | MEDIUM | Config folder was `k8s/` instead of `confs/` (subject requires `confs/`) | **Fixed** |
| 13 | P3 | MEDIUM | Deployment used `v2` image instead of `v1` (need v1 → v2 demo) | **Fixed** |
| 14 | Bonus | **CRITICAL** | No `scripts/` folder — no automation for Helm/GitLab setup | **Fixed** |
| 15 | Bonus | HIGH | `namespaces.yml` missing `gitlab` and `argocd` namespaces | **Fixed** |
| 16 | Bonus | HIGH | README was a copy of Part 3 — no GitLab documentation | **Fixed** |
| 17 | Bonus | MEDIUM | Config folder was `k8s/` instead of `confs/` | **Fixed** |
| 18 | Bonus | MEDIUM | Deployment used `v2` instead of `v1` | **Fixed** |

---

## Detailed Changes

### Part 1 (`p1/`)

#### `p1/Vagrantfile`
- **Cleaned up**: Removed ~60 lines of commented-out Vagrant template code
- **Added**: `vb.customize ["modifyvm", :id, "--name", "bsouharS"]` and same for `bsouharSW` — the subject example explicitly shows this
- **Fixed**: Proper Ruby block indentation and end statements

#### `p1/scripts/server.sh`
- **Added**: `INSTALL_K3S_EXEC` with `--node-ip=192.168.56.110`, `--bind-address=192.168.56.110`, `--flannel-iface=eth1`, `--write-kubeconfig-mode=644`
  - **Why**: Without these flags, K3s binds to the NAT interface (eth0) instead of the private network. The worker cannot connect reliably.
- **Added**: `export DEBIAN_FRONTEND=noninteractive` to prevent apt interactive prompts
- **Added**: `kubectl wait --for=condition=Ready` to verify K3s is ready before sharing token

#### `p1/scripts/worker.sh`
- **Added**: `INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=eth1"` 
  - **Why**: Ensures the agent binds to the correct network interface
- **Added**: `export DEBIAN_FRONTEND=noninteractive`
- **Removed**: Unnecessary `git` package (not needed on the worker)

### Part 2 (`p2/`)

#### `p2/Vagrantfile`
- **Fixed**: Wrapped VM config in proper `config.vm.define "bsouharS" do |server|` block
- **Added**: `vb.customize ["modifyvm", :id, "--name", "bsouharS"]`
- **Cleaned up**: Removed ~60 lines of commented boilerplate

#### `p2/scripts/server.sh`
- **Complete rewrite** — now:
  1. Installs K3s with proper networking flags (`--node-ip`, `--bind-address`, `--flannel-iface`, `--write-kubeconfig-mode`)
  2. Waits for K3s to be ready
  3. **Auto-deploys** all app manifests from `/vagrant/confs/` (app1, app2, app3, ingress)
  4. Waits for pods to be ready and prints status
  - **Why**: The subject expects apps to work after `vagrant up` — manual `kubectl apply` should not be required

#### `p2/k3s-deploy/` → `p2/confs/`
- **Renamed** folder from `k3s-deploy/` to `confs/` per subject Ch. VI: *"The configuration files will be in a confs folder."*
- Files unchanged: `app1.yaml`, `app2.yaml`, `app3.yaml`, `ingress.yml`

#### `p2/README.md`
- Updated all references from `k3s-deploy/` to `confs/`
- Updated instructions to reflect automatic deployment

### Part 3 (`p3/`)

#### `p3/scripts/setup.sh` (NEW FILE - was completely missing)
- **Created** full automation script that:
  1. Installs Docker (if not installed)
  2. Installs kubectl (if not installed)
  3. Installs k3d (if not installed)
  4. Creates k3d cluster with port 80 exposed for Traefik Ingress
  5. Installs Argo CD in the `argocd` namespace
  6. Configures Argo CD for insecure (HTTP) mode
  7. Applies all Kubernetes manifests (namespaces, ingress, ArgoCD app)
  8. Prints access information (URLs, credentials)
  - **Why**: Subject says "you must write a script to install all the necessary packages and tools during your defense"

#### `p3/k8s/` → `p3/confs/`
- **Renamed** folder from `k8s/` to `confs/` per subject requirements

#### `p3/confs/deployment.yml`
- **Changed** image from `bsouhar/my-app:v2` → `bsouhar/my-app:v1`
  - **Why**: Subject requires demonstrating a v1 → v2 version change. Starting at v2 makes it impossible to show the upgrade workflow.

#### `p3/confs/argocd-app.yml`
- **Updated** `path` from `p3/k8s` → `p3/confs`

#### `p3/README.md`
- Updated all references from `k8s/` to `confs/`
- Added Quick Setup section referencing `scripts/setup.sh`
- Fixed image version reference from v2 to v1

### Bonus (`bonus/`)

#### `bonus/scripts/setup.sh` (NEW FILE - was completely missing)
- **Created** full automation script that:
  1. Installs Docker, kubectl, k3d (same as p3)
  2. Installs **Helm** (required for GitLab deployment)
  3. Creates k3d cluster
  4. Creates all namespaces (dev, gitlab, argocd)
  5. Installs **GitLab CE via Helm** in the `gitlab` namespace
  6. Installs Argo CD
  7. Applies Ingress routes for GitLab, Argo CD, and the app
  8. Prints credentials and next-step instructions

#### `bonus/k8s/` → `bonus/confs/`
- **Renamed** folder from `k8s/` to `confs/`

#### `bonus/confs/namespaces.yml`
- **Added** `gitlab` namespace (was completely missing!)
- **Added** `argocd` namespace
  - **Why**: Subject says "Create a dedicated namespace named gitlab"

#### `bonus/confs/deployment.yml`
- **Changed** image from `bsouhar/my-app:v2` → `bsouhar/my-app:v1`

#### `bonus/confs/argocd-app.yml`
- **Updated** repo URL to use proper internal GitLab service address
- **Updated** `path` to `confs`

#### `bonus/README.md`
- **Complete rewrite** — was previously an exact copy of the Part 3 README with no mention of GitLab
- Now includes: architecture diagram, GitLab setup instructions, Helm configuration explanation, credentials table, troubleshooting guide, differences from Part 3

---

## Subject Compliance Checklist

### Part 1 Requirements
- [x] Two machines with proper naming (loginS, loginSW)
- [x] IPs: 192.168.56.110 (Server), 192.168.56.111 (Worker)
- [x] 1 CPU, 1024MB RAM per machine
- [x] K3s in controller mode on Server
- [x] K3s in agent mode on Worker
- [x] SSH access (Vagrant default)
- [x] Proper Vagrantfile with `vm.define`, `modifyvm`

### Part 2 Requirements
- [x] Single VM with K3s in server mode
- [x] 3 web applications
- [x] app1.com → app1, app2.com → app2, default → app3
- [x] app2 has 3 replicas
- [x] Ingress configuration
- [x] Config files in `confs/` folder

### Part 3 Requirements
- [x] K3d installed (via setup script)
- [x] Setup script for defense
- [x] Two namespaces: argocd and dev
- [x] Application deployed by Argo CD from GitHub
- [x] Two versions (v1, v2) — deployment starts at v1
- [x] Version change demonstrable
- [x] Config files in `confs/`, scripts in `scripts/`

### Bonus Requirements
- [x] GitLab running locally (Helm chart)
- [x] Dedicated `gitlab` namespace
- [x] Everything from Part 3 works with local GitLab
- [x] Argo CD points to local GitLab repo
- [x] Setup automation script
- [x] Config files in `confs/`, scripts in `scripts/`

---

## Directory Structure (Final)

```
.
├── p1/
│   ├── Vagrantfile
│   ├── README.md
│   └── scripts/
│       ├── server.sh
│       └── worker.sh
├── p2/
│   ├── Vagrantfile
│   ├── README.md
│   ├── scripts/
│   │   └── server.sh
│   └── confs/
│       ├── app1.yaml
│       ├── app2.yaml
│       ├── app3.yaml
│       └── ingress.yml
├── p3/
│   ├── README.md
│   ├── app/
│   │   ├── Dockerfile
│   │   └── index.html
│   ├── scripts/
│   │   └── setup.sh
│   └── confs/
│       ├── argocd-app.yml
│       ├── deployment.yml
│       ├── ingress-argocd.yml
│       ├── ingress.yml
│       ├── namespaces.yml
│       └── service.yml
├── bonus/
│   ├── README.md
│   ├── app/
│   │   ├── Dockerfile
│   │   └── index.html
│   ├── scripts/
│   │   └── setup.sh
│   └── confs/
│       ├── argocd-app.yml
│       ├── deployment.yml
│       ├── ingress-argocd.yml
│       ├── ingress-gitlab.yml
│       ├── ingress.yml
│       ├── namespaces.yml
│       ├── service.yml
│       └── values.yml
├── CHANGES_README.md
├── HOW_TO_RUN.md
├── README.md
└── subject.txt
```
