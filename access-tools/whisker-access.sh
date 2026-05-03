#!/usr/bin/env bash

if [ -z $@ ]; then
  echo "Usage: $0 </path/to/key> <address>"
  exit 1
fi

KEY=$1
ADDRESS=$2

echo -e "\nOpening port. Go to http://localhost:8081 to access Whisker.\n\n"

ssh -L 8081:localhost:8081 -i $1 ubuntu@$2 \
  "kubectl port-forward -n calico-system svc/whisker 8081:8081"
