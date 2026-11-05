#!/bin/bash
# gplatform 에이전트팀 스타터킷 (맥) — Finder 에서 더블클릭하면 터미널이 열리고 실행됩니다.
# 메일 앱 비밀번호 연결 — 부록 B-2 (윈도우판 메일_연결.bat)
cd "$(dirname "$0")" || exit 1
/bin/bash ./env_check.sh --mail-only "$@"
