# runbook — 세션 운영 절차

## 세션 시작

```bash
# 0. 환경변수 (셸 프로필 or .env-not-committed)
export NCLOUD_ACCESS_KEY=... NCLOUD_SECRET_KEY=... NCLOUD_REGION=KR

# 1. bootstrap 은 상시 — apply 불필요. output 만 확인
cd terraform/bootstrap && terraform output

# 2. cluster 스택 apply (과금 시작 지점)
cd ../cluster && terraform apply
#    시작 시각 기록: docs/notes.md 하단 로그

# 3. kubeconfig
make kubeconfig          # ncp-iam-authenticator 기반 kubeconfig 생성
kubectl get nodes        # Ready 2 확인
```

## 세션 종료 (필수)

```bash
make down
#  ├─ kubectl delete ingress,svc --all --all-namespaces   (k8s생성 LB 제거)
#  ├─ kubectl delete pvc --all --all-namespaces            (동적 PV 제거)
#  ├─ (LB/PV 실제 삭제까지 대기)
#  └─ cd terraform/cluster && terraform destroy
```

종료 후 체크:
- [ ] NCP 콘솔 → Server / Load Balancer / NAT Gateway / Kubernetes Service 목록 비어있음
- [ ] 요금 조회에서 오늘 사용액 확인, `docs/notes.md` 에 기록
- [ ] bootstrap 리소스(VPC/서브넷/NCR)만 남아있음

## 비상 — Terraform state 꼬임

- k8s가 만든 LB는 TF state에 없음 → 콘솔에서 수동 삭제
- `terraform destroy` 부분 실패 시: 남은 리소스 콘솔 확인 → `terraform state rm` 후 수동 삭제 → 재시도

## 크레딧 모니터링

- 매 세션 종료 시 누적 사용액 기록
- 잔액 < 100,000원 또는 만료 D-7 → 남은 마일스톤 우선순위 재조정
