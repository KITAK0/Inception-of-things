# Inception of Things (IoT)

A System Administration project focused on Kubernetes, introducing **K3s**, **K3d**, **Vagrant**, **Argo CD**, and **GitLab** through a series of hands-on exercises.

## Overview

This project is divided into 3 mandatory parts and 1 bonus:

| Part | Topic | Tools | Description |
|------|-------|-------|-------------|
| **Part 1** | K3s + Vagrant | Vagrant, VirtualBox, K3s | Set up a 2-node K3s cluster (Server + Worker) on VMs |
| **Part 2** | Three Applications | Vagrant, K3s, Ingress | Deploy 3 web apps with host-based routing via Ingress |
| **Part 3** | K3d + Argo CD | K3d, Docker, Argo CD | GitOps deployment with Argo CD watching a GitHub repo |
| **Bonus** | GitLab Integration | K3d, Helm, GitLab, Argo CD | Replace GitHub with a local GitLab instance in-cluster |

## Project Structure

```
.
├── p1/                     # Part 1: K3s two-node cluster
│   ├── Vagrantfile
│   ├── scripts/
│   │   ├── server.sh       # K3s server (controller) setup
│   │   └── worker.sh       # K3s agent setup
│   └── README.md
│
├── p2/                     # Part 2: Three applications
│   ├── Vagrantfile
│   ├── scripts/
│   │   └── server.sh       # K3s install + auto-deploy apps
│   ├── confs/
│   │   ├── app1.yaml       # App 1 (1 replica)
│   │   ├── app2.yaml       # App 2 (3 replicas)
│   │   ├── app3.yaml       # App 3 (default, 1 replica)
│   │   └── ingress.yml     # Host-based routing rules
│   └── README.md
│
├── p3/                     # Part 3: K3d + Argo CD
│   ├── app/
│   │   ├── Dockerfile
│   │   └── index.html
│   ├── scripts/
│   │   └── setup.sh        # Full setup script (Docker, k3d, ArgoCD)
│   ├── confs/
│   │   ├── argocd-app.yml  # Argo CD Application resource
│   │   ├── deployment.yml  # App deployment (v1)
│   │   ├── service.yml
│   │   ├── ingress.yml
│   │   ├── ingress-argocd.yml
│   │   └── namespaces.yml
│   └── README.md
│
├── bonus/                  # Bonus: GitLab integration
│   ├── app/
│   │   ├── Dockerfile
│   │   └── index.html
│   ├── scripts/
│   │   └── setup.sh        # Full setup (Docker, k3d, Helm, GitLab, ArgoCD)
│   ├── confs/
│   │   ├── argocd-app.yml  # ArgoCD pointing to local GitLab
│   │   ├── deployment.yml
│   │   ├── service.yml
│   │   ├── ingress.yml
│   │   ├── ingress-argocd.yml
│   │   ├── ingress-gitlab.yml
│   │   ├── namespaces.yml  # dev + gitlab + argocd
│   │   └── values.yml      # GitLab Helm chart values
│   └── README.md
│
├── CHANGES_README.md       # Audit report of all fixes made
├── HOW_TO_RUN.md           # Step-by-step run guide for all parts
└── README.md               # This file
```

## Quick Start

### Parts 1 & 2 (Vagrant)
```bash
cd p1    # or p2
vagrant up
```

### Part 3 (K3d + ArgoCD)
```bash
cd p3
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### Bonus (K3d + GitLab + ArgoCD)
```bash
cd bonus
chmod +x scripts/setup.sh
./scripts/setup.sh
```

## Requirements

- **Parts 1 & 2**: [Vagrant](https://www.vagrantup.com/downloads) + [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- **Part 3 & Bonus**: Docker (setup scripts install the rest automatically)
- **Bonus**: 8+ GB RAM recommended (GitLab is resource-intensive)

## Documentation

- **[HOW_TO_RUN.md](HOW_TO_RUN.md)** — Detailed step-by-step instructions for every part
- **[CHANGES_README.md](CHANGES_README.md)** — Audit log of all changes and fixes
- Each part has its own README with architecture details

## Authors

- **bsouhar**
- **akheired**
- **atoukmat**