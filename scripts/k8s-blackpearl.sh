#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
OPS_DIR=$(dirname "$SCRIPT_DIR")
ANSIBLE_DIR="${OPS_DIR}/ansible"
CLUSTER_DIR="${OPS_DIR}/k8s/blackpearl"
K0SCTL_PATH="${CLUSTER_DIR}/k0sctl.yaml"

export KUBECONFIG="${CLUSTER_DIR}/kubeconfig.yaml"

# Preparation
ansible-playbook -i "${ANSIBLE_DIR}/inventory/hosts.yaml" "${ANSIBLE_DIR}/playbooks/k8s/blackpearl.yaml"

# Create cluster
k0sctl apply --config="${K0SCTL_PATH}"
k0sctl kubeconfig > "${KUBECONFIG}" --config "${K0SCTL_PATH}"

# Install Flux
kubectl apply --server-side -k "${CLUSTER_DIR}/bootstrap"

# Apply cluster configuration
export KEY_FP=CA5BED07549253B341EA32066AAF42B07E71095E
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: sops-gpg
  namespace: flux-system
type: Opaque
data:
  sops.asc: $(gpg --export-secret-keys --armor ${KEY_FP} | base64)
EOF
sops --config "${OPS_DIR}/.sops.yaml" --decrypt "${CLUSTER_DIR}/flux-system/var/cluster-secrets.sops.yaml" | kubectl apply -f -
kubectl apply -f "${CLUSTER_DIR}/flux-system/var/cluster-settings.yaml"

# Kick off Flux apply this repository
kubectl apply --server-side -k "${CLUSTER_DIR}/flux-system/flux"
