# CLAUDE.md — 작업 규칙

NCP NKS CI/CD 실습 레포. **Spec-driven** 으로 진행한다.

## 단일 진실

- [`spec.md`](spec.md) 가 유일한 사양서. 모든 코드/Terraform/manifest는 이 스펙의 구현물.
- 구현 중 스펙과 어긋나는 결정이 필요하면 **코드보다 `spec.md` 를 먼저 고치고**, 커밋 메시지에 근거를 남긴다.
- [`docs/PLAN.md`](docs/PLAN.md) 는 배경/비용 산정. [`docs/runbook.md`](docs/runbook.md) 는 세션 운영 절차.

## 진행 방식

- `spec.md` §8 마일스톤(M0~M10) 순서대로. 한 번에 한 마일스톤.
- 마일스톤 착수 전: 해당 섹션의 오픈 이슈(§12) 확인, 없으면 진행.
- 마일스톤 완료 시: Done 기준 충족 확인 → 커밋 `[Mn] ...` → `spec.md` §8 표에 체크.
- **사용자 지시 없이 `terraform apply` / `kubectl apply` / 과금 발생 명령을 실행하지 않는다.** 명령은 제시하고 사용자가 실행.

## 비용 가드레일

- cluster 스택은 세션별 `apply`→실습→`destroy`. 절대 켜놓고 방치하지 않는다.
- 세션 종료는 항상 `bash scripts/down.sh` (k8s LB/PVC 정리 → `terraform destroy`).
- 새 과금 리소스를 스펙에 추가할 때는 24h 환산 비용을 §4 표에 함께 적는다.

## 절대 커밋 금지

`.gitignore` 로 막혀 있지만 재확인:
- `*.tfstate*`, `*.tfvars`, `.terraform/`
- `kubeconfig*`, `*.pem`, `*.key`, `.env`
- NCP Access/Secret Key, NCR 자격증명 — 코드/문서/커밋 어디에도 평문 금지

## 컨벤션 (spec.md §10)

- NCP 리소스: `nks-practice-<역할>` / TF 리소스명: snake_case 역할 기준
- 이미지 태그: git short sha(7). 배포 매니페스트는 sha 태그만 참조
- 커밋: 간결 명령형, 한글 OK, `[Mn]` 접두. 솔로 → `main` 직접 푸시
- 커밋 푸터: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`

## 환경

- Region `KR` / Zone `KR-2` 전 리소스 통일
- 노드: `s2-g2-h50` × 2 고정
- Terraform >= 1.6, provider `NaverCloudPlatform/ncloud` >= 3.x
- 필요 CLI: `terraform`, `kubectl`, `ncp-iam-authenticator`, `helm`, `docker`
