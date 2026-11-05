#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 슬랙 열쇠 3개 + 내 이름 → 연결 시험 → 서버 첫 기동 → 자동시작 (윈도우판 슬랙열쇠_넣기.bat)
cd "$(dirname "$0")" || exit 1
/bin/bash ./env_check.sh --slack-only "$@"
