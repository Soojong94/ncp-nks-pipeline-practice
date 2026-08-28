# notes — NCP 특이사항 / 배운 점

실습하며 채운다. 최종적으로 README 와 track-a.md 로 요약.

## 네트워크
- (M1) LB 는 `usage_type=LOADB` 전용 서브넷 필요 — AWS 와 다른 점
- (M1) ACG 규칙은 Terraform 에서 set-of-object 문법 (`inbound = [ {...} ]`)

## NKS
- (M3) 노드는 사설 서브넷 → NAT Gateway 없으면 CNI/이미지 pull 실패
- (M3) 인증: `ncp-iam-authenticator` exec, `NCLOUD_*` 환경변수 참조
- (M4) Service `type=LoadBalancer` → CCM 이 NCP LB 생성. 어노테이션:
  - `ncloud-load-balancer-internal`, `-size`, `-layer-type`(l4/l7), `-subnet-no`
  - 이 LB 는 Terraform state 밖 → destroy 전 `kubectl delete svc` 필수

## CI/CD
- (M6) 트랙 B: ...
- (M9) 트랙 A: SourceCommit/Build/Deploy/Pipeline 전부 Terraform provider 지원

## destroy 함정
- k8s 생성 LB / 동적 PV → `terraform destroy` 가 못 지움
- NAT Gateway 는 cluster 스택에 포함해 같이 제거

## 비용 실측
- (S2) ...
- (S3) ...
- (S4) ...
