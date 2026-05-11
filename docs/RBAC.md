# RBAC Tests

### Cluster Role

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

### Cluster Role Binding

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