# spec.md — NCP NKS CI/CD 실습 스펙

> Spec-driven. 이 문서가 단일 진실. 코드/Terraform은 이 스펙을 구현할 뿐이며,
> 스펙과 어긋나면 코드가 아니라 이 문서를 먼저 고친다.
> 상태: **DRAFT — 구현 시작 전**

---

## 1. 목적 & 범위

### 1.1 목적
NCP 민간 클라우드에서 NKS 클러스터를 IaC로 프로비저닝하고, 컨테이너 앱을
두 가지 CI/CD 방식(NCP 네이티브 / GitHub Actions+ArgoCD)으로 배포·운영하는
전 과정을 손으로 구현한다. 결과물은 재현 가능한 레퍼런스로 남긴다.

### 1.2 In scope
- Terraform으로 VPC~NKS 전체 프로비저닝 (2스택 분리)
- 컨테이너 이미지 빌드 → NCR 푸시 → NKS 배포
- Ingress / LoadBalancer 외부 노출
- CI/CD 트랙 A(NCP 네이티브), 트랙 B(GHA + ArgoCD)
- 롤아웃 / 롤백 / HPA 오토스케일 검증
- 세션별 apply/destroy 운영 및 비용 관리

### 1.3 Out of scope (Non-goals)
- AWS 등 타 CSP와의 비교 (순수 NCP CI/CD 실습)
- 프로덕션급 보안 하드닝 (NetworkPolicy, PSP/PSA, mTLS 등)
- 멀티 클러스터 / 멀티 리전 / DR
- 스테이트풀 워크로드, DB 운영
- 관측 스택 전면 구축 (Prometheus/Grafana/Loki) — metrics-server까지만
- 비용 최적화 자동화 (Spot, Karpenter류)

---

## 2. 제약 & 전제

| 항목 | 값 |
|------|-----|
| 크레딧 | 400,000원, 만료 2027-02 |
| 운영 모델 | bootstrap 상시 / cluster 세션별 apply→destroy |
| Region / Zone | `KR` / `KR-2` (전 리소스 통일) |
| 노드 스펙 | `s2-g2-h50` (2 vCPU / 8 GB / 50 GB), 119원/hr |
| 노드 수 | 2 (고정, autoscale off — HPA 실습 시 노드풀 min/max 조정) |
| k8s 버전 | apply 시점 NKS 지원 최신 −1 |
| Terraform | >= 1.6, provider `NaverCloudPlatform/ncloud` >= 3.x |
| 예산 가드 | 실습일당 8,000~15,000원, 세션 종료 시 필수 `make down` |

---

## 3. 아키텍처

```
                        Internet
                           │
                  ┌────────┴────────┐
                  │  NCP LB (공인)   │  ← Ingress Controller
                  └────────┬────────┘
                     10.0.3.0/24 (LOADB, public)
                           │
   VPC 10.0.0.0/16 ┌───────┴───────────────────────────┐
                   │                                   │
        10.0.1.0/24 (GEN, private)          10.0.2.0/24 (LOADB, private)
        ┌──────────┴──────────┐                    사설 LB
        │  NKS node pool ×2   │
        │  s2-g2-h50          │
        └──────────┬──────────┘
                   │ outbound
             10.0.0.0/24 (GEN, public)
             ┌─────┴─────┐
             │ NAT GW    │ → private route table
             └───────────┘
```

- **bootstrap 스택**: VPC, 서브넷 4종, NCR, login key, ACG 2종, (선택) Object Storage 버킷
- **cluster 스택**: NAT GW + private RT 라우트, NKS 클러스터, NKS 노드풀
- **클러스터 내부** (Terraform 밖): imagePullSecret, Ingress Controller, metrics-server, ArgoCD, 샘플 앱

---

## 4. 리소스 인벤토리

### 4.1 bootstrap (상시)

