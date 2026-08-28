# ncp-nks-pipeline

NCP(민간) NKS 소규모 클러스터에 CI/CD 파이프라인 실습.
목표: "NCP k8s 생태계가 AWS와 뭐가 다른가"를 손으로 겪어보고 레퍼런스 남기기.

## 구성

- NKS 클러스터 1개, 노드풀 2vCPU/8GB × 2 (또는 micro)
- VPC / Subnet (LB 전용 서브넷 별도)
- Container Registry (NCR)
- 샘플 웹앱: Deployment + Service(LoadBalancer) + Ingress

## 실습 트랙

| 트랙 | 경로 | 내용 |
|------|------|------|
| A | `pipeline/ncp-native/` | SourceCommit → SourceBuild → SourcePipeline → NCR → NKS |
| B | `pipeline/github-actions/` | GitHub Actions + ncp-iam-authenticator + ArgoCD (GitOps) |

## 학습 포인트 (AWS 대비 차이)

- LB 연동: `service.beta.kubernetes.io/ncloud-load-balancer-*` annotation
- 인증: sub account + `ncp-iam-authenticator`, kubeconfig exec
- 스토리지: Block Storage CSI / NAS(NFS) CSI, StorageClass 파라미터
- Ingress: NCP ALB Ingress Controller vs nginx ingress

## 크레딧 관리

- 노드 2대 + LB 상시 ≈ 하루 1만원 안쪽
- 실습 종료 시 LB / Public IP / 노드풀 삭제
- 요금 조회에서 일별 사용액 확인, 크레딧 만료일 체크

## 디렉토리

```
app/                    샘플 애플리케이션 소스
k8s/                    매니페스트 (deployment, service, ingress)
pipeline/ncp-native/    트랙 A
pipeline/github-actions/ 트랙 B
docs/                   실습 노트, 차이점 정리
```
