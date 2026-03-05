# Inception of Things - Part 1

## Project Overview

Part 1 of the Inception of Things project sets up a lightweight Kubernetes cluster using **K3s** across two virtual machines. The setup includes:

- **Server Node**: The Kubernetes control plane that manages the cluster
- **Worker Node**: A compute node that runs application workloads

Both machines are created using **Vagrant** and **VirtualBox**, making it easy to set up and tear down the entire infrastructure.

## Prerequisites

Before running Part 1, ensure you have installed:

- **Vagrant**: [Download here](https://www.vagrantup.com/downloads)
- **VirtualBox**: [Download here](https://www.virtualbox.org/wiki/Downloads)
- A terminal/command line interface

Verify installation:
```bash
vagrant --version
vboxmanage --version
```

## Project Structure

```
p1/
├── README.md                 # This file
├── Vagrantfile              # Vagrant configuration for VMs
└── scripts/
    ├── server.sh            # Server node setup script
    └── worker.sh            # Worker node setup script
```

## How It Works

### Vagrantfile
The `Vagrantfile` defines two virtual machines:
- **akheiredS** (Server): IP `192.168.56.110`, runs K3s server
- **akheiredSW** (Worker): IP `192.168.56.111`, joins the K3s cluster

Both VMs use Debian Bullseye with 1GB RAM and 1 CPU.

### server.sh
This script runs on the server VM and:
1. Updates the system packages
2. Installs necessary tools (curl, vim, net-tools)
3. Downloads and installs K3s in server mode
4. Extracts the node token and saves it for the worker to use

### worker.sh
This script runs on the worker VM and:
1. Updates the system packages
2. Installs necessary tools (curl, vim, net-tools, git)
3. Waits for the server node to be ready and provide a token
4. Joins the K3s cluster using the server's IP and token

## Quick Start

### Step 1: Navigate to the Project Directory
```bash
cd p1
```

### Step 2: Start the Vagrant Machines
```bash
vagrant up
```

This command will:
- Create and start both VMs
- Run the provisioning scripts automatically
- Set up the K3s cluster (this may take 2-5 minutes)

### Step 3: Access the Machines
Once setup is complete, you can SSH into the machines:

**Access the Server Node:**
```bash
vagrant ssh akheiredS
```

**Access the Worker Node:**
```bash
vagrant ssh akheiredSW
```

### Step 4: Verify the Cluster
SSH into the server node and check the cluster status:
```bash
vagrant ssh akheiredS
kubectl get nodes -o wide
```

You should see both nodes in a `Ready` state (it may take a minute).

## Common Commands

### View VM Status
```bash
vagrant status
```

### Restart the Cluster
```bash
vagrant reload
```

### Stop the VMs (without deleting them)
```bash
vagrant halt
```

### Destroy the VMs and Start Fresh
```bash
vagrant destroy -f
vagrant up
```

### View Provisioning Logs
```bash
vagrant up --debug
```
## References

- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [K3s Documentation](https://docs.k3s.io)
- [Kubernetes Basics](https://kubernetes.io/docs/concepts/overview/)
