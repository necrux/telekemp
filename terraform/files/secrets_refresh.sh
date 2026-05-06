#!/usr/bin/env bash

KUBE_ADMIN_FILE='/etc/kubernetes/admin.conf'
SECRETS_STORE='control-plane-secrets'
TMP_SECRET_FILE='/tmp/secret_refresh.txt'
TMP_SECRET_JSON='/tmp/secret_refresh.json'

kubeadm token create --print-join-command > ${TMP_SECRET_FILE}

CP_ADDRESS=$(awk '/^kubeadm join/ {print $3}' ${TMP_SECRET_FILE})
CP_TOKEN=$(awk '/^kubeadm join/ {print $5}' ${TMP_SECRET_FILE})
CP_HASH=$(awk '/^kubeadm join/ {print $7}' ${TMP_SECRET_FILE})

echo "{\"Address\": \"${CP_ADDRESS}\",\"Token\": \"${CP_TOKEN}\", \"Hash\": \"${CP_HASH}\",\"Status\": \"Online\"}" > ${TMP_SECRET_JSON}

aws secretsmanager put-secret-value \
  --secret-id ${SECRETS_STORE} \
  --secret-string file://${TMP_SECRET_JSON}

rm -f ${TMP_SECRET_FILE}
rm -f ${TMP_SECRET_JSON}
