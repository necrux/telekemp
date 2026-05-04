#!/usr/bin/env bash

if [ -z $@ ]; then
  echo "Usage: $0 </path/to/key> <address>"
  exit 1
fi

KEY=$1
ADDRESS=$2
PORT=8081

echo -e "\nOpening port. Go to http://localhost:${PORT} to access Whisker.\n\n"

ssh -L ${PORT}:localhost:${PORT} -i $1 ubuntu@$2 \
  "kubectl port-forward -n calico-system svc/whisker ${PORT}:8081"
