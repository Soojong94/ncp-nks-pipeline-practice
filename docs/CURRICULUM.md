# CURRICULUM — NCP NKS CI/CD 실습 커리큘럼

> 이 문서 하나만 위에서부터 따라가면 전 과정이 끝나도록 구성.
> `spec.md`(사양) 와 `docs/runbook.md`(세션 운영 절차) 를 참조한다.
> 각 모듈: **목표 → 이론 → 준비물 → 실행 → 검증 → 정리 → 비용**.

---

## 0. 전체 지도

### 0.1 모듈 목록

| # | 모듈 | 과금 | 클러스터 필요 | 예상 소요 |
|---|------|------|--------------|-----------|
| M0 | 준비 (계정/키/CLI/레포) | 무료 | ✗ | 30분 |
| M1 | bootstrap 인프라 (VPC~ACG, NCR) | 무료 | ✗ | 1시간 |
| M2 | 샘플 앱 + 컨테이너 (FastAPI, Docker, NCR push) | 무료 | ✗ | 1시간 |
| M3 | NKS 클러스터 프로비저닝 (NAT/클러스터/노드풀) | **유료** | 생성 | 1.5시간 |
| M4 | 앱 수동 배포 + 외부 노출 (Ingress, LB) | **유료** | ✓ | 2시간 |
| M5 | GitOps: ArgoCD | **유료** | ✓ | 2시간 |
| M6 | CI: GitHub Actions (build→NCR→manifest) | 일부 유료 | 배포검증만 | 2시간 |
| M7 | HPA + 부하테스트 + 노드 오토스케일 | **유료** | ✓ | 1.5시간 |
| M8 | 롤아웃 / 롤백 | **유료** | ✓ | 1시간 |
| M9 | 트랙 A: NCP 네이티브 파이프라인 (Source*) | **유료** | ✓ | 3시간 |
| M10 | 최종 정리 & teardown & 회고 | 무료 | ✗ | 30분 |

### 0.2 세션 묶음 (권장)

클러스터는 세션마다 `apply`→`destroy`. 세션 안에서 여러 모듈을 몰아서 한다.

| 세션 | 모듈 | 과금 | 클러스터 가동 |
|------|------|------|--------------|
| **S1** | M0 · M1 · M2 | 무료 | — |
| **S2** | M3 · M4 · M5 | 유료 | 4~6시간 |
| **S3** | M6 · M7 · M8 | 유료 | 4~6시간 |
| **S4** | M9 | 유료 | 3~4시간 |
| **S5** | M10 | 무료 | — |

- 한 세션을 하루에 다 못 끝내면: 그날 `bash scripts/down.sh` → 다음날 `bash scripts/up.sh` 후 이어서.
  bootstrap·NCR·git에 상태가 다 있으므로 클러스터는 언제든 재생성 가능.
- 집중 스프린트로 2~3일 연속 켜두는 것도 가능 (3일 ≈ 90,000원). 기본은 세션 종료 시 destroy.

### 0.3 비용 가계부