| # | 리소스 | Terraform 타입 | 파라미터 | 비용 |
|---|--------|---------------|----------|------|
| B1 | VPC | `ncloud_vpc` | cidr `10.0.0.0/16` | 무료 |
| B2 | Subnet 노드 | `ncloud_subnet` | `10.0.1.0/24`, private, `usage_type=GEN` | 무료 |
| B3 | Subnet 사설LB | `ncloud_subnet` | `10.0.2.0/24`, private, `usage_type=LOADB` | 무료 |
| B4 | Subnet 공인 | `ncloud_subnet` | `10.0.0.0/24`, public, `usage_type=GEN` | 무료 |
| B5 | Subnet 공인LB | `ncloud_subnet` | `10.0.3.0/24`, public, `usage_type=LOADB` | 무료 |
| B6 | NCR | **provider 미지원 → 콘솔 생성** | name `nkspracticecr`, endpoint를 이후 var로 주입 | 스토리지 실사용 |
| B7 | Login key | `ncloud_login_key` | name `nks-practice-key` | 무료 |
| B8 | ACG 노드 | `ncloud_access_control_group` (+rules) | 노드간 all, outbound all | 무료 |
| B9 | ACG LB | `ncloud_access_control_group` (+rules) | inbound 80/443 from 0.0.0.0/0 | 무료 |
| B10 | (선택) OBS 버킷 | `ncloud_objectstorage_bucket` | TF remote state | ~무료 |

### 4.2 cluster (세션별)

| # | 리소스 | Terraform 타입 | 파라미터 | 비용(24h) |
|---|--------|---------------|----------|-----------|
| C1 | NAT Gateway | `ncloud_nat_gateway` | 공인 서브넷(B4), zone KR-2 | 수백원 |
| C2 | Route (private→NAT) | `ncloud_route` | private RT, `0.0.0.0/0`→NAT | 무료 |
| C3 | NKS 클러스터 | `ncloud_nks_cluster` | name `nks-practice`, subnet B2, `lb_private_subnet_no`=B3, `lb_public_subnet_no`=B5, zone KR-2, `public_network=false`, k8s ver | ~2,400원 |
| C4 | NKS 노드풀 | `ncloud_nks_node_pool` | name `np-main`, `node_count=2`, `product_code`=s2-g2-h50, login key B7 | ~5,700원 |

### 4.3 클러스터 내부 (helm / kubectl / manifest)

| # | 항목 | 방법 | 비고 |
|---|------|------|------|
| K1 | Namespace | manifest | `demo`, `argocd` |
| K2 | imagePullSecret | `kubectl create secret docker-registry` | NCR endpoint + API key |
| K3 | Ingress Controller | nginx-ingress (helm) | 1차. NCP ALB Ingress는 2차 확장 |
| K4 | metrics-server | helm | HPA 전제 |
| K5 | 샘플 앱 | `k8s/` manifest | 아래 §5 |
| K6 | ArgoCD | 공식 manifest / helm | 트랙 B |

---

## 5. 샘플 애플리케이션

| 항목 | 값 |
|------|-----|
| 언어/프레임워크 | **Python 3.12 + FastAPI + uvicorn** |
| 엔드포인트 | `GET /` → `{"app":"nks-demo","version":"<VER>","pod":"<HOSTNAME>"}` |
| | `GET /healthz` → 200 `{"status":"ok"}` (readiness/liveness 공용) |
| | `GET /work?ms=<n>` → n밀리초 CPU 소모 (HPA 부하테스트용) |
| 버전 주입 | 빌드 시 `APP_VERSION` build-arg → 이미지 env |
| 이미지 | `app/Dockerfile` 멀티스테이지, distroless 또는 slim, non-root |
| 태그 정책 | `<git-short-sha>` + `latest` 병행. 배포 매니페스트는 sha 태그만 참조 |

### 5.1 k8s 매니페스트 (`k8s/`)
- `namespace.yaml`
- `deployment.yaml` — replicas 2, resources requests `100m/128Mi` / limits `500m/256Mi`, readiness `/healthz`, liveness `/healthz`, `APP_VERSION` env
- `service.yaml` — `ClusterIP` (Ingress 뒤) + 별도 `service-lb.yaml`로 `type=LoadBalancer` 실험 (NCP 어노테이션)
- `ingress.yaml` — host 기반 or path 기반, nginx class
- `hpa.yaml` — target CPU 50%, min 2 max 5

