#!/usr/bin/env bash
set -eo pipefail

BOOTSTRAP_LOG='/var/log/bootstrap.log'
CP_SECRETS="${CP_SECRETS}"
REGION="${REGION}"
VPC_ID="${VPC_ID}"
KUBE_USER="ubuntu"
KUBE_ADMIN_FILE="/etc/kubernetes/admin.conf"
NODE_STATUS="Offline"
KUBE_VERSION="${KUBE_VERSION}"
CALICO_VERSION="${CALICO_VERSION}"
POD_CIDR="${POD_CIDR}"
BASE_PACKAGES="${BASE_PACKAGES}"
KUBE_PACKAGES="${KUBE_PACKAGES}"
GATEWAY="${GATEWAY}"
ISTIO_VERSION="${ISTIO_VERSION}"
TELEPORT="${TELEPORT}"
TELEPORT_VERSION="${TELEPORT_VERSION}"
LB_CONTROLLER="${LB_CONTROLLER}"
ARGOCD="${ARGOCD}"
FLUX="${FLUX}"

KUBE_PACKAGES_VERSIONED=()

# Configure: Logging
exec > >(tee $${BOOTSTRAP_LOG} | logger -t user-data -s 2>/dev/console) 2>&1
echo -e "\nStarting user_data script...\n"

# Set: Control Plane Status
apt-get update
apt-get install -y awscli

if [ "${CONTROL_PLANE}" == "true" ]; then
  aws secretsmanager put-secret-value \
    --secret-id $${CP_SECRETS} \
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

for package in $${KUBE_PACKAGES}; do
  KUBE_PACKAGES_VERSIONED+="$${package}=${KUBE_VERSION} "
done

# Install: Base Packages
apt-get upgrade -y
apt-get install -y $${BASE_PACKAGES}

mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' \
  | tee /etc/apt/sources.list.d/kubernetes.list

# Configure: containerd
## Change the pause container to version 3.10 (holds the Linux NS for k8s namespaces)
## Set `SystemdCgroup` to true to use same cgroup drive as kubelet
mkdir -p /etc/containerd

containerd config default \
  | sed 's/SystemdCgroup = false/SystemdCgroup = true/' \
  | sed 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' \
  | tee /etc/containerd/config.toml > /dev/null

systemctl restart containerd

swapoff -a ||:

# Install: Kube (pinned version)
apt-get update
apt-get install -y $${KUBE_PACKAGES_VERSIONED[@]}
apt-mark hold $${KUBE_PACKAGES_VERSIONED[@]}

## enable IP packet forwarding on the node, allowing the kernel
## to route network traffic between interfaces (pod-to-pod comms)
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/50-cloudimg-settings.conf
sysctl -p /etc/sysctl.d/50-cloudimg-settings.conf

