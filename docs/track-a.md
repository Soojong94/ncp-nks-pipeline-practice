# track-a — NCP 네이티브 파이프라인 & 트랙 비교

M9 에서 작성. SourceCommit / SourceBuild / SourceDeploy / SourcePipeline 구성 기록.

## 구성 절차
(작성 예정 — Terraform `terraform/pipeline` + 콘솔 보완분)

## 트랙 A vs 트랙 B 비교

| 항목 | 트랙 A (NCP 네이티브) | 트랙 B (GitHub Actions + ArgoCD) |
|------|----------------------|----------------------------------|
| 구성 난이도 | | |
| Terraform 커버리지 | Source* 리소스 지원 | 워크플로 YAML + ArgoCD manifest |
| 트리거 유연성 | | |
| 로그 / 가시성 | | |
| 배포 방식 | push 기반 | pull 기반 (GitOps) |
| 비용 | 빌드 시간 과금 | GH 무료분 + 클러스터 |
| 벤더 락인 | 높음 | 낮음 |
| 실무 적합 | NCP-only 고객 | 대부분 |

## 결론
(작성 예정)
