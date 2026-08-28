# ncp-nks-pipeline-practice

NCP(민간) NKS 소규모 클러스터에 실제 CI/CD 파이프라인을 구축하는 실습.

## 구성

- NKS 클러스터 1개, 노드풀 소형 노드 × 2
- VPC / Subnet (LB 전용 서브넷 별도)
- Container Registry (NCR)
- 샘플 웹앱: Deployment + Service(LoadBalancer) + Ingress

## 문서

| 문서 | 역할 |
|------|------|
| [spec.md](spec.md) | 사양 (단일 진실) — 리소스 인벤토리, 마일스톤, 컨벤션 |
| [docs/CURRICULUM.md](docs/CURRICULUM.md) | **따라하기 가이드** — 모듈 M0~M10, 명령어·검증·teardown·비용 |
| [docs/PLAN.md](docs/PLAN.md) | 배경 / 비용 산정 |
| [docs/runbook.md](docs/runbook.md) | 세션 시작·종료 절차 |
| [CLAUDE.md](CLAUDE.md) | 작업 규칙 |

## 실습 트랙

| 트랙 | 경로 | 내용 |
|------|------|------|
| A | `pipeline/ncp-native/` | SourceCommit → SourceBuild → SourcePipeline → NCR → NKS |
| B | `pipeline/github-actions/` | GitHub Actions + ncp-iam-authenticator + ArgoCD (GitOps) |

## 다뤄볼 것

- NKS 클러스터 / 노드풀 프로비저닝, kubeconfig (`ncp-iam-authenticator`)
- NCR 이미지 빌드·푸시, imagePullSecret
- LB 연동 annotation (`service.beta.kubernetes.io/ncloud-load-balancer-*`)
- Ingress Controller (NCP ALB or nginx)
- Block Storage / NAS CSI, StorageClass
- 배포 자동화: SourcePipeline vs GitHub Actions + ArgoCD
- 롤아웃/롤백, 헬스체크, HPA

## 크레딧 관리 (핵심)

40만원 / 실습기간. **24시간 켜두면 안 됨.**

대략 일 비용 (소형 노드 2대 상시 기준, 검증 필요):

| 항목 | 하루 |
|------|------|
| NKS 컨트롤플레인 | ~2,400원 |
| 워커노드 소형 × 2 | ~4,000~7,000원 |
| Load Balancer | ~500원 |
| Public IP / 블록스토리지 등 | ~500원 |
| **합계** | **약 8,000~11,000원 (Standard 노드면 15,000원+)** |

→ 24/7이면 하루 1~2만원. **세션 단위로 켜고 끄는 게 정석.**

- 노드풀 최소 노드 수는 1 → 완전히 멈추려면 **클러스터 삭제**
- 실습 종료 시: LB → 노드풀/클러스터 → Public IP 순으로 삭제
- 모든 리소스는 git + 셋업 스크립트로 재현 가능하게 (재생성 15~20분)
- 요금 조회에서 일별 사용액 확인, 크레딧 만료일 체크
- 실제 요금은 NCP 요금계산기로 노드 스펙 확정 후 재산정

## 디렉토리

```
app/                     샘플 애플리케이션 소스
k8s/                     매니페스트 (deployment, service, ingress)
pipeline/ncp-native/     트랙 A
pipeline/github-actions/ 트랙 B
docs/                    실습 노트
```
