#!/usr/bin/env bash

if [ -z "$2" ]; then
  echo "Usage: $0 </path/to/key> <address>"
  exit 1
fi

KEY=$1
ADDRESS=$2
PORT=8084

INITIAL_PW=$(ssh -i $1 ubuntu@$2 '(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)')

echo -e "\nLogin Credentials can be found below.\n  The password displayed is the initial, random password set by ArgoCD and should be changed.\n"
echo "User: admin"
echo -e "Password: ${INITIAL_PW}\n"

echo -e "\nOpening port. Go to https://localhost:${PORT} to access ArgoCD.\n\n"

ssh -L ${PORT}:localhost:${PORT} -i $1 ubuntu@$2 \
  "kubectl port-forward service/argocd-server -n argocd ${PORT}:443"
