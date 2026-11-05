#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 내가 만든 것(직원·스킬·workspace)만 ZIP 으로 백업합니다. 열쇠·로그인 정보는 넣지 않습니다.
cd "$(dirname "$0")" || exit 1
/bin/bash ./backup_my_company.sh "$@"
