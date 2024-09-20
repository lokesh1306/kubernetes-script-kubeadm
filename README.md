# Kubeadm Kubernetes Setup Script

## Introduction
This repository provides a shell script designed to automate the process of setting up a Kubernetes cluster on Ubuntu 24.04. The script handles everything from system preparation, package installations, kernel module configuration, and setting up container runtime (Containerd), all the way through to initializing Kubernetes with `kubeadm`, installing Cilium as the CNI (Container Networking Interface), and setting up a metrics server for monitoring.

## Overview
The script provides a robust and streamlined way to get a Kubernetes cluster up and running, especially useful for those who want to skip manual configurations and ensure a consistent setup. The script:
1. Verifies the Ubuntu version.
2. Sets up essential aliases and completions.
3. Updates the system packages.
4. Installs Kubernetes components (`kubelet`, `kubeadm`, `kubectl`).
5. Configures kernel modules and networking for Kubernetes.
6. Installs and configures the container runtime (Containerd).
7. Initializes the Kubernetes control plane using `kubeadm`.
8. Installs Cilium as the CNI.
9. Sets up the Kubernetes metrics server.
10. Generates the `kubeadm` join command for worker nodes.

## Prerequisites
Before running the script, ensure the following:

1. You are running Ubuntu 24.04 
2. You have root or sudo privileges on the machine
3. You have an internet connection, as the script downloads several packages and dependencies

## How to Use

### Clone the Repository
Start by cloning the repository to your local machine:

```bash
git clone https://github.com/lokesh1306/kubernetes-script-kubeadm.git
cd kubernetes-script-kubeadm
```

### Running the Script
Make the script executable:

```bash
chmod +x masher.sh
chmod +x worker.sh (for worker node)
```

Run the script:

```bash
./master.sh
./worker.sh (on worker node)
```

This will execute all the steps outlined in the script, including updating the system, installing required packages, setting up Kubernetes, and initializing the control plane.

**If you want to setup multiple worker nodes, you can run the `worker.sh` script on each worker node and provide the join command generated by the `master.sh` script.**

```bash

### Expected Output
As the script runs, you will see output for each major step, including:
- Architecture detection.
- Confirmation of installed packages.
- Kubernetes control plane initialization.
- Final `kubeadm` join command for worker nodes.

If there are any errors during the process, the script will terminate and display appropriate error messages.

## Customization

### Modify Kubernetes Version
By default, the script installs Kubernetes version `1.30.3`. You can modify this version by changing the `VERSION` variable in the script:

```bash
VERSION=1.30.3
```

### Custom Containerd Configuration
The script includes two default containerd configuration files for ARM64 and AMD64 architectures. You can replace or modify these files (`config_arm64.toml` and `config_amd64.toml`) if you have specific containerd configurations.

