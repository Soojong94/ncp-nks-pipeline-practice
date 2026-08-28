#!/usr/bin/env bash
# 세션 종료: k8s 가 만든 LB/PVC 정리 후 cluster 스택 destroy.
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/ncloud-env.sh
export KUBECONFIG="$PWD/kubeconfig"

echo "== k8s LB/Ingress/PVC 정리 (terraform state 밖 리소스) =="
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete ingress --all --all-namespaces --ignore-not-found --timeout=120s || true
  kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found || true
  # 위 field-selector 미지원 시 네임스페이스별로:
  for ns in demo ingress-nginx argocd; do
    kubectl -n "$ns" get svc -o name 2>/dev/null | while read -r s; do
      t=$(kubectl -n "$ns" get "$s" -o jsonpath='{.spec.type}')
      [ "$t" = "LoadBalancer" ] && kubectl -n "$ns" delete "$s" --ignore-not-found
    done
  done
  kubectl delete pvc --all --all-namespaces --ignore-not-found --timeout=120s || true
  echo "LB 실제 삭제까지 40초 대기..."
  sleep 40
else
  echo "클러스터 접근 불가 — LB 잔여 여부 콘솔에서 직접 확인 필요"
fi

echo "== cluster destroy =="
terraform -chdir=terraform/cluster destroy -auto-approve

cat <<'EOF'

확인:
  - NCP 콘솔: Kubernetes Service / Server / NAT Gateway / Load Balancer 목록 비었는지
  - docs/CURRICULUM.md 부록 A 비용 로그 기록
EOF