### 5.2 NCP LB 어노테이션 (실험 대상, 문서화 필수)
```
service.beta.kubernetes.io/ncloud-load-balancer-internal: "false"
service.beta.kubernetes.io/ncloud-load-balancer-size: "SMALL"
service.beta.kubernetes.io/ncloud-load-balancer-layer-type: "l7" | "l4"
service.beta.kubernetes.io/ncloud-load-balancer-subnet-no: "<B5 subnet no>"
```

---

## 6. CI/CD

### 6.1 트랙 B — GitHub Actions + ArgoCD (우선 구현)

**빌드/푸시** — `.github/workflows/build-deploy.yml`
1. trigger: `push` to `main` (paths: `app/**`)
2. checkout → set `VER=${GITHUB_SHA::7}`
3. docker login NCR (`${NCR_ENDPOINT}`, user=access key, pw=secret key — GH Secrets)
4. `docker build --build-arg APP_VERSION=$VER -t $NCR_ENDPOINT/nks-demo:$VER .`
5. push `:$VER`
6. `k8s/deployment.yaml`의 이미지 태그를 `$VER`로 `sed`/`kustomize edit` → commit & push (GitOps 소스 갱신)

**배포** — ArgoCD
- `Application` CR: repo = 이 레포, path = `k8s/`, dest namespace `demo`, `syncPolicy.automated` (prune + selfHeal)
- 이미지 태그 커밋 감지 → 자동 sync

**GH Secrets 목록**
| Secret | 용도 |
|--------|------|
| `NCR_ENDPOINT` | `xxx.kr.ncr.ntruss.com` |
| `NCP_ACCESS_KEY` / `NCP_SECRET_KEY` | NCR 로그인 |

### 6.2 트랙 A — NCP 네이티브 (2차 구현)
provider가 Source* 전부 지원 → Terraform으로 구성 (별도 스택 `terraform/pipeline`):
- `ncloud_sourcecommit_repository` — 레포 미러 또는 소스 저장소
- `ncloud_sourcebuild_project` — `app/` Dockerfile 빌드 → NCR push, `APP_VERSION` 주입
- `ncloud_sourcedeploy_project` + `_stage` + `_stage_scenario` — NKS 배포 시나리오
- `ncloud_sourcepipeline_project` — SourceBuild → SourceDeploy 연결, 트리거
- 콘솔에서만 되는 부분은 `docs/track-a.md`에 절차 기록

---

## 7. 인증 & 시크릿

| 시크릿 | 저장 위치 | 절대 금지 |
|--------|-----------|-----------|
| NCP Access/Secret Key | 로컬 env var, GH Secrets | git 커밋 |
| kubeconfig | 로컬 `~/.kube/` 또는 `./kubeconfig` (gitignore됨) | git 커밋 |
| TF state | 로컬(gitignore) 또는 OBS 버킷 | git 커밋 |
| login key (pem) | 로컬 (gitignore `*.pem`) | git 커밋 |

`ncp-iam-authenticator` 로 kubeconfig exec 인증. 서브계정 권장(NKS/NCR/VPC 권한).

---

## 8. 마일스톤 & 완료 기준

| M | 내용 | Done 기준 |
|---|------|-----------|
| M0 | 사전 준비 | 인증키 발급, CLI 설치 확인 ✅(terraform/kubectl/helm/ncp-iam-authenticator/docker), env var 인식 |
| M1 | bootstrap 스택 | `terraform apply` 성공, VPC/서브넷 4/login key/ACG 2 생성 확인. NCR 콘솔 생성 + `docker login` 성공 |
| M2 | 샘플 앱 | 로컬 `docker run` → `/`, `/healthz`, `/work` 정상. 이미지 NCR push 성공 |
| M3 | cluster 스택 | `terraform apply` 성공, `kubectl get nodes` Ready 2, NAT 경유 인터넷 OK |
| M4 | 앱 수동 배포 | Ingress Controller + 앱 배포, 외부 URL로 `/` 응답, LB 어노테이션 실험 문서화 |
| M5 | 트랙 B | `app/` 수정 push → GHA 빌드/푸시 → ArgoCD auto-sync → 새 version 반영 확인 |
| M6 | HPA | `/work` 부하 → replica 2→5 스케일아웃, 부하 종료 후 스케일인 확인 |
| M7 | 롤백 | 잘못된 이미지 배포 → `kubectl rollout undo` 또는 ArgoCD history 롤백 확인 |
| M8 | 트랙 A | SourceBuild/Pipeline 구성, commit→배포 자동화 1회 성공, `docs/track-a.md` 완성 |
| M9 | teardown | `make down` 실행 → k8s LB/PVC 정리 → `cluster` destroy 완료, 잔여 리소스 0, 콘솔에서 과금 리소스 없음 확인 |
| M10 | 마무리 | `docs/notes.md`에 배운 점/NCP 특이사항 정리, README 갱신 |

