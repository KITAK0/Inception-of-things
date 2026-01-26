# Inception of Things - Part 2

## Overview

Part 2 demonstrates deploying multiple web applications on a Kubernetes cluster using K3s, and exposing them using Kubernetes **Ingress**. This approach allows you to route external HTTP requests to different services and pods inside your cluster, all through a single entry point.

## Project Structure

```
p2/
├── Vagrantfile                # VM setup for the cluster
├── scripts/
│   └── server.sh              # K3s installation script
└── k3s-deploy/
		├── app1.yaml              # Deployment, Service, ConfigMap for App 1
		├── app2.yaml              # Deployment, Service, ConfigMap for App 2
		├── app3.yaml              # Deployment, Service, ConfigMap for App 3
		└── ingress.yml            # Ingress resource for routing
```

## How It Works

### 1. Vagrant & K3s Setup
- The `Vagrantfile` creates a single VM (Debian) and runs `scripts/server.sh` to install K3s (a lightweight Kubernetes distribution).
- K3s runs the Kubernetes control plane and worker on the same VM for simplicity.

### 2. Deploying Applications
- Each `appX.yaml` file defines:
	- A **Deployment** (runs one or more pods with Nginx serving a custom HTML page)
	- A **Service** (ClusterIP, exposes the pods on port 80 inside the cluster)
	- A **ConfigMap** (provides the HTML content)

### 3. Ingress Resource
- The `ingress.yml` file defines an **Ingress** resource with rules:
	- Requests to `app1.com` go to the `app1` service
	- Requests to `app2.com` go to the `app2` service
	- All other requests go to the `app3` service (default)

## How to Run

### 1. Start the VM and K3s
```bash
cd p2
vagrant up
```
This will create the VM, install K3s, and get your cluster ready.

### 2. SSH into the VM
```bash
vagrant ssh
```

### 3. Deploy the Applications and Ingress
```bash
cd /vagrant/k3s-deploy
kubectl apply -f app1.yaml
kubectl apply -f app2.yaml
kubectl apply -f app3.yaml
kubectl apply -f ingress.yml
```

### 4. Test the Ingress

Now, in your browser (after changing /etc/hosts ) or with `curl`, access:
- http://app1.com → App 1
- http://app2.com → App 2
- http://192.168.56.110 or any other host → App 3

## How Ingress Works (Request Flow)

1. **Client** makes a request to `app1.com` (browser/curl)
2. **Ingress Controller** receives the request on port 80
3. Ingress matches the host (`app1.com`) and forwards the request to the **Service** named `app1`
4. The **Service** load-balances the request to one of the **Pods** running App 1
5. The **Pod** (Nginx) serves the HTML page

This is repeated for `app2.com` and the default backend (`app3`).

## Useful Commands

Check all resources:
```bash
kubectl get all
kubectl get ingress
```

Describe ingress for debugging:
```bash
kubectl describe ingress apps-ingress
```

## Troubleshooting

- Make sure the Ingress controller is running (K3s includes Traefik by default)
- Check pod and service status with `kubectl get pods,svc`
- If requests don't route, check `/etc/hosts` and Ingress rules

## References

- [Kubernetes Ingress Docs](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [K3s Documentation](https://docs.k3s.io)
- [Traefik Ingress Controller](https://doc.traefik.io/traefik/)
