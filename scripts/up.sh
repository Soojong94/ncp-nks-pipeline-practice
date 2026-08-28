#!/usr/bin/env bash
# 세션 시작: cluster 스택 apply + kubeconfig 생성.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/ncloud-env.sh

echo "== cluster apply =="
terraform -chdir=terraform/cluster init -input=false
terraform -chdir=terraform/cluster apply -auto-approve

echo "== kubeconfig =="
bash scripts/kubeconfig.sh

echo "== nodes =="
KUBECONFIG="$PWD/kubeconfig" kubectl get nodes -o wide

cat <<'EOF'

다음: bash scripts/addons.sh   (imagePullSecret / ingress-nginx / metrics-server / argocd)
세션 종료: bash scripts/down.sh
EOF
