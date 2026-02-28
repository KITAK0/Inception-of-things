# Inception of Things - How to Run (Step-by-Step Guide)

This guide provides detailed, step-by-step instructions to run each part of the project. Follow them in order: Part 1 → Part 2 → Part 3 → Bonus.

---

## Prerequisites (Install These First)

### On Your Host Machine

| Tool | Purpose | Install |
|------|---------|---------|
| **Vagrant** | VM orchestration | [vagrantup.com/downloads](https://www.vagrantup.com/downloads) |
| **VirtualBox** | VM hypervisor | [virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads) |

Verify:
```bash
vagrant --version    # Should print Vagrant x.x.x
vboxmanage --version # Should print VirtualBox version
```

> **Note**: Parts 1 & 2 use Vagrant+VirtualBox. Parts 3 & Bonus use Docker+k3d (installed by the setup scripts).

---

## Part 1: K3s and Vagrant (Two-Node Cluster)

### What This Does
Sets up a 2-node K3s Kubernetes cluster:
- **bsouharS** (Server/Controller) — IP `192.168.56.110`
- **bsouharSW** (Worker/Agent) — IP `192.168.56.111`

### Steps

#### Step 1: Navigate to Part 1
```bash
cd p1
```

#### Step 2: Start the VMs
```bash
vagrant up
```
This will:
- Download the Debian Bullseye base box (first time only)
- Create both VMs in VirtualBox
- Run provisioning scripts automatically
- Install K3s on both nodes
- **Estimated time: 3-5 minutes**

#### Step 3: Verify the Cluster
SSH into the Server node:
```bash
vagrant ssh bsouharS
```

Check that both nodes are registered and Ready:
```bash
kubectl get nodes -o wide
```

Expected output (after ~1 minute):
```
NAME        STATUS   ROLES                  AGE   VERSION
bsouharS    Ready    control-plane,master   Xm    vX.XX.X
bsouharSW   Ready    <none>                 Xm    vX.XX.X
```

#### Step 4: Verify Networking
```bash
# On the server
ip a show eth1    # Should show 192.168.56.110

# Exit and SSH to worker
exit
vagrant ssh bsouharSW
ip a show eth1    # Should show 192.168.56.111
```

#### Step 5: Clean Up (when done)
```bash
exit              # Exit SSH
vagrant halt      # Stop VMs (preserves state)
# OR
vagrant destroy -f  # Completely delete VMs
```

---

## Part 2: K3s and Three Applications

### What This Does
Sets up a single-node K3s cluster with 3 web applications, routed via Ingress:
- `app1.com` → App 1 (1 replica)
- `app2.com` → App 2 (3 replicas)
- Default (any other host) → App 3 (1 replica)

### Steps

#### Step 1: Navigate to Part 2
```bash
cd p2
```

#### Step 2: Start the VM
```bash
vagrant up
```
This will:
- Create the VM and install K3s
- **Automatically deploy** all 3 applications and the Ingress
- **Estimated time: 3-5 minutes**

#### Step 3: Verify Deployment
SSH into the VM:
```bash
vagrant ssh bsouharS
```

Check all resources:
```bash
kubectl get pods           # Should show 5 pods (1+3+1)
kubectl get svc            # Should show 3 services
kubectl get ingress        # Should show the ingress rules
```

Expected pods:
```
NAME                    READY   STATUS    RESTARTS   AGE
app1-xxxxxxxxx-xxxxx    1/1     Running   0          Xm
app2-xxxxxxxxx-xxxxx    1/1     Running   0          Xm
app2-xxxxxxxxx-xxxxx    1/1     Running   0          Xm
app2-xxxxxxxxx-xxxxx    1/1     Running   0          Xm
app3-xxxxxxxxx-xxxxx    1/1     Running   0          Xm
```

#### Step 4: Test the Routing

From inside the VM:
```bash
# Test app1
curl -H "Host: app1.com" 192.168.56.110
# Expected: <h1>App 1</h1>

# Test app2
curl -H "Host: app2.com" 192.168.56.110
# Expected: <h1>App 2</h1>

# Test default (app3)
curl 192.168.56.110
# Expected: <h1>App 3</h1>
```

From your host machine (add to `/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts`):
```
192.168.56.110 app1.com
192.168.56.110 app2.com
```
Then open `http://app1.com` and `http://app2.com` in a browser.

#### Step 5: Clean Up
```bash
exit
vagrant halt      # OR: vagrant destroy -f
```

---

## Part 3: K3d and Argo CD

### What This Does
Sets up a k3d Kubernetes cluster with:
- **Argo CD** for GitOps continuous deployment
- An application deployed from a **GitHub repository**
- The app starts at **v1** and can be upgraded to **v2** via Git

### Prerequisites
- **Docker** must be installed and running
- **Linux environment** (native Linux, WSL2, or VM)

### Steps

#### Step 1: Navigate to Part 3
```bash
cd p3
```

#### Step 2: Run the Setup Script
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The script will:
1. Install Docker (if not installed)
2. Install kubectl (if not installed)
3. Install k3d (if not installed)
4. Create a k3d cluster named `iot-cluster`
5. Install Argo CD in the `argocd` namespace
6. Configure Argo CD for HTTP mode
7. Apply all Kubernetes manifests
8. Print access URLs and credentials

**Estimated time: 3-5 minutes**

#### Step 3: Verify Namespaces
```bash
kubectl get ns
```

Expected:
```
NAME              STATUS   AGE
argocd            Active   Xm
dev               Active   Xm
default           Active   Xm
kube-system       Active   Xm
...
```

#### Step 4: Access Argo CD UI
1. Open browser: **http://argocd.localhost**
2. Login:
   - Username: `admin`
   - Password: (printed by the setup script, or run):
     ```bash
     kubectl -n argocd get secret argocd-initial-admin-secret \
       -o jsonpath="{.data.password}" | base64 --decode && echo
     ```

#### Step 5: Verify the Application
```bash
# Check pods in dev namespace
kubectl get pods -n dev

# Check the ArgoCD application status
kubectl get application -n argocd
```

Access the app: **http://my-app.localhost**

#### Step 6: Demonstrate Version Change (v1 → v2)

This is the key evaluation step — showing GitOps in action.

1. **Verify current version is v1:**
   ```bash
   kubectl get deployment my-app -n dev -o jsonpath='{.spec.template.spec.containers[0].image}'
   # Should output: bsouhar/my-app:v1
   ```

2. **Change to v2 in the Git repository:**
   Edit `p3/confs/deployment.yml` and change:
   ```yaml
   image: bsouhar/my-app:v1
   ```
   to:
   ```yaml
   image: bsouhar/my-app:v2
   ```

3. **Push the change:**
   ```bash
   git add p3/confs/deployment.yml
   git commit -m "Update app to v2"
   git push origin deploy
   ```

4. **Watch Argo CD sync:**
   - In the Argo CD UI, you'll see the application status change
   - Argo CD will automatically deploy v2

5. **Verify the update:**
   ```bash
   kubectl get deployment my-app -n dev -o jsonpath='{.spec.template.spec.containers[0].image}'
   # Should now output: bsouhar/my-app:v2
   ```

#### Step 7: Clean Up
```bash
k3d cluster delete iot-cluster
```

---

## Bonus: GitLab Integration

### What This Does
Extends Part 3 by running a **local GitLab instance** inside the cluster, replacing GitHub as the Git source for Argo CD. Everything runs locally — no external dependencies.

### Prerequisites
- **Docker** must be installed and running
- **8+ GB RAM** recommended (GitLab is resource-intensive)
- **Linux environment**

### Steps

#### Step 1: Navigate to Bonus
```bash
cd bonus
```

#### Step 2: Run the Setup Script
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The script will:
1. Install Docker, kubectl, k3d, **Helm**
2. Create a k3d cluster named `iot-bonus`
3. Create namespaces: `dev`, `gitlab`, `argocd`
4. Install **GitLab CE via Helm** in the `gitlab` namespace
5. Install Argo CD in the `argocd` namespace
6. Apply all Ingress routes

**Estimated time: 10-15 minutes** (GitLab takes time to start)

#### Step 3: Wait for GitLab to Start

GitLab takes several minutes to initialize. Monitor:
```bash
kubectl get pods -n gitlab -w
```

Wait until `gitlab-webservice-default-*` shows `Running` and `READY 2/2`.

#### Step 4: Access GitLab
1. Open browser: **http://gitlab.localhost**
2. Login:
   - Username: `root`
   - Password:
     ```bash
     kubectl get secret gitlab-gitlab-initial-root-password \
       -n gitlab -o jsonpath="{.data.password}" | base64 --decode && echo
     ```

#### Step 5: Create GitLab Repository

1. In GitLab UI, click **"New project"** → **"Create blank project"**
2. Name it: `iot-app`
3. Set visibility to **Public** or **Internal**
4. Click **Create project**

#### Step 6: Push Application Manifests to GitLab

Clone the repo and push the app manifests:
```bash
# Clone the GitLab repo (from inside the cluster network, or use localhost)
git clone http://gitlab.localhost/root/iot-app.git /tmp/iot-app
cd /tmp/iot-app

# Create a confs directory and copy the manifests
mkdir -p confs
cp /path/to/bonus/confs/deployment.yml confs/
cp /path/to/bonus/confs/service.yml confs/
cp /path/to/bonus/confs/ingress.yml confs/

# Push
git add .
git commit -m "Initial app manifests (v1)"
git push origin main
```

#### Step 7: Apply the ArgoCD Application
```bash
kubectl apply -f confs/argocd-app.yml
```

This tells Argo CD to watch the local GitLab repository and sync the manifests to the `dev` namespace.

#### Step 8: Verify Everything

```bash
# Check all three namespaces
kubectl get ns | grep -E "argocd|dev|gitlab"

# Check Argo CD application
kubectl get application -n argocd

# Check app pods
kubectl get pods -n dev

# Check all Ingress
kubectl get ingress --all-namespaces
```

Access the services:
- **GitLab**: http://gitlab.localhost
- **Argo CD**: http://argocd.localhost
- **Application**: http://my-app.localhost

#### Step 9: Demonstrate Version Change (v1 → v2)

1. In GitLab UI, navigate to `iot-app` → `confs/deployment.yml`
2. Click **Edit** 
3. Change `image: bsouhar/my-app:v1` to `image: bsouhar/my-app:v2`
4. Commit the change
5. Watch Argo CD auto-sync (check the Argo CD UI)
6. Verify:
   ```bash
   kubectl get deployment my-app -n dev -o jsonpath='{.spec.template.spec.containers[0].image}'
   # Should output: bsouhar/my-app:v2
   ```

#### Step 10: Clean Up
```bash
k3d cluster delete iot-bonus
```

---

## Useful Commands Reference

| Command | Purpose |
|---------|---------|
| `vagrant up` | Start VMs |
| `vagrant ssh <name>` | SSH into a VM |
| `vagrant halt` | Stop VMs |
| `vagrant destroy -f` | Delete VMs |
| `kubectl get nodes` | List cluster nodes |
| `kubectl get pods [-n namespace]` | List pods |
| `kubectl get svc [-n namespace]` | List services |
| `kubectl get ingress [-n namespace]` | List ingress rules |
| `kubectl get ns` | List namespaces |
| `kubectl describe pod <name>` | Debug a pod |
| `kubectl logs <pod-name>` | View pod logs |
| `k3d cluster list` | List k3d clusters |
| `k3d cluster delete <name>` | Delete k3d cluster |

---

## Troubleshooting

### Vagrant won't start (VT-x/AMD-V not available)
- Enable virtualization in BIOS/UEFI settings
- On Windows: Disable Hyper-V if it conflicts with VirtualBox

### K3s nodes not Ready
- Wait 1-2 minutes after `vagrant up`
- Check logs: `sudo journalctl -u k3s` (server) or `sudo journalctl -u k3s-agent` (worker)

### Can't access apps from host browser
- Add entries to hosts file:
  - **Linux/Mac**: `/etc/hosts`
  - **Windows**: `C:\Windows\System32\drivers\etc\hosts`

### ArgoCD Application stuck in "Unknown" or "Progressing"
- Check ArgoCD server logs: `kubectl logs -n argocd deployment/argocd-server`
- Verify the Git repository URL is accessible from the cluster

### GitLab pods failing (Bonus)
- GitLab needs ~4GB RAM minimum. Check available resources.
- Check events: `kubectl describe pods -n gitlab`
- Some pods take 5-10 minutes to fully start