---

## 9. 디렉토리 구조 (목표)

```
ncp-nks-pipeline-practice/
├── spec.md                      ← 이 문서 (단일 진실)
├── CLAUDE.md                    ← 작업 규칙
├── README.md
├── Makefile                     ← up / down / kubeconfig / clean-k8s-lb
├── .github/workflows/
│   └── build-deploy.yml
├── terraform/
│   ├── bootstrap/               ← 상시: VPC/서브넷/login key/ACG
│   ├── cluster/                 ← 세션별: NAT GW/NKS 클러스터/노드풀
│   └── pipeline/                ← 트랙 A: SourceCommit/Build/Deploy/Pipeline
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── service-lb.yaml
│   ├── ingress.yaml
│   └── hpa.yaml
├── argocd/
│   └── application.yaml
└── docs/
    ├── PLAN.md
    ├── runbook.md               ← 세션 시작/종료 절차
    ├── track-a.md               ← NCP 네이티브 파이프라인 기록
    └── notes.md                 ← NCP 특이사항 / 배운 점
```

---

## 10. 네이밍 & 컨벤션

| 대상 | 규칙 | 예 |
|------|------|-----|
| NCP 리소스 | `nks-practice-<역할>` | `nks-practice-vpc`, `nks-practice-cr` |
| Terraform 리소스명 | snake_case, 역할 기준 | `resource "ncloud_subnet" "node"` |
| k8s 리소스 | `nks-demo` (앱), ns `demo` | |
| 이미지 태그 | git short sha (7) | `nks-demo:a1b2c3d` |
| git 커밋 | 간결 명령형, 한글 OK, 마일스톤 태그 `[M3]` 접두 | `[M1] bootstrap VPC/subnet/NCR` |
| git 브랜치 | `main` 직접 (솔로). 큰 변경만 `feat/*` | |

---

## 11. 리스크 & 대응

| 리스크 | 대응 |
|--------|------|
| k8s 생성 LB/PV가 destroy 후 고아 → 과금 지속 | `make down`이 `kubectl delete svc,ingress,pvc --all --all-namespaces` 선행 |
| NAT Gateway 깜빡하고 안 지움 | cluster 스택에 포함 → `terraform destroy`로 같이 제거 |
| TF state / pem / kubeconfig 커밋 사고 | `.gitignore` + 커밋 전 `git status` 확인, pre-commit 훅 검토 |
| NKS 노드풀 min 1 → 완전 정지 불가 | 세션 종료 시 클러스터 자체 destroy |
| 크레딧 조기 소진 | 매일 요금 조회, 세션당 예산 상한, 만료 D-7 알림 |
| k8s 버전 / product_code 값 변경 | apply 직전 data source(`ncloud_nks_versions`, `ncloud_nks_server_products`)로 재확인 |

---

## 12. 오픈 이슈 (구현 전 확정 필요)

- [ ] TF state: 로컬 vs OBS 백엔드 — 1차는 로컬로 시작, M1 이후 판단
- [ ] Ingress: nginx-ingress 우선, NCP ALB Ingress Controller는 M4 확장 과제로
- [ ] 서브계정 생성 여부 — 메인 계정 키로 시작 가능하나 서브계정 권장
- [x] `product_code` — cluster 스택에서 `data.ncloud_nks_server_products` 로 `s2-g2-h50` 필터링해 해결
- [x] NCR — provider 미지원 확인, 콘솔 생성 후 endpoint를 var로 주입
- [ ] 도메인: nip.io / sslip.io 사용 vs LB IP 직접
