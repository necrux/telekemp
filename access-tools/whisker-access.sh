#!/usr/bin/env bash

KEY=$1
ADDRESS=$2

ssh -L 8081:localhost:8081 -i $1 ubuntu@$2 \
  "kubectl port-forward -n calico-system svc/whisker 8081:8081"
