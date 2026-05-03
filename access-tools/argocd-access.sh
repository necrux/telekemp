#!/usr/bin/env bash

if [ -z $@ ]; then
  echo "Usage: $0 </path/to/key> <address>"
  exit 1
fi

KEY=$1
ADDRESS=$2

echo -e "\nOpening port. Go to http://localhost:8082 to access ArgoCD.\n\n"

ssh -L 8082:localhost:8082 -i $1 ubuntu@$2 \
  "kubectl port-forward service/argocd-server -n argocd 8082:443"
