#!/usr/bin/env bash
# Windows User 환경변수(setx로 등록)를 현재 셸에 주입.
# Claude Code 세션이 stale한 환경을 물고 있을 때 우회용.
#   사용: source scripts/ncloud-env.sh && terraform -chdir=terraform/bootstrap plan
_ps() { powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('$1','User')" | tr -d '\r\n'; }
export NCLOUD_ACCESS_KEY="$(_ps NCLOUD_ACCESS_KEY)"
export NCLOUD_SECRET_KEY="$(_ps NCLOUD_SECRET_KEY)"
export NCLOUD_REGION="$(_ps NCLOUD_REGION)"
unset -f _ps
[ -n "$NCLOUD_ACCESS_KEY" ] && [ -n "$NCLOUD_SECRET_KEY" ] \
  && echo "ncloud env loaded (region=$NCLOUD_REGION)" \
  || echo "WARN: ncloud env not found in User scope"
