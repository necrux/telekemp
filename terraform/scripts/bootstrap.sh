#!/usr/bin/env bash
set -eo pipefail

# Configure logging.
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo -e "\nStarting user_data script...\n"

KUBE_VERSION="${KUBE_VERSION}"
CALICO_VERSION="${CALICO_VERSION}"
POD_CIDR="${POD_CIDR}"
BASE_PACKAGES="${BASE_PACKAGES}"
KUBE_PACKAGES="${KUBE_PACKAGES}"

KUBE_PACKAGES_VERSIONED=()

for package in $${KUBE_PACKAGES}; do
  KUBE_PACKAGES_VERSIONED+="$${package}=${KUBE_VERSION} "
done

# Package prep.
apt-get update
apt-get upgrade -y
apt-get install -y $${BASE_PACKAGES}

mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' \
  | tee /etc/apt/sources.list.d/kubernetes.list

# Generate the default containerd configuration
# Change the pause container to version 3.10 (pause container holds the Linux NS for Kubernetes namespaces)
# Set `SystemdCgroup` to true to use same cgroup drive as kubelet
mkdir -p /etc/containerd

containerd config default \
  | sed 's/SystemdCgroup = false/SystemdCgroup = true/' \
  | sed 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' \
  | tee /etc/containerd/config.toml > /dev/null

systemctl restart containerd

# Kubernetes doesn’t support swap unless explicitly configured under cgroup v2.
swapoff -a ||:

# Install pinned version of Kube.
apt-get update
apt-get install -y $${KUBE_PACKAGES_VERSIONED[@]}
apt-mark hold $${KUBE_PACKAGES_VERSIONED[@]}

# enable IP packet forwarding on the node, allowing the kernel
# to route network traffic between interfaces (pod-to-pod comms)
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/50-cloudimg-settings.conf
sysctl -p /etc/sysctl.d/50-cloudimg-settings.conf

# Configure the control-plane
if [ "${CONTROL_PLANE}" == "true" ]; then
  echo -e "\nConfiguring the Control Plane...\n"

  kubeadm init \
    --ignore-preflight-errors=Mem \
    --pod-network-cidr=$${POD_CIDR} \
    --cri-socket=unix:///run/containerd/containerd.sock

  export KUBECONFIG=/etc/kubernetes/admin.conf
  KUBE_USER="ubuntu"
  mkdir -p /home/$${KUBE_USER}/.kube
  cp -i /etc/kubernetes/admin.conf /home/$${KUBE_USER}/.kube/config
  chown -R $${KUBE_USER}:$${KUBE_USER} /home/$${KUBE_USER}/.kube

  # Install calcio
  kubectl apply -f \
    https://raw.githubusercontent.com/projectcalico/calico/v$${CALICO_VERSION}/manifests/tigera-operator.yaml
fi
