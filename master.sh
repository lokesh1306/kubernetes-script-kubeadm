#!/bin/sh

source /etc/lsb-release
if [ "$DISTRIB_RELEASE" != "24.04" ]; then
    echo "You're using: ${DISTRIB_DESCRIPTION}"
fi

VERSION=1.30.3
echo "Using version ${VERSION}"

# Fetch architecture
echo "Checking your system architechture"
ARCH=`uname -p`

if [ "${ARCH}" = "aarch64" ]; then 
    echo "You're using ARM64" && ARCH="arm64"
elif [ "${ARCH}" = "x86_64" ]; then
    echo "You're using AMD64" && ARCH="amd64"
else
  echo "You're using neither AMD64 or ARM64 supported by ContainerD"
  exit 1
fi

# Setup auto completion and aliases
echo "Adding aliases"
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
source ~/.bashrc
echo 'Done'

# Packages update and upgrade
echo "Running system upgrade"
sudo apt-get update && sudo apt-get upgrade -y
echo 'Done'

# Install a few packages
echo "Installing required packages"
sudo apt-get install -y apt-transport-https ca-certificates gnupg2 software-properties-common gpg curl wget vim nano 
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
echo 'Done, installed kubelet, kubeadm and kubectl'

# Turn off swap and comment existing swap partitions from fstab
echo "Turning off swap and disabling it in fstab"
sudo swapoff -a
sudo sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab

# Enable kernel modules and enable them 
echo "Adding required kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8.conf
overlay
br_netfilter
EOF
sudo modprobe overlay br_netfilter

# Enable netfilter and packet forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install containerd
echo "Installing containerd"
sudo mkdir -p /etc/containerd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install containerd.io -y

# containerd config file selection
CONFIG_FILE_ARM64="config_arm64.toml"
CONFIG_FILE_AMD64="config_amd64.toml"
ARCH=`uname -p`
if [ "${ARCH}" = "aarch64" ]; then 
    CONFIG_FILE=$CONFIG_FILE_ARM64
elif [ "${ARCH}" = "x86_64" ]; then
    CONFIG_FILE=$CONFIG_FILE_AMD64
fi

# See config file name
echo "Selected configuration file: $CONFIG_FILE"

# Ensure config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Read chosen file and update containerd config file
echo "Adding containerd config"
sudo rm -rf /etc/containerd/config.toml
while IFS= read -r line; do
    echo "$line" | sudo tee -a /etc/containerd/config.toml
done < "$CONFIG_FILE"

# Restart services
echo "Restarting services"
sudo systemctl daemon-reload
sudo systemctl enable containerd
sudo systemctl restart containerd
sudo systemctl enable kubelet && sudo systemctl start kubelet

# Initialize
sudo rm -rf /root/.kube/config 
sudo kubeadm init --config kubeadm-config.yaml --kubernetes-version=${VERSION} --ignore-preflight-errors=NumCPU --skip-token-print --pod-network-cidr 10.1.1.0/24
sudo mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Cilium client
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz*

# Install Cilium
cilium install --version 1.16.0

# Install metrics server
echo "Installing Metrics server"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Join command
echo "Join command for worker node"
kubeadm token create --print-join-command --ttl 0