# Configure: control-plane
if [ "${CONTROL_PLANE}" == "true" ]; then
  echo -e "\nConfiguring the Control Plane...\n"

  # Install: Helm
  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
    | gpg --dearmor \
    | tee /usr/share/keyrings/helm.gpg \
    > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" \
    | tee /etc/apt/sources.list.d/helm-stable-debian.list
  apt-get update
  apt-get install -y helm

  # Set: Kube Init
  kubeadm init \
    --pod-network-cidr=$${POD_CIDR} \
    --cri-socket=unix:///run/containerd/containerd.sock

  # Set: Secrets
  CP_ADDRESS=$(awk '/^kubeadm join/ {print $3}' $${BOOTSTRAP_LOG})
  CP_TOKEN=$(awk '/^kubeadm join/ {print $5}' $${BOOTSTRAP_LOG})
  CP_HASH=$(awk '/--discovery-token-ca-cert-hash/ {print $2}' $${BOOTSTRAP_LOG})

  echo "{\"Address\": \"$${CP_ADDRESS}\",\"Token\": \"$${CP_TOKEN}\", \"Hash\": \"$${CP_HASH}\",\"Status\": \"Online\"}" > /kube_connection_info.json

  # Configure: Kube Cluster
  mkdir -p /home/$${KUBE_USER}/.kube
  cp -i $${KUBE_ADMIN_FILE} /home/$${KUBE_USER}/.kube/config
  chown -R $${KUBE_USER}:$${KUBE_USER} /home/$${KUBE_USER}/.kube

  # Install: Calico
  kubectl apply \
    --kubeconfig=$${KUBE_ADMIN_FILE} \
    -f https://raw.githubusercontent.com/projectcalico/calico/v$${CALICO_VERSION}/manifests/tigera-operator.yaml

  echo -e "\nWaiting for the Tigera operator...\n"
  while true; do
    if kubectl get deployments --kubeconfig=$${KUBE_ADMIN_FILE} -A | grep -q "^tigera.* 1/1"; then
      kubectl apply \
        --kubeconfig=$${KUBE_ADMIN_FILE} \
        -f <(curl -s https://raw.githubusercontent.com/projectcalico/calico/v$${CALICO_VERSION}/manifests/custom-resources.yaml | sed 's@cidr:.*@cidr: ${POD_CIDR}@g' | sed 's@encapsulation: VXLANCrossSubnet@encapsulation: VXLAN@g')
      break
    else
      sleep 25
  fi
  done

  # Configure: Secrets Manager
  aws secretsmanager put-secret-value \
    --secret-id $${CP_SECRETS} \
    --secret-string file:///kube_connection_info.json

  # Configure: Kube Namespace & Role(s)
  kubectl \
    --kubeconfig=$${KUBE_ADMIN_FILE} \
    create \
    namespace ${NAMESPACE}

  kubectl \
    --kubeconfig=$${KUBE_ADMIN_FILE} \
    apply -f <(dev-role)
  kubectl \
    --kubeconfig=$${KUBE_ADMIN_FILE} \
    apply -f <(support-role)

  kubectl \
    --kubeconfig=$${KUBE_ADMIN_FILE} \
    create rolebinding ${DEV_ROLE}-binding \
    --role=${DEV_ROLE} \
    --namespace=${NAMESPACE}
  kubectl \
    --kubeconfig=$${KUBE_ADMIN_FILE} \
    create rolebinding ${SUPPORT_ROLE}-binding \
    --role=${SUPPORT_ROLE} \
    --namespace=${NAMESPACE}

  # Install: istio
  if [ "$${GATEWAY}" == "true" ]; then
    export KUBECONFIG=$${KUBE_ADMIN_FILE}
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm repo update

    helm install istio-base istio/base \
      --namespace istio-system \
      --version $${ISTIO_VERSION} \
      --create-namespace
    helm install istiod istio/istiod \
      --namespace istio-system \
      --version $${ISTIO_VERSION}
      #--set global.remotePilotAddress=istiod.istio-system.svc.cluster.local
      #--set pilot.resources.requests.memory=128Mi \
      #--set pilot.resources.requests.cpu=250m
    helm install istio-ingress istio/gateway \
      --namespace istio-ingress \
      --version $${ISTIO_VERSION} \
      --create-namespace
    kubectl label namespace ${NAMESPACE} istio-injection=enabled
  fi

  # Install: AWS Load Balancer Controller
  if [ "$${LB_CONTROLLER}" == "true" ]; then
    export KUBECONFIG=$${KUBE_ADMIN_FILE}
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update

    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set region=${REGION} \
    --set vpcID=${VPC_ID} \
    --set clusterName=${NAMESPACE} \
    --set serviceAccount.create=true
  fi

  # Install: Teleport
  if [ "$${TELEPORT}" == "true" ]; then
    helm repo add teleport https://charts.releases.teleport.dev
    helm repo update

    helm install teleport-cluster teleport/teleport-cluster \
        --namespace teleport-cluster \
        --set clusterName=teleport-cluster.teleport-cluster.svc.cluster.local \
        --set operator.enabled=true \
        --version $${TELEPORT_VERSION} \
        --create-namespace
  fi

  # Install: ArgoCD
  if [ "$${ARGOCD}" == "true" ]; then
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    helm install argocd argo/argo-cd \
      --namespace argocd \
      --create-namespace
    # Save initial password.
    kubectl -n argocd \
      get secret argocd-initial-admin-secret \
      -o jsonpath="{.data.password}" \
      | base64 -d \
      > /root/argocd_initial_password.txt
  fi

  # Install: Flux
  if [ "$${FLUX}" == "true" ]; then
    helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
      --namespace flux-system \
      --create-namespace
  fi

  echo -e "\nThe control-plane has been bootstrapped successfully."

else
  echo -e "\nConfiguring Worker Node...\n"

  echo -e "\nWaiting for the Control Plane...\n"
  while true; do
    if [ "$${NODE_STATUS}" != "Online" ]; then
      sleep 5
    else
      # Join the cluster.
      CP_ADDRESS=$(aws secretsmanager get-secret-value --secret-id $${CP_SECRETS} --query SecretString --output text | jq -r .Address)
      CP_TOKEN=$(aws secretsmanager get-secret-value --secret-id $${CP_SECRETS} --query SecretString --output text | jq -r .Token)
      CP_HASH=$(aws secretsmanager get-secret-value --secret-id $${CP_SECRETS} --query SecretString --output text | jq -r .Hash)

      kubeadm join $${CP_ADDRESS} \
        --token $${CP_TOKEN} \
        --discovery-token-ca-cert-hash $${CP_HASH}
      break
    fi

    NODE_STATUS=$(aws secretsmanager get-secret-value --secret-id $${CP_SECRETS} --query SecretString --output text | jq -r .Status)
  done

  echo -e "\nThe worker has been bootstrapped successfully."
fi
