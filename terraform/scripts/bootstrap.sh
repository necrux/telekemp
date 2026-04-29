#!/usr/bin/env bash
set -eo pipefail

KUBE_VERSION="1.33.11-1.1"
BASE_PACKAGES=(
  "containerd"
  "apt-transport-https"
  "ca-certificates"
  "curl"
  "gpg"
)
KUBE_PACKAGES=(
  "kubelet=${KUBE_VERSION}"
  "kubeadm=${KUBE_VERSION}"
  "kubectl=${KUBE_VERSION}"
)

# Package prep.
apt update
apt upgrade -y
apt install -y "${BASE_PACKAGES[@]}"

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

# Install Kube.
apt-get update
apt install -y "${KUBE_PACKAGES[@]}"

# Hold all Kube packages.
apt-mark hold "${KUBE_PACKAGES[@]}"