매 유료 세션 종료 시 [비용 로그](#부록-a-비용-로그)에 기록.
예상 총액: **S2~S4 각 2,000~5,000원 × 3 + 실수 버퍼 ≈ 3~5만원.** 크레딧 40만원 → 여유 큼.

### 0.4 반복 절차 (유료 세션 공통)

```
■ 세션 시작
  cd <repo>
  source scripts/ncloud-env.sh
  bash scripts/up.sh          # cluster apply + kubeconfig
  kubectl get nodes          # Ready 2 확인
  bash scripts/addons.sh     # imagePullSecret, ingress, metrics-server, argocd

■ 세션 종료 (반드시)
  bash scripts/down.sh        # k8s LB/PVC 정리 -> cluster destroy
  # NCP 콘솔에서 Server/LB/NAT/NKS 목록 비었는지 확인
  # 비용 로그 기록
```

> `scripts/*.sh` 는 S1(M3 준비)에서 이미 작성돼 있다. (make 미설치 환경이라 셸 스크립트)

---

## M0 — 준비

### 목표
계정·크레딧·인증키·CLI·레포가 모두 준비되어 `terraform plan` 이 인증까지 통과한다.

### 이론 — NCP 인증 모델
- **API 인증키**(Access Key / Secret Key): 모든 API/Terraform 호출에 사용. 마이페이지에서 발급.
- **Sub Account**: IAM 유사. 실습용 계정을 따로 파고 최소 권한만 부여하는 게 정석.
  실습 편의상 메인 계정 키로 시작 가능하나, 권장은 서브계정.
- Terraform ncloud provider 는 자격증명을 **환경변수**(`NCLOUD_ACCESS_KEY`,
  `NCLOUD_SECRET_KEY`, `NCLOUD_REGION`) 또는 provider 블록에서만 읽는다.
  `~/.ncloud/configure` 파일은 **안 읽는다** (ncloud CLI 전용).

### 준비물
- NCP 계정, 크레딧 40만원 (만료 2027-02)

### 실행

1. **크레딧 / 만료일 확인** — 콘솔 → 마이페이지 → 이용 현황 / 크레딧. 만료일 캘린더 등록.

2. **(권장) 서브계정 생성** — 콘솔 → Sub Account
   - 계정 생성 → 정책 연결: `NKSFullAccess`, `NCRFullAccess`(또는 Container Registry),
     `VPCFullAccess`, `ServerFullAccess`, `LoadBalancerFullAccess`, `NATGatewayFullAccess`,
     트랙 A 대비 `SourceCommit/Build/Deploy/PipelineFullAccess`
   - 해당 서브계정으로 API 인증키 발급

3. **API 인증키 발급** — 마이페이지 → 인증키 관리 → 신규 API 인증키 생성

4. **환경변수 등록** (PowerShell):
   ```powershell
   setx NCLOUD_ACCESS_KEY "액세스키"
   setx NCLOUD_SECRET_KEY "시크릿키"
   setx NCLOUD_REGION "KR"
   ```
   - 현재 열린 셸/에디터에는 즉시 반영 안 됨. 이미 실행 중인 Claude Code 세션이
     stale 환경을 물고 있으면 `scripts/ncloud-env.sh` 래퍼로 우회
     (`source scripts/ncloud-env.sh`).

5. **CLI 설치 확인**:
   ```bash
   terraform version    # >= 1.6
   kubectl version --client
   helm version
   ncp-iam-authenticator version
   docker version
   ```

6. **레포 클론** (이미 있음): `git clone https://github.com/Soojong94/ncp-nks-pipeline-practice`

### 검증 (Done)
- [ ] 크레딧 잔액·만료일 확인, 캘린더 등록
- [ ] `terraform version` >= 1.6, kubectl/helm/ncp-iam-authenticator/docker OK
- [ ] `source scripts/ncloud-env.sh` → `ncloud env loaded (region=KR)`
- [ ] `terraform -chdir=terraform/bootstrap init` 성공

### 정리
없음 (과금 리소스 없음)

### 비용
0원

---

## M1 — bootstrap 인프라

### 목표
상시 유지할 네트워크 기반(VPC/서브넷 4종/ACG 2종/login key)을 Terraform 으로 생성하고,
NCR(Container Registry)을 콘솔에서 만든다.

### 이론

**NCP VPC 환경**
- Classic 과 별개. 이 실습은 전부 VPC.
- VPC → Subnet → 리소스. Subnet 은 하나의 Zone 에 종속 (전 리소스 `KR-2` 통일).

**Subnet `usage_type`**
| usage_type | 용도 |
|-----------|------|
| `GEN` | 일반 (서버, NKS 노드) |
| `LOADB` | 로드밸런서 전용 — LB 는 반드시 이 타입 서브넷에 위치 |
| `NATGW` | (별도) |
- AWS 는 LB 가 아무 서브넷에나 붙지만 **NCP 는 LB 전용 서브넷을 미리 파야 한다.**
- 사설 LB / 공인 LB 서브넷을 따로 준비 (`10.0.2.0/24` private, `10.0.3.0/24` public).

**ACG (Access Control Group)**
- AWS Security Group 대응. Stateful. VPC 에 종속.
- 이 provider 에서 규칙은 **set-of-object** 문법 (`inbound = [ { ... } ]`).
- 노드 ACG: VPC 내부 전 통신 + 아웃바운드 전체.
- LB ACG: 0.0.0.0/0 → 80/443.

**Network ACL**
- 서브넷 레벨 stateless 필터. VPC 생성 시 default 하나 자동 → 서브넷에 그대로 사용.

**NCR (Container Registry)**
- **ncloud Terraform provider 에 리소스 없음.** 콘솔에서 생성.
- 뒤에 Object Storage 를 사용. 이미지 저장분만 과금 (수십원 규모).
- endpoint 형태: `<registry-name>.kr.ncr.ntruss.com`

### 준비물
- M0 완료

### 실행

1. **plan 확인**:
   ```bash
   cd <repo> && source scripts/ncloud-env.sh
   terraform -chdir=terraform/bootstrap plan
   ```
   기대: `Plan: 10 to add` (VPC1 + Subnet4 + LoginKey1 + ACG2 + ACGrule2)

2. **apply**:
   ```bash
   terraform -chdir=terraform/bootstrap apply
   ```
   무료 리소스. output 으로 `vpc_no`, `subnet_ids`, `default_private_route_table_no`,
   `acg_node_no`, `acg_lb_no`, `login_key_name` 확인.

3. **login key(pem) 저장** — apply 후:
   ```bash
   terraform -chdir=terraform/bootstrap output -raw login_key > ../nks-practice.pem   # gitignore됨
   ```
   (또는 `ncloud_login_key.private_key` 출력. 노드 SSH 접속용, 실습에선 거의 안 씀)

4. **NCR 콘솔 생성**:
   - 콘솔 → Container Registry → 레지스트리 생성
   - 이름 `nkspracticecr` (소문자), 활성화 상태
   - 생성 후 **공개 여부: Private**, endpoint 복사

5. **NCR 로그인 테스트**:
   ```bash
   docker login <endpoint> -u "$NCLOUD_ACCESS_KEY" -p "$NCLOUD_SECRET_KEY"
   # 또는 API Gateway 서명 방식이면 콘솔의 "인증 정보" 안내대로
   ```

6. **NCR endpoint 를 tfvars 가 아닌 `terraform/cluster` / 앱 배포에서 쓰도록 기록**
   → `docs/ENV.md` 에 `NCR_ENDPOINT=...` 한 줄 남긴다 (커밋 OK, 시크릿 아님).

### 검증 (Done)
- [ ] `terraform -chdir=terraform/bootstrap apply` 성공, 10 리소스
- [ ] 콘솔에서 VPC·서브넷 4개·ACG 2개 확인
- [ ] NCR `nkspracticecr` 생성됨, endpoint 확보
- [ ] `docker login <endpoint>` 성공
- [ ] `git commit` — `.terraform.lock.hcl` 포함, state·pem 제외 확인

### 정리
**destroy 안 함.** bootstrap 은 상시 유지 (전부 무료).

### 비용
0원 (NCR 이미지 저장분만 이후 수십원)

---

## M2 — 샘플 앱 + 컨테이너

### 목표
FastAPI 데모 앱을 만들고 컨테이너로 빌드해 로컬 검증 후 NCR 에 푸시한다.

### 이론
- **이미지 태그 전략**: `:latest` 는 배포에 쓰지 않는다. `:<git-short-sha>` 로 불변 태그.
  배포 매니페스트는 sha 태그만 참조 → 어떤 커밋이 떠 있는지 항상 명확.
- **멀티스테이지 빌드**: 빌드 의존성과 런타임 분리, 이미지 축소, non-root 실행.
- **`APP_VERSION` 주입**: 빌드 시 `--build-arg` → 런타임 env → `/` 응답에 노출.
  배포가 실제로 갱신됐는지 눈으로 확인하는 신호.

### 준비물
- M1 완료 (NCR endpoint)

### 실행

1. **앱 작성** — `app/main.py`, `app/requirements.txt` (커리큘럼 부록 B 코드)
   - `GET /` → `{"app","version","pod"}`
   - `GET /healthz` → 200
   - `GET /work?ms=n` → n ms CPU burn (HPA 용)

2. **Dockerfile** — `app/Dockerfile` (부록 B). `python:3.12-slim` builder + runtime, non-root.

3. **로컬 빌드 & 실행**:
   ```bash
   cd app
   docker build --build-arg APP_VERSION=dev-local -t nks-demo:dev .
   docker run --rm -p 8080:8080 nks-demo:dev
   curl localhost:8080/ ; curl localhost:8080/healthz ; curl "localhost:8080/work?ms=200"
   ```

4. **NCR 푸시**:
   ```bash
   NCR=<endpoint>
   VER=$(git rev-parse --short HEAD)
   docker build --build-arg APP_VERSION=$VER -t $NCR/nks-demo:$VER app/
   docker push $NCR/nks-demo:$VER
   ```

5. **k8s 매니페스트 초안** — `k8s/` (부록 C). 아직 apply 안 함, 파일만.

### 검증 (Done)
- [ ] `docker run` → `/`, `/healthz`, `/work` 정상 응답
- [ ] 이미지가 non-root 로 실행 (`docker inspect` 또는 컨테이너 내 `id`)
- [ ] `docker push $NCR/nks-demo:$VER` 성공, 콘솔 Container Registry 에서 태그 확인
- [ ] `k8s/*.yaml` 작성됨 (`kubectl apply --dry-run=client` 통과)

### 정리
로컬 이미지 정리(`docker image prune`) 정도. NCR 이미지는 유지.

### 비용
0원 (NCR 저장분 무시 가능)

---

## M3 — NKS 클러스터 프로비저닝  ⚠️ 첫 유료

### 목표
`terraform/cluster` 스택으로 NAT Gateway + NKS 클러스터 + 노드풀 2대를 올리고,
kubeconfig 를 발급해 `kubectl get nodes` 가 Ready 2 를 보인다. 세션 종료 시 destroy.

### 이론

**NKS 아키텍처**
- **컨트롤플레인**: NCP 관리. `cluster_type` 이 크기(노드 수 상한)를 결정.
  `SVR.VNKS.STAND.C002.M008...` = 최대 10노드급. 시간당 과금 (~100원/hr).
- **노드풀**: `ncloud_nks_node_pool`. `product_code` 로 서버 스펙, `node_count` 고정 또는 autoscale.
  노드는 **사설 서브넷**에 위치 → 인터넷 아웃바운드에 **NAT Gateway 필수** (이미지 pull).
- **LB 서브넷**: 클러스터 생성 시 `lb_private_subnet_no` (+선택 `lb_public_subnet_no`) 지정.
  이후 Service/Ingress 가 만드는 LB 가 이 서브넷에 뜬다.

**data source 로 스펙 해석**
- `data.ncloud_nks_versions` → 사용 가능한 k8s 버전. "최신 −1" 선택.
- `data.ncloud_nks_server_products` → `s2-g2-h50` 에 해당하는 `product_code` 필터.

**NAT Gateway**
- `ncloud_nat_gateway` (공인 서브넷). private route table 에
  `0.0.0.0/0 → NAT` 라우트(`ncloud_route`) 추가.
- 시간당 과금 + 처리 트래픽 과금 → **cluster 스택에 포함해 destroy 시 같이 제거**.

**인증 (`ncp-iam-authenticator`)**
- kubeconfig 의 `users[].user.exec` 가 `ncp-iam-authenticator token --clusterUuid ...` 호출.
- `NCLOUD_ACCESS_KEY/SECRET_KEY` 환경변수를 exec 가 참조.
- `data.ncloud_nks_kube_config` 또는 CLI 로 kubeconfig 생성.

### 준비물
- M1, M2 완료
- `terraform/cluster/*.tf` 작성 (부록 D — S1 에서 미리 작성)

### 실행

1. **세션 시작**:
   ```bash
   cd <repo> && source scripts/ncloud-env.sh
   ```

2. **cluster plan / apply** (⚠️ 과금 시작. 시각 기록):
   ```bash
   terraform -chdir=terraform/cluster init
   terraform -chdir=terraform/cluster plan
   terraform -chdir=terraform/cluster apply
   ```
   - 클러스터 생성 10~15분, 노드 조인 3~5분.

3. **kubeconfig**:
   ```bash
   bash scripts/kubeconfig.sh
   # 수동: terraform output → clusterUuid → ncp-iam-authenticator 로 kubeconfig 작성
   export KUBECONFIG=$PWD/kubeconfig
   kubectl get nodes -o wide
   ```

4. **NAT 경유 인터넷 확인**:
   ```bash
   kubectl run neti --rm -it --image=busybox --restart=Never -- wget -qO- https://ifconfig.io
   ```

5. **scripts 점검** — `up.sh`/`down.sh`/`kubeconfig.sh`/`addons.sh` 동작 확인 (이미 작성됨)

### 검증 (Done)
- [ ] `terraform -chdir=terraform/cluster apply` 성공
- [ ] `kubectl get nodes` → 2 Ready
- [ ] 파드에서 외부 인터넷 도달 (NAT 동작)
- [ ] `terraform output` 으로 clusterUuid, LB 서브넷 no 확인

### 정리 (세션 종료 시 반드시)
```bash
bash scripts/down.sh
#  kubectl delete ingress,svc --all -A ; kubectl delete pvc --all -A
#  terraform -chdir=terraform/cluster destroy
```
- [ ] 콘솔: Kubernetes Service / Server / NAT Gateway / Load Balancer 목록 비어있음
- [ ] 비용 로그 기록

### 비용
- 컨트롤플레인 ~100원/hr, 노드 2대 ~240원/hr, NAT ~55원/hr → 세션(5h) ≈ 2,000원

---

## M4 — 앱 수동 배포 + 외부 노출  ⚠️ 유료

### 목표
nginx-ingress 로 앱을 외부에 노출하고, NCP LB 가 자동 생성되는 과정을 관찰한다.
Service `type=LoadBalancer` 어노테이션도 직접 실험한다.

### 이론

**NCP LB 연동 (cloud-controller-manager)**
- Service `type=LoadBalancer` → NKS CCM 이 NCP LB 를 자동 생성.
- 제어 어노테이션:
  ```
  service.beta.kubernetes.io/ncloud-load-balancer-internal: "false"      # 공인/사설
  service.beta.kubernetes.io/ncloud-load-balancer-size: "SMALL"
  service.beta.kubernetes.io/ncloud-load-balancer-layer-type: "l4" | "l7"
  service.beta.kubernetes.io/ncloud-load-balancer-subnet-no: "<LB 서브넷 no>"
  ```
- **이 LB 는 Terraform state 에 없다** → destroy 전 `kubectl delete svc` 로 먼저 제거 필수.

**Ingress 전략**
- 1차: `ingress-nginx` (helm) — LB 1개 뒤에 여러 호스트/경로.
- 도메인 없이 테스트: `sslip.io` / `nip.io` (`<ip>.sslip.io` → 해당 IP 로 resolve).
- 2차(선택): NCP ALB Ingress Controller.

### 준비물
- M3 로 클러스터 가동 중
- `k8s/` 매니페스트 (M2)

### 실행

1. `bash scripts/up.sh` (없으면) → `bash scripts/addons.sh` 로:
   - `kubectl create ns demo`
   - imagePullSecret:
     ```bash
     kubectl -n demo create secret docker-registry ncr \
       --docker-server=$NCR_ENDPOINT --docker-username=$NCLOUD_ACCESS_KEY \
       --docker-password=$NCLOUD_SECRET_KEY
     ```
   - ingress-nginx:
     ```bash
     helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
     helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace \
       --set controller.service.annotations."service\.beta\.kubernetes\.io/ncloud-load-balancer-size"=SMALL
     ```

2. **앱 배포**:
   ```bash
   kubectl apply -f k8s/namespace.yaml -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/ingress.yaml
   kubectl -n demo rollout status deploy/nks-demo
   ```

3. **LB IP 확인 & 접속**:
   ```bash
   kubectl -n ingress-nginx get svc     # EXTERNAL-IP 대기
   IP=<external-ip>
   curl http://$IP.sslip.io/
   ```

4. **Service type=LoadBalancer 직접 실험** — `k8s/service-lb.yaml` apply →
   콘솔에서 LB 생성 관찰 → 어노테이션 바꿔보며 l4/l7, 사설/공인 차이 확인 →
   `docs/notes.md` 에 기록 → `kubectl delete -f k8s/service-lb.yaml`.

### 검증 (Done)
- [ ] `curl http://<ip>.sslip.io/` → `{"app":"nks-demo","version":"<sha>",...}`
- [ ] `/healthz` 200, replica 2개에 라운드로빈 (`pod` 값 바뀜)
- [ ] LB 어노테이션 실험 결과 `docs/notes.md` 기록
- [ ] 실험용 LB Service 삭제 확인

### 정리
`bash scripts/down.sh`. **ingress-nginx LB 가 지워졌는지 콘솔 확인** (destroy 가 못 지움).

### 비용
세션(5h) ≈ 2,000~2,500원 (LB 1~2개 추가분 포함)

---

## M5 — GitOps: ArgoCD  ⚠️ 유료

### 목표
ArgoCD 를 설치하고 이 레포의 `k8s/` 를 소스로 하는 Application 을 만들어
Git 커밋 → 자동 sync 되는 흐름을 확인한다.

### 이론
- **GitOps**: 클러스터 상태의 소스는 Git. ArgoCD 가 diff 를 감지해 apply.
- ArgoCD 자체는 클러스터에 산다 → **클러스터 destroy 시 함께 사라짐** →
  매 세션 `bash scripts/addons.sh` 에서 재설치 (설정은 `argocd/` 에 매니페스트로).
- `Application` CR: `source.repoURL`, `source.path=k8s/`, `destination.namespace=demo`,
  `syncPolicy.automated { prune: true, selfHeal: true }`.

### 준비물
- M4 완료 상태 (앱이 수동 배포로 떠 있음 → ArgoCD 로 관리 전환)

### 실행

1. **ArgoCD 설치** (`bash scripts/addons.sh` 에 포함):
   ```bash
   kubectl create ns argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl -n argocd rollout status deploy/argocd-server
   ```

2. **접속** (포트포워딩):
   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8081:443 &
   # 초기 admin 비번:
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
   ```

3. **Application 등록**:
   ```bash
   kubectl apply -f argocd/application.yaml
   argocd app sync nks-demo     # 또는 UI
   ```

4. **자동 sync 테스트**:
   - `k8s/deployment.yaml` 의 replica 2→3 커밋 & push
   - ArgoCD 가 감지 → 자동 apply → `kubectl -n demo get pods` 3개 확인

### 검증 (Done)
- [ ] ArgoCD Application `nks-demo` Synced / Healthy
- [ ] Git push → 수분 내 클러스터 반영 (수동 apply 없이)
- [ ] `argocd/application.yaml` 커밋됨

### 정리
`bash scripts/down.sh`. ArgoCD 는 클러스터와 함께 사라짐 (정상).

### 비용
세션(6h) ≈ 2,500~3,000원

---

## M6 — CI: GitHub Actions

### 목표
`app/` 수정 → GitHub Actions 가 이미지 빌드 → NCR push → `k8s/deployment.yaml`
이미지 태그 갱신 커밋 → ArgoCD 가 배포. 완전 자동 파이프라인(트랙 B) 완성.

### 이론
- 빌드/푸시는 GitHub-hosted runner 에서 (무료 분량 내). 클러스터 불필요.
- 배포는 ArgoCD 담당 → CI 는 kubectl 을 몰라도 됨 (image updater 패턴 = manifest 커밋).
- NCR 로그인: `docker/login-action` 에 endpoint + access/secret key (GH Secrets).
- 태그 갱신 방식: `sed`/`yq`/`kustomize edit set image` 로 `k8s/` 수정 후 커밋.

### 준비물
- M5 완료 (ArgoCD 동작)
- GitHub 레포 Secrets 권한

### 실행

1. **GH Secrets 등록** (레포 Settings → Secrets and variables → Actions):
   | 이름 | 값 |
   |------|-----|
   | `NCR_ENDPOINT` | `nkspracticecr.kr.ncr.ntruss.com` |
   | `NCP_ACCESS_KEY` | 액세스키 |
   | `NCP_SECRET_KEY` | 시크릿키 |

2. **워크플로 작성** — `.github/workflows/build-deploy.yml` (부록 E):
   - trigger: `push` (paths `app/**`)
   - `VER=${GITHUB_SHA::7}`
   - build --build-arg APP_VERSION=$VER → push `$NCR/nks-demo:$VER`
   - `sed -i` 로 `k8s/deployment.yaml` image 태그 → `$VER`, commit & push
     (`[skip ci]` 커밋 메시지로 루프 방지)

3. **E2E 테스트**:
   - `bash scripts/up.sh` (배포 검증용 클러스터)
   - `app/main.py` 문구 수정 → commit & push
   - Actions 통과 → deployment.yaml 커밋 확인 → ArgoCD sync → `curl` 로 새 version 확인

### 검증 (Done)
- [ ] push → Actions 빌드 성공, NCR 에 새 sha 태그
- [ ] `k8s/deployment.yaml` 이미지 태그 자동 커밋됨
- [ ] ArgoCD 가 자동 배포, `curl .../ ` version == 새 sha
- [ ] 무한 커밋 루프 없음

### 정리
`bash scripts/down.sh`. (Actions 는 클러스터 무관하게 계속 동작)

### 비용
세션(3h, 배포검증만) ≈ 1,200~1,500원 + GH Actions 무료분

---

## M7 — HPA + 부하테스트 + 노드 오토스케일  ⚠️ 유료

### 목표
`/work` 부하로 HPA 가 replica 2→5 스케일아웃, 부하 종료 후 스케일인 하는 것을 확인.
노드풀 autoscale 로 노드까지 늘어나는 것도 관찰.

### 이론
- **HPA** 는 metrics-server 필요 (NKS 기본 미포함일 수 있음 → helm 설치).
- `resources.requests.cpu` 기준으로 `targetCPUUtilizationPercentage` 계산.
- **노드 오토스케일**: `ncloud_nks_node_pool` 의 autoscale 블록 (`min`/`max`).
  파드가 Pending 이면 노드 추가. 실습 시 max 3~4 로 제한 (비용).

### 준비물
- M4 배포 상태

### 실행

1. `bash scripts/up.sh` → `bash scripts/addons.sh`
2. **metrics-server**:
   ```bash
   helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
   helm install metrics-server metrics-server/metrics-server -n kube-system \
     --set args={--kubelet-insecure-tls}
   kubectl top nodes
   ```
3. **HPA 적용**: `kubectl apply -f k8s/hpa.yaml` (min 2 max 5, CPU 50%)
4. **부하 생성**:
   ```bash
   # hey 또는 k6. 예: hey
   hey -z 3m -c 50 "http://<ip>.sslip.io/work?ms=150"
   watch kubectl -n demo get hpa,pods
   ```
5. **노드 오토스케일** (선택): 노드풀 autoscale max 4 로 `terraform apply` →
   replica 를 10+ 로 강제 → Pending → 노드 증가 관찰 → 되돌리기.

### 검증 (Done)
- [ ] `kubectl top pods` 값 나옴 (metrics-server OK)
- [ ] 부하 중 HPA `REPLICAS` 2→5
- [ ] 부하 종료 5분 내 스케일인
- [ ] (선택) 노드 2→3+ 후 복귀
- [ ] 결과 `docs/notes.md` 기록

### 정리
`bash scripts/down.sh`. 노드풀 autoscale 설정 원복 확인.

### 비용
세션(4h, 부하 중 노드 증가분) ≈ 2,000~3,500원

---

## M8 — 롤아웃 / 롤백  ⚠️ 유료 (M7 세션에 이어서 가능)

### 목표
롤링 업데이트 동작을 관찰하고, 깨진 배포를 두 가지 방법으로 롤백한다.

### 이론
- **RollingUpdate**: `maxSurge` / `maxUnavailable`. readiness probe 가 게이트.
- readiness 실패 이미지를 배포하면 롤아웃이 멈추고 구버전이 트래픽 유지.
- 롤백: `kubectl rollout undo deploy/nks-demo` (명령형) vs
  ArgoCD: 이전 커밋으로 revert & sync, 또는 App History rollback (GitOps).

### 준비물
- M7 클러스터 가동, 앱 배포 상태

### 실행

1. **정상 롤아웃 관찰**:
   ```bash
   kubectl -n demo set image deploy/nks-demo app=$NCR/nks-demo:<새태그>
   kubectl -n demo rollout status deploy/nks-demo
   kubectl -n demo rollout history deploy/nks-demo
   ```
2. **깨진 배포**:
   - 존재하지 않는 태그 또는 `/healthz` 500 나는 버전 배포
   - 롤아웃 멈춤 확인, 서비스는 계속 정상 (구 파드 유지) — `curl` 로 확인
3. **롤백 A (명령형)**: `kubectl -n demo rollout undo deploy/nks-demo`
4. **롤백 B (GitOps)**: `k8s/deployment.yaml` 이전 태그로 revert 커밋 → ArgoCD sync

### 검증 (Done)
- [ ] 깨진 배포 중에도 `curl /` 무중단
- [ ] `rollout undo` 로 즉시 복구
- [ ] git revert → ArgoCD 로 복구
- [ ] 두 방식 차이 `docs/notes.md` 정리

### 정리
`bash scripts/down.sh`

### 비용
M7 세션에 포함 시 추가 ~1,000원

---

## M9 — 트랙 A: NCP 네이티브 파이프라인  ⚠️ 유료

### 목표
SourceCommit / SourceBuild / SourceDeploy / SourcePipeline 을 Terraform(`terraform/pipeline`)
으로 구성해 커밋 → 빌드 → NKS 배포 자동화를 1회 성공시키고, 트랙 B 와 비교한다.

### 이론

| NCP 서비스 | 역할 | AWS 대응 |
|-----------|------|----------|
| SourceCommit | Git 저장소 | CodeCommit |
| SourceBuild | 빌드 (Docker in Docker) | CodeBuild |
| SourceDeploy | 배포 (NKS/Server/…) | CodeDeploy |
| SourcePipeline | 스테이지 오케스트레이션 | CodePipeline |

- Terraform 리소스: `ncloud_sourcecommit_repository`, `ncloud_sourcebuild_project`,
  `ncloud_sourcedeploy_project` + `_stage` + `_stage_scenario`,
  `ncloud_sourcepipeline_project`.
- SourceBuild 스펙 조회 data source: `ncloud_sourcebuild_project_computes`,
  `_os`, `_os_runtimes`, `_docker_engines`.
- SourceDeploy → NKS: 시나리오에 manifest 경로 / 이미지 치환 방식 지정.

### 준비물
- M2 이미지, M3 클러스터, `terraform/pipeline/*.tf` (부록 F — S4 시작 시 작성)
- SourceBuild 가 NCR 에 push 하려면 빌드 환경변수에 인증키

### 실행

1. `bash scripts/up.sh` (배포 대상 클러스터)
2. `terraform -chdir=terraform/pipeline init && plan && apply`
   - SourceCommit repo 생성 → 코드 push (또는 GitHub 연동)
   - SourceBuild: Dockerfile → NCR push, `APP_VERSION` 주입
   - SourceDeploy: NKS 대상, `k8s/` manifest, 이미지 태그 치환
   - SourcePipeline: build → deploy 연결, SourceCommit push 트리거
3. **E2E**: SourceCommit 에 커밋 → 파이프라인 실행 → NKS 에 반영 → `curl` 확인
4. **비교표 작성** — `docs/track-a.md`:
   - 구성 난이도, Terraform 커버리지, 트리거 유연성, 로그/가시성, 비용, 락인

### 검증 (Done)
- [ ] `terraform -chdir=terraform/pipeline apply` 성공
- [ ] 커밋 1회 → 파이프라인 자동 실행 → 배포 성공
- [ ] `docs/track-a.md` 비교표 완성

### 정리
```bash
bash scripts/down.sh
terraform -chdir=terraform/pipeline destroy   # SourceBuild/Pipeline 도 소액 과금 → destroy
```
- SourceCommit 저장소는 무료 티어면 유지 가능. 판단해서 destroy.

### 비용
세션(4h) ≈ 2,500~3,500원 (빌드 실행 시간 과금 포함)

---

## M10 — 최종 정리 & teardown & 회고

### 목표
모든 과금 리소스를 제거하고, 배운 것을 문서로 남긴다.

### 실행

1. **전체 destroy**:
   ```bash
   bash scripts/down.sh
   terraform -chdir=terraform/pipeline destroy
   # bootstrap 유지 여부 결정:
   #   - 추가 실습 예정 → 유지 (무료)
   #   - 완전 종료 → terraform -chdir=terraform/bootstrap destroy
   ```
2. **잔여 리소스 스캔** — 콘솔 전 서비스 + `NCP Nuke`(설치돼 있음) 로 확인
   ```bash
   # 주의: nuke 는 계정 전체 대상 → dry-run 먼저, 필터 확인 후 사용
   ```
3. **NCR 이미지 정리** — 오래된 sha 태그 삭제 (콘솔)
4. **문서 마무리**:
   - `docs/notes.md`: NCP 특이사항 총정리 (LB 서브넷, CCM 어노테이션, 인증,
     Source* vs AWS, destroy 함정)
   - `README.md`: 최종 결과 / 다이어그램 / 재현 방법
   - `docs/track-a.md`: 트랙 비교 결론
5. **크레딧 회고** — [비용 로그](#부록-a-비용-로그) 합계, 예상 대비.

### 검증 (Done)
- [ ] 콘솔 전 서비스에 과금 리소스 0 (bootstrap 제외 결정 시 VPC/서브넷만)
- [ ] `docs/notes.md`, `README.md`, `docs/track-a.md` 완성
- [ ] 비용 로그 합계 기록
- [ ] 최종 커밋 & 태그 `v1.0`

### 비용
0원

---

## 부록 A — 비용 로그

| 날짜 | 세션 | 클러스터 가동시간 | 당일 사용액 | 누적 | 메모 |
|------|------|------------------|------------|------|------|
| | S2 | | | | |
| | S3 | | | | |
| | S4 | | | | |

크레딧 시작 400,000원 · 만료 2027-02 · 목표 소진 < 100,000원

---

> 부록 B~F 의 파일은 **모두 미리 작성돼 있다** (`terraform validate` / `kustomize build` 통과).
> 각 모듈에서 하는 일은 "작성"이 아니라 "값 치환 + apply + 검증".

## 부록 B — 앱 코드 ✅작성됨

- `app/main.py` — FastAPI, `/` `/healthz` `/work?ms=`
- `app/requirements.txt` — `fastapi==0.115.6`, `uvicorn[standard]==0.34.0`
- `app/Dockerfile` — 멀티스테이지 `python:3.12-slim`, non-root(uid 10001), `APP_VERSION` ARG→ENV, 포트 8080
- `app/.dockerignore`

## 부록 C — k8s 매니페스트 ✅작성됨

- `k8s/kustomization.yaml` — ArgoCD source. `images[].newTag` 를 GHA 가 갱신
- `k8s/{namespace,deployment,service,ingress,hpa}.yaml`
- `k8s/experiments/service-lb.yaml` — M4 수동 실험용, `<LB_PUBLIC_SUBNET_NO>` 치환 필요
- 치환 포인트: `ingress.yaml` host → `<LB_IP>.sslip.io`

## 부록 D — cluster 스택 ✅작성됨 (M3 에서 apply)

- `terraform/cluster/{versions,variables,main,outputs}.tf`
- data: `ncloud_nks_versions`, `ncloud_nks_server_images` (버전/OS 이미지 자동 해석)
- resource: `ncloud_nat_gateway`, `ncloud_route`, `ncloud_nks_cluster`, `ncloud_nks_node_pool`
- bootstrap output 을 `terraform_remote_state` (로컬 state) 로 참조
- ⚠️ apply 전 확인: `var.cluster_type` 유효값 (기본 `...G002`), `var.hypervisor_code` (기본 KVM)

## 부록 E — GitHub Actions ✅작성됨

- `.github/workflows/build-deploy.yml` — push(`app/**`) → build → NCR push → `kustomization.yaml` newTag 커밋(`[skip ci]`)
- 필요 Secrets: `NCR_ENDPOINT`, `NCP_ACCESS_KEY`, `NCP_SECRET_KEY`

## 부록 F — pipeline 스택 ✅작성됨 (M9 에서 apply, live 조정 예상)

- `terraform/pipeline/{versions,variables,main,outputs}.tf`
- `ncloud_sourcecommit_repository` / `_sourcebuild_project` / `_sourcedeploy_project(+stage,scenario)` / `_sourcepipeline_project`
- ⚠️ `validate` 통과했으나 `platform.config` / `build_command` / scenario `manifest` 세부는
  콘솔에서 1회 만들어보고 맞추는 게 빠름. M9 에서 확정.

## 부록 G — 명령어 치트시트

```bash
# 환경
source scripts/ncloud-env.sh

# 세션
bash scripts/up.sh            # cluster apply + kubeconfig
bash scripts/down.sh          # k8s LB/PVC 정리 + cluster destroy
bash scripts/addons.sh        # ns/secret/ingress/metrics-server/argocd

# 확인
kubectl get nodes -o wide
kubectl -n demo get deploy,pods,svc,ingress,hpa
kubectl -n ingress-nginx get svc          # LB EXTERNAL-IP
kubectl top nodes ; kubectl top pods -n demo

# 배포
kubectl -n demo rollout status deploy/nks-demo
kubectl -n demo rollout undo deploy/nks-demo

# 비용 확인: NCP 콘솔 → 마이페이지 → 이용현황
```

## 부록 H — 트러블슈팅

| 증상 | 원인 / 대응 |
|------|------------|
| `terraform` 인증 에러 | `source scripts/ncloud-env.sh` 안 함 / 키 오타 |
| 노드 NotReady | NAT 라우트 누락 → CNI 이미지 pull 실패. private RT 확인 |
| 이미지 pull 실패 (ImagePullBackOff) | imagePullSecret 미생성 / endpoint 오타 / ns 불일치 |
| LB EXTERNAL-IP `<pending>` 지속 | LB 서브넷 `usage_type=LOADB` 아님 / 서브넷 no 어노테이션 오타 / ACG |
| `bash scripts/down.sh` 후에도 과금 | k8s 생성 LB 고아 → 콘솔 수동 삭제. NAT 남음 → destroy 재시도 |
| HPA `<unknown>` | metrics-server 미설치 / `--kubelet-insecure-tls` 누락 |
| ArgoCD sync 안 됨 | repoURL 접근 권한 (public 이므로 OK), path 오타, branch 불일치 |
