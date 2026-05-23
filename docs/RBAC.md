# RBAC Tests

### Cluster Role -- Example

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: <NAME>
rules:
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
```

### Cluster Role Binding -- Example

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: <NAME>
subjects:
- kind: User
  name: "<USER>"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: <ROLE>
  apiGroup: rbac.authorization.k8s.io
```

### Submit CSR -- Example

```
cat <<EOF >/tmp/sre-csr.json
{
  "CN": "necrux-sre",
  "hosts": [
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "teleport"
    }
  ]
}
EOF

cat <<EOF >/tmp/dev-csr.json
{
  "CN": "necrux-dev",
  "hosts": [
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "teleport"
    }
  ]
}
EOF


rm -rf csr-dir
mkdir -p csr-dir
set -o pipefail
cd csr-dir || exit 1

cfssl genkey ./sre-csr.json | cfssljson -bare sre
cfssl genkey ./dev-csr.json | cfssljson -bare dev
DEV_CSR_CONTENT_64=$(cat dev.csr | base64 -w 0)
SRE_CSR_CONTENT_64=$(cat sre.csr | base64 -w 0)


cat <<EOF >/tmp/kube-csr-dev.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: necrux-dev
spec:
  request: $DEV_CSR_CONTENT_64
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
cat <<EOF >/tmp/kube-csr-sre.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: necrux-sre
spec:
  request: $SRE_CSR_CONTENT_64
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
```