# ENV — 환경값 (시크릿 아님, 커밋 OK)

실습 진행하며 확정되는 non-secret 참조값. 시크릿(키/비번/kubeconfig)은 절대 여기 넣지 않는다.

| 키 | 값 | 확정 시점 |
|----|-----|-----------|
| Region | `KR` | M0 |
| Zone | `KR-2` | M0 |
| VPC CIDR | `10.0.0.0/16` | M1 |
| NCR_ENDPOINT | `<미정 — nkspracticecr.kr.ncr.ntruss.com 예상>` | M1 |
| VPC_NO | `<terraform output>` | M1 |
| CLUSTER_UUID | `<terraform output>` | M3 |
| LB_PUBLIC_SUBNET_NO | `<terraform output>` | M1 |
| LB_PRIVATE_SUBNET_NO | `<terraform output>` | M1 |

## GitHub Actions Secrets (레포 Settings, 값은 미기재)
- `NCR_ENDPOINT`
- `NCP_ACCESS_KEY`
- `NCP_SECRET_KEY`
