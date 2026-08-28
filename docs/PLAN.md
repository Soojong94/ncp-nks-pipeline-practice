# 실습 계획 — 리소스 & 진행 순서

## 0. 원칙

- Terraform 2스택: `bootstrap`(상시, 저비용) / `cluster`(세션별, apply→실습→destroy)
- 클러스터/노드풀/LB/NAT는 매 세션 파괴
- destroy 전 `kubectl delete svc,ingress,pvc --all` 로 k8s가 만든 LB/블록스토리지 고아 방지
- state 파일은 시크릿 포함 → `.gitignore` 처리 (로컬 state로 시작, 필요시 Object Storage 백엔드)

## 1. 사전 준비 (수동, 1회)

| 항목 | 내용 |
|------|------|
| NCP 계정 | 크레딧 확인, 만료일 메모 |
| API 인증키 | 마이페이지 → 인증키 관리 → Access Key / Secret Key 발급 |
| 환경변수 | `NCLOUD_ACCESS_KEY`, `NCLOUD_SECRET_KEY`, `NCLOUD_REGION=KR` |
| CLI 도구 | `terraform`, `kubectl`, `ncp-iam-authenticator`, `helm`, `docker` |
| 리전/존 | Region `KR`, Zone `KR-2` (VPC 기준 통일) |
| k8s 버전 | NKS 지원 최신 - 1 (apply 시점에 확정) |

## 2. bootstrap 스택 (상시 유지, 월 몇백원)

| 리소스 | Terraform | 스펙 | 비용 |
|--------|-----------|------|------|
| VPC | `ncloud_vpc` | `10.0.0.0/16` | 무료 |
| Subnet - 노드 | `ncloud_subnet` | `10.0.1.0/24`, private, `usage_type=GEN` | 무료 |
| Subnet - LB(사설) | `ncloud_subnet` | `10.0.2.0/24`, private, `usage_type=LOADB` | 무료 |
| Subnet - 공인/NAT | `ncloud_subnet` | `10.0.0.0/24`, public, `usage_type=GEN` | 무료 |
| Subnet - LB(공인) | `ncloud_subnet` | `10.0.3.0/24`, public, `usage_type=LOADB` | 무료 |
| NCR 레지스트리 | `ncloud_container_registry` | 1개 | 스토리지 실사용분 (수십원) |
| 로그인 키 | `ncloud_login_key` | 노드 SSH 키페어 | 무료 |
| ACG - 노드 | `ncloud_access_control_group` + rule | 노드간 통신, NAT 아웃바운드 | 무료 |
| ACG - LB | `ncloud_access_control_group` + rule | 80/443 인바운드 | 무료 |
| (선택) Object Storage 버킷 | `ncloud_objectstorage_bucket` | TF state 백엔드용 | 거의 무료 |

Route Table: VPC 생성 시 기본 public/private RT 자동. private RT → NAT Gateway 라우트는 cluster 스택에서 추가.

## 3. cluster 스택 (세션별, apply/destroy)

| 리소스 | Terraform | 스펙 | 비용 (24h 환산) |
|--------|-----------|------|------|
| NAT Gateway | `ncloud_nat_gateway` | 공인 서브넷에 배치, private RT에 라우트 | ~시간당 과금, 하루 수백원 |
| NKS 클러스터 | `ncloud_nks_cluster` | node subnet, `lb_private_subnet_no`, `lb_public_subnet_no`, zone `KR-2`, `public_network=false` | 컨트롤플레인 ~2,400원/일 |
| NKS 노드풀 | `ncloud_nks_node_pool` | `node_count=2`, 소형 서버(2vCPU/4~8GB), autoscale off | ~4,000~7,000원/일 |
| (k8s생성) LB | Service `type=LoadBalancer` 어노테이션 | 사설 or 공인 | ~500원/일 + 트래픽 |

노드 서버 스펙 후보 (요금계산기로 확정):
- Compact 2vCPU/4GB SSD — 최저가, 실습엔 빠듯
- Standard 2vCPU/8GB SSD — 안정적, ArgoCD+앱+빌드 동시 여유

## 4. 클러스터 내부 (Terraform 밖 — helm/kubectl/manifest)

| 항목 | 방법 | 용도 |
|------|------|------|
| imagePullSecret | `kubectl create secret docker-registry` (NCR) | 이미지 pull |
| Ingress Controller | NCP ALB Ingress Controller **또는** nginx-ingress (helm) | 외부 노출 |
| ArgoCD | helm / 공식 manifest | 트랙 B GitOps |
| metrics-server | helm | HPA 동작에 필요 (NKS 기본 미포함일 수 있음) |
| 샘플 앱 | `k8s/` manifest | 배포 대상 |

## 5. CI/CD 파이프라인

### 트랙 A — NCP 네이티브 (콘솔 생성, provider 지원 제한적)
- SourceCommit 저장소 (또는 GitHub 미러 연동)
- SourceBuild: Dockerfile 빌드 → NCR push
- SourcePipeline: SourceBuild 트리거 → 배포 스테이지에서 `kubectl set image` 또는 manifest apply
- 배포 실행 주체: SourcePipeline이 직접 kubectl 못 하면 SourceBuild 컨테이너에서 `ncp-iam-authenticator` + kubectl

### 트랙 B — GitHub Actions + ArgoCD
- `.github/workflows/build.yml`: docker build → NCR push (login: NCR endpoint + access key)
- 이미지 태그를 `k8s/` manifest 또는 kustomize에 커밋 (또는 별도 config repo)
- ArgoCD가 repo 감시 → 자동 sync
- 러너: GitHub-hosted, `ncp-iam-authenticator` 설치 스텝 포함

## 6. 샘플 앱

- 언어: Node.js(Express) 또는 Python(FastAPI) — `/` 200, `/healthz`, 버전 문자열 노출
- `app/Dockerfile` 멀티스테이지
- `k8s/`: namespace, deployment(2 replica, resources requests/limits, readiness/liveness), service, ingress, hpa

## 7. 진행 순서

1. [ ] 사전 준비 (1) — 인증키, CLI, 요금계산기로 노드 스펙 확정
2. [ ] `terraform/bootstrap` 작성 → apply (상시)
3. [ ] 샘플 앱 + Dockerfile + k8s manifest 작성 (로컬 docker로 검증)
4. [ ] `terraform/cluster` 작성 → apply
5. [ ] kubeconfig 발급, imagePullSecret, Ingress Controller, metrics-server 설치
6. [ ] 수동 배포로 앱 동작 확인 (LB 어노테이션, Ingress 경로)
7. [ ] 트랙 B: GitHub Actions 빌드→push, ArgoCD 설치→sync
8. [ ] 트랙 A: SourceBuild/SourcePipeline 구성
9. [ ] 롤아웃/롤백, HPA 부하테스트
10. [ ] `make down` (kubectl 정리 → cluster destroy) 검증
11. [ ] docs에 실습 노트 정리

## 8. 비용 가드레일

- 세션 시작 시각 메모, 종료 시 반드시 `make down`
- 매일 아침 NCP 요금 조회 → 일별 사용액 확인
- NAT Gateway는 cluster 스택에 포함 (destroy 시 같이 제거)
- 크레딧 만료 D-7 알림 설정
- 예상: 실습일당 8,000~15,000원 × 실습일수. 40만원이면 25~40 세션.
