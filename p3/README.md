# Inception of Things - Part 3

## Project Overview

Part 3 demonstrates deploying an application using **GitOps** principles with **Argo CD** on a local Kubernetes cluster. This setup showcases continuous deployment where Argo CD automatically syncs your application from a Git repository to your cluster.

## Goal

Deploy a containerized web application using:
- **k3d**: A lightweight Kubernetes distribution (k3s) running in Docker
- **Argo CD**: A declarative GitOps continuous delivery tool
- **Traefik Ingress**: For HTTP routing without port-forwarding or NodePort
- **GitOps workflow**: Application state managed via Git repository

## Architecture

### Components

1. **k3d Cluster**
   - Lightweight Kubernetes cluster running locally
   - Port 80 exposed for HTTP traffic

2. **Argo CD (argocd namespace)**
   - Deployed in its own namespace for separation
   - Runs in insecure (HTTP) mode for local development
   - Exposed via Traefik Ingress at `argocd.localhost`

3. **Application (dev namespace)**
   - Custom web application (Nginx-based)
   - Deployed from Docker Hub (`bsouhar/my-app:v2`)
   - Managed by Argo CD Application resource
   - Exposed via Traefik Ingress at `my-app.localhost`

### GitOps Workflow

```
Git Repository (GitHub)
        ↓
  Argo CD watches for changes
        ↓
  Automatically syncs to cluster
        ↓
  Application deployed in dev namespace
```

Argo CD monitors the `deploy` branch of the repository and automatically applies any changes to the Kubernetes manifests in the `p3/k8s` directory.

## Project Structure

```
p3/
├── app/
│   ├── Dockerfile           # Application container image
│   └── index.html           # Web application content
└── k8s/
    ├── argocd-app.yml       # Argo CD Application resource
    ├── deployment.yml       # Application deployment
    ├── service.yml          # ClusterIP service
    ├── ingress.yml          # Traefik Ingress for the app
    ├── ingress-argocd.yml   # Traefik Ingress for Argo CD
    └── namespaces.yml       # dev namespace definition
```

## Exposure Method: Traefik Ingress

This setup uses **Traefik Ingress Controller** (built into k3s) for routing HTTP traffic:

- **No port-forwarding**: Direct access via standard HTTP (port 80)
- **No NodePort**: Uses ClusterIP services with Ingress
- **Host-based routing**: Different hostnames route to different services
  - `argocd.localhost` → Argo CD UI
  - `my-app.localhost` → Your application

### Why This Is Better

- **Production-ready pattern**: Ingress is the standard way to expose services in Kubernetes
- **Clean URLs**: Use domain names instead of ports
- **Single entry point**: All traffic goes through port 80
- **Scalability**: Easy to add more applications with different hostnames
- **SSL/TLS ready**: In production, Ingress handles TLS termination

## Why Argo CD Runs in Insecure (HTTP) Mode

Argo CD is configured to run without TLS for this local development setup:

1. **Simplicity**: No need to generate or manage certificates locally
2. **Local development**: Running on `localhost` doesn't require encryption
3. **Production pattern**: In production, TLS termination is handled at the Ingress level, not by Argo CD itself
4. **Compliance**: Meets the project requirements while following Kubernetes best practices

The `--insecure` flag disables Argo CD's internal TLS, allowing it to serve HTTP traffic behind the Traefik Ingress.

## Prerequisites

- **Docker**: For running k3d
- **k3d**: Lightweight Kubernetes in Docker
- **kubectl**: Kubernetes CLI tool

Install k3d:
```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

Verify installation:
```bash
k3d --version
kubectl version --client
```

## Step-by-Step Instructions

### 1. Create the k3d Cluster

Create a k3d cluster with port 80 exposed for Ingress:

```bash
k3d cluster create iot-cluster \
  -p "80:80@loadbalancer" \
  --agents 2
```

This creates a cluster named `iot-cluster` with 1 server node and 2 agent nodes, mapping port 80 from your host to the cluster's load balancer.

Verify the cluster:
```bash
kubectl get nodes
```

### 2. Install Argo CD

Create the Argo CD namespace and install Argo CD:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for Argo CD to be ready:
```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 3. Configure Argo CD for Insecure Mode

Patch the Argo CD server to run in insecure mode and set the external URL:

