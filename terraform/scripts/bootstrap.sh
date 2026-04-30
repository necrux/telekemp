#!/usr/bin/env bash
set -eo pipefail

# Configure logging.
BOOTSTRAP_LOG='/var/log/telekemp-bootstrap.log'
exec > >(tee $${BOOTSTRAP_LOG} | logger -t user-data -s 2>/dev/console) 2>&1
echo -e "\nStarting user_data script...\n"

# Set node status.
apt-get update
apt-get install -y awscli

if [ "${CONTROL_PLANE}" == "true" ]; then
  aws secretsmanager put-secret-value \
    --secret-id control-plane-connection-info \
    --secret-string '{"Status": "Offline"}'
fi

function dev-role {
cat << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NAMESPACE}
  name: ${DEV_ROLE}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["*"]
EOF
}

function support-role {
cat << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NAMESPACE}
  name: ${SUPPORT_ROLE}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
EOF
}

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
    --pod-network-cidr=$${POD_CIDR} \
    --cri-socket=unix:///run/containerd/containerd.sock

  # Store connection info in Secrets Manager
  CP_ADDRESS=$(awk '/^kubeadm join/ {print $3}' $${BOOTSTRAP_LOG})
  CP_TOKEN=$(awk '/^kubeadm join/ {print $5}' $${BOOTSTRAP_LOG})
  CP_HASH=$(awk '/--discovery-token-ca-cert-hash/ {print $2}' $${BOOTSTRAP_LOG})

  echo "{\"Address\": \"$${CP_ADDRESS}\",\"Token\": \"$${CP_TOKEN}\", \"Hash\": \"$${CP_HASH}\",\"Status\": \"Online\"}" > /kube_connection_info.json

  # Configure Kube Cluster
  KUBE_USER="ubuntu"
  mkdir -p /home/$${KUBE_USER}/.kube
  cp -i /etc/kubernetes/admin.conf /home/$${KUBE_USER}/.kube/config
  chown -R $${KUBE_USER}:$${KUBE_USER} /home/$${KUBE_USER}/.kube

  # Install Calcio
  kubectl apply \
    --kubeconfig=/etc/kubernetes/admin.conf \
    -f https://raw.githubusercontent.com/projectcalico/calico/v$${CALICO_VERSION}/manifests/tigera-operator.yaml

  echo -e "\nWaiting for the Tigera operator...\n"
  while true; do
    if kubectl get deployments --kubeconfig=/etc/kubernetes/admin.conf -A | grep -q "^tigera.* 1/1"; then
      kubectl apply \
        --kubeconfig=/etc/kubernetes/admin.conf \
        -f https://raw.githubusercontent.com/projectcalico/calico/v$${CALICO_VERSION}/manifests/custom-resources.yaml
      break
    else
      sleep 25
  fi
  done

  # Upload connection info -- mark node Online
  aws secretsmanager put-secret-value \
    --secret-id control-plane-connection-info \
    --secret-string file:///kube_connection_info.json

  # Configure Kube Namespace(s)
  kubectl \
    --kubeconfig=/etc/kubernetes/admin.conf \
    create \
    namespace ${NAMESPACE}

  kubectl \
    --kubeconfig=/etc/kubernetes/admin.conf \
    apply -f <(dev-role)
  kubectl \
    --kubeconfig=/etc/kubernetes/admin.conf \
    apply -f <(support-role)

  kubectl \
    --kubeconfig=/etc/kubernetes/admin.conf \
    create rolebinding ${DEV_ROLE}-binding \
    --role=${DEV_ROLE} \
    --namespace=${NAMESPACE}
  kubectl \
    --kubeconfig=/etc/kubernetes/admin.conf \
    create rolebinding ${SUPPORT_ROLE}-binding \
    --role=${SUPPORT_ROLE} \
    --namespace=${NAMESPACE}
else
  echo -e "\nConfiguring Worker Node...\n"

  echo -e "\nWaiting for the Control Plane...\n"
  while true; do
    NODE_STATUS=$(aws secretsmanager get-secret-value --secret-id control-plane-connection-info --query SecretString --output text | jq -r .Status)

    if [ "$${NODE_STATUS}" != "Online" ]; then
      sleep 5
    else
      CP_ADDRESS=$(aws secretsmanager get-secret-value --secret-id control-plane-connection-info --query SecretString --output text | jq -r .Address)
      CP_TOKEN=$(aws secretsmanager get-secret-value --secret-id control-plane-connection-info --query SecretString --output text | jq -r .Token)
      CP_HASH=$(aws secretsmanager get-secret-value --secret-id control-plane-connection-info --query SecretString --output text | jq -r .Hash)

      kubeadm join $${CP_ADDRESS} \
        --token $${CP_TOKEN} \
        --discovery-token-ca-cert-hash $${CP_HASH}
    fi
  done
fi
