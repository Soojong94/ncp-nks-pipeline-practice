#!/usr/bin/env bash
# 클러스터 부가 구성요소 설치 (매 세션 클러스터 재생성 후 실행).
#   imagePullSecret / ingress-nginx / metrics-server / argocd
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/ncloud-env.sh
export KUBECONFIG="$PWD/kubeconfig"

: "${NCR_ENDPOINT:?docs/ENV.md 의 NCR_ENDPOINT 를 환경변수로 지정하세요 (예: export NCR_ENDPOINT=nkspracticecr.kr.ncr.ntruss.com)}"

echo "== namespace + imagePullSecret =="
kubectl apply -f k8s/namespace.yaml
kubectl -n demo delete secret ncr --ignore-not-found
kubectl -n demo create secret docker-registry ncr \
  --docker-server="$NCR_ENDPOINT" \
  --docker-username="$NCLOUD_ACCESS_KEY" \
  --docker-password="$NCLOUD_SECRET_KEY"

echo "== ingress-nginx =="
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/ncloud-load-balancer-size"=SMALL

echo "== metrics-server =="
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install metrics-server metrics-server/metrics-server \
  -n kube-system --set 'args={--kubelet-insecure-tls}'

echo "== argocd =="
kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
kubectl apply -f argocd/application.yaml

echo
echo "ArgoCD admin 비번:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "UI: kubectl -n argocd port-forward svc/argocd-server 8081:443"
echo
echo "LB EXTERNAL-IP 확인: kubectl -n ingress-nginx get svc"