```bash
kubectl patch deployment argocd-server -n argocd --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'

kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge -p '{"data":{"server.insecure":"true"}}'
```

Wait for the server to restart:
```bash
kubectl rollout status deployment/argocd-server -n argocd
```

### 4. Apply Kubernetes Manifests

Navigate to the k8s directory and apply all manifests:

```bash
cd p3/k8s

# Create the dev namespace
kubectl apply -f namespaces.yml

# Create Ingress for Argo CD
kubectl apply -f ingress-argocd.yml

# Create the Argo CD Application (this will deploy your app)
kubectl apply -f argocd-app.yml
```

**Note**: You don't need to manually apply `deployment.yml`, `service.yml`, or `ingress.yml` because Argo CD will automatically deploy them from the Git repository.

### 5. Get Argo CD Admin Password

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode && echo
```

### 6. Update /etc/hosts

Add the following entries to your `/etc/hosts` file:

```bash
sudo nano /etc/hosts
```

Add these lines:
```
127.0.0.1 argocd.localhost
127.0.0.1 my-app.localhost
```

Save and exit.

### 7. Access the Applications

**Argo CD UI:**
- URL: http://argocd.localhost
- Username: `admin`
- Password: (from step 5)

**Your Application:**
- URL: http://my-app.localhost

## Verify the Deployment

Check that all resources are running:

```bash
# Check Argo CD
kubectl get pods -n argocd

# Check your application
kubectl get pods -n dev
kubectl get svc -n dev
kubectl get ingress -n dev

# Check Argo CD Application status
kubectl get application -n argocd
```

In the Argo CD UI, you should see your application synced and healthy.

## How Requests Travel Through the System

### For the Application (my-app.localhost)

1. **Client** makes a request to `my-app.localhost`
2. **Traefik Ingress Controller** receives the request on port 80
3. Ingress matches the host `my-app.localhost` and routes to the `my-app-service` Service
4. The **Service** (ClusterIP) load-balances to one of the **Pods**
5. The **Pod** (Nginx container) serves the HTML content

### For Argo CD (argocd.localhost)

1. **Client** makes a request to `argocd.localhost`
2. **Traefik Ingress Controller** receives the request on port 80
3. Ingress matches the host `argocd.localhost` and routes to the `argocd-server` Service
4. The **Service** forwards to the **argocd-server** Pod
5. The **Argo CD server** serves the web UI

## GitOps in Action

Once deployed, Argo CD continuously monitors your Git repository:

- Any changes to manifests in `p3/k8s` on the `deploy` branch are automatically detected
- Argo CD syncs the changes to the cluster (if `automated` sync is enabled)
- The application is updated without manual intervention

To test this:
1. Update `deployment.yml` in your Git repository (e.g., change image tag)
2. Commit and push to the `deploy` branch
3. Watch Argo CD automatically sync the changes

## Cleanup

To destroy the cluster:

```bash
k3d cluster delete iot-cluster
```

## Kubernetes Best Practices Followed

This setup demonstrates several Kubernetes best practices:

1. **Namespace Isolation**: Argo CD and the application run in separate namespaces
2. **GitOps**: Application state is version-controlled and declaratively managed
3. **Ingress for Routing**: Standard way to expose HTTP services
4. **Resource Limits**: Pods have memory and CPU limits defined
5. **ClusterIP Services**: Internal services use ClusterIP (not NodePort)
6. **Automated Sync**: Argo CD keeps the cluster in sync with Git
7. **Self-Healing**: Argo CD automatically corrects drift

This setup is compliant with the Inception of Things subject requirements while following production-grade Kubernetes patterns.

## Troubleshooting

### Argo CD UI Not Accessible
- Verify Ingress: `kubectl get ingress -n argocd`
- Check Argo CD pods: `kubectl get pods -n argocd`
- Verify `/etc/hosts` entry for `argocd.localhost`

### Application Not Accessible
- Check Argo CD Application status: `kubectl get application -n argocd`
- Verify application pods: `kubectl get pods -n dev`
- Check Ingress: `kubectl get ingress -n dev`

### Application Not Syncing
- Check Argo CD logs: `kubectl logs -n argocd deployment/argocd-server`
- Verify Git repository URL and branch in `argocd-app.yml`
- Ensure the `deploy` branch exists and contains the manifests

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [k3d Documentation](https://k3d.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [GitOps Principles](https://www.gitops.tech/)
